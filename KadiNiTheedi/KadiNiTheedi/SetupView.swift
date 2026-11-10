import SwiftUI

struct SetupView: View {
    @Bindable var game: GameController

    var body: some View {
        let cfg = GameConfig(playerCount: game.playerCount)
        ZStack {
            FeltBackground()
            HStack(spacing: 36) {
                VStack(spacing: 6) {
                    Text("♠").font(.system(size: 64)).foregroundStyle(Theme.gold)
                    Text("Kali Ni Teedi")
                        .font(.system(size: 36, weight: .heavy, design: .serif))
                    Text("3♠ · the secret-partner card game")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    Text("Players at the table").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 8) {
                        ForEach(GameConfig.supportedPlayerCounts, id: \.self) { n in
                            Button { withAnimation(.spring(duration: 0.25)) { game.playerCount = n } } label: {
                                Text("\(n)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .frame(width: 38, height: 38)
                                    .foregroundStyle(game.playerCount == n ? Color.black : Theme.gold)
                                    .background(game.playerCount == n ? Theme.gold : Color.white.opacity(0.1), in: Circle())
                                    .overlay(Circle().strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1))
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        Chip(text: "\(cfg.deckCount) deck\(cfg.deckCount > 1 ? "s" : "")")
                        Chip(text: "\(cfg.cpuCount) CPUs")
                        Chip(text: "\(cfg.partnerCalls) partner call\(cfg.partnerCalls > 1 ? "s" : "")")
                        Chip(text: "opens at \(cfg.openingBid)")
                    }
                    TextField("Your name (optional)", text: $game.humanName)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .padding(8)
                        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: 240)
                    Button("Start Game") { game.startGame() }
                        .buttonStyle(GoldButtonStyle())
                }
                .padding(22)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.gold.opacity(0.25)))
                .frame(maxWidth: 500)
            }
            .padding(.horizontal, 40)
        }
    }
}
