import SwiftUI

/// Beispiele für die Previews der Bild-Karten, nach den Tweaks in `TeilenKarte.dc.html`.
enum ShareCardVorschau {
    static let deutsch = Locale(identifier: "de_DE")

    /// Donnerstag, 29. Oktober 2026.
    static var donnerstag: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 12)) ?? .now
    }

    private static func gericht(
        _ name: String, _ beschreibung: String, kategorie: String = "Essen 1", mensa: String = "Mensa Ehrenberg",
        badges: [String] = [], regional: Bool = false, preise: [Double?]
    ) -> MensaMeal {
        MensaMeal(
            id: name, category: kategorie, name: name, description: beschreibung.isEmpty ? nil : beschreibung,
            price: MensaMealPrice(student: preise[0], staff: preise[1], guest: preise[2], currency: "€"),
            allergies: [], badges: badges, additives: [], categories: regional ? ["Regional"] : [],
            co2GramPerPortion: nil, components: [], canteenName: mensa, date: donnerstag
        )
    }

    /// Die acht Gerichte des Mittags; die ersten vier sind der Standard im Artboard.
    static let mittag: [MensaMeal] = [
        gericht("Linsen-Dal", "Basmatireis, Mango-Chutney", badges: ["Vegan"], regional: true, preise: [2.9, 4.4, 5.8]),
        gericht("Hähnchenschnitzel „Wiener Art“ mit Pommes frites und bunter Salatbeilage", "Pommes frites, Salat, Joghurt-Dressing", preise: [3.8, 5.3, 6.7]),
        gericht("Pasta Arrabbiata", "", badges: ["Vegan"], preise: [2.6, 3.9, nil]),
        gericht("Thüringer Rostbratwurst", "Sauerkraut, Kartoffelpüree", regional: true, preise: [3.4, 4.9, 6.3]),
        gericht("Gemüse-Curry mit Kokos", "Jasminreis", badges: ["Vegan", "Bio"], preise: [2.8, 4.3, 5.7]),
        gericht("Käsespätzle mit Röstzwiebeln", "Gurkensalat", badges: ["Vegetarisch"], preise: [3.1, 4.6, 6.0]),
        gericht("Seelachsfilet", "Dillkartoffeln, Gurkensalat", preise: [4.2, 5.7, 7.1]),
        gericht("Ofengemüse mit Feta", "Couscous, Kräuterdip", badges: ["Vegetarisch", "Bio"], preise: [3.0, 4.5, 5.9])
    ]

    static let abend: [MensaMeal] = [
        gericht("Flammkuchen mit Lauch und Speck", "", kategorie: "Abendessen", mensa: "Cafeteria Mensa Ehrenberg", preise: [3.2, 4.7, 6.1]),
        gericht("Gemüse-Bowl mit Erdnusssoße", "Reis, Edamame, Rotkohl", kategorie: "Abendessen", mensa: "Cafeteria Mensa Ehrenberg", badges: ["Vegan"], preise: [3.0, 4.5, 5.9]),
        gericht("Ofenkartoffel mit Kräuterquark", "Blattsalat", kategorie: "Abendessen", mensa: "Cafeteria Mensa Ehrenberg", badges: ["Vegetarisch"], regional: true, preise: [2.7, 4.2, 5.6])
    ]

    static func speiseplan(
        gerichte: Int = 4, gruppe: MensaPriceGroup = .studierende, locale: Locale = deutsch
    ) -> MensaPlanShare {
        MensaPlanShare(
            venue: .mensaEhrenberg, day: donnerstag, allMeals: Array(mittag.prefix(gerichte)), priceGroup: gruppe,
            hours: "11:00–14:00", locale: locale
        )
    }

    static func abendessen(locale: Locale = deutsch) -> MensaPlanShare {
        MensaPlanShare(
            venue: .cafeteriaEhrenberg, day: donnerstag, mealtime: .dinner, allMeals: abend, priceGroup: .studierende,
            hours: "16:30–19:30", locale: locale
        )
    }

    /// Mit Beschreibung, Chips, Allergenen, Zusatzstoffen und CO₂.
    static let gerichtVollstaendig = MensaMeal(
        id: "dal", category: "Essen 1", name: "Linsen-Dal", description: "Basmatireis, Mango-Chutney",
        price: MensaMealPrice(student: 2.9, staff: 4.4, guest: 5.8, currency: "€"),
        allergies: ["Sellerie", "Senf"], badges: ["Vegan"], additives: ["Mit Antioxidationsmittel"], categories: ["Regional"],
        co2GramPerPortion: 420, components: [], canteenName: "Mensa Ehrenberg", date: donnerstag
    )

    /// Ohne Beschreibung, Allergene, Zusatzstoffe und CO₂, ohne Gästepreis.
    static let gerichtKnapp = MensaMeal(
        id: "pasta", category: "Aktionstheke", name: "Pasta Arrabbiata", description: nil,
        price: MensaMealPrice(student: 2.6, staff: 3.9, guest: nil, currency: "€"),
        allergies: [], badges: ["Vegan"], additives: [], categories: [],
        co2GramPerPortion: nil, components: [], canteenName: "Mensa Ehrenberg", date: donnerstag
    )

    // MARK: Veranstaltung

    private static func berlin(_ tag: Int, _ stunde: Int) -> Date {
        EventKalender.kalender.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: stunde)) ?? .now
    }

    static let partyBeschreibung = "Kürbisse, Kunstblut und DJs bis zum Morgengrauen. Das beste Kostüm gewinnt einen Monat freien Eintritt."

    /// Freitag, 30. Oktober, 21:00–03:00 Uhr im Studi-Club, wie im Artboard (Tweak `status`, `daten`).
    static func party(
        status: EventStatus = .findetStatt, mitEnde: Bool = true, beschreibung: String? = partyBeschreibung
    ) -> CampusEvent {
        CampusEvent(
            id: "party", titel: "Halloween-Party", beginn: berlin(30, 21), ende: mitEnde ? berlin(31, 3) : nil, status: status,
            ort: "Studi-Club", adresse: "Max-Planck-Ring 6, 98693 Ilmenau", veranstalter: "Studi-Club", beschreibung: beschreibung
        )
    }

    /// Knapp: nur Titel, Beginn und Status.
    static let partyKnapp = CampusEvent(id: "knapp", titel: "Halloween-Party", beginn: berlin(30, 21))

    static func veranstaltung(_ event: CampusEvent, locale: Locale = deutsch) -> EventShare {
        EventShare(event: event, locale: locale)
    }

    static func gericht(_ meal: MensaMeal, gruppe: MensaPriceGroup = .studierende, locale: Locale = deutsch) -> MensaMealShare {
        MensaMealShare(meal: meal, priceGroup: gruppe, locale: locale)
    }
}

