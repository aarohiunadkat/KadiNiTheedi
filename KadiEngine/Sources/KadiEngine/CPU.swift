import Foundation

/// Everything a CPU is allowed to know: its own hand plus public information.
public struct CPUView: Sendable {
    public let me: Int
    public let config: GameConfig
    public let hand: [Card]
    public let removedCards: [Card]
    public let auction: Auction
    public let trump: Suit?
    public let bidder: Int?
    public let winningBid: Int?
    public let partnerCalls: [PartnerCall]
    public let revealedPartners: [Int]
    public let occurrenceCounts: [CardIdentity: Int]
    public let currentTrickPlays: [PlayedCard]
    public let completedTricks: [Trick]
    public let handSizes: [Int]
    public let inPlayCounts: [CardIdentity: Int]
}

public enum BidAction: Equatable, Sendable { case pass, bid(Int) }

extension GameState {
    public func cpuView(for player: Int) -> CPUView {
        CPUView(
            me: player, config: config, hand: players[player].hand, removedCards: removedCards,
            auction: auction, trump: trump, bidder: bidder, winningBid: winningBid,
            partnerCalls: partnerCalls, revealedPartners: revealedPartners,
            occurrenceCounts: occurrenceCounts, currentTrickPlays: currentTrick?.plays ?? [],
            completedTricks: completedTricks, handSizes: players.map { $0.hand.count },
            inPlayCounts: inPlayCounts)
    }
}

public func chooseCpuBid<R: RandomNumberGenerator>(_ view: CPUView, using rng: inout R) -> BidAction {
    let auction = view.auction
    let valid = auction.validBids
    if auction.mustBid { return .bid(auction.minimumBid) }
    guard !valid.isEmpty else { return .pass }
    let bidChance = auction.highestBid == nil ? 0.45 : 0.3
    guard Double.random(in: 0..<1, using: &rng) < bidChance else { return .pass }
    // Mostly small raises; occasionally a big jump.
    let steps = Int.random(in: 0..<10, using: &rng) < 8 ? Int.random(in: 0...3, using: &rng) : Int.random(in: 4...10, using: &rng)
    let amount = min(auction.minimumBid + steps * GameConfig.bidIncrement, auction.maxBid)
    return .bid(amount)
}

public func chooseCpuTrump<R: RandomNumberGenerator>(_ view: CPUView, using rng: inout R) -> Suit {
    Suit.allCases.randomElement(using: &rng)!
}

public func chooseCpuPartnerCalls<R: RandomNumberGenerator>(_ view: CPUView, using rng: inout R) -> [PartnerCall] {
    let valid = PartnerRules.validCalls(
        deckCount: view.config.deckCount, inPlayCounts: view.inPlayCounts, bidderHand: view.hand)
    return Array(valid.shuffled(using: &rng).prefix(view.config.partnerCalls))
}

public func chooseCpuCard<R: RandomNumberGenerator>(_ view: CPUView, legal: [Card], using rng: inout R) -> Card {
    legal.randomElement(using: &rng)!
}

extension GameState {
    /// Performs the current actor's move with CPU logic (regardless of the human flag;
    /// the UI controller only calls this for CPU actors). Resolves full tricks.
    @discardableResult
    public mutating func performCPUAction<R: RandomNumberGenerator>(using rng: inout R) throws -> [GameEvent] {
        if awaitingTrickResolution { return try resolveTrick() }
        guard let actor else { throw GameError.wrongPhase }
        let view = cpuView(for: actor)
        switch phase {
        case .bidding:
            switch chooseCpuBid(view, using: &rng) {
            case .pass: try pass(player: actor)
            case .bid(let n): try placeBid(player: actor, amount: n)
            }
        case .trumpSelection:
            try chooseTrump(chooseCpuTrump(view, using: &rng), by: actor)
        case .partnerSelection:
            try choosePartnerCalls(chooseCpuPartnerCalls(view, using: &rng), by: actor)
        case .playing:
            let card = chooseCpuCard(view, legal: legalCards(for: actor), using: &rng)
            return try playCard(player: actor, cardID: card.id)
        default:
            throw GameError.wrongPhase
        }
        return []
    }

    public mutating func autoplayToEnd<R: RandomNumberGenerator>(using rng: inout R) throws {
        while phase != .gameOver { try performCPUAction(using: &rng) }
    }
}
