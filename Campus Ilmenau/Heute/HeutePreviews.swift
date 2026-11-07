import SwiftUI

/// Beispieldaten für die Previews von „Heute“: Donnerstag, 29. Oktober 2026. Mensa-Namen und Gruppen wie in der API,
/// Gerichte, Preise und Events nach `Heute.dc.html`.
@MainActor
enum HeuteVorschau {
    enum Verhalten {
        case daten
        /// Antwortet nie: Platzhalter-Zustand.
        case laedt
        case fehler
        /// Nur Speiseplan und Öffnungszeiten scheitern, Events und Hinweise kommen.
        case mensaFehler
    }

    private static func gericht(_ name: String, mensa: String, gruppe: String = "Mittagessen", badges: [String] = [],
                                kategorien: [String] = [], preis: Double) -> MensaMeal {
        MensaMeal(
            id: "\(mensa)-\(name)", category: gruppe, name: name, description: nil,
            price: MensaMealPrice(student: preis, staff: preis + 1.6, guest: preis + 2.9, currency: "€"),
            allergies: [], badges: badges, additives: [], categories: kategorien, co2GramPerPortion: nil,
            components: [], canteenName: mensa, date: zeit("12:00")
        )
    }

    static func zeit(_ uhr: String, tag: Int = 0) -> Date { EventsVorschauQuelle.zeit(tag, uhr) }

    static let heute: [MensaMeal] = [
        gericht("Linsen-Dal mit Basmatireis", mensa: "Mensa Ehrenberg", badges: ["Vegan"], kategorien: ["Regional"], preis: 2.9),
        gericht("Hähnchenschnitzel, Kartoffelsalat", mensa: "Mensa Ehrenberg", preis: 3.8),
        gericht("Pasta Arrabbiata", mensa: "Mensa Ehrenberg", badges: ["Vegan"], preis: 2.6),
        gericht("Flammkuchen mit Lauch und Speck", mensa: "Cafeteria Mensa Ehrenberg", gruppe: "Abendessen", preis: 3.2),
        gericht("Gemüse-Bowl mit Erdnusssoße", mensa: "Cafeteria Mensa Ehrenberg", gruppe: "Abendessen", badges: ["Vegan"], preis: 3.0),
        gericht("Gemüse-Curry mit Kokos und Reis", mensa: "Cafeteria NANOteria", badges: ["Vegan"], preis: 2.8),
        gericht("Käsespätzle mit Röstzwiebeln", mensa: "Cafeteria NANOteria", badges: ["Vegetarisch"], preis: 3.1),
        gericht("Chili sin Carne", mensa: "Cafeteria NANOteria", badges: ["Vegan"], preis: 2.7),
        gericht("Ofengemüse mit Feta und Couscous", mensa: "Cafeteria Röntgenbau", badges: ["Vegetarisch"], preis: 3.0),
        gericht("Seelachs, Dillkartoffeln", mensa: "Cafeteria Röntgenbau", preis: 4.2)
    ]

    static let morgen: [MensaMeal] = [
        gericht("Reispfanne mit Gemüse", mensa: "Mensa Ehrenberg", badges: ["Vegan"], preis: 2.8),
        gericht("Reispfanne mit Gemüse", mensa: "Cafeteria NANOteria", badges: ["Vegan"], preis: 2.8)
    ]

