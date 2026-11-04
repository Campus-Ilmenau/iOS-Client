//
//  MensaFilterSheet.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

/// Sheet „Filter“: Ernährung als Segment (immer gleich wie die Pills), „Nur Bio“ und ein Schalter je Allergen.
/// Gilt für alle Mensen und Tage und bleibt gespeichert.
struct MensaFilterSheet: View {
    @Binding var filter: MensaFilter
    /// Alle bekannten Allergene (feste Liste), dazu ausgeschlossene und neue aus dem Speiseplan.
    let availableAllergens: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionTitle("Ernährung")
                    group {
                        SegmentedControl(
                            selection: $filter.diet,
                            options: [(.alle, "Alle"), (.vegetarisch, "Vegetarisch"), (.vegan, "Vegan")]
                        )
                        .padding(.vertical, 12)
                        separator
                        toggleRow("Nur Bio", isOn: $filter.onlyBio)
                    }
                    note("„Vegetarisch“ zeigt auch vegane Gerichte.")

                    sectionTitle("Allergene ausschließen")
                        .padding(.top, 22)
                    group {
                        ForEach(Array(availableAllergens.enumerated()), id: \.element) { index, allergen in
                            if index > 0 { separator }
                            toggleRow("Ohne \(allergen)", isOn: allergenBinding(allergen))
                        }
                    }
                    note("Alle Allergene, die der Speiseplan kennt. Der Filter gilt für alle Mensen und Tage und bleibt gespeichert.")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 34)
            }
            .background(Color(.background))
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zurücksetzen") { filter = MensaFilter() }
                        .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .tint(Color(.accent))
        }
    }

    // MARK: - Bausteine

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.65)
            .foregroundStyle(Color(.textTertiary))
            .padding(.horizontal, 6)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .padding(.horizontal, 16)
            .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var separator: some View {
        Rectangle().fill(Color(.separator)).frame(height: 1)
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color(.textTertiary))
            .padding(.horizontal, 6)
            .padding(.top, 8)
    }

    /// Neutral: an = `buttonPrimary`. Es sind Einstellungen, kein Rot und kein Grün.
    private func toggleRow(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .foregroundStyle(Color(.textPrimary))
        }
        .toggleStyle(NeutralToggleStyle())
        .frame(minHeight: 52)
    }

    private func allergenBinding(_ allergen: String) -> Binding<Bool> {
        Binding(
            get: { filter.excludedAllergens.contains(allergen) },
            set: { isOn in
                if isOn {
                    filter.excludedAllergens.insert(allergen)
                } else {
                    filter.excludedAllergens.remove(allergen)
                }
            }
        )
    }
}

// MARK: - Previews

/// Zeigt das Sheet ohne Präsentations-Animation: bei `.medium` etwa halbe Höhe über dem abgedunkelten Hintergrund, bei `.large` fast ganz.
private struct FilterSheetPreview: View {
    let detent: PresentationDetent
    var filter = MensaFilter(diet: .vegetarisch, onlyBio: false, excludedAllergens: ["Weizen"])
    @State private var currentFilter = MensaFilter()

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color(.background)
                Color.black.opacity(0.35)
                MensaFilterSheet(
                    filter: $currentFilter,
                    availableAllergens: MensaFilter.availableAllergens(in: [], keeping: [])
                )
                .frame(height: detent == .medium ? proxy.size.height * 0.55 : proxy.size.height - 12)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34))
                .shadow(color: Color(.brandNight).opacity(0.28), radius: 18, y: -8)
            }
            .ignoresSafeArea()
        }
        .onAppear { currentFilter = filter }
    }
}

#Preview("Filter-Sheet medium – Light") {
    FilterSheetPreview(detent: .medium).preferredColorScheme(.light)
}

#Preview("Filter-Sheet medium – Dark") {
    FilterSheetPreview(detent: .medium).preferredColorScheme(.dark)
}

#Preview("Filter-Sheet large – Light") {
    FilterSheetPreview(detent: .large).preferredColorScheme(.light)
}

#Preview("Filter-Sheet large – Dark") {
    FilterSheetPreview(detent: .large).preferredColorScheme(.dark)
}

#Preview("Filter-Sheet leer – Light") {
    FilterSheetPreview(detent: .large, filter: MensaFilter()).preferredColorScheme(.light)
}
