import Foundation

// Der Mensa-Filter: Typ, Logik und Speicher, einmal für die Mensa-Ansicht, Heute und das Widget „Mensa heute“.
// Ohne SwiftUI. Diese Datei gehört zu App und Widget-Extension, ihre Typen sind darum ausdrücklich `nonisolated`.

/// Ernährungsstufe des Filters. „Vegetarisch“ lässt auch vegane Gerichte durch.
nonisolated enum MensaDiet: String, Codable, CaseIterable, Hashable, Sendable {
    case alle
    case vegetarisch
    case vegan
}

/// Filter für den Speiseplan: Ernährungsstufe, „Nur Bio“ und ausgeschlossene Allergene, alles UND-verknüpft.
/// Er gilt für alle Mensen und Tage und wird für die Mensa-Ansicht, die Mensa-Karte auf „Heute“ und das Widget
/// (Schalter „Filter aus der App anwenden“) gleich verwendet. Gespeichert wird er in der App Group (`MensaFilterStore`).
nonisolated struct MensaFilter: Equatable, Codable, Sendable {
    var diet: MensaDiet = .alle
    var onlyBio = false
    /// Kürzel der ausgeschlossenen Allergene (`Wz`, `Mi` …), nie angezeigte Namen: Die Namen wechseln mit der Sprache,
    /// das Kürzel nicht. Ein Filter mit deutschen Namen aus älteren Versionen wird beim Lesen umgestellt.
    var excludedAllergens: Set<String> = []

    // Namen der Badges, wie `MensaService.determineBadges` sie vergibt. Die Chips des Widgets heißen genauso.
    private static let veganBadge = "Vegan"
    private static let vegetarianBadge = "Vegetarisch"
    private static let bioBadge = "Bio"

    /// Die eine Prüfung, auf der alles andere aufbaut. `allergies` sind die Allergen-**Kürzel** des Gerichts.
    func matches(badges: Set<String>, allergies: [String]) -> Bool {
        switch diet {
        case .alle:
            break
        case .vegetarisch:
            guard badges.contains(Self.vegetarianBadge) || badges.contains(Self.veganBadge) else { return false }
        case .vegan:
            guard badges.contains(Self.veganBadge) else { return false }
        }
        if onlyBio, !badges.contains(Self.bioBadge) { return false }
        return excludedAllergens.isDisjoint(with: allergies)
    }

    /// Ein Gericht im Speicher der Widgets. Dessen Chips tragen die Namen der Badges (Vegan, Vegetarisch, Bio).
    func matches(_ gericht: WidgetGericht) -> Bool {
        matches(badges: Set(gericht.chips.map(\.titel)), allergies: gericht.allergenCodes)
    }

    func apply(to gerichte: [WidgetGericht]) -> [WidgetGericht] {
        isActive ? gerichte.filter { matches($0) } : gerichte
    }

    /// Irgendetwas ist gesetzt.
    var isActive: Bool { diet != .alle || extraCount > 0 }

    /// Anzahl der Einstellungen jenseits der Pills: „Nur Bio“ und ausgeschlossene Allergene (Zahl an der Filter-Taste).
    var extraCount: Int { (onlyBio ? 1 : 0) + excludedAllergens.count }

    /// „Nur Bio“, „ohne Gluten, Ei“ (Namen in der App-Sprache); ohne die Ernährungsstufe, die steht in den Pills.
    var summaryParts: [String] {
        var parts: [String] = []
        if onlyBio { parts.append(LocalizedStringResource("Nur Bio", table: "Shared").inAppSprache) }
        if !excludedAllergens.isEmpty {
            let names = excludedAllergens.map(MensaAllergen.displayName(code:))
                .sorted { $0.localizedCompare($1) == .orderedAscending }
                .joined(separator: ", ")
            parts.append(LocalizedStringResource("ohne \(names)", table: "Shared").inAppSprache)
        }
        return parts
    }

    /// „Nur Bio · ohne Gluten, Ei“, `nil` ohne zusätzliche Einstellungen.
    var summary: String? {
        summaryParts.isEmpty ? nil : summaryParts.joined(separator: " · ")
    }

    /// Für den leeren Zustand und das Widget: „Vegetarisch · Nur Bio · ohne Gluten“.
    var activeDescription: String {
        let dietName: [String] = switch diet {
        case .alle: []
        case .vegetarisch: [LocalizedStringResource("Vegetarisch", table: "Shared").inAppSprache]
        case .vegan: [LocalizedStringResource("Vegan", table: "Shared").inAppSprache]
        }
        return (dietName + summaryParts).joined(separator: " · ")
    }

    /// Alle 26 Allergene, die die Mensa-API kennt (`/v1/mensa/codes`, Kategorie `allergen`), als Kürzel.
    /// Das Sheet zeigt sie immer, auch wenn der Speiseplan des Tages sie nicht enthält: Wer etwas meiden muss,
    /// soll den Filter an jedem Tag im Voraus einstellen können.
    static let knownAllergens: [String] = MensaAllergen.knownCodes
}

