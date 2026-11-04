//
//  MensaMealDetailView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

/// Gericht-Detail, per Push geöffnet. Liest die Preisgruppe und merkt Favoriten lokal auf dem Gerät.
struct MensaMealDetailView: View {
    let meal: MensaMeal
    var canteens: [Canteen] = []

    @AppStorage(MensaPriceGroup.storageKey) private var priceGroup: MensaPriceGroup = .studierende
    @State private var isFavorite: Bool

    init(meal: MensaMeal, canteens: [Canteen] = []) {
        self.meal = meal
        self.canteens = canteens
        self._isFavorite = State(initialValue: MensaFavoriteStore().isFavorite(meal))
    }

    var body: some View {
        MensaMealDetailContent(
            meal: meal,
            priceGroup: priceGroup,
            canteens: canteens,
            isFavorite: Binding(
                get: { isFavorite },
                set: { newValue in
                    isFavorite = newValue
                    MensaFavoriteStore().setFavorite(newValue, for: meal)
                }
            )
        )
    }
}

/// Oberfläche des Details ohne eigene Datenhaltung, damit sie sich in Previews in jeder Variante zeigen lässt.
struct MensaMealDetailContent: View {
    let meal: MensaMeal
    let priceGroup: MensaPriceGroup
    let canteens: [Canteen]
    @Binding var isFavorite: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var expandedComponents: Set<UUID> = []
    @State private var showsHours = false

    private static let headerHeight: CGFloat = 250
    private static let overlap: CGFloat = 36

    private var venueName: String {
        MensaVenue.allCases.first { $0.matches(canteenName: meal.canteenName) }?.displayName ?? meal.canteenName
    }

    private var kicker: String {
        let category = meal.category.isEmpty ? "Gericht" : meal.category
        return "\(venueName) · \(category) · \(MensaFormatting.dayLabel(meal.date))"
    }

