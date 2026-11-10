import Foundation

/// Deterministic generator (SplitMix64) so tests can replay shuffles and CPU choices.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public func createDecks(deckCount: Int) -> [Card] {
    (1...deckCount).flatMap { deck in
        Suit.allCases.flatMap { suit in
            Rank.allCases.map { Card(deck: deck, rank: $0, suit: suit) }
        }
    }
}

/// Fisher–Yates.
public func shuffleDeck<R: RandomNumberGenerator>(_ deck: [Card], using rng: inout R) -> [Card] {
    var cards = deck
    guard cards.count > 1 else { return cards }
    for i in stride(from: cards.count - 1, to: 0, by: -1) {
        cards.swapAt(i, Int.random(in: 0...i, using: &rng))
    }
    return cards
}

/// Removes `count` low cards: random 2s first, then random 3s (never 3♠).
public func removeLowCards<R: RandomNumberGenerator>(
    from deck: [Card], count: Int, using rng: inout R
) -> (kept: [Card], removed: [Card]) {
    guard count > 0 else { return (deck, []) }
    let twos = shuffleDeck(deck.filter { $0.rank == .two }, using: &rng)
    let threes = shuffleDeck(deck.filter { $0.rank == .three && $0.suit != .spades }, using: &rng)
    let removed = Array((twos + threes).prefix(count))
    precondition(removed.count == count, "Not enough low cards to remove")
    let removedIDs = Set(removed.map(\.id))
    return (deck.filter { !removedIDs.contains($0.id) }, removed)
}

public func chooseRandomDealer<R: RandomNumberGenerator>(playerCount: Int, using rng: inout R) -> Int {
    Int.random(in: 0..<playerCount, using: &rng)
}

/// Deals one card at a time clockwise starting with the player after the dealer.
public func dealCards(_ deck: [Card], playerCount: Int, dealer: Int) -> [[Card]] {
    precondition(deck.count % playerCount == 0, "Deck must divide evenly")
    var hands = [[Card]](repeating: [], count: playerCount)
    for (i, card) in deck.enumerated() {
        hands[(dealer + 1 + i) % playerCount].append(card)
    }
    return hands
}

func sortedHand(_ cards: [Card]) -> [Card] {
    cards.sorted {
        if $0.suit != $1.suit { return $0.suit < $1.suit }
        if $0.rank != $1.rank { return $0.rank > $1.rank }
        return $0.deck < $1.deck
    }
}
