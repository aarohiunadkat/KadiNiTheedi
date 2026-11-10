import XCTest
@testable import KadiEngine

final class TrickTests: XCTestCase {
    func testTrumpBeatsNonTrump() {
        let p = plays([(0, c(.ace, .hearts)), (1, c(.two, .clubs)), (2, c(.king, .hearts)), (3, c(.ace, .diamonds))])
        XCTAssertEqual(determineTrickWinner(plays: p, trump: .clubs), 1)
    }

    func testHighestTrumpWins() {
        let p = plays([(0, c(.ace, .hearts)), (1, c(.three, .clubs)), (2, c(.four, .clubs)), (3, c(.king, .hearts))])
        XCTAssertEqual(determineTrickWinner(plays: p, trump: .clubs), 2)
    }

    func testNoTrumpHighestLeadSuitWins() {
        let p = plays([(0, c(.nine, .hearts)), (1, c(.ace, .spades)), (2, c(.ten, .hearts)), (3, c(.ace, .diamonds))])
        XCTAssertEqual(determineTrickWinner(plays: p, trump: .clubs), 2)
    }

    func testOffSuitCannotWin() {
        let p = plays([(0, c(.two, .hearts)), (1, c(.ace, .spades)), (2, c(.ace, .diamonds)), (3, c(.three, .hearts))])
        XCTAssertEqual(determineTrickWinner(plays: p, trump: .clubs), 3)
    }

    func testLaterIdenticalCardWins() {
        let p = plays([(0, c(.ace, .hearts)), (1, c(.ten, .hearts)), (2, c(.ace, .hearts, deck: 2)), (3, c(.king, .hearts))])
        XCTAssertEqual(determineTrickWinner(plays: p, trump: .spades), 2)
        let q = plays([(0, c(.ace, .hearts, deck: 2)), (1, c(.ace, .hearts))])
        XCTAssertEqual(determineTrickWinner(plays: q, trump: .spades), 1, "deck number is irrelevant")
    }

    func testLaterIdenticalTrumpWins() {
        let p = plays([(0, c(.five, .hearts)), (1, c(.queen, .clubs)), (2, c(.queen, .clubs, deck: 2)), (3, c(.ace, .hearts))])
        XCTAssertEqual(determineTrickWinner(plays: p, trump: .clubs), 2)
    }

    func testIdenticalAcesLoseToTrump() {
        let p = plays([(0, c(.ace, .hearts)), (1, c(.ace, .hearts, deck: 2)), (2, c(.two, .clubs))])
        XCTAssertEqual(determineTrickWinner(plays: p, trump: .clubs), 2)
    }

    func testThreeOfSpadesHasNoSpecialRank() {
        let p = plays([(0, c(.two, .clubs)), (1, c(.three, .spades)), (2, c(.four, .diamonds))])
        XCTAssertEqual(determineTrickWinner(plays: p, trump: .diamonds), 2)
        let q = plays([(0, c(.two, .clubs)), (1, c(.three, .spades))])
        XCTAssertEqual(determineTrickWinner(plays: q, trump: .hearts), 0)
        XCTAssertEqual(calculateTrickPoints(q), 30)
    }

    func testLegalCards() {
        let hand = [c(.ace, .hearts), c(.four, .hearts), c(.nine, .spades)]
        XCTAssertEqual(getLegalCards(hand: hand, leadSuit: nil).count, 3)
        XCTAssertEqual(Set(getLegalCards(hand: hand, leadSuit: .hearts).map(\.id)),
                       Set([c(.ace, .hearts), c(.four, .hearts)].map(\.id)), "not forced to play the ace")
        XCTAssertEqual(getLegalCards(hand: hand, leadSuit: .clubs).count, 3, "void: anything, trump optional")
    }

    func testEngineEnforcesFollowSuitAndTurnOrder() throws {
        let hands = [
            [c(.nine, .hearts), c(.two, .clubs)], [c(.ace, .hearts), c(.king, .spades)],
            [c(.five, .clubs), c(.six, .clubs)], [c(.seven, .diamonds), c(.eight, .diamonds)],
        ]
        var s = try makePlayingState(playerCount: 4, dealer: 3, hands: hands, trump: .clubs, calls: [PartnerCall(rank: .six, suit: .clubs)])
        XCTAssertEqual(s.actor, 0, "bidder leads first trick")
        XCTAssertThrowsError(try s.playCard(player: 1, cardID: c(.ace, .hearts).id)) { XCTAssertEqual($0 as? GameError, .notYourTurn) }
        try s.playCard(player: 0, cardID: c(.nine, .hearts).id)
        XCTAssertThrowsError(try s.playCard(player: 1, cardID: c(.king, .spades).id)) { XCTAssertEqual($0 as? GameError, .illegalCard) }
        try s.playCard(player: 1, cardID: c(.ace, .hearts).id)
        try s.playCard(player: 2, cardID: c(.five, .clubs).id)    // void: trump
        try s.playCard(player: 3, cardID: c(.seven, .diamonds).id) // void: discard
        XCTAssertTrue(s.awaitingTrickResolution)
        XCTAssertThrowsError(try s.playCard(player: 0, cardID: c(.two, .clubs).id))
        try s.resolveTrick()
        XCTAssertEqual(s.completedTricks[0].winner, 2)
        XCTAssertEqual(s.actor, 2, "winner leads next trick")
    }

    func testTrumpCanBeLedOnFirstTrick() throws {
        let hands = [[c(.nine, .clubs)], [c(.ace, .hearts)], [c(.five, .clubs)], [c(.seven, .diamonds)]]
        var s = try makePlayingState(playerCount: 4, dealer: 3, hands: hands, trump: .clubs, calls: [PartnerCall(rank: .ace, suit: .hearts)])
        try s.playCard(player: 0, cardID: c(.nine, .clubs).id)
        XCTAssertEqual(s.currentTrick?.leadSuit, .clubs)
    }
}
