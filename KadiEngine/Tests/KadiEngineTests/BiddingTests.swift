import XCTest
@testable import KadiEngine

final class BiddingTests: XCTestCase {
    private func fresh(_ n: Int = 5, dealer: Int = 4) -> GameState {
        GameState(config: GameConfig(playerCount: n), hands: dealCards(createDecks(deckCount: GameConfig(playerCount: n).deckCount).prefix(GameConfig(playerCount: n).cardsPerPlayer * n).map { $0 }, playerCount: n, dealer: dealer), removed: [], dealer: dealer)
    }

    func testOpeningBidRulesAndIncrements() throws {
        var s = fresh()
        XCTAssertEqual(s.auction.minimumBid, 120)
        XCTAssertThrowsError(try s.placeBid(player: 0, amount: 115))
        XCTAssertThrowsError(try s.placeBid(player: 0, amount: 122))
        XCTAssertThrowsError(try s.placeBid(player: 1, amount: 120), "out of turn")
        try s.placeBid(player: 0, amount: 120)
        XCTAssertEqual(s.auction.minimumBid, 125)
        XCTAssertThrowsError(try s.placeBid(player: 1, amount: 120))
        XCTAssertThrowsError(try s.placeBid(player: 1, amount: 255), "above max")
        try s.placeBid(player: 1, amount: 140)
        XCTAssertEqual(s.auction.highestBidder, 1)
    }

    func testPassIsPermanentAndHighBidderNotForcedToActAgain() throws {
        var s = fresh()
        try s.placeBid(player: 0, amount: 120)
        try s.pass(player: 1)
        try s.placeBid(player: 2, amount: 125)
        XCTAssertEqual(s.auction.current, 3)
        try s.pass(player: 3)
        try s.pass(player: 4)
        // 0 was outbid and must act again; 1 never does.
        XCTAssertEqual(s.auction.current, 0)
        XCTAssertThrowsError(try s.placeBid(player: 1, amount: 200))
        try s.pass(player: 0)
        XCTAssertEqual(s.phase, .trumpSelection)
        XCTAssertEqual(s.bidder, 2)
        XCTAssertEqual(s.winningBid, 125)
    }

    func testAuctionEndsWithoutHighBidderActingAgain() throws {
        var s = fresh()
        try s.placeBid(player: 0, amount: 120)
        for p in 1...4 { try s.pass(player: p) }
        XCTAssertEqual(s.phase, .trumpSelection)
        XCTAssertEqual(s.bidder, 0)
    }

    func testDealerForcedToOpen() throws {
        var s = fresh(5, dealer: 4)
        for p in 0..<4 { try s.pass(player: p) }
        XCTAssertEqual(s.phase, .bidding)
        XCTAssertEqual(s.auction.current, 4)
        XCTAssertTrue(s.auction.mustBid)
        XCTAssertThrowsError(try s.pass(player: 4)) { XCTAssertEqual($0 as? GameError, .dealerMustBid) }
        try s.placeBid(player: 4, amount: 120)
        XCTAssertEqual(s.phase, .trumpSelection)
        XCTAssertEqual(s.bidder, 4)
        XCTAssertEqual(s.winningBid, 120)
    }

    func testMaxBidEndsAuction() throws {
        var s = fresh()
        try s.placeBid(player: 0, amount: 250)
        XCTAssertEqual(s.phase, .trumpSelection)
        XCTAssertEqual(s.bidder, 0)
    }

    func testCPUAuctionsAlwaysTerminate() throws {
        for seed in 0..<300 {
            var rng = SeededGenerator(seed: UInt64(seed))
            var s = GameState.newGame(playerCount: 4 + seed % 6, using: &rng)
            var steps = 0
            while s.phase == .bidding {
                try s.performCPUAction(using: &rng)
                steps += 1
                XCTAssertLessThan(steps, 5000)
            }
            XCTAssertNotNil(s.bidder)
            XCTAssertGreaterThanOrEqual(s.winningBid!, s.config.openingBid)
            XCTAssertLessThanOrEqual(s.winningBid!, s.config.maxBid)
            XCTAssertEqual(s.winningBid! % 5, 0)
        }
    }
}