extension MensaFilter {
    private enum CodingKeys: String, CodingKey {
        case diet, onlyBio, excludedAllergens
    }

    /// Defensiv: fehlende Felder bekommen ihren Standard, gespeicherte deutsche Allergen-Namen werden zu Kürzeln.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        diet = try container.decodeIfPresent(MensaDiet.self, forKey: .diet) ?? .alle
        onlyBio = try container.decodeIfPresent(Bool.self, forKey: .onlyBio) ?? false
        excludedAllergens = Set(
            (try container.decodeIfPresent(Set<String>.self, forKey: .excludedAllergens) ?? [])
                .map(MensaAllergen.migratedCode)
        )
    }
}

// Die Gerichte der App (`MensaMeal`) gehören nicht zum Widget; hier stehen nur die Anschlüsse an die Prüfung oben.
extension MensaFilter {
    func matches(_ meal: MensaMeal) -> Bool {
        matches(badges: Set(meal.badges), allergies: meal.allergenCodes.map(\.code))
    }

    func apply(to meals: [MensaMeal]) -> [MensaMeal] {
        isActive ? meals.filter { matches($0) } : meals
    }

    /// Allergen-Kürzel für das Sheet, alphabetisch nach Anzeigename: die feste Liste, dazu alles, was ein geladenes
    /// Gericht nennt (falls die API ein neues Allergen einführt), und ausgeschlossene, die nicht mehr in der Liste stehen.
    static func availableAllergens(in meals: [MensaMeal], keeping excluded: Set<String>) -> [String] {
        sortedByName(Set(knownAllergens).union(meals.flatMap { $0.allergenCodes.map(\.code) }).union(excluded), in: meals)
    }

    /// Anzeigename eines Kürzels: aus der festen Liste (App-Sprache), sonst der Name, den die API für das Gericht lieferte.
    static func allergenName(code: String, in meals: [MensaMeal] = []) -> String {
        let known = MensaAllergen.displayName(code: code)
        guard known == code else { return known }
        return meals.lazy.flatMap(\.allergenCodes).first { $0.code == code }?.name ?? code
    }

    private static func sortedByName(_ codes: Set<String>, in meals: [MensaMeal]) -> [String] {
        codes.sorted {
            allergenName(code: $0, in: meals).localizedCompare(allergenName(code: $1, in: meals)) == .orderedAscending
        }
    }
}

extension MensaFilter {
    /// Allergene für das Popover auf dem iPad, alphabetisch: nur die, die ein Gericht des geladenen Tages nennt, dazu die
    /// ausgeschlossenen (sie bleiben sichtbar, damit man sie wieder abschalten kann).
    static func allergens(onDay meals: [MensaMeal], keeping excluded: Set<String>) -> [String] {
        sortedByName(Set(meals.flatMap { $0.allergenCodes.map(\.code) }).union(excluded), in: meals)
    }
}

/// Speichert den Filter in der App Group, damit App und Widget denselben lesen, und übernimmt Einstellungen des
/// alten Drei-Zustände-Filters. Werte aus den Standard-Einstellungen der App holt `AppGroup` einmalig herüber.
nonisolated enum MensaFilterStore {
    static let key = "MensaFilter"
    /// Alter Schlüssel: `[String: "exclude" | "any" | "include"]` je Badge oder Allergen.
    static let legacyKey = "MensaFilterStates"

    static func load(defaults: UserDefaults = AppGroup.defaults) -> MensaFilter {
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

    static func save(_ filter: MensaFilter, defaults: UserDefaults = AppGroup.defaults) {
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
        filter.excludedAllergens = Set(
            legacy.filter { $0.value == "exclude" && !badges.contains($0.key) }.keys.map(MensaAllergen.migratedCode)
        )
        return filter
    }
}
