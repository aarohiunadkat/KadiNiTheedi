import Foundation

public struct GameConfig: Equatable, Sendable {
    public static let supportedPlayerCounts = 4...9

    public let playerCount: Int
    public let deckCount: Int
    public let partnerCalls: Int
    public let openingBid: Int

    public init(playerCount: Int) {
        precondition(Self.supportedPlayerCounts.contains(playerCount), "Unsupported player count \(playerCount)")
        self.playerCount = playerCount
        switch playerCount {
        case 4: (deckCount, partnerCalls, openingBid) = (1, 1, 150)
        case 5: (deckCount, partnerCalls, openingBid) = (1, 1, 120)
        case 6: (deckCount, partnerCalls, openingBid) = (2, 2, 300)
        case 7: (deckCount, partnerCalls, openingBid) = (2, 2, 235)
        case 8: (deckCount, partnerCalls, openingBid) = (2, 3, 300)
        default: (deckCount, partnerCalls, openingBid) = (2, 3, 235)
        }
    }

    public var cpuCount: Int { playerCount - 1 }
    public var totalCards: Int { deckCount * 52 }
    public var cardsPerPlayer: Int { totalCards / playerCount }
    public var removedCardCount: Int { totalCards - cardsPerPlayer * playerCount }
    public var totalPoints: Int { deckCount * 250 }
    public var maxBid: Int { totalPoints }
    public static let bidIncrement = 5
}

public func getGameConfiguration(playerCount: Int) -> GameConfig { GameConfig(playerCount: playerCount) }
public func getMinimumBid(playerCount: Int) -> Int { GameConfig(playerCount: playerCount).openingBid }
