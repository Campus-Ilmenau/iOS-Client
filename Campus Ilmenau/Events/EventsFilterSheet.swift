import SwiftUI

/// Sheet „Filter“ (Detents medium und large): „Art“ als Segment und „Abgesagte ausblenden“.
/// Tag, „Heute Abend“ und Veranstalter wählt man über der Liste.
struct EventsFilterSheet: View {
    @Binding var auswahl: EventsAuswahl

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    abschnittstitel("Art")
                    SegmentedControl(
                        selection: $auswahl.art,
                        options: [(.alle, "Alle"), (.veranstaltung, "Veranstaltungen"), (.frist, "Fristen")]
                    )
                    .accessibilityLabel("Art")

                    VStack(spacing: 0) {
                        Toggle(isOn: $auswahl.abgesagteAusblenden) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Abgesagte ausblenden")
                                    .foregroundStyle(Color(.textPrimary))
                                Text("Sonst erscheinen sie mit „Fällt aus“.")
                                    .font(.footnote)
                                    .foregroundStyle(Color(.textTertiary))
                            }
                        }
                        .toggleStyle(NeutralToggleStyle())
                        .frame(minHeight: 52)
                    }
                    .padding(.horizontal, 16)
                    .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 22)

                    Text("Tag, Heute Abend und Veranstalter wählst du über der Liste.")
                        .font(.caption)
                        .foregroundStyle(Color(.textTertiary))
                        .padding(.horizontal, 6)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
            .background(Color(.background))
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zurücksetzen") { auswahl.sheetZuruecksetzen() }
                        .disabled(auswahl.sheetAnzahl == 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .tint(Color(.accent))
        }
        .presentationDetents([.medium, .large])
    }

    private func abschnittstitel(_ titel: LocalizedStringKey) -> some View {
        Text(titel)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.65)
            .foregroundStyle(Color(.textTertiary))
            .padding(.horizontal, 6)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}
