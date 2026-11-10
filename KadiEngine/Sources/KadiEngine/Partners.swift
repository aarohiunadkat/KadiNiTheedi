import Foundation

public struct PartnerCall: Hashable, Comparable, Codable, Sendable {
    public let identity: CardIdentity
    /// 1 = first copy played, 2 = second copy played (chronological, not by deck).
    public let occurrence: Int

    public init(rank: Rank, suit: Suit, occurrence: Int = 1) {
        identity = CardIdentity(rank: rank, suit: suit)
        self.occurrence = occurrence
    }

    public init(identity: CardIdentity, occurrence: Int = 1) {
        self.identity = identity
        self.occurrence = occurrence
    }

    public static func < (a: PartnerCall, b: PartnerCall) -> Bool {
        (a.identity, a.occurrence) < (b.identity, b.occurrence)
    }

    public var label: String { occurrence == 1 ? identity.label : "\(identity.label) (2nd)" }
}

public enum PartnerRules {
    /// Every call the bidder may legally make.
    /// - one deck: card must not be in the bidder's hand
    /// - two decks: held cards allowed; occurrence N needs N copies in play
    public static func validCalls(
        deckCount: Int, inPlayCounts: [CardIdentity: Int], bidderHand: [Card]
    ) -> [PartnerCall] {
        let held = Set(bidderHand.map(\.identity))
        var calls: [PartnerCall] = []
        for identity in CardIdentity.all {
            let copies = inPlayCounts[identity] ?? 0
            guard copies > 0 else { continue }
            if deckCount == 1 && held.contains(identity) { continue }
            for occ in 1...copies { calls.append(PartnerCall(identity: identity, occurrence: occ)) }
        }
        return calls
    }

    public static func validate(
        _ calls: [PartnerCall], required: Int, deckCount: Int,
        inPlayCounts: [CardIdentity: Int], bidderHand: [Card]
    ) throws {
        guard calls.count == required else {
            throw GameError.invalidPartnerCalls("Select exactly \(required) partner call(s)")
        }
        guard Set(calls).count == calls.count else {
            throw GameError.invalidPartnerCalls("The same occurrence cannot be called twice")
        }
        let valid = Set(validCalls(deckCount: deckCount, inPlayCounts: inPlayCounts, bidderHand: bidderHand))
        for call in calls where !valid.contains(call) {
            throw GameError.invalidPartnerCalls("\(call.label) is not available")
        }
    }
}
