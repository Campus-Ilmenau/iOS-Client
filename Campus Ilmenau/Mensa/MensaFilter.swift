import Foundation

/// Ernährungsstufe des Filters. „Vegetarisch“ lässt auch vegane Gerichte durch.
enum MensaDiet: String, Codable, CaseIterable, Hashable {
    case alle
    case vegetarisch
    case vegan
}

/// Filter für den Speiseplan: Ernährungsstufe, „Nur Bio“ und ausgeschlossene Allergene, alles UND-verknüpft.
/// Er gilt für alle Mensen und Tage und wird für die Mensa-Ansicht und die Mensa-Karte auf „Heute“ gleich verwendet.
struct MensaFilter: Equatable, Codable {
    var diet: MensaDiet = .alle
    var onlyBio = false
    var excludedAllergens: Set<String> = []

    // Namen der Badges, wie `MensaService.determineBadges` sie vergibt.
    private static let veganBadge = "Vegan"
    private static let vegetarianBadge = "Vegetarisch"
    private static let bioBadge = "Bio"

    func matches(_ meal: MensaMeal) -> Bool {
        let badges = Set(meal.badges)
        switch diet {
        case .alle:
            break
        case .vegetarisch:
            guard badges.contains(Self.vegetarianBadge) || badges.contains(Self.veganBadge) else { return false }
        case .vegan:
            guard badges.contains(Self.veganBadge) else { return false }
        }
        if onlyBio, !badges.contains(Self.bioBadge) { return false }
        return excludedAllergens.isDisjoint(with: meal.allergies)
    }

    func apply(to meals: [MensaMeal]) -> [MensaMeal] {
        isActive ? meals.filter(matches) : meals
    }

    /// Irgendetwas ist gesetzt.
    var isActive: Bool { diet != .alle || extraCount > 0 }

    /// Anzahl der Einstellungen jenseits der Pills: „Nur Bio“ und ausgeschlossene Allergene (Zahl an der Filter-Taste).
    var extraCount: Int { (onlyBio ? 1 : 0) + excludedAllergens.count }

    /// „Nur Bio“, „ohne Gluten, Ei“; ohne die Ernährungsstufe, die steht in den Pills.
    var summaryParts: [String] {
        var parts: [String] = []
        if onlyBio { parts.append("Nur Bio") }
        if !excludedAllergens.isEmpty {
            parts.append("ohne " + excludedAllergens.sorted { $0.localizedCompare($1) == .orderedAscending }.joined(separator: ", "))
        }
        return parts
    }

    /// „Nur Bio · ohne Gluten, Ei“, `nil` ohne zusätzliche Einstellungen.
    var summary: String? {
        summaryParts.isEmpty ? nil : summaryParts.joined(separator: " · ")
    }

    /// Für den leeren Zustand: „Vegetarisch · Nur Bio · ohne Gluten“.
    var activeDescription: String {
        let dietName: [String] = switch diet {
        case .alle: []
        case .vegetarisch: ["Vegetarisch"]
        case .vegan: ["Vegan"]
        }
        return (dietName + summaryParts).joined(separator: " · ")
    }

    /// Alle 26 Allergene, die die Mensa-API kennt (`/v1/mensa/codes`, Kategorie `allergen`), mit den Namen der API.
    /// Das Sheet zeigt sie immer, auch wenn der Speiseplan des Tages sie nicht enthält: Wer etwas meiden muss,
    /// soll den Filter an jedem Tag im Voraus einstellen können.
    static let knownAllergens: [String] = [
        "Weizen", "Roggen", "Gerste", "Hafer", "Dinkel", "Kamut", "Krebstiere", "Hühnerei", "Fisch", "Erdnüsse",
        "Soja", "Milch und Milchzucker", "Mandeln", "Haselnüsse", "Walnüsse", "Cashewnüsse", "Pekannüsse",
        "Paranüsse", "Pistazien", "Macadamianüsse", "Sellerie", "Senf", "Sesam", "Schwefeloxid/Sulfite", "Lupine",
        "Weichtiere"
    ]

    /// Allergene für das Sheet, alphabetisch: die feste Liste, dazu alles, was ein geladenes Gericht nennt
    /// (falls die API ein neues Allergen einführt), und ausgeschlossene, die nicht mehr in der Liste stehen.
    static func availableAllergens(in meals: [MensaMeal], keeping excluded: Set<String>) -> [String] {
        Set(knownAllergens).union(meals.flatMap(\.allergies)).union(excluded)
            .sorted { $0.localizedCompare($1) == .orderedAscending }
    }
}

/// Speichert den Filter auf dem Gerät und übernimmt Einstellungen des alten Drei-Zustände-Filters.
enum MensaFilterStore {
    static let key = "MensaFilter"
    /// Alter Schlüssel: `[String: "exclude" | "any" | "include"]` je Badge oder Allergen.
    static let legacyKey = "MensaFilterStates"

    static func load(defaults: UserDefaults = .standard) -> MensaFilter {
        if let data = defaults.data(forKey: key), let filter = try? JSONDecoder().decode(MensaFilter.self, from: data) {
            defaults.removeObject(forKey: legacyKey)
            return filter
        }

        guard let legacyData = defaults.data(forKey: legacyKey) else { return MensaFilter() }
        let legacy = (try? JSONDecoder().decode([String: String].self, from: legacyData)) ?? [:]
        let filter = migrate(legacy: legacy)
        save(filter, defaults: defaults)
        defaults.removeObject(forKey: legacyKey)
        return filter
    }

    static func save(_ filter: MensaFilter, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(filter) else { return }
        defaults.set(data, forKey: key)
    }

    /// „Vegan einschließen“ → vegan, „Vegetarisch einschließen“ → vegetarisch, „Bio einschließen“ → Nur Bio,
    /// „Allergen ausschließen“ → ohne. Alles andere → egal.
    static func migrate(legacy: [String: String]) -> MensaFilter {
        let badges: Set<String> = ["Vegan", "Vegetarisch", "Bio"]
        var filter = MensaFilter()
        if legacy["Vegan"] == "include" {
            filter.diet = .vegan
        } else if legacy["Vegetarisch"] == "include" {
            filter.diet = .vegetarisch
        }
        filter.onlyBio = legacy["Bio"] == "include"
        filter.excludedAllergens = Set(legacy.filter { $0.value == "exclude" && !badges.contains($0.key) }.keys)
        return filter
    }
}
