//
//  MensaMealCard.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

/// Gericht in der Liste nach dem Design: Kategorie, Name mit Preis der Preisgruppe, Beschreibung, Chips, Allergene.
/// Die Karte ist reine Darstellung; das Öffnen (Push) übernimmt der Aufrufer.
struct MensaMealCard: View {
    let meal: MensaMeal
    @AppStorage(MensaPriceGroup.storageKey, store: AppGroup.defaults) private var priceGroup: MensaPriceGroup = .studierende

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text(meal.category.isEmpty ? "Gericht" : meal.category)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Color(.textTertiary))
                    .padding(.bottom, 4)

                // Der Name darf umbrechen, der Preis bleibt in einer Zeile.
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(meal.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(meal.price.formatted(for: priceGroup))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.textPrimary))
                        .fixedSize()
                }

                if let description = meal.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Color(.textSecondary))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }

                if !meal.listChips.isEmpty {
                    ChipFlowLayout(spacing: 6) {
                        ForEach(meal.listChips, id: \.title) { chip in
                            Chip(LocalizedStringKey(chip.title), variant: chip.variant)
                        }
                    }
                    .padding(.top, 8)
                }

                if !meal.uniqueAllergies.isEmpty {
                    Text("Enthält \(meal.uniqueAllergies.joined(separator: ", "))")
                        .font(.footnote)
                        .foregroundStyle(Color(.textTertiary))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Karte") {
    ScrollView {
        VStack(spacing: 10) {
            MensaMealCard(meal: .previewSample)
            MensaMealCard(meal: .previewMinimal)
        }
        .padding(16)
    }
    .background(Color(.background))
}

extension MensaMeal {
    /// Beispielgericht für Previews.
    static var previewSample: MensaMeal {
        MensaMeal(
            id: "preview-1",
            category: "Mittagessen",
            name: "Linsen-Dal mit Basmatireis",
            description: "Basmatireis, Mango-Chutney",
            price: MensaMealPrice(student: 2.9, staff: 4.4, guest: 5.8, currency: "€"),
            allergies: ["Sellerie", "Senf"],
            badges: ["Vegan", "Vegetarisch"],
            additives: [],
            categories: ["Regional"],
            co2GramPerPortion: 850,
            components: [MensaMealComponent(name: "Basmatireis", codes: [])],
            canteenName: "Mensa Ehrenberg",
            date: .now
        )
    }

    /// Ohne Beschreibung, Chips und Allergene, mit fehlendem Preis.
    static var previewMinimal: MensaMeal {
        MensaMeal(
            id: "preview-2",
            category: "Mittagessen",
            name: "Pasta Arrabbiata",
            description: nil,
            price: MensaMealPrice(student: nil, staff: 4.4, guest: 5.8, currency: "€"),
            allergies: [],
            badges: [],
            additives: [],
            categories: [],
            co2GramPerPortion: nil,
            components: [],
            canteenName: "Mensa Ehrenberg",
            date: .now
        )
    }
}
