import Foundation

/// Preisgruppe, deren Preis in der Liste und im Detail groß steht. Die Einstellung dafür kommt mit „Mehr“;
/// bis dahin gilt „Studierende“ (Schlüssel `mensaPriceGroup`).
enum MensaPriceGroup: String, CaseIterable, Identifiable {
    case studierende
    case bedienstete
    case gaeste

    static let storageKey = "mensaPriceGroup"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studierende: "Studierende"
        case .bedienstete: "Bedienstete"
        case .gaeste: "Gäste"
        }
    }
}

extension MensaMealPrice {
    /// „2,90 €“ oder „–“ bei fehlendem Preis.
    func formatted(for group: MensaPriceGroup) -> String {
        switch group {
        case .studierende: studentFormatted
        case .bedienstete: staffFormatted
        case .gaeste: guestFormatted
        }
    }
}

/// Ein Chip für Liste und Detail.
struct MensaChipItem: Hashable {
    let title: String
    let variant: Chip.Variant
}

/// Angaben zu einer Komponente („Bestandteile“), getrennt nach Allergenen und Zusatzstoffen.
struct MensaComponentInfo: Identifiable {
    let id: UUID
    let name: String
    let allergens: [String]
    let additives: [String]

    /// „Allergene: Sellerie · Zusatzstoffe: Antioxidationsmittel“ oder „Keine weiteren Angaben“.
    var infoText: String {
        var parts: [String] = []
        if !allergens.isEmpty { parts.append("Allergene: " + allergens.joined(separator: ", ")) }
        if !additives.isEmpty { parts.append("Zusatzstoffe: " + additives.joined(separator: ", ")) }
        return parts.isEmpty ? "Keine weiteren Angaben" : parts.joined(separator: " · ")
    }
}

extension MensaMeal {
    /// Nur Vegan, Vegetarisch, Bio und Regional. Ein veganes Gericht zeigt nur „Vegan“.
    var listChips: [MensaChipItem] {
        var items: [MensaChipItem] = []
        let isVegan = badges.contains("Vegan")
        if isVegan { items.append(MensaChipItem(title: "Vegan", variant: .green)) }
        if !isVegan, badges.contains("Vegetarisch") { items.append(MensaChipItem(title: "Vegetarisch", variant: .neutral)) }
        if badges.contains("Bio") { items.append(MensaChipItem(title: "Bio", variant: .green)) }
        if categories.contains(where: { $0.localizedCaseInsensitiveContains("regional") }) {
            items.append(MensaChipItem(title: "Regional", variant: .blue))
        }
        return items
    }

    /// Wie in der Liste, dazu weitere Kategorien der API (z. B. „Kinderessen“) als neutrale Chips.
    var detailChips: [MensaChipItem] {
        let covered: Set<String> = ["vegan", "vegetarisch", "bio", "regional"]
        var seen = Set<String>()
        let others = categories
            .filter { !covered.contains($0.lowercased()) && seen.insert($0).inserted }
            .map { MensaChipItem(title: $0, variant: .neutral) }
        return listChips + others
    }

    /// Die API liefert manche Allergene doppelt.
    var uniqueAllergies: [String] { allergies.uniquedKeepingOrder() }

    var uniqueAdditives: [String] { additives.uniquedKeepingOrder() }

    /// Zusatzstoffe, wie die API sie kennt (`/v1/mensa/codes`, Kategorie `additive`).
    private static let knownAdditives: Set<String> = [
        "Farbstoff", "Konservierungsstoff", "Antioxidationsmittel", "Geschmacksverstärker", "Geschwärzt", "Gewachst",
        "Phosphat", "Süßungsmittel", "Phenylalaninquelle", "Kakaohaltige Fettglasur", "Koffeinhaltig", "Chininhaltig",
        "Tierische Gelatine", "Tierisches Lab", "Karmin", "Sepia", "Honig"
    ]

    /// Die Codes einer Komponente kommen ohne Kategorie. Die Zuordnung läuft deshalb über die Namen:
    /// Allergene aus der festen Liste und dem Gericht, Zusatzstoffe aus der Liste der API und dem Gericht.
    /// Symbole wie „Vegan“ oder „Knoblauch“ und „Ohne Zusatzstoffe“ gehören zu keinem von beiden.
    var componentInfos: [MensaComponentInfo] {
        let allergenNames = Set(MensaFilter.knownAllergens).union(allergies)
        let additiveNames = Self.knownAdditives.union(additives)
        return components.map { component in
            MensaComponentInfo(
                id: component.id,
                name: component.name,
                allergens: component.codes.filter { allergenNames.contains($0) }.uniquedKeepingOrder(),
                additives: component.codes.filter { additiveNames.contains($0) }.uniquedKeepingOrder()
            )
        }
    }
}

extension Array where Element: Hashable {
    func uniquedKeepingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

/// Favoriten, lokal auf dem Gerät. Ein Gericht zählt über seinen Namen, weil die ID der API pro Tag wechselt.
struct MensaFavoriteStore {
    static let key = "mensaFavoriteMeals"

    var defaults: UserDefaults = .standard

    private func normalized(_ meal: MensaMeal) -> String {
        meal.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var stored: [String] {
        defaults.stringArray(forKey: Self.key) ?? []
    }

    func isFavorite(_ meal: MensaMeal) -> Bool {
        stored.contains(normalized(meal))
    }

    func setFavorite(_ isFavorite: Bool, for meal: MensaMeal) {
        let key = normalized(meal)
        var names = stored.filter { $0 != key }
        if isFavorite { names.append(key) }
        defaults.set(names, forKey: Self.key)
    }
}
