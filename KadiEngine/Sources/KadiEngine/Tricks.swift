import Foundation

public struct PlayedCard: Hashable, Sendable {
    public let card: Card
    public let player: Int
}

public struct Trick: Sendable {
    public let number: Int          // 1-based
    public let leader: Int
    public let playerCount: Int
    public internal(set) var plays: [PlayedCard] = []
    public internal(set) var winner: Int?

    init(number: Int, leader: Int, playerCount: Int) {
        self.number = number
        self.leader = leader
        self.playerCount = playerCount
    }

    public var leadSuit: Suit? { plays.first?.card.suit }
    public var isComplete: Bool { plays.count == playerCount }
    public var currentPlayer: Int? { isComplete ? nil : (leader + plays.count) % playerCount }
    public var points: Int { plays.reduce(0) { $0 + $1.card.points } }
}

/// Follow suit if possible; otherwise anything.
public func getLegalCards(hand: [Card], leadSuit: Suit?) -> [Card] {
    guard let leadSuit else { return hand }
    let following = hand.filter { $0.suit == leadSuit }
    return following.isEmpty ? hand : following
}

/// Index into `plays` of the winning card. Trump beats everything; otherwise
/// highest lead-suit card; an identical card played later beats the earlier one.
public func determineTrickWinnerIndex(plays: [PlayedCard], trump: Suit) -> Int {
    precondition(!plays.isEmpty)
    let leadSuit = plays[0].card.suit
    let eligibleSuit = plays.contains { $0.card.suit == trump } ? trump : leadSuit
    var best = -1
    for (i, play) in plays.enumerated() where play.card.suit == eligibleSuit {
        if best < 0 || play.card.rank >= plays[best].card.rank { best = i }
    }
    return best
}

public func determineTrickWinner(plays: [PlayedCard], trump: Suit) -> Int {
    plays[determineTrickWinnerIndex(plays: plays, trump: trump)].player
}

public func calculateTrickPoints(_ plays: [PlayedCard]) -> Int {
    plays.reduce(0) { $0 + $1.card.points }
}
