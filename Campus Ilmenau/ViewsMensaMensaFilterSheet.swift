//
//  MensaFilterSheet.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

/// Tri-state filter for a single meal attribute (z.B. "Vegan" oder "Gluten")
enum MealFilterState: String, CaseIterable, Identifiable, Codable {
    case exclude
    case any
    case include

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .exclude: return "xmark"
        case .any: return "circle"
        case .include: return "checkmark"
        }
    }

    var tintColor: Color {
        switch self {
        case .exclude: return .red
        case .any: return .secondary
        case .include: return .green
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .exclude: return "Ausschließen"
        case .any: return "Egal"
        case .include: return "Einschließen"
        }
    }
}

/// Persistiert die aktiven Speiseplan-Filter in UserDefaults, damit sie geräteweit
/// über Tage hinweg erhalten bleiben und nicht täglich neu gesetzt werden müssen.
enum MensaFilterStore {
    private static let key = "MensaFilterStates"

    static func load() -> [String: MealFilterState] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: MealFilterState].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func save(_ filterStates: [String: MealFilterState]) {
        guard let data = try? JSONEncoder().encode(filterStates) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// Bottom-Sheet zum Filtern des Speiseplans nach Ernährungs-Badges und Allergenen.
/// Jedes Attribut kann auf "ausschließen", "egal" oder "einschließen" gesetzt werden.
struct MensaFilterSheet: View {
    @Binding var filterStates: [String: MealFilterState]
    let availableBadges: [String]
    let availableAllergies: [String]

    var body: some View {
        NavigationStack {
            List {
                if !availableBadges.isEmpty {
                    Section("Ernährung") {
                        ForEach(availableBadges, id: \.self) { badge in
                            MealAttributeFilterRow(title: badge, state: binding(for: badge))
                        }
                    }
                }

                if !availableAllergies.isEmpty {
                    Section("Allergene") {
                        ForEach(availableAllergies, id: \.self) { allergy in
                            MealAttributeFilterRow(title: allergy, state: binding(for: allergy))
                        }
                    }
                }

                if availableBadges.isEmpty && availableAllergies.isEmpty {
                    ContentUnavailableView(
                        "Keine Filter verfügbar",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Sobald Gerichte geladen sind, können sie hier gefiltert werden.")
                    )
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zurücksetzen") {
                        filterStates.removeAll()
                    }
                    .disabled(!hasActiveFilters)
                }
            }
        }
    }

    private var hasActiveFilters: Bool {
        filterStates.contains { $0.value != .any }
    }

    private func binding(for attribute: String) -> Binding<MealFilterState> {
        Binding(
            get: { filterStates[attribute] ?? .any },
            set: { filterStates[attribute] = $0 }
        )
    }
}

/// Eine Zeile mit drei Tasten (ausschließen / egal / einschließen) für ein Attribut.
private struct MealAttributeFilterRow: View {
    let title: String
    @Binding var state: MealFilterState

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 6) {
                ForEach(MealFilterState.allCases) { option in
                    Button {
                        state = option
                    } label: {
                        Image(systemName: option.symbolName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(width: 28, height: 28)
                            .foregroundStyle(state == option ? .white : option.tintColor)
                            .background(state == option ? option.tintColor : option.tintColor.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.accessibilityLabel)
                    .accessibilityAddTraits(state == option ? [.isSelected] : [])
                }
            }
        }
    }
}

#Preview {
    MensaFilterSheet(
        filterStates: .constant(["Vegan": .include, "Gluten": .exclude]),
        availableBadges: ["Vegan", "Vegetarisch", "Bio"],
        availableAllergies: ["Gluten", "Ei", "Milch"]
    )
}
