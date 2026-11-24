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
        case "Wz": LocalizedStringResource("Weizen", table: "Shared").inAppSprache
        case "Ro": LocalizedStringResource("Roggen", table: "Shared").inAppSprache
        case "Gs": LocalizedStringResource("Gerste", table: "Shared").inAppSprache
        case "Hf": LocalizedStringResource("Hafer", table: "Shared").inAppSprache
        case "Di": LocalizedStringResource("Dinkel", table: "Shared").inAppSprache
        case "Ka": LocalizedStringResource("Kamut", table: "Shared").inAppSprache
        case "Kr": LocalizedStringResource("Krebstiere", table: "Shared").inAppSprache
        case "Ei": LocalizedStringResource("Hühnerei", table: "Shared").inAppSprache
        case "Fi": LocalizedStringResource("Fisch", table: "Shared").inAppSprache
        case "Er": LocalizedStringResource("Erdnüsse", table: "Shared").inAppSprache
        case "So": LocalizedStringResource("Soja", table: "Shared").inAppSprache
        case "Mi": LocalizedStringResource("Milch und Milchzucker", table: "Shared").inAppSprache
        case "Ma": LocalizedStringResource("Mandeln", table: "Shared").inAppSprache
        case "Ha": LocalizedStringResource("Haselnüsse", table: "Shared").inAppSprache
        case "Wa": LocalizedStringResource("Walnüsse", table: "Shared").inAppSprache
        case "Ca": LocalizedStringResource("Cashewnüsse", table: "Shared").inAppSprache
        case "Pe": LocalizedStringResource("Pekannüsse", table: "Shared").inAppSprache
        case "Pa": LocalizedStringResource("Paranüsse", table: "Shared").inAppSprache
        case "Pi": LocalizedStringResource("Pistazien", table: "Shared").inAppSprache
        case "Mc": LocalizedStringResource("Macadamianüsse", table: "Shared").inAppSprache
        case "Sel": LocalizedStringResource("Sellerie", table: "Shared").inAppSprache
        case "Sen": LocalizedStringResource("Senf", table: "Shared").inAppSprache
        case "Ses": LocalizedStringResource("Sesam", table: "Shared").inAppSprache
        case "Su": LocalizedStringResource("Schwefeloxid/Sulfite", table: "Shared").inAppSprache
        case "Lu": LocalizedStringResource("Lupine", table: "Shared").inAppSprache
        case "We": LocalizedStringResource("Weichtiere", table: "Shared").inAppSprache
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
