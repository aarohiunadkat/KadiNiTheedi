import SwiftUI

struct CardView: View {
    let card: Card
    var width: CGFloat = 54
    var dimmed = false
    var glow = false

    private var height: CGFloat { width * 1.42 }
    private var color: Color { Theme.suitColor(card.suit) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.12)
                .fill(LinearGradient(colors: [.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom))
            VStack(spacing: -width * 0.04) {
                Text(card.rank.label).font(.system(size: width * 0.34, weight: .heavy, design: .rounded))
                Text(card.suit.symbol).font(.system(size: width * 0.26))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(width * 0.08)
            Text(card.suit.symbol)
                .font(.system(size: width * 0.52))
                .foregroundStyle(color.opacity(0.9))
                .offset(x: width * 0.08, y: height * 0.1)
        }
        .frame(width: width, height: height)
        .overlay(RoundedRectangle(cornerRadius: width * 0.12).strokeBorder(glow ? Theme.gold : .black.opacity(0.25), lineWidth: glow ? 2.5 : 1))
        .shadow(color: glow ? Theme.gold.opacity(0.7) : .black.opacity(0.35), radius: glow ? 8 : 3, y: 2)
        .saturation(dimmed ? 0.2 : 1)
        .brightness(dimmed ? -0.25 : 0)
    }
}

struct CardBackView: View {
    var width: CGFloat = 30
    private var height: CGFloat { width * 1.42 }
    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.12)
            .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.1, blue: 0.2), Color(red: 0.3, green: 0.04, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: width * 0.08).strokeBorder(.white.opacity(0.5), lineWidth: 1).padding(width * 0.09))
            .overlay(Text("♠").font(.system(size: width * 0.5)).foregroundStyle(.white.opacity(0.35)))
            .overlay(RoundedRectangle(cornerRadius: width * 0.12).strokeBorder(.black.opacity(0.4), lineWidth: 1))
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }
}

/// A small fan of face-down cards with a count badge (CPU hands).
struct CardFan: View {
    let count: Int
    var width: CGFloat = 24

    var body: some View {
        let shown = min(count, 5)
        ZStack {
            ForEach(0..<shown, id: \.self) { i in
                let t = shown > 1 ? Double(i) / Double(shown - 1) - 0.5 : 0
                CardBackView(width: width)
                    .rotationEffect(.degrees(t * 28), anchor: .bottom)
                    .offset(x: t * width * 0.9)
            }
        }
        .frame(width: width * 2, height: width * 1.42)
        .overlay(alignment: .bottomTrailing) {
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.black.opacity(0.75), in: Capsule())
                .offset(x: 4, y: 4)
        }
        .animation(.spring(duration: 0.3), value: count)
    }
}

struct HandView: View {
    let cards: [Card]
    let legal: Set<String>?       // nil = no highlighting (not your turn)
    @Binding var selected: String?
    let revealed: Bool
    let onPlay: (Card) -> Void

    var body: some View {
        GeometryReader { geo in
            let cardW: CGFloat = 54
            let avail = geo.size.width - cardW
            let step = cards.count > 1 ? min(cardW * 0.78, avail / CGFloat(cards.count - 1)) : 0
            let total = step * CGFloat(max(cards.count - 1, 0)) + cardW
            ZStack(alignment: .bottomLeading) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                    let isLegal = legal?.contains(card.id) ?? true
                    let isSelected = selected == card.id
                    CardView(card: card, width: cardW, dimmed: legal != nil && !isLegal, glow: legal != nil && isLegal)
                        .offset(x: CGFloat(i) * step, y: isSelected ? -20 : (revealed ? 0 : 140))
                        .opacity(revealed ? 1 : 0)
                        .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(revealed ? Double(i) * 0.05 : 0), value: revealed)
                        .animation(.spring(duration: 0.25), value: isSelected)
                        .zIndex(Double(i))
                        .onTapGesture {
                            guard legal != nil, isLegal else { return }
                            if isSelected { selected = nil; onPlay(card) } else { selected = card.id }
                        }
                }
            }
            .frame(width: total, height: geo.size.height, alignment: .bottomLeading)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 54 * 1.42 + 24)
    }
}
