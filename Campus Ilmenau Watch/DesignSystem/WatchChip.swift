import SwiftUI

/// Kapsel mit kurzer Aussage, 11 pt Bold. Grün und Blau sind Flächen mit eigener Schriftfarbe (`onGreen`, `onBlue`),
/// Neutral ist `surfaceSecondary`. Der Text darf umbrechen statt abgeschnitten zu werden.
struct WatchChip: View {
    enum Variante {
        case green
        case blue
        case neutral
        case danger

        fileprivate var hintergrund: Color {
            switch self {
            case .green: Color(.green)
            case .blue: Color(.blue)
            case .neutral, .danger: Color(.watchSurface2)
            }
        }

        fileprivate var schrift: Color {
            switch self {
            case .green: Color(.onGreen)
            case .blue: Color(.onBlue)
            case .neutral: Color(.watchText2)
            case .danger: Color(.watchDanger)
            }
        }
    }

    private let titel: LocalizedStringKey
    private let variante: Variante
    private let systemImage: String?

    init(_ titel: LocalizedStringKey, variante: Variante = .neutral, systemImage: String? = nil) {
        self.titel = titel
        self.variante = variante
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .accessibilityHidden(true)
            }
            Text(titel)
        }
            .uhrSchrift(11, .bold)
            .foregroundStyle(variante.schrift)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(variante.hintergrund, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview("Chips") {
    VStack(alignment: .leading, spacing: 6) {
        WatchChip("Vegan", variante: .green)
        WatchChip("Regional", variante: .blue)
        WatchChip("Vegetarisch", variante: .neutral)
        WatchChip("Geschlossen", variante: .danger)
        WatchChip("Ein langer Text, der auf der kleinen Uhr umbrechen muss", variante: .neutral)
    }
    .padding(8)
    .containerBackground(Color(.watchBackground), for: .navigation)
}
