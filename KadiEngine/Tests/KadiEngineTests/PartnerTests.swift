import XCTest
@testable import KadiEngine

final class PartnerTests: XCTestCase {
    func testOneDeckCannotCallOwnCard() {
        let hand = [c(.ace, .hearts)]
        let counts: [CardIdentity: Int] = [CardIdentity(rank: .ace, suit: .hearts): 1, CardIdentity(rank: .king, suit: .hearts): 1]
        let valid = PartnerRules.validCalls(deckCount: 1, inPlayCounts: counts, bidderHand: hand)
        XCTAssertEqual(valid, [PartnerCall(rank: .king, suit: .hearts)])
        XCTAssertThrowsError(try PartnerRules.validate([PartnerCall(rank: .ace, suit: .hearts)], required: 1, deckCount: 1, inPlayCounts: counts, bidderHand: hand))
    }

    func testTwoDeckCanCallHeldCardAndBothOccurrences() throws {
        let hand = [c(.ace, .hearts)]
        let counts: [CardIdentity: Int] = [CardIdentity(rank: .ace, suit: .hearts): 2]
        let calls = [PartnerCall(rank: .ace, suit: .hearts, occurrence: 1), PartnerCall(rank: .ace, suit: .hearts, occurrence: 2)]
        try PartnerRules.validate(calls, required: 2, deckCount: 2, inPlayCounts: counts, bidderHand: hand)
        XCTAssertThrowsError(try PartnerRules.validate([calls[0], calls[0]], required: 2, deckCount: 2, inPlayCounts: counts, bidderHand: hand), "same occurrence twice")
        XCTAssertThrowsError(try PartnerRules.validate([calls[0]], required: 2, deckCount: 2, inPlayCounts: counts, bidderHand: hand), "wrong count")
    }

    func testRemovedCardsCannotBeCalled() {
        // One 2♥ copy removed -> only first occurrence; both removed -> none.
        let two = CardIdentity(rank: .two, suit: .hearts)
        let one = PartnerRules.validCalls(deckCount: 2, inPlayCounts: [two: 1], bidderHand: [])
        XCTAssertEqual(one, [PartnerCall(identity: two, occurrence: 1)])
        XCTAssertTrue(PartnerRules.validCalls(deckCount: 2, inPlayCounts: [:], bidderHand: []).isEmpty)
    }

    func testRealDealOffersOnlyExistingOccurrences() {
        for seed in 0..<20 {
            var rng = SeededGenerator(seed: UInt64(seed))
            var s = GameState.newGame(playerCount: 7, using: &rng)
            while s.phase == .bidding { try! s.performCPUAction(using: &rng) }
            try! s.chooseTrump(.hearts, by: s.bidder!)
            let removed = Dictionary(grouping: s.removedCards, by: \.identity).mapValues(\.count)
            for call in s.validPartnerCalls() {
                XCTAssertLessThanOrEqual(call.occurrence, 2 - (removed[call.identity] ?? 0))
            }
        }
    }

    /// 6 players (2 decks). Hearts led by p0; p1 plays the first A♥, p3 the second.
    private func sixPlayerHands() -> [[Card]] {
        [[c(.nine, .hearts)], [c(.ace, .hearts)], [c(.king, .diamonds)],
         [c(.ace, .hearts, deck: 2)], [c(.four, .hearts)], [c(.two, .hearts)]]
    }

    func testSecondOccurrenceNotRevealedByFirst() throws {
        let calls = [PartnerCall(rank: .ace, suit: .hearts, occurrence: 2), PartnerCall(rank: .king, suit: .diamonds)]
        var s = try makePlayingState(playerCount: 6, dealer: 5, hands: sixPlayerHands(), trump: .spades, calls: calls)
        try s.playCard(player: 0, cardID: c(.nine, .hearts).id)
        let e1 = try s.playCard(player: 1, cardID: c(.ace, .hearts).id)
        XCTAssertFalse(e1.contains { if case .partnerRevealed = $0 { return true } else { return false } })
        XCTAssertTrue(s.revealedPartners.isEmpty)
        let e2 = try s.playCard(player: 2, cardID: c(.king, .diamonds).id)
        XCTAssertTrue(e2.contains(.partnerRevealed(player: 2, call: calls[1])))
        let e3 = try s.playCard(player: 3, cardID: c(.ace, .hearts, deck: 2).id)
        XCTAssertTrue(e3.contains(.partnerRevealed(player: 3, call: calls[0])))
        XCTAssertEqual(s.revealedPartners, [2, 3])
        XCTAssertEqual(s.callResolutions, [3, 2])
    }

