import Foundation

public enum GameError: Error, Equatable {
    case wrongPhase
    case notYourTurn
    case invalidBid
    case dealerMustBid
    case cardNotInHand
    case illegalCard
    case invalidPartnerCalls(String)
}

public struct Auction: Sendable {
    public let dealer: Int
    public let playerCount: Int
    public let openingBid: Int
    public let maxBid: Int
    public private(set) var current: Int
    public private(set) var highestBid: Int?
    public private(set) var highestBidder: Int?
    public private(set) var passed: Set<Int> = []

    init(config: GameConfig, dealer: Int) {
        self.dealer = dealer
        playerCount = config.playerCount
        openingBid = config.openingBid
        maxBid = config.maxBid
        current = (dealer + 1) % config.playerCount
    }

    public var minimumBid: Int { highestBid.map { $0 + GameConfig.bidIncrement } ?? openingBid }
    public var activeCount: Int { playerCount - passed.count }

    /// Nobody has opened and everyone else has passed: the dealer cannot pass.
    public var mustBid: Bool { highestBid == nil && activeCount == 1 }

    public var validBids: [Int] {
        guard minimumBid <= maxBid else { return [] }
        return Array(stride(from: minimumBid, through: maxBid, by: GameConfig.bidIncrement))
    }

    public func isValidBid(_ amount: Int) -> Bool {
        amount % GameConfig.bidIncrement == 0 && amount >= minimumBid && amount <= maxBid
    }

    /// Next clockwise player still in the auction who is not the standing high bidder.
    private func nextCandidate(after player: Int) -> Int? {
        for step in 1...playerCount {
            let p = (player + step) % playerCount
            if !passed.contains(p) && p != highestBidder { return p }
        }
        return nil
    }

    public var isComplete: Bool { highestBidder != nil && nextCandidate(after: current) == nil }

    mutating func placeBid(player: Int, amount: Int) throws {
        guard !isComplete else { throw GameError.wrongPhase }
        guard player == current else { throw GameError.notYourTurn }
        guard isValidBid(amount) else { throw GameError.invalidBid }
        highestBid = amount
        highestBidder = player
        if amount == maxBid {
            // Nobody can raise further.
            passed = Set((0..<playerCount).filter { $0 != player })
        } else if let next = nextCandidate(after: player) {
            current = next
        }
    }

    mutating func pass(player: Int) throws {
        guard !isComplete else { throw GameError.wrongPhase }
        guard player == current else { throw GameError.notYourTurn }
        guard !mustBid else { throw GameError.dealerMustBid }
        passed.insert(player)
        if let next = nextCandidate(after: player) { current = next }
    }
}
