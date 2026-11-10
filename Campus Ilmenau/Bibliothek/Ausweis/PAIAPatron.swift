import Foundation

/// Nutzerkonto aus PAIA `GET /core/{patron}` für den Bibliotheksausweis.
/// Absichtlich nur die Felder, die der Ausweis braucht: `email` und `address` werden beim
/// Dekodieren verworfen. Das Modell lebt nur im Speicher (siehe `PAIAService.patron`).
struct PAIAPatron: Decodable, Equatable {
    let name: String?
    let expires: Date?
    let status: Int?
    /// Nutzergruppen als URIs; die Anzeige geht über `PAIANutzergruppe`.
    let type: [String]?
    let note: String?

    init(name: String? = nil, expires: Date? = nil, status: Int? = nil, type: [String]? = nil, note: String? = nil) {
        self.name = name
        self.expires = expires
        self.status = status
        self.type = type
        self.note = note
    }

    /// Nutzergruppe als Text, oder `nil`, wenn keine URI bekannt ist.
    var nutzergruppe: String? { PAIANutzergruppe.text(for: type ?? []) }
}

/// Feste Tabelle: type-URI aus PAIA → Text für den Chip auf dem Ausweis.
enum PAIANutzergruppe {
    /// TODO: Die echten URIs der UB Ilmenau sind noch nicht bekannt. Bei der UB erfragen oder aus
    /// einer `/core/{patron}`-Antwort ablesen und hier eintragen, jeweils mit einem der Texte
    /// „Studierende“, „Beschäftigte“, „Externe“. Bis dahin bleibt der Chip weg.
    static let tabelle: [String: String] = [:]

    /// Text der ersten bekannten URI. Unbekannte URIs ergeben `nil`, die URI selbst wird nie gezeigt.
    static func text(for uris: [String], tabelle: [String: String] = PAIANutzergruppe.tabelle) -> String? {
        uris.lazy.compactMap { tabelle[$0] }.first
    }
}
