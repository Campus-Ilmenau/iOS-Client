//
//  MensaMeal.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//  CORRECTED VERSION
//

import Foundation

struct MensaMeal: Identifiable {
    let id: String
    let category: String
    let name: String
    let description: String?
    let price: MensaMealPrice
    let allergies: [String]
    let badges: [String]
    let additives: [String]
    let categories: [String]
    let co2GramPerPortion: Double?
    let components: [MensaMealComponent]
    let canteenName: String
    let date: Date
    /// `true`: Titel, Gruppe und Komponenten sind maschinell übersetzt (nur bei `lang=en`, nur für heutige Gerichte).
    /// `false` bei `lang=en` heißt: keine Übersetzung, der Text ist Deutsch. Das ist ein normaler Fall.
    var translated = false
    /// Allergene mit sprachunabhängigem Kürzel. Filter und Prüfung nutzen nur die Kürzel, nie `allergies`.
    var allergenCodes: [MensaCodeRef] = []
    var additiveCodes: [MensaCodeRef] = []
}

/// Ein Code der API (`Wz`, `V*`, `7`): das Kürzel ist der stabile Schlüssel, der Name folgt der Sprache.
struct MensaCodeRef: Hashable, Sendable {
    let code: String
    let name: String?
}

/// Eine Komponente eines Gerichts (z.B. "Reis", "Soße") mit ihren eigenen Zusatz-/Allergen-Codes
struct MensaMealComponent: Identifiable {
    let id = UUID()
    let name: String
    let codes: [String]
    /// Dieselben Codes mit kürzel; die Zuordnung zu Allergen und Zusatzstoff läuft darüber, nicht über die Namen.
    var codeRefs: [MensaCodeRef] = []
}

/// Preise eines Gerichts nach Personengruppe
struct MensaMealPrice {
    let student: Double?
    let staff: Double?
    let guest: Double?
    let currency: String

    var studentFormatted: String { Self.format(student, currency: currency) }
    var staffFormatted: String { Self.format(staff, currency: currency) }
    var guestFormatted: String { Self.format(guest, currency: currency) }

    /// „2,90 €“ bzw. „€2.90“ in der Schreibweise der App-Sprache (oder der übergebenen); ein fehlender Preis ist „–“.
    static func format(_ value: Double?, currency: String, locale: Locale = .current) -> String {
        guard let value else { return "–" }
        let code = currency.count == 3 ? currency.uppercased() : "EUR"
        return value.formatted(.currency(code: code).locale(locale))
    }
}
