import Foundation

/// Die Allergene der Mensa-API. Der Schlüssel ist immer das `code`-Kürzel (`Wz`, `Mi` …): Es ist sprachunabhängig,
/// die Namen der API wechseln dagegen mit `lang`. Filter, Prüfung und Speicher arbeiten nur mit Kürzeln;
/// Namen sind Anzeige. Die Liste entspricht `/v1/mensa/codes`, Kategorie `allergen`.
/// Die Datei gehört zu App und Widget-Extension.
nonisolated enum MensaAllergen {
    /// Alle 26 Kürzel in der Reihenfolge der API.
    static let knownCodes: [String] = [
        "Wz", "Ro", "Gs", "Hf", "Di", "Ka", "Kr", "Ei", "Fi", "Er", "So", "Mi", "Ma", "Ha", "Wa", "Ca", "Pe", "Pa",
        "Pi", "Mc", "Sel", "Sen", "Ses", "Su", "Lu", "We"
    ]

    /// Zusatzstoffe laut `/v1/mensa/codes`, Kategorie `additive`. Komponenten-Codes kommen ohne Kategorie.
    static let knownAdditiveCodes: Set<String> = [
        "1", "2", "3", "4", "6", "7", "8", "9", "10", "14", "15", "16", "T1", "T2", "T3", "T4", "T5"
    ]

    /// Anzeigename in der App-Sprache. Unbekannte Kürzel zeigen sich selbst.
    static func displayName(code: String) -> String {
        switch code {
        case "Wz": String(localized: "Weizen", table: "Shared")
        case "Ro": String(localized: "Roggen", table: "Shared")
        case "Gs": String(localized: "Gerste", table: "Shared")
        case "Hf": String(localized: "Hafer", table: "Shared")
        case "Di": String(localized: "Dinkel", table: "Shared")
        case "Ka": String(localized: "Kamut", table: "Shared")
        case "Kr": String(localized: "Krebstiere", table: "Shared")
        case "Ei": String(localized: "Hühnerei", table: "Shared")
        case "Fi": String(localized: "Fisch", table: "Shared")
        case "Er": String(localized: "Erdnüsse", table: "Shared")
        case "So": String(localized: "Soja", table: "Shared")
        case "Mi": String(localized: "Milch und Milchzucker", table: "Shared")
        case "Ma": String(localized: "Mandeln", table: "Shared")
        case "Ha": String(localized: "Haselnüsse", table: "Shared")
        case "Wa": String(localized: "Walnüsse", table: "Shared")
        case "Ca": String(localized: "Cashewnüsse", table: "Shared")
        case "Pe": String(localized: "Pekannüsse", table: "Shared")
        case "Pa": String(localized: "Paranüsse", table: "Shared")
        case "Pi": String(localized: "Pistazien", table: "Shared")
        case "Mc": String(localized: "Macadamianüsse", table: "Shared")
        case "Sel": String(localized: "Sellerie", table: "Shared")
        case "Sen": String(localized: "Senf", table: "Shared")
        case "Ses": String(localized: "Sesam", table: "Shared")
        case "Su": String(localized: "Schwefeloxid/Sulfite", table: "Shared")
        case "Lu": String(localized: "Lupine", table: "Shared")
        case "We": String(localized: "Weichtiere", table: "Shared")
        default: code
        }
    }

    /// Deutsche Namen von früher: Der gespeicherte Filter enthielt sie statt der Kürzel (`MensaFilter` migriert damit).
    private static let legacyGermanNames: [String: String] = [
        "Weizen": "Wz", "Roggen": "Ro", "Gerste": "Gs", "Hafer": "Hf", "Dinkel": "Di", "Kamut": "Ka",
        "Krebstiere": "Kr", "Hühnerei": "Ei", "Fisch": "Fi", "Erdnüsse": "Er", "Soja": "So",
        "Milch und Milchzucker": "Mi", "Mandeln": "Ma", "Haselnüsse": "Ha", "Walnüsse": "Wa", "Cashewnüsse": "Ca",
        "Pekannüsse": "Pe", "Paranüsse": "Pa", "Pistazien": "Pi", "Macadamianüsse": "Mc", "Sellerie": "Sel",
        "Senf": "Sen", "Sesam": "Ses", "Schwefeloxid/Sulfite": "Su", "Lupine": "Lu", "Weichtiere": "We"
    ]

    /// Kürzel zu einem früher gespeicherten deutschen Namen; ein Kürzel bleibt, wie es ist.
    /// Ein unbekannter Name bleibt ebenfalls stehen (er schließt dann nichts aus, bleibt aber sichtbar abwählbar).
    static func migratedCode(_ stored: String) -> String {
        if knownCodes.contains(stored) { return stored }
        return legacyGermanNames[stored] ?? stored
    }
}
