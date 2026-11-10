import XCTest
@testable import KadiEngine

final class DeckTests: XCTestCase {
    func testDeckSizesAndPoints() {
        let one = createDecks(deckCount: 1), two = createDecks(deckCount: 2)
        XCTAssertEqual(Set(one.map(\.id)).count, 52)
        XCTAssertEqual(Set(two.map(\.id)).count, 104)
        XCTAssertEqual(one.reduce(0) { $0 + $1.points }, 250)
        XCTAssertEqual(two.reduce(0) { $0 + $1.points }, 500)
        XCTAssertEqual(c(.three, .spades).points, 30)
        XCTAssertEqual(c(.three, .hearts).points, 0)
        XCTAssertEqual(c(.five, .clubs).points, 5)
    }

    func testConfigurationTable() {
        let expected: [(Int, Int, Int, Int, Int, Int)] = [ // players, decks, partners, bid, perPlayer, removed
            (4, 1, 1, 150, 13, 0), (5, 1, 1, 120, 10, 2), (6, 2, 2, 300, 17, 2),
            (7, 2, 2, 235, 14, 6), (8, 2, 3, 300, 13, 0), (9, 2, 3, 235, 11, 5),
        ]
        for (n, d, p, b, per, rem) in expected {
            let cfg = GameConfig(playerCount: n)
            XCTAssertEqual(cfg.deckCount, d); XCTAssertEqual(cfg.partnerCalls, p)
            XCTAssertEqual(cfg.openingBid, b); XCTAssertEqual(cfg.cardsPerPlayer, per)
            XCTAssertEqual(cfg.removedCardCount, rem); XCTAssertEqual(cfg.cpuCount, n - 1)
            XCTAssertEqual(getMinimumBid(playerCount: n), b)
        }
    }

    func testDealingForEveryPlayerCount() {
        for n in 4...9 {
            var rng = SeededGenerator(seed: UInt64(n))
            let state = GameState.newGame(playerCount: n, using: &rng)
            let cfg = state.config
            XCTAssertEqual(state.removedCards.count, cfg.removedCardCount)
            XCTAssertTrue(state.removedCards.allSatisfy { $0.rank == .two }, "only 2s removed for \(n) players")
            XCTAssertTrue(state.removedCards.allSatisfy { $0.points == 0 })
            let dealt = state.players.flatMap(\.hand)
            XCTAssertTrue(state.players.allSatisfy { $0.hand.count == cfg.cardsPerPlayer })
            XCTAssertEqual(Set(dealt.map(\.id)).count, dealt.count)
            XCTAssertEqual(dealt.count + state.removedCards.count, cfg.totalCards)
            XCTAssertEqual(dealt.reduce(0) { $0 + $1.points }, cfg.totalPoints)
            XCTAssertEqual(state.phase, .bidding)
            XCTAssertEqual(state.auction.current, (state.dealer + 1) % n)
        }
    }

    func testThreesRemovedOnlyAfterTwosExhausted() {
        var rng = SeededGenerator(seed: 1)
        let (kept, removed) = removeLowCards(from: createDecks(deckCount: 1), count: 6, using: &rng)
        XCTAssertEqual(removed.filter { $0.rank == .two }.count, 4)
        XCTAssertEqual(removed.filter { $0.rank == .three }.count, 2)
        XCTAssertFalse(removed.contains { $0.rank == .three && $0.suit == .spades })
        XCTAssertEqual(kept.count, 46)
    }

    func testShuffleIsPermutationAndSeedReproducible() {
        let deck = createDecks(deckCount: 2)
        var a = SeededGenerator(seed: 42), b = SeededGenerator(seed: 42)
        let s1 = shuffleDeck(deck, using: &a), s2 = shuffleDeck(deck, using: &b)
        XCTAssertEqual(s1.map(\.id), s2.map(\.id))
        XCTAssertEqual(Set(s1.map(\.id)), Set(deck.map(\.id)))
        XCTAssertNotEqual(s1.map(\.id), deck.map(\.id))
    }

    func testDealStartsAfterDealer() {
        let deck = createDecks(deckCount: 1)
        let hands = dealCards(deck, playerCount: 4, dealer: 2)
        XCTAssertEqual(hands[3][0], deck[0])
        XCTAssertEqual(hands[0][0], deck[1])
        XCTAssertEqual(hands[2][0], deck[3])
    }
}
