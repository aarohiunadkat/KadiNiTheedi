import XCTest
@testable import KadiEngine

final class ScoringTests: XCTestCase {
    private let calls = [PartnerCall(rank: .ace, suit: .hearts)]

    private func result(bid: Int, teamCards: [Card], oppCards: [Card] = [], partner: Int = 2) -> GameResult {
        var tricks: [Trick] = []
        for card in teamCards { tricks.append(syntheticTrick(number: tricks.count + 1, winner: tricks.count % 2 == 0 ? 0 : partner, card: card)) }
        for card in oppCards { tricks.append(syntheticTrick(number: tricks.count + 1, winner: 1, card: card)) }
        return Scoring.compute(playerCount: 4, bidder: 0, winningBid: bid, trump: .clubs, calls: calls, callResolutions: [partner], tricks: tricks)
    }

    func testSuccessAboveAndExactlyAtBid() {
        let above = result(bid: 150, teamCards: [c(.three, .spades), c(.ace, .clubs), c(.king, .clubs), c(.queen, .clubs), c(.jack, .clubs), c(.ten, .clubs)])
        XCTAssertEqual(above.teamPoints, 80)
        let exact = result(bid: 80, teamCards: [c(.three, .spades), c(.ace, .clubs), c(.king, .clubs), c(.queen, .clubs), c(.jack, .clubs), c(.ten, .clubs)])
        XCTAssertTrue(exact.bidderSucceeded)
        XCTAssertEqual(exact.scores, [160, 0, 80, 0])
    }

    func testFailureScores() {
        let r = result(bid: 100, teamCards: [c(.ace, .clubs)], oppCards: [c(.three, .spades)])
        XCTAssertFalse(r.bidderSucceeded)
        XCTAssertEqual(r.scores, [-100, 100, 0, 100])
        XCTAssertEqual(r.teamPoints, 10); XCTAssertEqual(r.opponentPoints, 30)
    }

    func testPartnerTricksWonBeforeRevealStillCount() {
        // Trick 1 won by player 2, who is only "revealed" by a later call resolution.
        let r = Scoring.compute(playerCount: 4, bidder: 0, winningBid: 30, trump: .clubs, calls: calls, callResolutions: [2],
                                tricks: [syntheticTrick(number: 1, winner: 2, card: c(.three, .spades))])
        XCTAssertEqual(r.teamPoints, 30)
        XCTAssertTrue(r.bidderSucceeded)
    }

    func testRankingWithTies() {
        let r = Scoring.rank([200, 0, 100, 0])
        XCTAssertEqual(r.map(\.player), [0, 2, 1, 3])
        XCTAssertEqual(r.map(\.rank), [1, 2, 3, 3])
    }
}
