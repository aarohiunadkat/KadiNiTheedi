import SwiftUI

enum Theme {
    static let feltLight = Color(red: 0.10, green: 0.42, blue: 0.29)
    static let feltDark = Color(red: 0.03, green: 0.17, blue: 0.12)
    static let gold = Color(red: 0.97, green: 0.80, blue: 0.38)
    static let panel = Color.black.opacity(0.55)
    static let redSuit = Color(red: 0.82, green: 0.11, blue: 0.16)
    static let blackSuit = Color(red: 0.08, green: 0.09, blue: 0.13)

    static func suitColor(_ suit: Suit) -> Color { suit.isRed ? redSuit : blackSuit }
}

struct FeltBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.08)
            Ellipse()
                .fill(RadialGradient(colors: [Theme.feltLight, Theme.feltDark], center: .center, startRadius: 20, endRadius: 520))
                .padding(.horizontal, 14).padding(.vertical, 8)
            Ellipse()
                .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 2)
                .padding(.horizontal, 22).padding(.vertical, 16)
        }
        .ignoresSafeArea()
    }
}

struct Chip: View {
    let text: String
    var tint: Color = .white
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .lineLimit(1).fixedSize()
            .foregroundStyle(tint)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Theme.panel, in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
    }
}

struct GoldButtonStyle: ButtonStyle {
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(prominent ? Color.black : Theme.gold)
            .padding(.horizontal, 18).padding(.vertical, 9)
            .background(prominent ? Theme.gold : Color.white.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.6), lineWidth: prominent ? 0 : 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
