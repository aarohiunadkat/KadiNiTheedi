import Foundation

public enum PlayerRole: String, Sendable { case bidder, partner, opponent }

public struct RankedPlayer: Sendable {
    public let player: Int
    public let score: Int
    public let rank: Int
}

public struct GameResult: Sendable {
    public let bidder: Int
    public let winningBid: Int
    public let trump: Suit
    public let calls: [PartnerCall]
    /// Player who satisfied each call (parallel to `calls`).
    public let callResolutions: [Int?]
    /// Unique partners, excluding the bidder.
    public let partners: [Int]
    public let teamPoints: Int
    public let opponentPoints: Int
    public let bidderSucceeded: Bool
    public let scores: [Int]
    public let roles: [PlayerRole]
    public let ranking: [RankedPlayer]
}

public enum Scoring {
    public static func compute(
        playerCount: Int, bidder: Int, winningBid: Int, trump: Suit,
        calls: [PartnerCall], callResolutions: [Int?], tricks: [Trick]
    ) -> GameResult {
        var partnerSet = Set(callResolutions.compactMap { $0 })
        partnerSet.remove(bidder)
        let team = partnerSet.union([bidder])

        var teamPoints = 0
        var opponentPoints = 0
        for trick in tricks {
            guard let winner = trick.winner else { continue }
            if team.contains(winner) { teamPoints += trick.points } else { opponentPoints += trick.points }
        }
        let succeeded = teamPoints >= winningBid

        var scores = [Int](repeating: 0, count: playerCount)
        var roles = [PlayerRole](repeating: .opponent, count: playerCount)
        for p in partnerSet { roles[p] = .partner }
        roles[bidder] = .bidder
        for p in 0..<playerCount {
            switch (roles[p], succeeded) {
            case (.bidder, true): scores[p] = 2 * winningBid
            case (.partner, true): scores[p] = winningBid
            case (.opponent, true): scores[p] = 0
            case (.bidder, false): scores[p] = -winningBid
            case (.partner, false): scores[p] = 0
            case (.opponent, false): scores[p] = winningBid
            }
        }
        return GameResult(
            bidder: bidder, winningBid: winningBid, trump: trump, calls: calls,
            callResolutions: callResolutions, partners: partnerSet.sorted(),
            teamPoints: teamPoints, opponentPoints: opponentPoints,
            bidderSucceeded: succeeded, scores: scores, roles: roles,
            ranking: rank(scores))
    }

    /// Competition ranking (ties share a rank), highest score first.
    static func rank(_ scores: [Int]) -> [RankedPlayer] {
        let order = scores.indices.sorted { (scores[$0], $1) > (scores[$1], $0) }
        return order.map { p in
            RankedPlayer(player: p, score: scores[p], rank: 1 + scores.filter { $0 > scores[p] }.count)
        }
    }
}
