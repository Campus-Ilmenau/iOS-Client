//
//  MensaMealDetailView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

/// Modal mit allen Details zu einem Gericht.
struct MensaMealDetailView: View {
    let meal: MensaMeal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    priceCard

                    if let description = meal.description {
                        DetailSection(title: "Beschreibung", icon: "text.alignleft") {
                            Text(description)
                                .font(.body)
                        }
                    }

                    if !meal.allergies.isEmpty {
                        DetailSection(title: "Allergene", icon: "exclamationmark.triangle.fill") {
                            chipGrid(for: meal.allergies, tint: .orange)
                        }
                    }

                    DetailSection(title: "Mensa", icon: "fork.knife.circle.fill") {
                        Text(meal.canteenName)
                            .font(.body)
                    }

                    DetailSection(title: "Datum", icon: "calendar") {
                        Text(formattedDate)
                            .font(.body)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meal.category)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(meal.name)
                .font(.title2)
                .fontWeight(.bold)

            if !meal.badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(meal.badges, id: \.self) { badge in
                        BadgeView(text: badge)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var priceCard: some View {
        HStack {
            Label("Preis", systemImage: "eurosign.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(meal.price)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.orange)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func chipGrid(for items: [String], tint: Color) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tint.opacity(0.15))
                    .foregroundStyle(tint)
                    .clipShape(Capsule())
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, dd. MMMM yyyy"
        return formatter.string(from: meal.date)
    }
}

/// Eine Detail-Sektion mit Icon-Titel und beliebigem Inhalt.
private struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MensaMealDetailView(
        meal: MensaMeal(
            id: "meal_preview_1",
            category: "Hauptgericht 1",
            name: "Hähnchenschnitzel",
            description: "mit Pommes Frites und Salat",
            price: "3,50 €",
            allergies: ["Gluten", "Ei"],
            badges: ["Vegetarisch"],
            canteenName: "Mensa Ehrenberg",
            date: Date()
        )
    )
}