    private static func oeffnung(_ name: String, von: String, bis: String) -> Canteen {
        Canteen(
            rscId: nil, name: name, hasMenu: true, city: nil, address: nil,
            openingHours: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"].map {
                OpeningHour(weekday: $0, opensAt: von, closesAt: bis)
            }
        )
    }

    static let mensen: [Canteen] = [
        oeffnung("Mensa Ehrenberg", von: "11:00", bis: "14:00"),
        oeffnung("Cafeteria Mensa Ehrenberg", von: "08:00", bis: "15:00"),
        oeffnung("Cafeteria NANOteria", von: "08:00", bis: "15:00"),
        oeffnung("Cafeteria Röntgenbau", von: "08:00", bis: "14:00")
    ]

    static let events: [CampusEvent] = [
        CampusEvent(id: "v1", titel: "Spieleabend", beginn: zeit("19:00"), ende: zeit("23:00"),
                    ort: "Studi-Club", veranstalter: "Studi-Club"),
        CampusEvent(id: "v3", titel: "Kneipenabend mit Live-Musik", beginn: zeit("20:00"),
                    ort: "Baracke5", veranstalter: "Baracke5 e. V."),
        CampusEvent(id: "v4", titel: "Filmabend: Lieblingsfilme der Fachschaften", beginn: zeit("20:30"),
                    ort: "Hans-Club", veranstalter: "Fachschaftsrat"),
        CampusEvent(id: "v2", titel: "Halloween-Party", beginn: zeit("21:00", tag: 1),
                    ort: "Studi-Club", veranstalter: "Studi-Club")
    ]

    static let hinweise: [Hinweis] = [
        Hinweis(id: "pruefung", kategorie: "Studium", zeitangabe: "ab Mo, 9. Nov.", titel: "Bald beginnt die Prüfungsanmeldung",
                text: "Anmeldung im Prüfungsportal bis 20. November", symbol: "checklist", farbe: .blau, prioritaet: 2),
        Hinweis(id: "stura", kategorie: "Hochschulpolitik", zeitangabe: "nächste Woche", titel: "Wahl des StuRa",
                text: "10. bis 12. November, Wahllokale auf dem Campus", symbol: "person.3", farbe: .gruen, prioritaet: 1)
    ]

    private struct Mensa: HeuteMensaDatenquelle {
        let verhalten: Verhalten
        func speiseplan(am tag: Date) async throws -> [MensaMeal] {
            try await pruefen()
            return HeuteUhr.istGleicherTag(tag, zeit("12:00")) ? HeuteVorschau.heute : HeuteVorschau.morgen
        }
        func mensen() async throws -> [Canteen] {
            try await pruefen()
            return HeuteVorschau.mensen
        }
        private func pruefen() async throws {
            switch verhalten {
            case .daten: break
            case .laedt: try await Task.sleep(for: .seconds(3600))
            case .fehler, .mensaFehler: throw URLError(.notConnectedToInternet)
            }
        }
    }

    private struct Hinweise: HinweiseQuelle {
        let liste: [Hinweis]
        func hinweise(jetzt: Date) async throws -> [Hinweis] { liste }
    }

    /// Modell mit fester Uhr und eigenem Speicher, damit sich Previews nicht gegenseitig beeinflussen.
    static func modell(
        _ uhr: String, mensa: MensaVenue = .mensaEhrenberg, hinweise: Bool = true, events mitEvents: Bool = true,
        verhalten: Verhalten = .daten
    ) -> HeuteModel {
        let defaults = UserDefaults(suiteName: "HeuteVorschau-\(UUID().uuidString)") ?? .standard
        let speicher = HeuteMensaSpeicher(defaults: defaults)
        speicher.venue = mensa
        let jetzt = zeit(uhr)
        let eventsVerhalten: EventsVorschauQuelle.Verhalten
        switch verhalten {
        case .daten, .mensaFehler: eventsVerhalten = mitEvents ? .daten : .leer
        case .laedt: eventsVerhalten = .laedt
        case .fehler: eventsVerhalten = .fehler
        }
        return HeuteModel(
            now: { jetzt },
            mensaQuelle: Mensa(verhalten: verhalten),
            eventsQuelle: EventsVorschauQuelle(verhalten: eventsVerhalten, events: mitEvents ? events : []),
            hinweiseQuelle: Hinweise(liste: hinweise ? Self.hinweise : []),
            mensaSpeicher: speicher,
            ausblendSpeicher: HinweiseAusblendSpeicher(defaults: defaults),
            preisgruppe: { .studierende },
            zeitlimit: .seconds(2)
        )
    }
}

// MARK: - Previews

#Preview("08:15 Morgen – Light", traits: .fixedLayout(width: 393, height: 1250)) {
    HeuteView(model: HeuteVorschau.modell("08:15", mensa: .nanoteria)).preferredColorScheme(.light)
}

#Preview("11:45 Mittag Ehrenberg – Light", traits: .fixedLayout(width: 393, height: 1250)) {
    HeuteView(model: HeuteVorschau.modell("11:45")).preferredColorScheme(.light)
}

#Preview("15:10 Nachmittag Ehrenberg – Light", traits: .fixedLayout(width: 393, height: 1250)) {
    HeuteView(model: HeuteVorschau.modell("15:10")).preferredColorScheme(.light)
}

