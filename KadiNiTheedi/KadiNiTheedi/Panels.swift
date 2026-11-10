import SwiftUI

private struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.gold.opacity(0.35)))
            .shadow(radius: 12)
    }
}
extension View { fileprivate func panel() -> some View { modifier(PanelBackground()) } }

struct BiddingPanel: View {
    @Bindable var game: GameController
    @State private var amount = 0

    var body: some View {
        if let s = game.state {
            let a = s.auction
            let myTurn = game.humanIsActing
            VStack(spacing: 5) {
                Text("Auction").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.gold)
                if let bid = a.highestBid, let who = a.highestBidder {
                    Text("\(bid)").font(.system(size: 26, weight: .heavy, design: .rounded))
                    Text("high bid · \(game.name(who))").font(.caption).foregroundStyle(.white.opacity(0.7))
                } else {
                    Text("No bids yet").font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Opening bid \(a.openingBid)").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                if myTurn {
                    HStack(spacing: 12) {
                        Button { amount = max(a.minimumBid, amount - 5) } label: { Image(systemName: "minus") }
                            .buttonStyle(GoldButtonStyle(prominent: false)).disabled(amount <= a.minimumBid)
                        Text("\(amount)").font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit().frame(minWidth: 56)
                        Button { amount = min(a.maxBid, amount + 5) } label: { Image(systemName: "plus") }
                            .buttonStyle(GoldButtonStyle(prominent: false)).disabled(amount >= a.maxBid)
                    }
                    HStack(spacing: 10) {
                        Button("Bid \(amount)") { game.bid(amount) }
                            .buttonStyle(GoldButtonStyle()).disabled(!a.isValidBid(amount))
                        Button("Pass") { game.pass() }
                            .buttonStyle(GoldButtonStyle(prominent: false)).disabled(a.mustBid)
                    }
                    if a.mustBid { Text("You're the dealer: you must open.").font(.caption2).foregroundStyle(Theme.gold) }
                } else if let actor = s.actor {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("\(game.name(actor)) is deciding…").font(.caption)
                    }
                }
            }
            .frame(width: 250)
            .panel()
            .onAppear { amount = a.minimumBid }
            .onChange(of: a.minimumBid) { _, new in if amount < new { amount = new } }
            .onChange(of: myTurn) { _, mine in if mine { amount = a.minimumBid } }
        }
    }
}

struct TrumpPanel: View {
    @Bindable var game: GameController
    var body: some View {
        VStack(spacing: 10) {
            Text("Choose trump").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.gold)
            HStack(spacing: 12) {
                ForEach(Suit.allCases, id: \.self) { suit in
                    Button { game.chooseTrump(suit) } label: {
                        Text(suit.symbol)
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.suitColor(suit))
                            .frame(width: 64, height: 64)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
        .panel()
    }
}

struct PartnerPanel: View {
    @Bindable var game: GameController

    struct Slot: Equatable { var rank: Rank; var suit: Suit; var occurrence: Int }
    @State private var slots: [Slot] = []

    var body: some View {
        if let s = game.state {
            let valid = Set(s.validPartnerCalls())
            let twoDecks = s.config.deckCount == 2
            let held = Set(s.players[0].hand.map(\.identity))
            VStack(alignment: .leading, spacing: 8) {
                Text("Select \(s.config.partnerCalls) partner card\(s.config.partnerCalls > 1 ? "s" : "")")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.gold)
                ForEach(slots.indices, id: \.self) { i in
                    let issue = problem(for: i, valid: valid)
                    HStack(spacing: 10) {
                        Text("\(i + 1).").font(.caption.bold())
                        Picker("Rank", selection: $slots[i].rank) {
                            ForEach(Rank.allCases.reversed(), id: \.self) { Text($0.label).tag($0) }
                        }.pickerStyle(.menu).frame(width: 70)
                        ForEach(Suit.allCases, id: \.self) { suit in
                            Button { slots[i].suit = suit } label: {
                                Text(suit.symbol).font(.system(size: 22))
                                    .foregroundStyle(Theme.suitColor(suit))
                                    .frame(width: 34, height: 34)
                                    .background(.white.opacity(slots[i].suit == suit ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.gold, lineWidth: slots[i].suit == suit ? 2 : 0))
                            }
                        }
                        if twoDecks {
                            Picker("Occurrence", selection: $slots[i].occurrence) {
                                Text("1st").tag(1); Text("2nd").tag(2)
                            }.pickerStyle(.segmented).frame(width: 96)
                        }
                        Image(systemName: issue == nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(issue == nil ? .green : .orange)
                        if twoDecks && held.contains(CardIdentity(rank: slots[i].rank, suit: slots[i].suit)) {
                            Text("in your hand").font(.caption2).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    if let issue { Text(issue).font(.caption2).foregroundStyle(.orange) }
                }
                Button("Confirm") { game.choosePartners(slots.map(call)) }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(!slots.indices.allSatisfy { problem(for: $0, valid: valid) == nil })
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: twoDecks ? 490 : 380)
            .panel()
            .onAppear { seed(from: s) }
        }
    }

    private func call(_ slot: Slot) -> PartnerCall { PartnerCall(rank: slot.rank, suit: slot.suit, occurrence: slot.occurrence) }

    private func problem(for i: Int, valid: Set<PartnerCall>) -> String? {
        guard slots.indices.contains(i) else { return nil }
        let c = call(slots[i])
        if !valid.contains(c) {
            return game.state?.config.deckCount == 1
                ? "\(c.identity.label) is in your hand or was removed."
                : "\(c.label) isn't available (removed copies)."
        }
        if slots.indices.contains(where: { $0 != i && call(slots[$0]) == c }) { return "Already selected." }
        return nil
    }

    /// Start with distinct valid calls so Confirm is usable immediately.
    private func seed(from s: GameState) {
        guard slots.isEmpty else { return }
        slots = s.validPartnerCalls().shuffled().prefix(s.config.partnerCalls).map {
            Slot(rank: $0.identity.rank, suit: $0.identity.suit, occurrence: $0.occurrence)
        }
    }
}
