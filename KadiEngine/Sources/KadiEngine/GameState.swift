import Foundation

public enum Phase: Equatable, Sendable {
    case setup, dealing, bidding, trumpSelection, partnerSelection, playing, gameOver
}

public struct Player: Sendable {
    public let id: Int
    public let name: String
    public let isHuman: Bool
    public internal(set) var hand: [Card]
}

public enum GameEvent: Equatable, Sendable {
    case cardPlayed(player: Int, card: Card)
    case partnerRevealed(player: Int, call: PartnerCall)
    /// The bidder satisfied one of their own calls (slot wasted, no bonus).
    case selfPartnered(call: PartnerCall)
    case trickComplete(number: Int)
    case trickResolved(number: Int, winner: Int)
    case gameOver
}

public struct GameState: Sendable {
    public let config: GameConfig
    public private(set) var phase: Phase
    public private(set) var players: [Player]
    /// Public: removed cards are visible before bidding.
    public let removedCards: [Card]
    public let dealer: Int
    public private(set) var auction: Auction
    public private(set) var bidder: Int?
    public private(set) var winningBid: Int?
    public private(set) var trump: Suit?
    public private(set) var partnerCalls: [PartnerCall] = []
    public private(set) var callResolutions: [Int?] = []
    /// Times each rank+suit has been played so far (public information).
    public private(set) var occurrenceCounts: [CardIdentity: Int] = [:]
    /// Revealed partners in reveal order (never includes the bidder).
    public private(set) var revealedPartners: [Int] = []
    public private(set) var currentTrick: Trick?
    public private(set) var completedTricks: [Trick] = []
    /// Only populated in `.gameOver`.
    public private(set) var result: GameResult?
    /// Copies of each rank+suit dealt into hands (removed cards excluded).
    public let inPlayCounts: [CardIdentity: Int]

    // MARK: Setup

    public static func newGame<R: RandomNumberGenerator>(
        playerCount: Int, humanName: String = "You", using rng: inout R
    ) -> GameState {
        let config = GameConfig(playerCount: playerCount)
        let dealer = chooseRandomDealer(playerCount: playerCount, using: &rng)
        let (kept, removed) = removeLowCards(
            from: createDecks(deckCount: config.deckCount), count: config.removedCardCount, using: &rng)
        let shuffled = shuffleDeck(kept, using: &rng)
        let hands = dealCards(shuffled, playerCount: playerCount, dealer: dealer)
        return GameState(config: config, hands: hands, removed: removed, dealer: dealer, humanName: humanName)
    }

    init(config: GameConfig, hands: [[Card]], removed: [Card], dealer: Int, humanName: String = "You") {
        self.config = config
        self.dealer = dealer
        removedCards = removed
        players = hands.enumerated().map { i, hand in
            Player(id: i, name: i == 0 ? humanName : "CPU \(i)", isHuman: i == 0, hand: sortedHand(hand))
        }
        var counts: [CardIdentity: Int] = [:]
        for card in hands.joined() { counts[card.identity, default: 0] += 1 }
        inPlayCounts = counts
        auction = Auction(config: config, dealer: dealer)
        phase = .bidding
    }

    // MARK: Who acts

    /// The player whose decision is needed now (nil while a full trick awaits resolution or game over).
    public var actor: Int? {
        switch phase {
        case .bidding: return auction.current
        case .trumpSelection, .partnerSelection: return bidder
        case .playing: return currentTrick?.currentPlayer
        default: return nil
        }
    }

    public var awaitingTrickResolution: Bool { phase == .playing && currentTrick?.isComplete == true }

    // MARK: Bidding

    public mutating func placeBid(player: Int, amount: Int) throws {
        guard phase == .bidding else { throw GameError.wrongPhase }
        try auction.placeBid(player: player, amount: amount)
        finishAuctionIfComplete()
    }

    public mutating func pass(player: Int) throws {
        guard phase == .bidding else { throw GameError.wrongPhase }
        try auction.pass(player: player)
        finishAuctionIfComplete()
    }

