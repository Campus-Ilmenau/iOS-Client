import SwiftUI
import WidgetKit

#if DEBUG
/// Das Widget „Mensa heute“ auf dem Sperrbildschirm, zum Ansehen in der Preview.
///
/// Die Preview-Funktion für Widgets zeichnet Sperrbildschirm-Widgets nicht (weiß auf weiß). Darum stehen die Ansichten
/// hier auf einem dunklen Verlauf wie das Hintergrundbild, in den Maßen des Artboards (Rechteck 160 × 72, Kreis
/// 72 × 72), wie bei „Heute Abend“. Das System legt die Fläche und färbt einfarbig; hier ist es weiß.
private struct MensaSperreVorschau: View {
    let sperre: MensaSperreAnzeige
    let uhr: String

    var body: some View {
        VStack(spacing: 14) {
            // Die Zeile über der Uhr: Datum, Gabel und Text.
            HStack(spacing: 6) {
                Text("Do 29.")
                MensaWidgetSperre(sperre: sperre, family: .accessoryInline)
            }
            .font(.system(size: 17, weight: .semibold))
            .opacity(0.88)

            Text(uhr)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .opacity(0.95)

            HStack(spacing: 12) {
                MensaWidgetSperre(sperre: sperre, family: .accessoryRectangular)
                    .padding(.horizontal, 10)
                    .frame(width: 160, height: 72)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                MensaWidgetSperre(sperre: sperre, family: .accessoryCircular)
                    .frame(width: 72, height: 72)
                    .background(.white.opacity(0.14), in: Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 30)
        .frame(width: 390)
        .background(
            LinearGradient(colors: [Color(.brandNight), Color(.brandDusk)], startPoint: .top, endPoint: .bottom)
        )
    }
}

private extension MensaSperreVorschau {
    init(_ uhr: String, tag: String = "2026-10-29", filter: MensaFilter? = nil) {
        self.init(sperre: MensaWidgetVorschau.sperre(uhr, tag: tag, filter: filter), uhr: uhr)
    }
}

// Die Zeiten aus dem Artboard `WidgetSperrMensa` und den Varianten Lücke (14:20) und Abend (15:40).

#Preview("Sperre 08:15") { MensaSperreVorschau("08:15") }
#Preview("Sperre 11:45") { MensaSperreVorschau("11:45") }
#Preview("Sperre 11:45 mit Filter") { MensaSperreVorschau("11:45", filter: MensaWidgetVorschau.filterVeganOhneMilch) }
#Preview("Sperre 11:45 nichts passt") { MensaSperreVorschau("11:45", filter: MensaWidgetVorschau.filterNichtsPasst) }
#Preview("Sperre 14:20 noch offen") { MensaSperreVorschau("14:20") }
#Preview("Sperre 15:40 Abendessen ab") { MensaSperreVorschau("15:40") }
#Preview("Sperre 17:40 Abendessen bis") { MensaSperreVorschau("17:40") }
#Preview("Sperre 21:30 Mittag morgen") { MensaSperreVorschau("21:30") }
#Preview("Sperre Freitag 21:30 Mittag Montag") { MensaSperreVorschau("21:30", tag: "2026-10-30") }
#endif