#Preview("15:10 Nachmittag Nanoteria – Light", traits: .fixedLayout(width: 393, height: 1250)) {
    HeuteView(model: HeuteVorschau.modell("15:10", mensa: .nanoteria)).preferredColorScheme(.light)
}

#Preview("17:40 Abend Ehrenberg – Light", traits: .fixedLayout(width: 393, height: 1250)) {
    HeuteView(model: HeuteVorschau.modell("17:40")).preferredColorScheme(.light)
}

#Preview("21:30 Nacht – Light", traits: .fixedLayout(width: 393, height: 1250)) {
    HeuteView(model: HeuteVorschau.modell("21:30")).preferredColorScheme(.light)
}

#Preview("11:45 ohne Hinweise – Light") {
    HeuteView(model: HeuteVorschau.modell("11:45", hinweise: false)).preferredColorScheme(.light)
}

#Preview("11:45 Mittag – Dark", traits: .fixedLayout(width: 393, height: 1250)) {
    HeuteView(model: HeuteVorschau.modell("11:45")).preferredColorScheme(.dark)
}

#Preview("21:30 Nacht – Dark", traits: .fixedLayout(width: 393, height: 1250)) {
    HeuteView(model: HeuteVorschau.modell("21:30")).preferredColorScheme(.dark)
}

#Preview("11:45 große Schrift – Light") {
    HeuteView(model: HeuteVorschau.modell("11:45"))
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.light)
}

#Preview("11:45 ohne Events – Light", traits: .fixedLayout(width: 393, height: 1000)) {
    HeuteView(model: HeuteVorschau.modell("11:45", events: false)).preferredColorScheme(.light)
}

#Preview("11:45 nur Mensa-Fehler – Light", traits: .fixedLayout(width: 393, height: 1000)) {
    HeuteView(model: HeuteVorschau.modell("11:45", verhalten: .mensaFehler)).preferredColorScheme(.light)
}

#Preview("17:40 Abend – Dark", traits: .fixedLayout(width: 393, height: 1250)) {
    HeuteView(model: HeuteVorschau.modell("17:40")).preferredColorScheme(.dark)
}

#Preview("17:40 große Schrift (AX3) – Light", traits: .fixedLayout(width: 393, height: 2600)) {
    HeuteView(model: HeuteVorschau.modell("17:40"))
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.light)
}

// Ohne Hinweise, damit der untere Teil der Seite im Bild liegt
#Preview("08:15 unten – Light") {
    HeuteView(model: HeuteVorschau.modell("08:15", mensa: .nanoteria, hinweise: false)).preferredColorScheme(.light)
}

#Preview("11:45 unten – Light") {
    HeuteView(model: HeuteVorschau.modell("11:45", hinweise: false)).preferredColorScheme(.light)
}

#Preview("15:10 unten – Light") {
    HeuteView(model: HeuteVorschau.modell("15:10", hinweise: false)).preferredColorScheme(.light)
}

#Preview("17:40 unten – Light") {
    HeuteView(model: HeuteVorschau.modell("17:40", hinweise: false)).preferredColorScheme(.light)
}

#Preview("21:30 unten – Light") {
    HeuteView(model: HeuteVorschau.modell("21:30", hinweise: false)).preferredColorScheme(.light)
}

#Preview("17:40 unten – Dark") {
    HeuteView(model: HeuteVorschau.modell("17:40", hinweise: false)).preferredColorScheme(.dark)
}

#Preview("17:40 unten AX3 – Light") {
    HeuteView(model: HeuteVorschau.modell("17:40", hinweise: false))
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.light)
}

#Preview("Lädt") {
    HeuteView(model: HeuteVorschau.modell("11:45", verhalten: .laedt))
}

#Preview("Fehler") {
    HeuteView(model: HeuteVorschau.modell("11:45", verhalten: .fehler))
}

#Preview("Mensa-Sheet – Light") {
    HeuteMensaSheet(
        optionen: MensaVenue.allCases.map {
            HeuteModel.MensaOption(venue: $0, info: $0 == .cafeteriaEhrenberg
                ? "08:00–15:00 Uhr · Abendessen ab 16:30" : "11:00–14:00 Uhr")
        },
        gewaehlt: .mensaEhrenberg,
        onWahl: { _ in }
    )
    .preferredColorScheme(.light)
}
