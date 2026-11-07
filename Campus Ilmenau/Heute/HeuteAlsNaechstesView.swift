import SwiftUI

/// Abschnitt „Als Nächstes“: eine Karte mit Zeilen aus Zeit, Farbpunkt, Titel, Unterzeile und Chevron.
/// Ohne Einträge entfällt der Abschnitt.
struct HeuteAlsNaechstesView: View {
    let termine: [HeuteTermin]
    let onTermin: (HeuteZiel) -> Void

    @Environment(\.dynamicTypeSize) private var schriftgroesse
    /// Feste Breite der Zeitspalte, damit Farbpunkte und Titel untereinander fluchten (wächst mit der Schrift).
    @ScaledMetric(relativeTo: .subheadline) private var zeitBreite: CGFloat = 52

    var body: some View {
        if !termine.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Als Nächstes")
                    .heuteAbschnittstitel()
                VStack(spacing: 0) {
                    ForEach(termine) { termin in
                        zeile(termin)
                        if termin.id != termine.last?.id {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 1)
                                // Eingerückt bis zum Titel
                                .padding(.leading, schriftgroesse.isAccessibilitySize ? 0 : zeitBreite + 8 + 24)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func zeile(_ termin: HeuteTermin) -> some View {
        Button {
            onTermin(termin.ziel)
        } label: {
            let layout = schriftgroesse.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            HStack(spacing: 12) {
                layout {
                    Text(termin.zeit)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color(.textPrimary))
                        .frame(width: schriftgroesse.isAccessibilitySize ? nil : zeitBreite, alignment: .leading)
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Circle()
                            .fill(farbe(termin.farbe))
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(termin.titel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(.textPrimary))
                                .multilineTextAlignment(.leading)
                            if !termin.unterzeile.isEmpty {
                                Text(termin.unterzeile)
                                    .font(.footnote)
                                    .foregroundStyle(Color(.textSecondary))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.textTertiary))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([termin.zeit, termin.titel, termin.unterzeile].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }

    private func farbe(_ farbe: HeuteFarbe) -> Color {
        switch farbe {
        case .brandOrange: Color(.brandOrange)
        case .blue: Color(.blue)
        }
    }
}