    func testOccurrenceIgnoresDeckNumberAndSpansTricks() throws {
        // deck-2 copy is played first; it is still the FIRST occurrence.
        let hands: [[Card]] = [
            [c(.nine, .hearts), c(.two, .clubs)], [c(.ace, .hearts, deck: 2), c(.three, .clubs)],
            [c(.five, .hearts), c(.four, .clubs)], [c(.six, .hearts), c(.ace, .hearts)],
            [c(.seven, .hearts), c(.five, .clubs)], [c(.eight, .hearts), c(.six, .clubs)],
        ]
        let calls = [PartnerCall(rank: .ace, suit: .hearts, occurrence: 1), PartnerCall(rank: .ace, suit: .hearts, occurrence: 2)]
        var s = try makePlayingState(playerCount: 6, dealer: 5, hands: hands, trump: .spades, calls: calls)
        try s.playCard(player: 0, cardID: c(.nine, .hearts).id)
        try s.playCard(player: 1, cardID: c(.ace, .hearts, deck: 2).id)
        XCTAssertEqual(s.callResolutions, [1, nil])
        for p in 2...5 { try s.playCard(player: p, cardID: s.legalCards(for: p).first(where: { $0.suit == .hearts && $0.rank != .ace })!.id) }
        try s.resolveTrick()
        XCTAssertEqual(s.actor, 1, "A♥ won")
        // Second A♥ comes later in a different trick.
        try s.playCard(player: 1, cardID: c(.three, .clubs).id)
        for (p, card) in [(2, c(.four, .clubs)), (3, c(.ace, .hearts)), (4, c(.five, .clubs)), (5, c(.six, .clubs))] {
            _ = try s.playCard(player: p, cardID: card.id)
        }
        XCTAssertEqual(s.callResolutions, [1, nil].enumerated().map { $0.offset == 1 ? 3 : $0.element })
    }

    func testSelfPartnerWastesSlotAndDuplicatePartnerCountsOnce() throws {
        let hands: [[Card]] = [
            [c(.ace, .hearts)], [c(.five, .hearts)], [c(.king, .diamonds)],
            [c(.ace, .hearts, deck: 2)], [c(.four, .hearts)], [c(.two, .hearts)],
        ]
        // p0 calls first A♥ (self), second A♥ and K♦ (p3 and p2).
        let calls = [PartnerCall(rank: .ace, suit: .hearts, occurrence: 1), PartnerCall(rank: .ace, suit: .hearts, occurrence: 2)]
        var s = try makePlayingState(playerCount: 6, dealer: 5, hands: hands, trump: .spades, calls: calls)
        let e = try s.playCard(player: 0, cardID: c(.ace, .hearts).id)
        XCTAssertTrue(e.contains(.selfPartnered(call: calls[0])))
        XCTAssertTrue(s.revealedPartners.isEmpty)
        XCTAssertEqual(s.callResolutions[0], 0)
    }

    func testScoringSelfPartnerAndDuplicates() {
        let calls = [PartnerCall(rank: .ace, suit: .hearts), PartnerCall(rank: .king, suit: .hearts), PartnerCall(rank: .queen, suit: .hearts)]
        // Bidder 0 self-calls once; player 2 satisfies two calls.
        let r = Scoring.compute(playerCount: 4, bidder: 0, winningBid: 30, trump: .clubs, calls: calls,
                                callResolutions: [0, 2, 2], tricks: [syntheticTrick(number: 1, winner: 0, card: c(.three, .spades))])
        XCTAssertEqual(r.partners, [2])
        XCTAssertEqual(r.scores, [60, 0, 30, 0])
        XCTAssertEqual(r.roles, [.bidder, .opponent, .partner, .opponent])
    }
}
