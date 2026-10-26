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
}

/// Eine Komponente eines Gerichts (z.B. "Reis", "Soße") mit ihren eigenen Zusatz-/Allergen-Codes
struct MensaMealComponent: Identifiable {
    let id = UUID()
    let name: String
    let codes: [String]
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

    private static func format(_ value: Double?, currency: String) -> String {
        guard let value else { return "–" }
        return String(format: "%.2f %@", value, currency)
    }
}
