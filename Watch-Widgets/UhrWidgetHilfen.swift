import WidgetKit
import SwiftUI

extension View {
    /// Rechteck und Kreis liegen auf der Fläche des Systems; Zeile und Ecke haben keine. Die Farben bestimmt das
    /// Zifferblatt.
    func uhrWidgetHintergrund(_ family: WidgetFamily) -> some View {
        containerBackground(for: .widget) {
            if family == .accessoryInline || family == .accessoryCorner { Color.clear } else { AccessoryWidgetBackground() }
        }
    }
}

/// Das kleine Wort unter der Zahl im Kreis, immer in 9 pt. Unten ist der Kreis schmal: Passt das Wort nicht, steht an
/// seiner Stelle das Ersatzwort. Kein Buchstabe wird abgeschnitten, und die Schrift wird nicht kleiner.
struct UhrKreisWort: View {
    /// So breit ist der Kreis auf Höhe dieser Zeile höchstens.
    static let breite: CGFloat = 36

    let text: String
    let ersatz: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wort(text)
            wort(ersatz)
        }
        .frame(maxWidth: Self.breite)
    }

    private func wort(_ wort: String) -> some View {
        Text(wort)
            .font(.system(size: 9, weight: .semibold))
            .opacity(0.8)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

extension SmartStack.Relevanz {
    /// Für den Eintrag der Zeitleiste.
    var eintragRelevanz: TimelineEntryRelevance {
        TimelineEntryRelevance(score: score, duration: dauer)
    }
}
