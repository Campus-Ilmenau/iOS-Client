//
//  MensaMealCard.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct MensaMealCard: View {
    let meal: MensaMeal
    var disablesInteraction: Bool = false
    @State private var showDetail = false

    var body: some View {
        Button {
            // Unterdrückt den Tap, falls er durch einen horizontalen
            // Mensa-Swipe ausgelöst wurde (die Karte folgt dabei dem Finger,
            // weshalb der Button-eigene Tap-Erkenner das sonst nicht bemerkt).
            guard !disablesInteraction else { return }
            showDetail = true
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            MensaMealDetailView(meal: meal)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kategorie
            HStack {
                Text(meal.category)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                // Badges (Vegan, Bio, etc.)
                HStack(spacing: 4) {
                    ForEach(meal.badges, id: \.self) { badge in
                        BadgeView(text: badge)
                    }
                }
            }
            
            // Name des Gerichts
            Text(meal.name)
                .font(.headline)
                .fontWeight(.bold)
            
            // Beschreibung (falls vorhanden)
            if let description = meal.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Preise (Studierende / Mitarbeiter / Gäste)
            HStack(spacing: 0) {
                priceColumn(label: "Studierende", value: meal.price.studentFormatted, isPrimary: true)
                priceColumn(label: "Mitarbeiter", value: meal.price.staffFormatted, isPrimary: false)
                priceColumn(label: "Gäste", value: meal.price.guestFormatted, isPrimary: false)
            }

            // Allergien
            if !meal.allergies.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)

                    Text(meal.allergies.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func priceColumn(label: String, value: String, isPrimary: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(isPrimary ? .subheadline : .caption)
                .fontWeight(.bold)
                .foregroundStyle(isPrimary ? .orange : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MensaMealCard(
        meal: MensaMeal(
            id: "meal_preview_1",
            category: "Hauptgericht 1",
            name: "Hähnchenschnitzel",
            description: "mit Pommes Frites und Salat",
            price: MensaMealPrice(student: 3.50, staff: 4.70, guest: 5.90, currency: "€"),
            allergies: ["Gluten", "Ei"],
            badges: ["Vegetarisch"],
            additives: ["Konservierungsstoff"],
            categories: ["Kinderessen"],
            co2GramPerPortion: 850,
            components: [
                MensaMealComponent(name: "Hähnchenschnitzel", codes: ["Gluten"]),
                MensaMealComponent(name: "Pommes Frites", codes: [])
            ],
            canteenName: "Mensa Ehrenberg",
            date: Date()
        )
    )
    .padding()
}
