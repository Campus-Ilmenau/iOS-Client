import Foundation

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
        if !allergens.isEmpty { parts.append(LocalizedStringResource("Allergene: \(allergens.joined(separator: ", "))").inAppSprache) }
        if !additives.isEmpty { parts.append(LocalizedStringResource("Zusatzstoffe: \(additives.joined(separator: ", "))").inAppSprache) }
        return parts.isEmpty ? LocalizedStringResource("Keine weiteren Angaben").inAppSprache : parts.joined(separator: " · ")
    }
}

extension MensaMeal {
    /// Nur Vegan, Vegetarisch, Bio und Regional. Ein veganes Gericht zeigt nur „Vegan“. Die Regeln liegen in
    /// `widgetChips`, damit Liste und Widget dasselbe zeigen.
    var listChips: [MensaChipItem] {
        widgetChips.map { chip in
            let variant: Chip.Variant = switch chip.art {
            case .gruen: .green
            case .blau: .blue
            case .neutral: .neutral
            }
            return MensaChipItem(title: chip.titel, variant: variant)
        }
    }

    /// Wie in der Liste, dazu weitere Kategorien der API (z. B. „Kinderessen“) als neutrale Chips.
    var detailChips: [MensaChipItem] {
        // Vegan, Vegetarisch, Bio und Regional zeigt `listChips` schon. Die Symbole werden am Kürzel erkannt,
        // nicht am Namen, denn der wechselt mit der Sprache („Vegetarisch“ / „Vegetarian“).
        let coveredCodes: Set<String> = ["V", "V*"]
        func covered(_ symbol: MensaCodeRef) -> Bool {
            coveredCodes.contains(symbol.code)
                || symbol.code.lowercased().contains("bio")
                || (symbol.name ?? "").localizedCaseInsensitiveContains("regional")
        }
        var seen = Set<String>()
        let others: [MensaChipItem]
        if symbolCodes.isEmpty {
            // Ohne Kürzel (Vorschauen, ältere Daten): nach den bekannten deutschen Namen.
            let names: Set<String> = ["vegan", "vegetarisch", "bio", "regional"]
            others = categories.filter { !names.contains($0.lowercased()) && seen.insert($0).inserted }
                .map { MensaChipItem(title: $0, variant: .neutral) }
        } else {
            others = symbolCodes.filter { !covered($0) }.compactMap(\.name)
                .filter { seen.insert($0).inserted }.map { MensaChipItem(title: $0, variant: .neutral) }
        }
        return listChips + others
    }

    /// Die API liefert manche Allergene doppelt.
    var uniqueAllergies: [String] { allergies.uniquedKeepingOrder() }

    var uniqueAdditives: [String] { additives.uniquedKeepingOrder() }

    /// Die Codes einer Komponente kommen ohne Kategorie. Die Zuordnung läuft über das sprachunabhängige Kürzel:
    /// Allergene aus der festen Liste und dem Gericht, Zusatzstoffe aus der Liste der API und dem Gericht.
    /// Symbole wie „Vegan“ oder „Knoblauch“ und „Ohne Zusatzstoffe“ gehören zu keinem von beiden.
    /// Die Namen stehen so, wie die API sie in der App-Sprache liefert.
    var componentInfos: [MensaComponentInfo] {
        let allergenCodes = Set(MensaAllergen.knownCodes).union(self.allergenCodes.map(\.code))
        let additiveCodes = MensaAllergen.knownAdditiveCodes.union(self.additiveCodes.map(\.code))
        return components.map { component in
            MensaComponentInfo(
                id: component.id,
                name: component.name,
                allergens: component.codeRefs.filter { allergenCodes.contains($0.code) }.compactMap(\.name).uniquedKeepingOrder(),
                additives: component.codeRefs.filter { additiveCodes.contains($0.code) }.compactMap(\.name).uniquedKeepingOrder()
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
