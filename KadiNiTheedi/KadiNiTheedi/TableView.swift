import SwiftUI

struct TableView: View {
    @Bindable var game: GameController
    @State private var selected: String?

    var body: some View {
        if let s = game.state {
            GeometryReader { geo in
                let size = geo.size
                let n = s.config.playerCount
                let angle: (Int) -> Double = { .pi / 2 + 2 * .pi * Double($0) / Double(n) }
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.42)

                ZStack {
                    FeltBackground()

                    ForEach(1..<n, id: \.self) { p in
                        let a = angle(p)
                        seat(p, in: s)
                            .position(x: center.x + cos(a) * size.width * 0.37,
                                      y: center.y + sin(a) * size.height * 0.29)
                    }

                    TrickArea(plays: s.currentTrick?.plays ?? [], angleFor: angle,
                              sweepTarget: game.sweepTarget, winner: game.winnerHighlight)
                        .position(x: center.x, y: center.y + 4)

                    phaseOverlay(s)
                        .position(x: center.x, y: center.y + 26)

                    hud(s).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(.leading, 18).padding(.top, 10)
                    topRight(s).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(.trailing, 18).padding(.top, 10)

                    VStack(spacing: 4) {
                        Spacer()
                        HStack(alignment: .bottom) {
                            seat(0, in: s)
                            Spacer()
                        }
                        .padding(.leading, 20)
                        HandView(cards: s.players[0].hand, legal: legalIDs(s), selected: $selected,
                                 revealed: !game.dealing) { game.play($0) }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                    }

                    if let toast = game.toast {
                        Text(toast)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(.black.opacity(0.75), in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.5)))
                            .position(x: center.x, y: size.height * 0.715)
                            .transition(.scale.combined(with: .opacity))
                    }

                    if game.dealing {
                        Text("Dealing…").font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(Theme.gold)
                            .position(center)
                    }

                    if game.showResults, let result = s.result {
                        ResultsView(game: game, state: s, result: result).transition(.opacity)
                    }
                }
            }
            .onChange(of: game.humanIsActing) { _, _ in selected = nil }
            .sensoryFeedback(.impact(weight: .light), trigger: game.playTick)
            .sensoryFeedback(.success, trigger: game.revealTick)
        }
    }

    // MARK: Pieces

    private func legalIDs(_ s: GameState) -> Set<String>? {
        guard s.phase == .playing, game.humanIsActing else { return nil }
        return Set(s.legalCards(for: 0).map(\.id))
    }

    private func seat(_ p: Int, in s: GameState) -> some View {
        let player = s.players[p]
        let inAuction = s.phase == .bidding
        let bidText: String? = inAuction && s.auction.highestBidder == p ? s.auction.highestBid.map(String.init) : nil
        return SeatView(
            name: player.name,
            cardCount: p == 0 ? nil : player.hand.count,
            isDealer: s.dealer == p,
            isActing: s.actor == p && !s.awaitingTrickResolution,
            isWinner: game.winnerHighlight == p,
            isBidder: s.bidder == p,
            isPartner: s.revealedPartners.contains(p),
            passed: inAuction && s.auction.passed.contains(p),
            bidText: bidText,
            pulse: game.revealPulse == p && game.winnerHighlight == nil && game.toast != nil)
    }

    @ViewBuilder
    private func phaseOverlay(_ s: GameState) -> some View {
        switch s.phase {
        case .bidding:
            if !game.dealing { BiddingPanel(game: game) }
        case .trumpSelection:
            if s.bidder == 0 { TrumpPanel(game: game) } else { waiting("\(game.name(s.bidder ?? 0)) is choosing trump…") }
        case .partnerSelection:
            if s.bidder == 0 { PartnerPanel(game: game) } else { waiting("\(game.name(s.bidder ?? 0)) is choosing partners…") }
        default:
            EmptyView()
        }
    }

    private func waiting(_ text: String) -> some View {
        HStack(spacing: 8) { ProgressView().controlSize(.small); Text(text).font(.system(size: 14, weight: .semibold, design: .rounded)) }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.black.opacity(0.7), in: Capsule())
    }

    private func hud(_ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let trump = s.trump {
                HStack(spacing: 6) {
                    Text("Trump").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                    Text(trump.symbol).font(.system(size: 26)).foregroundStyle(trump.isRed ? Color(red: 1, green: 0.4, blue: 0.4) : .white)
                }
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Theme.panel, in: Capsule())
            }
            if let bid = s.winningBid, let b = s.bidder { Chip(text: "\(game.name(b)) · bid \(bid)", tint: Theme.gold) }
            if s.phase == .playing, let t = s.currentTrick { Chip(text: "Trick \(t.number)/\(s.config.cardsPerPlayer)") }
            if !s.removedCards.isEmpty, s.phase == .bidding || s.phase == .partnerSelection || s.phase == .trumpSelection {
                Menu {
                    Text("Removed before dealing")
                    Text(s.removedCards.map(\.label).joined(separator: "  "))
                } label: { Chip(text: "Removed: \(s.removedCards.count) ⓘ") }
            }
        }
    }

    private func topRight(_ s: GameState) -> some View {
        VStack(alignment: .trailing, spacing: 5) {
            Menu {
                Toggle("Fast CPU turns", isOn: $game.fastMode)
                Button("Quit to menu", role: .destructive) { game.quitToMenu() }
            } label: {
                Image(systemName: "ellipsis.circle.fill").font(.system(size: 22)).foregroundStyle(.white.opacity(0.8))
            }
            if !s.partnerCalls.isEmpty {
                Text("Partner calls").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                ForEach(Array(s.partnerCalls.enumerated()), id: \.offset) { i, call in
                    HStack(spacing: 4) {
                        Text(call.identity.label).foregroundStyle(Theme.suitColor(call.identity.suit) == Theme.redSuit ? Color(red: 1, green: 0.45, blue: 0.45) : .white)
                        if s.config.deckCount == 2 { Text(call.occurrence == 1 ? "1st" : "2nd").foregroundStyle(.white.opacity(0.7)) }
                        Text("→").foregroundStyle(.white.opacity(0.5))
                        Text(resolution(s, i)).foregroundStyle(s.callResolutions[i] == nil ? .white.opacity(0.5) : .mint)
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.panel, in: Capsule())
                }
            }
        }
    }

    private func resolution(_ s: GameState, _ i: Int) -> String {
        guard let p = s.callResolutions[i] else { return "?" }
        return p == s.bidder ? "\(game.name(p)) (self)" : game.name(p)
    }
}