    private mutating func finishAuctionIfComplete() {
        guard auction.isComplete, let b = auction.highestBidder, let bid = auction.highestBid else { return }
        bidder = b
        winningBid = bid
        phase = .trumpSelection
    }

    // MARK: Trump & partners

    public mutating func chooseTrump(_ suit: Suit, by player: Int) throws {
        guard phase == .trumpSelection else { throw GameError.wrongPhase }
        guard player == bidder else { throw GameError.notYourTurn }
        trump = suit
        phase = .partnerSelection
    }

    public func validPartnerCalls() -> [PartnerCall] {
        guard let bidder else { return [] }
        return PartnerRules.validCalls(
            deckCount: config.deckCount, inPlayCounts: inPlayCounts, bidderHand: players[bidder].hand)
    }

    public mutating func choosePartnerCalls(_ calls: [PartnerCall], by player: Int) throws {
        guard phase == .partnerSelection, let bidder else { throw GameError.wrongPhase }
        guard player == bidder else { throw GameError.notYourTurn }
        try PartnerRules.validate(
            calls, required: config.partnerCalls, deckCount: config.deckCount,
            inPlayCounts: inPlayCounts, bidderHand: players[bidder].hand)
        partnerCalls = calls
        callResolutions = Array(repeating: nil, count: calls.count)
        currentTrick = Trick(number: 1, leader: bidder, playerCount: config.playerCount)
        phase = .playing
    }

    // MARK: Playing

    public func legalCards(for player: Int) -> [Card] {
        getLegalCards(hand: players[player].hand, leadSuit: currentTrick?.leadSuit)
    }

    @discardableResult
    public mutating func playCard(player: Int, cardID: String) throws -> [GameEvent] {
        guard phase == .playing, var trick = currentTrick, !trick.isComplete else { throw GameError.wrongPhase }
        guard trick.currentPlayer == player else { throw GameError.notYourTurn }
        guard let idx = players[player].hand.firstIndex(where: { $0.id == cardID }) else {
            throw GameError.cardNotInHand
        }
        let card = players[player].hand[idx]
        guard legalCards(for: player).contains(card) else { throw GameError.illegalCard }

        players[player].hand.remove(at: idx)
        trick.plays.append(PlayedCard(card: card, player: player))
        currentTrick = trick

        var events: [GameEvent] = [.cardPlayed(player: player, card: card)]

        // Occurrence is chronological per rank+suit, regardless of physical deck.
        let occurrence = (occurrenceCounts[card.identity] ?? 0) + 1
        occurrenceCounts[card.identity] = occurrence
        let match = PartnerCall(identity: card.identity, occurrence: occurrence)
        for (i, call) in partnerCalls.enumerated() where call == match {
            callResolutions[i] = player
            if player == bidder {
                events.append(.selfPartnered(call: call))
            } else if !revealedPartners.contains(player) {
                revealedPartners.append(player)
                events.append(.partnerRevealed(player: player, call: call))
            }
        }

        if trick.isComplete { events.append(.trickComplete(number: trick.number)) }
        return events
    }

    @discardableResult
    public mutating func resolveTrick() throws -> [GameEvent] {
        guard phase == .playing, var trick = currentTrick, trick.isComplete, let trump else {
            throw GameError.wrongPhase
        }
        let winner = determineTrickWinner(plays: trick.plays, trump: trump)
        trick.winner = winner
        completedTricks.append(trick)
        var events: [GameEvent] = [.trickResolved(number: trick.number, winner: winner)]

        if completedTricks.count == config.cardsPerPlayer {
            currentTrick = nil
            result = Scoring.compute(
                playerCount: config.playerCount, bidder: bidder!, winningBid: winningBid!, trump: trump,
                calls: partnerCalls, callResolutions: callResolutions, tricks: completedTricks)
            phase = .gameOver
            events.append(.gameOver)
        } else {
            currentTrick = Trick(number: trick.number + 1, leader: winner, playerCount: config.playerCount)
        }
        return events
    }
}
