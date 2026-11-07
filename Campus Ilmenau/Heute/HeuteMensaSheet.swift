import SwiftUI

/// Sheet „Mensa auf der Startseite“: Radio-Liste der vier Mensen mit den heutigen Öffnungszeiten.
/// Die Wahl wird sofort gespeichert (`HeuteMensaSpeicher`), „Fertig“ schließt nur.
struct HeuteMensaSheet: View {
    let optionen: [HeuteModel.MensaOption]
    let gewaehlt: MensaVenue
    let onWahl: (MensaVenue) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mensa auf der Startseite")
                        .font(.display(size: 22, relativeTo: .title2))
                        .tracking(-0.44)
                        .foregroundStyle(Color(.textPrimary))
                        .accessibilityAddTraits(.isHeader)
                    Text("Gilt für die Jetzt-Karte und „Als Nächstes“. Auch unter Mehr änderbar.")
                        .font(.subheadline)
                        .foregroundStyle(Color(.textSecondary))
                        .padding(.bottom, 6)

                    ForEach(optionen) { option in
                        zeile(option)
                        if option.id != optionen.last?.id {
                            Rectangle().fill(Color(.separator)).frame(height: 1)
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color(.background))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color(.accent))
                }
            }
        }
    }

    private func zeile(_ option: HeuteModel.MensaOption) -> some View {
        let istGewaehlt = option.venue == gewaehlt
        return Button {
            onWahl(option.venue)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.venue.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(.textPrimary))
                    if let info = option.info {
                        Text(info)
                            .font(.footnote)
                            .foregroundStyle(Color(.textSecondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Häkchen in accent; die leere Fläche hält den Platz, damit nichts springt
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color(.accent))
                    .frame(width: 24, height: 24)
                    .opacity(istGewaehlt ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel([option.venue.displayName, option.info].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(istGewaehlt ? .isSelected : [])
    }
}