    var body: some View {
        // Die Safe-Area-Höhe oben muss außerhalb von `ignoresSafeArea` gelesen werden, sonst ist sie 0
        // und die Tasten liegen auf der Statusleiste.
        GeometryReader { proxy in
            let top = proxy.safeAreaInsets.top
            ZStack(alignment: .top) {
                // Kopf mit zwei Bändern, steht fest und reicht bis an den oberen Bildschirmrand.
                DiagonalBands(.header, height: Self.headerHeight) { EmptyView() }
                    .ignoresSafeArea(edges: .top)

                // Die Karte ragt 36 pt in den Kopf. Der Inhalt beginnt unter der Statusleiste,
                // der Kopf misst 250 pt vom Bildschirmrand.
                VStack(spacing: 0) {
                    Color.clear.frame(height: max(0, Self.headerHeight - Self.overlap - top))
                    ScrollView {
                        content
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }

                HStack {
                    roundButton(systemImage: "chevron.left", label: "Zurück zum Speiseplan") { dismiss() }
                    Spacer()
                    roundButton(
                        systemImage: isFavorite ? "heart.fill" : "heart",
                        label: isFavorite ? "Favorit entfernen" : "Als Favorit merken",
                        tint: isFavorite ? Color(.danger) : Color(.brandNight)
                    ) { isFavorite.toggle() }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .background(Color(.background).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showsHours) {
            MensaOpeningHoursView(canteens: canteens)
        }
    }

    // MARK: - Inhalt

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleCard
            priceSection
            if !meal.uniqueAllergies.isEmpty {
                chipSection("Allergene", icon: "exclamationmark.triangle", items: meal.uniqueAllergies)
            }
            if !meal.uniqueAdditives.isEmpty {
                chipSection("Zusatzstoffe", icon: "testtube.2", items: meal.uniqueAdditives)
            }
            if !meal.components.isEmpty {
                componentsSection
            }
            if let co2 = meal.co2GramPerPortion {
                sectionHead("Umwelt", icon: "leaf")
                Card {
                    Text("≈ \(co2.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE")))) g CO₂ pro Portion")
                        .font(.body)
                        .foregroundStyle(Color(.textPrimary))
                }
            }
            actions
            footer
        }
    }

    private var titleCard: some View {
        Card(verticalPadding: 18) {
            VStack(alignment: .leading, spacing: 0) {
                // Im Mockup steht das Label weiß im Kopf, dort liegt es aber teils auf Grün und teils auf dem Hintergrund
                // und ist nicht lesbar. Deshalb steht es hier als Kategorie-Zeile wie in der Liste.
                Text(kicker)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.72)
                    .foregroundStyle(Color(.textTertiary))
                    .padding(.bottom, 4)

                Text(meal.name)
                    .display(size: 26, relativeTo: .title)
                    .foregroundStyle(Color(.textPrimary))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let description = meal.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(Color(.textSecondary))
                        .padding(.top, 6)
                }

                if !meal.detailChips.isEmpty {
                    ChipFlowLayout(spacing: 6) {
                        ForEach(meal.detailChips, id: \.self) { chip in
                            Chip(LocalizedStringKey(chip.title), variant: chip.variant)
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
    }

    // MARK: - Preis

    private var priceSection: some View {
        let others = MensaPriceGroup.allCases.filter { $0 != priceGroup }
        return VStack(alignment: .leading, spacing: 0) {
            sectionHead("Preis", icon: "tag")
            Card(verticalPadding: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(priceGroup.title)
                        .font(.footnote)
                        .foregroundStyle(Color(.textTertiary))
                    Text(meal.price.formatted(for: priceGroup))
                        .display(size: 40, relativeTo: .largeTitle)
                        .foregroundStyle(Color(.textPrimary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.bottom, 10)
                    ForEach(others) { group in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(group.title)
                                .foregroundStyle(Color(.textSecondary))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(meal.price.formatted(for: group))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color(.textPrimary))
                        }
                        .padding(.vertical, 11)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Color(.separator)).frame(height: 1)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Chips

    private func chipSection(_ title: LocalizedStringKey, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(title, icon: icon)
            Card {
                ChipFlowLayout(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        Chip(LocalizedStringKey(item), variant: .neutral)
                    }
                }
            }
        }
    }

    // MARK: - Bestandteile

    private var componentsSection: some View {
        let infos = meal.componentInfos
        return VStack(alignment: .leading, spacing: 0) {
            sectionHead("Bestandteile", icon: "list.bullet")
            Card(verticalPadding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(infos.enumerated()), id: \.element.id) { index, info in
                        componentRow(info, isFirst: index == 0)
                    }
                }
            }
        }
    }

    private func componentRow(_ info: MensaComponentInfo, isFirst: Bool) -> some View {
        let isExpanded = expandedComponents.contains(info.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    if isExpanded { expandedComponents.remove(info.id) } else { expandedComponents.insert(info.id) }
                }
            } label: {
                HStack(spacing: 12) {
                    Text(info.name)
                        .font(.body)
                        .foregroundStyle(Color(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(.textTertiary))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "aufgeklappt" : "zugeklappt")

            if isExpanded {
                Text(info.infoText)
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Color(.separator)).frame(height: 1) }
        }
    }

    // MARK: - Abschluss

    private var actions: some View {
        VStack(spacing: 10) {
            PrimaryButton(isFavorite ? "Als Favorit gemerkt ✓" : "Als Favorit merken") {
                isFavorite.toggle()
            }
            SecondaryButton("Öffnungszeiten der Mensa") {
                showsHours = true
            }
        }
        .padding(.top, 22)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(venueName) · \(MensaFormatting.fullDate(meal.date))")
            Text("Angaben laut Speiseplan des Studierendenwerks. Ohne Gewähr.")
        }
        .font(.caption)
        .foregroundStyle(Color(.textTertiary))
        .padding(.horizontal, 2)
        .padding(.top, 14)
    }

    // MARK: - Bausteine

    private func sectionHead(_ title: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(.textTertiary))
                .accessibilityHidden(true)
            Text(title)
                .font(.body.bold())
                .foregroundStyle(Color(.textPrimary))
        }
        .padding(.horizontal, 2)
        .padding(.top, 22)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func roundButton(
        systemImage: String,
        label: LocalizedStringKey,
        tint: Color = Color(.brandNight),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Color(.onBlue).opacity(0.92), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Previews

private extension MensaMeal {
    static var previewFull: MensaMeal {
        MensaMeal(
            id: "detail-full",
            category: "Essen 1",
            name: "Linsen-Dal",
            description: "Basmatireis, Mango-Chutney",
            price: MensaMealPrice(student: 2.9, staff: 4.4, guest: 5.8, currency: "€"),
            allergies: ["Sellerie", "Senf"],
            badges: ["Vegan", "Vegetarisch"],
            additives: ["Antioxidationsmittel"],
            categories: ["Regional", "Kinderessen"],
            co2GramPerPortion: 420,
            components: [
                MensaMealComponent(name: "Linsen-Dal", codes: ["Sellerie", "Vegan", "Vegetarisch"]),
                MensaMealComponent(name: "Basmatireis", codes: ["Ohne Zusatzstoffe", "Vegan"]),
                MensaMealComponent(name: "Mango-Chutney", codes: ["Senf", "Antioxidationsmittel", "Vegan"])
            ],
            canteenName: "Mensa Ehrenberg",
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 29)) ?? .now
        )
    }

    /// Ohne Beschreibung, Allergene, Zusatzstoffe, Bestandteile und CO₂, ohne Gästepreis.
    static var previewShort: MensaMeal {
        MensaMeal(
            id: "detail-short",
            category: "Aktionstheke",
            name: "Pasta Arrabbiata",
            description: nil,
            price: MensaMealPrice(student: 2.6, staff: 3.9, guest: nil, currency: "€"),
            allergies: [],
            badges: ["Vegan"],
            additives: [],
            categories: [],
            co2GramPerPortion: nil,
            components: [],
            canteenName: "Mensa Ehrenberg",
            date: .now
        )
    }
}

private struct DetailPreview: View {
    let meal: MensaMeal
    var group: MensaPriceGroup = .studierende
    @State private var isFavorite = false

    var body: some View {
        NavigationStack {
            MensaMealDetailContent(meal: meal, priceGroup: group, canteens: [], isFavorite: $isFavorite)
        }
    }
}

#Preview("Gericht vollständig – Light") {
    DetailPreview(meal: .previewFull).preferredColorScheme(.light)
}

#Preview("Gericht vollständig – Dark") {
    DetailPreview(meal: .previewFull).preferredColorScheme(.dark)
}

#Preview("Gericht knapp – Light") {
    DetailPreview(meal: .previewShort).preferredColorScheme(.light)
}

#Preview("Gericht knapp – Dark") {
    DetailPreview(meal: .previewShort).preferredColorScheme(.dark)
}

#Preview("Preisgruppe Bedienstete – Light") {
    DetailPreview(meal: .previewFull, group: .bedienstete).preferredColorScheme(.light)
}

#Preview("Preisgruppe Bedienstete – Dark") {
    DetailPreview(meal: .previewFull, group: .bedienstete).preferredColorScheme(.dark)
}

#Preview("Gericht – Große Schrift") {
    DetailPreview(meal: .previewFull)
        .dynamicTypeSize(.xxxLarge)
}
