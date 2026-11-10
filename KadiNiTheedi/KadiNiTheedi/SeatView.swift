import SwiftUI

struct SeatView: View {
    let name: String
    let cardCount: Int?
    var isDealer = false
    var isActing = false
    var isWinner = false
    var isBidder = false
    var isPartner = false
    var passed = false
    var bidText: String?
    var pulse = false

    var body: some View {
        VStack(spacing: 3) {
            if let cardCount { CardFan(count: cardCount, width: 22) }
            Text(name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(isActing ? Theme.gold : Color.black.opacity(0.6), in: Capsule())
                .foregroundStyle(isActing ? Color.black : Color.white)
                .overlay(Capsule().strokeBorder(isWinner ? Theme.gold : .white.opacity(0.2), lineWidth: isWinner ? 2.5 : 1))
                .shadow(color: isActing ? Theme.gold.opacity(0.8) : .clear, radius: 8)
            HStack(spacing: 3) {
                if isDealer { badge("D", .white) }
                if isBidder { badge("Bidder", Theme.gold) }
                if isPartner { badge("Partner", .mint) }
                if passed { badge("Pass", .gray) }
                if let bidText { badge(bidText, Theme.gold) }
                if isWinner { badge("Wins", Theme.gold) }
            }
        }
        .scaleEffect(pulse ? 1.18 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: pulse)
        .animation(.easeInOut(duration: 0.2), value: isActing)
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.9), in: Capsule())
            .foregroundStyle(.black)
    }
}

struct TrickArea: View {
    let plays: [PlayedCard]
    let angleFor: (Int) -> Double
    let sweepTarget: Int?
    let winner: Int?

    var body: some View {
        ZStack {
            ForEach(plays, id: \.card.id) { play in
                let a = angleFor(play.player)
                let slot = CGSize(width: cos(a) * 64, height: sin(a) * 30)
                let sweep = sweepTarget.map { CGSize(width: cos(angleFor($0)) * 360, height: sin(angleFor($0)) * 230) }
                CardView(card: play.card, width: 46, glow: winner == play.player && sweepTarget == nil)
                    .rotationEffect(.degrees(Double(play.player % 5) * 4 - 8))
                    .offset(sweep ?? slot)
                    .opacity(sweep == nil ? 1 : 0)
                    .transition(.scale(scale: 0.5).combined(with: .opacity).combined(with: .offset(x: cos(a) * 160, y: sin(a) * 110)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: plays.map(\.card.id))
    }
}
