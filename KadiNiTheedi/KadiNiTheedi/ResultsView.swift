import SwiftUI

struct ResultsView: View {
    @Bindable var game: GameController
    let state: GameState
    let result: GameResult

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            HStack(alignment: .top, spacing: 24) {
                summary.frame(width: 300)
                table
            }
            .padding(20)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.gold.opacity(0.4)))
            .padding(.horizontal, 24).padding(.vertical, 12)
        }
    }

    private func name(_ p: Int) -> String { state.players[p].name }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.bidderSucceeded ? "Bid made!" : "Bid failed")
                .font(.system(size: 28, weight: .heavy, design: .serif))
                .foregroundStyle(result.bidderSucceeded ? Color.mint : Color.orange)
            line("Bidder", name(result.bidder))
            line("Winning bid", "\(result.winningBid)")
            line("Trump", result.trump.symbol)
            line("Bidder team", "\(result.teamPoints) pts")
            line("Opponents", "\(result.opponentPoints) pts")
            Divider().overlay(.white.opacity(0.2))
            Text("Partner calls").font(.caption.bold()).foregroundStyle(Theme.gold)
            ForEach(Array(result.calls.enumerated()), id: \.offset) { i, call in
                let who = result.callResolutions[i].map { $0 == result.bidder ? "\(name($0)) (self)" : name($0) } ?? "—"
                line(state.config.deckCount == 2 ? call.label : call.identity.label, who)
            }
            Spacer(minLength: 4)
            HStack {
                Button("Play Again") { game.startGame() }.buttonStyle(GoldButtonStyle())
                Button("New Game") { game.quitToMenu() }.buttonStyle(GoldButtonStyle(prominent: false))
            }
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
    }

    private func line(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.white.opacity(0.65)); Spacer(); Text(v).fontWeight(.bold) }
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack {
                Text("#").frame(width: 28, alignment: .leading)
                Text("Player"); Spacer()
                Text("Role").frame(width: 80, alignment: .leading)
                Text("Score").frame(width: 70, alignment: .trailing)
            }
            .font(.caption.bold()).foregroundStyle(Theme.gold).padding(.bottom, 6)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(result.ranking, id: \.player) { r in
                        HStack {
                            Text("\(r.rank)").frame(width: 28, alignment: .leading)
                            Text(name(r.player)).fontWeight(r.player == 0 ? .heavy : .regular)
                            Spacer()
                            Text(result.roles[r.player].rawValue.capitalized).frame(width: 80, alignment: .leading)
                                .foregroundStyle(result.roles[r.player] == .opponent ? .white.opacity(0.6) : Theme.gold)
                            Text("\(r.score)").monospacedDigit().fontWeight(.bold).frame(width: 70, alignment: .trailing)
                                .foregroundStyle(r.score < 0 ? Color.orange : .white)
                        }
                        .font(.system(size: 14, design: .rounded))
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(r.player == 0 ? Theme.gold.opacity(0.18) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
