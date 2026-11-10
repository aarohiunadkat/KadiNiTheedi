import SwiftUI

/// Drives the engine: runs CPU turns with pacing, pauses for human input, and
/// publishes only information a player at a real table could see.
@MainActor @Observable
final class GameController {
    enum Screen { case setup, table }

    var screen: Screen = .setup
    var state: GameState?
    var playerCount = 5
    var humanName = ""
    var fastMode = false

    // Presentation state
    var dealing = false
    var winnerHighlight: Int?
    var sweepTarget: Int?
    var toast: String?
    var revealPulse: Int?
    var showResults = false
    /// Debug only: lets CPU logic play the human seat so the whole flow can be screenshotted.
    var debugAutoHuman = false
    var playTick = 0
    var revealTick = 0

    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var pendingPause = 0.0
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    // MARK: Derived (public information only)

    var humanIsActing: Bool {
        guard let s = state, !s.awaitingTrickResolution, !debugAutoHuman else { return false }
        return s.actor == 0
    }

    func name(_ p: Int) -> String { state?.players[p].name ?? "" }

    // MARK: Lifecycle

    func startGame() {
        generation += 1
        isRunning = false
        toastTask?.cancel()
        let trimmed = humanName.trimmingCharacters(in: .whitespaces)
        state = GameState.newGame(playerCount: playerCount, humanName: trimmed.isEmpty ? "You" : trimmed, using: &rng)
        winnerHighlight = nil; sweepTarget = nil; toast = nil; revealPulse = nil
        showResults = false
        dealing = true
        screen = .table
        kick()
    }

    func quitToMenu() {
        generation += 1
        isRunning = false
        toastTask?.cancel()
        state = nil
        toast = nil
        showResults = false
        screen = .setup
    }

    // MARK: Human actions

    func bid(_ amount: Int) { apply { try $0.placeBid(player: 0, amount: amount); return [] } }
    func pass() { apply { try $0.pass(player: 0); return [] } }
    func chooseTrump(_ suit: Suit) { apply { try $0.chooseTrump(suit, by: 0); return [] } }
    func choosePartners(_ calls: [PartnerCall]) { apply { try $0.choosePartnerCalls(calls, by: 0); return [] } }
    func play(_ card: Card) { apply { try $0.playCard(player: 0, cardID: card.id) } }

    private func apply(_ mutation: (inout GameState) throws -> [GameEvent]) {
        guard var s = state, humanIsActing else { return }
        let before = s
        do {
            let events = try mutation(&s)
            state = s
            handle(events: events, before: before, after: s)
            kick()
        } catch {
            showToast("That move isn't allowed.")
        }
    }

    // MARK: Game loop

    private func kick() {
        guard !isRunning else { return }
        isRunning = true
        let gen = generation
        Task {
            await run(gen)
            if gen == generation { isRunning = false }
        }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds * (fastMode ? 0.35 : 1) * 1000)))
    }

    private func run(_ gen: Int) async {
        if dealing {
            await pause(1.5)
            guard gen == generation else { return }
            dealing = false
        }
        while gen == generation {
            guard let s = state else { return }
            if pendingPause > 0 {
                let p = pendingPause
                pendingPause = 0
                await pause(p)
                continue
            }
            if s.phase == .gameOver { return }
            if s.awaitingTrickResolution {
                await resolveCurrentTrick(gen)
                continue
            }
            guard let actor = s.actor, actor != 0 || debugAutoHuman else { return }
            await pause(Double.random(in: 0.6...1.0))
            guard gen == generation, var next = state else { return }
            let before = next
            do {
                let events = try next.performCPUAction(using: &rng)
                state = next
                handle(events: events, before: before, after: next)
            } catch {
                assertionFailure("CPU produced an illegal action: \(error)")
                return
            }
        }
    }

    private func resolveCurrentTrick(_ gen: Int) async {
        guard let s = state, let trick = s.currentTrick, let trump = s.trump else { return }
        let winner = determineTrickWinner(plays: trick.plays, trump: trump)
        winnerHighlight = winner
        await pause(1.3)
        guard gen == generation else { return }
        withAnimation(.easeIn(duration: 0.45)) { sweepTarget = winner }
        await pause(0.55)
        guard gen == generation, var next = state else { return }
        _ = try? next.resolveTrick()
        state = next
        sweepTarget = nil
        winnerHighlight = nil
        if next.phase == .gameOver {
            await pause(0.9)
            guard gen == generation else { return }
            withAnimation { showResults = true }
        }
    }

    // MARK: Event handling

    private func handle(events: [GameEvent], before: GameState, after: GameState) {
        if before.phase == .bidding, let actor = before.actor {
            if after.auction.highestBid != before.auction.highestBid, let amount = after.auction.highestBid {
                showToast("\(name(actor)) bids \(amount)")
            } else {
                showToast("\(name(actor)) passes")
            }
        }

        for event in events {
            switch event {
            case .cardPlayed:
                playTick += 1
            case .partnerRevealed(let player, let call):
                revealPulse = player
                revealTick += 1
                showToast("\(name(player)) is a partner! (\(call.label))", duration: 3)
                pendingPause = max(pendingPause, 1.4)
            case .selfPartnered(let call):
                revealTick += 1
                showToast("\(name(after.bidder ?? 0)) played their own call (\(call.label))", duration: 3)
                pendingPause = max(pendingPause, 1.2)
            default:
                break
            }
        }

        guard before.phase != after.phase else { return }
        switch after.phase {
        case .trumpSelection:
            if let b = after.bidder, let bid = after.winningBid {
                showToast("\(name(b)) wins the bid at \(bid)", duration: 3)
                pendingPause = max(pendingPause, 1.6)
            }
        case .playing:
            let calls = after.partnerCalls.map(\.label).joined(separator: ", ")
            showToast("\(name(after.bidder ?? 0)) calls: \(calls)", duration: 3.5)
            pendingPause = max(pendingPause, 1.8)
        default:
            break
        }
    }

    func showToast(_ text: String, duration: Double = 2) {
        toastTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { toast = text }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
        }
    }
}
