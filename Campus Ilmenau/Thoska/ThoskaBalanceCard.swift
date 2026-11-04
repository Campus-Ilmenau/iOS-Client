import SwiftUI

/// Die Thoska-Karte der Ansicht „Thoska“: Verlauf von Blau nach Nachtblau mit grünem Band.
/// Bleibt in Light und Dark gleich und nutzt deshalb nur Farben ohne Dark-Variante.
struct ThoskaBalanceCard: View {
    /// Betrag, schon formatiert („12,40 €“ oder „–,– €“).
    let balanceText: String
    /// Vorgelesener Text der ganzen Karte.
    let accessibilityText: String
    /// Vom Nutzer vergebener Kartenname, steht neben „Guthaben“.
    var cardName: String?

    @State private var cardWidth: CGFloat = 0

    /// Der Betrag soll links vom grünen Band bleiben (dessen Kante beginnt unten bei 48 % der Breite).
    /// Bei großer Schrift schrumpft er deshalb, statt aufs Band zu laufen.
    private var amountMaxWidth: CGFloat {
        cardWidth > 0 ? max(0, cardWidth * 0.46 - 20) : .infinity
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(.symbolWhite)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                Text("Thoska")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.96)
                    .opacity(0.85)
            }

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(cardName.map { "Guthaben · \($0)" } ?? "Guthaben")
                    .font(.footnote)
                    .opacity(0.8)
                    .lineLimit(1)
                Text(balanceText)
                    .display(size: 44, relativeTo: .largeTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .frame(maxWidth: amountMaxWidth, alignment: .leading)
            }
        }
        .foregroundStyle(Color(.onBlue))
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Color(.blue), Color(.brandNight)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                UnitPolygon(points: [
                    CGPoint(x: 0.72, y: 0), CGPoint(x: 0.86, y: 0),
                    CGPoint(x: 0.62, y: 1), CGPoint(x: 0.48, y: 1)
                ])
                .fill(Color(.green).opacity(0.9))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cardWidth = $0 }
        // Weicher Schatten nach unten; der eingerückte Untergrund ersetzt den negativen Spread aus dem Mockup.
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.brandNight))
                .padding(14)
                .shadow(color: Color(.brandNight).opacity(0.55), radius: 16, x: 0, y: 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

#Preview("Thoska-Karte") {
    VStack(spacing: 24) {
        ThoskaBalanceCard(balanceText: "12,40 €", accessibilityText: "Thoska-Guthaben 12,40 Euro")
        ThoskaBalanceCard(balanceText: "–,– €", accessibilityText: "Thoska-Guthaben noch nicht ausgelesen")
    }
    .padding(16)
    .background(Color(.background))
}