/// Die Bilder liegen auf einer Fläche in der Farbe des Bildhintergrunds und werden in voller Höhe gezeigt.
private struct ShareCardPreview<Share: ShareImageContent>: View {
    let share: Share

    var body: some View {
        ScrollView { share.card }
            .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview("Speiseplan · 4 Gerichte") {
    ShareCardPreview(share: ShareCardVorschau.speiseplan())
}

#Preview("Speiseplan · 8 Gerichte") {
    ShareCardPreview(share: ShareCardVorschau.speiseplan(gerichte: 8))
}

#Preview("Speiseplan · Abendessen") {
    ShareCardPreview(share: ShareCardVorschau.abendessen())
}

#Preview("Speiseplan · Gäste, ein Preis fehlt") {
    ShareCardPreview(share: ShareCardVorschau.speiseplan(gruppe: .gaeste))
}

#Preview("Gericht · vollständig") {
    ShareCardPreview(share: ShareCardVorschau.gericht(ShareCardVorschau.gerichtVollstaendig))
}

#Preview("Gericht · knapp") {
    ShareCardPreview(share: ShareCardVorschau.gericht(ShareCardVorschau.gerichtKnapp))
}

#Preview("Gericht · knapp, Gäste") {
    ShareCardPreview(share: ShareCardVorschau.gericht(ShareCardVorschau.gerichtKnapp, gruppe: .gaeste))
}

#Preview("Speiseplan · Dark Mode des Geräts") {
    ShareCardPreview(share: ShareCardVorschau.speiseplan())
        .preferredColorScheme(.dark)
}

#Preview("Veranstaltung · findet statt") {
    ShareCardPreview(share: ShareCardVorschau.veranstaltung(ShareCardVorschau.party()))
}

#Preview("Veranstaltung · abgesagt") {
    ShareCardPreview(share: ShareCardVorschau.veranstaltung(ShareCardVorschau.party(status: .abgesagt)))
}

#Preview("Veranstaltung · unbestätigt") {
    ShareCardPreview(share: ShareCardVorschau.veranstaltung(ShareCardVorschau.party(status: .unbestaetigt)))
}

#Preview("Veranstaltung · ohne Ende") {
    ShareCardPreview(share: ShareCardVorschau.veranstaltung(ShareCardVorschau.party(mitEnde: false)))
}

#Preview("Veranstaltung · knapp") {
    ShareCardPreview(share: ShareCardVorschau.veranstaltung(ShareCardVorschau.partyKnapp))
}

#Preview("Veranstaltung · lange Beschreibung") {
    ShareCardPreview(share: ShareCardVorschau.veranstaltung(ShareCardVorschau.party(
        beschreibung: ShareCardVorschau.partyBeschreibung + " Einlass ab 20:30 Uhr, bitte Studierendenausweis mitbringen. Gäste nur in Begleitung. Garderobe vorhanden, Getränke zu Club-Preisen."
    )))
}

#Preview("Veranstaltung · Gerät im Hellen") {
    ShareCardPreview(share: ShareCardVorschau.veranstaltung(ShareCardVorschau.party()))
        .preferredColorScheme(.light)
}
