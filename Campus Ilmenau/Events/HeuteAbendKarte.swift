import SwiftUI

/// Abschnitt „Heute Abend“ für die Heute-Seite: bis zu 3 Veranstaltungen als horizontal scrollende Karten, ohne Bild
/// und Logo. Ohne Einträge (auch bei Fehler oder Zeitablauf) entfällt der Abschnitt ganz, es gibt keinen Leer-Zustand.
///
/// Die Karte bekommt fertige Events (siehe `HeuteModel.heuteAbend` bzw. `HeuteAbendModel`) und entscheidet nur über
/// die Darstellung.
struct HeuteAbendKarte: View {
    let events: [CampusEvent]
    /// Bezugszeit für „Läuft seit …“.
    let jetzt: Date
    /// „Alle“: Events-Tab mit aktivem „Heute Abend“.
    let onAlle: () -> Void
    /// Tippen auf eine Karte: das Detail.
    let onOeffne: (CampusEvent) -> Void

    @Environment(\.dynamicTypeSize) private var schriftgroesse

    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                kopf
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(events) { event in
                            karte(event)
                        }
                    }
                    // Alle Karten so hoch wie die höchste: bei großer Schrift wachsen sie, nichts wird abgeschnitten
                    .fixedSize(horizontal: false, vertical: true)
                }
                // Die Karten laufen bis an den Bildschirmrand, der erste Eintrag beginnt am 16-pt-Rand der Seite
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .padding(.horizontal, -16)
                .scrollClipDisabled()
            }
        }
    }

    private var kopf: some View {
        HStack {
            Text("Heute Abend")
                .heuteAbschnittstitel()
            Spacer(minLength: 8)
            Button(action: onAlle) {
                Text("Alle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.accent))
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -12)
            .accessibilityLabel("Alle Veranstaltungen heute Abend")
        }
    }

    private func karte(_ event: CampusEvent) -> some View {
        let laeuft = event.beginn <= jetzt
        let uhrzeit = HeuteUhr.uhrzeit(event.beginn)
        let zeit = laeuft ? "Läuft seit \(uhrzeit)" : "Heute · \(uhrzeit)"
        let veranstalter = event.veranstalterAnzeigen ?? event.ort?.trimmingCharacters(in: .whitespacesAndNewlines).nilWennLeer
        return Button {
            onOeffne(event)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(zeit)
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Color(.accent))
                Text(event.titel)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    // Zwei Zeilen; bei großer Schrift ohne Grenze, damit die Karte höher wird statt abzuschneiden
                    .lineLimit(schriftgroesse.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)
                if let veranstalter {
                    Text(veranstalter)
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 220, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [laeuft ? "läuft seit \(uhrzeit)" : uhrzeit, event.titel, veranstalter].compactMap { $0 }.joined(separator: ", ")
        )
        .accessibilityAddTraits(.isButton)
    }
}

private extension String {
    var nilWennLeer: String? { isEmpty ? nil : self }
}
