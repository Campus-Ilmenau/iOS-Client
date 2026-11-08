import SwiftUI
import WidgetKit

#if DEBUG
/// Das Widget „Heute Abend“ auf dem Sperrbildschirm, zum Ansehen in der Preview der App.
///
/// Die Preview-Funktion für Widgets zeichnet Sperrbildschirm-Widgets nicht (weiß auf weiß). Darum liegen die Ansichten
/// in `Shared/` und erscheinen hier auf einem dunklen Verlauf wie das Hintergrundbild, in den Maßen des Artboards
/// (Rechteck 160 × 72, Kreis 72 × 72). Das System legt die Fläche und färbt einfarbig; hier ist es weiß.
private struct SperrbildschirmVorschau: View {
    let szenario: AbendWidgetVorschau.Szenario

    private var sperre: AbendWidgetAnzeige.Sperrbildschirm { AbendWidgetVorschau.anzeige(szenario).sperre }

    var body: some View {
        VStack(spacing: 14) {
            // Die Zeile über der Uhr: Datum, Mond und Text.
            HStack(spacing: 6) {
                Text("Do 29.")
                AbendWidgetSperre(sperre: sperre, family: .accessoryInline)
            }
            .font(.system(size: 17, weight: .semibold))
            .opacity(0.88)

            Text(Self.uhr(szenario))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .opacity(0.95)

            HStack(spacing: 12) {
                AbendWidgetSperre(sperre: sperre, family: .accessoryRectangular)
                    .padding(.horizontal, 10)
                    .frame(width: 160, height: 72)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                AbendWidgetSperre(sperre: sperre, family: .accessoryCircular)
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

    private static func uhr(_ szenario: AbendWidgetVorschau.Szenario) -> String {
        HeuteUhr.uhrzeit(szenario.jetzt)
    }
}

#Preview("Sperrbildschirm nichts") { SperrbildschirmVorschau(szenario: .nichts) }
#Preview("Sperrbildschirm 18:30") { SperrbildschirmVorschau(szenario: .abend1830) }
#Preview("Sperrbildschirm 19:40") { SperrbildschirmVorschau(szenario: .laeuft1940) }
#Preview("Sperrbildschirm 23:50") { SperrbildschirmVorschau(szenario: .naechsterAbend) }
#Preview("Sperrbildschirm leer") { SperrbildschirmVorschau(szenario: .leer) }
#endif
