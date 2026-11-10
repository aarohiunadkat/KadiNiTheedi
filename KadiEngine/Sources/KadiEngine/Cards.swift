import Foundation

public enum Suit: Int, CaseIterable, Comparable, Hashable, Codable, Sendable {
    case spades, hearts, diamonds, clubs

    public static func < (a: Suit, b: Suit) -> Bool { a.rawValue < b.rawValue }

    public var name: String {
        switch self {
        case .spades: return "spades"
        case .hearts: return "hearts"
        case .diamonds: return "diamonds"
        case .clubs: return "clubs"
        }
    }

    public var symbol: String {
        switch self {
        case .spades: return "♠"
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        }
    }

    public var isRed: Bool { self == .hearts || self == .diamonds }
}

public enum Rank: Int, CaseIterable, Comparable, Hashable, Codable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace

    public static func < (a: Rank, b: Rank) -> Bool { a.rawValue < b.rawValue }

    public var label: String {
        switch self {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return String(rawValue)
        }
    }

    /// Point value of the rank alone (3♠ is special-cased on `Card`).
    public var points: Int {
        switch self {
        case .ace, .king, .queen, .jack, .ten: return 10
        case .five: return 5
        default: return 0
        }
    }
}

/// Rank + suit, ignoring which physical deck a card came from.
public struct CardIdentity: Hashable, Comparable, Codable, Sendable {
    public let rank: Rank
    public let suit: Suit

    public init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    public static func < (a: CardIdentity, b: CardIdentity) -> Bool {
        (a.suit, a.rank) < (b.suit, b.rank)
    }

    public var label: String { "\(rank.label)\(suit.symbol)" }

    public static let all: [CardIdentity] = Suit.allCases.flatMap { suit in
        Rank.allCases.map { CardIdentity(rank: $0, suit: suit) }
    }
}

public struct Card: Hashable, Identifiable, Codable, Sendable {
    /// Physical deck number (1 or 2). Internal bookkeeping only: never affects
    /// ranking, points, or partner-call occurrence.
    public let deck: Int
    public let rank: Rank
    public let suit: Suit

    public init(deck: Int, rank: Rank, suit: Suit) {
        self.deck = deck
        self.rank = rank
        self.suit = suit
    }

    public var id: String { "deck\(deck)_\(rank.label)_\(suit.name)" }
    public var identity: CardIdentity { CardIdentity(rank: rank, suit: suit) }
    public var points: Int { (rank == .three && suit == .spades) ? 30 : rank.points }
    public var label: String { identity.label }
}
