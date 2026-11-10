import XCTest
@testable import KadiEngine

final class SimulationTests: XCTestCase {
    func testFullCPUGamesForEveryPlayerCount() throws {
        for n in 4...9 {
            for seed in 0..<40 {
                var rng = SeededGenerator(seed: UInt64(n * 1000 + seed))
                var s = GameState.newGame(playerCount: n, using: &rng)
                let cfg = s.config
                while s.phase != .gameOver {
                    XCTAssertNil(s.result, "no results before game over")
                    try s.performCPUAction(using: &rng)
                }
                XCTAssertEqual(s.completedTricks.count, cfg.cardsPerPlayer)
                XCTAssertTrue(s.players.allSatisfy { $0.hand.isEmpty })
                XCTAssertTrue(s.completedTricks.allSatisfy { $0.plays.count == n && $0.winner != nil })
                let ids = s.completedTricks.flatMap { $0.plays.map(\.card.id) }
                XCTAssertEqual(Set(ids).count, ids.count)
                XCTAssertEqual(ids.count, cfg.totalCards - cfg.removedCardCount)
                XCTAssertEqual(s.completedTricks.reduce(0) { $0 + $1.points }, cfg.totalPoints)

                let r = try XCTUnwrap(s.result)
                XCTAssertEqual(r.teamPoints + r.opponentPoints, cfg.totalPoints)
                XCTAssertEqual(r.bidderSucceeded, r.teamPoints >= r.winningBid)
                XCTAssertTrue(r.callResolutions.allSatisfy { $0 != nil }, "every call resolves by the last trick")
                XCTAssertEqual(r.scores.count, n)
                XCTAssertEqual(r.ranking.first?.score, r.scores.max())
                XCTAssertEqual(s.completedTricks[0].leader, r.bidder)
                // Each trick leader is the previous trick's winner.
                for (a, b) in zip(s.completedTricks, s.completedTricks.dropFirst()) { XCTAssertEqual(b.leader, a.winner) }
            }
        }
    }

    func testGamesAreReproducibleFromSeed() throws {
        func run() throws -> [Int] {
            var rng = SeededGenerator(seed: 7)
            var s = GameState.newGame(playerCount: 7, using: &rng)
            try s.autoplayToEnd(using: &rng)
            return s.result!.scores
        }
        XCTAssertEqual(try run(), try run())
    }

    func testCPUViewDoesNotExposeOtherHands() {
        var rng = SeededGenerator(seed: 3)
        let s = GameState.newGame(playerCount: 5, using: &rng)
        let v = s.cpuView(for: 2)
        XCTAssertEqual(v.hand.map(\.id), s.players[2].hand.map(\.id))
        XCTAssertEqual(v.handSizes, s.players.map { $0.hand.count })
    }
}
