import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Campus_Ilmenau

/// Vergleicht die Teilen-Texte mit den Beispielen aus `Uebergabe.md`, Kapitel „Teilen“ → „Texte“.
@MainActor
struct ShareTextTests {
    private let de = Locale(identifier: "de_DE")
    private let en = Locale(identifier: "en_US")
    private let brand = "Geteilt mit Campus Ilmenau – campus-ilmenau.de"

    // MARK: - Beispiele

    /// Donnerstag, 29. Oktober 2026, mittags in der Zeitzone des Geräts.
    private var thursday: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 12)) ?? .now
    }

    private func meal(
        _ name: String,
        description: String? = nil,
        category: String = "Essen 1",
        canteen: String = "Mensa Ehrenberg",
        badges: [String] = [],
        categories: [String] = [],
        allergies: [String] = [],
        additives: [String] = [],
        price: MensaMealPrice? = nil,
        co2: Double? = nil
    ) -> MensaMeal {
        MensaMeal(
            id: name, category: category, name: name, description: description,
            price: price ?? MensaMealPrice(student: 2.9, staff: 4.4, guest: 5.8, currency: "€"),
            allergies: allergies, badges: badges, additives: additives, categories: categories,
            co2GramPerPortion: co2, components: [], canteenName: canteen, date: thursday
        )
    }

    private func prices(_ student: Double?, _ staff: Double? = nil, _ guest: Double? = nil) -> MensaMealPrice {
        MensaMealPrice(student: student, staff: staff, guest: guest, currency: "€")
    }

    private var lunchMeals: [MensaMeal] {
        [
            meal("Linsen-Dal", badges: ["Vegan", "Vegetarisch"], categories: ["Regional"], price: prices(2.9)),
            meal("Hähnchenschnitzel „Wiener Art“ mit Pommes frites und bunter Salatbeilage", price: prices(3.8)),
            meal("Pasta Arrabbiata", badges: ["Vegan"], price: prices(2.6)),
            meal("Thüringer Rostbratwurst", categories: ["Regional"], price: prices(3.4))
        ]
    }

    // MARK: - Speiseplan

    @Test func planMatchesExample() {
        let share = MensaPlanShare(
            venue: .mensaEhrenberg, day: thursday, allMeals: lunchMeals, priceGroup: .studierende,
            hours: "11:00–14:00", locale: de
        )
        #expect(share.text == """
        Mensa Ehrenberg · Donnerstag, 29. Oktober
        Mittagsangebot, 11:00–14:00 Uhr

        • Linsen-Dal – 2,90 € (vegan, regional)
        • Hähnchenschnitzel „Wiener Art“ mit Pommes frites und bunter Salatbeilage – 3,80 €
        • Pasta Arrabbiata – 2,60 € (vegan)
        • Thüringer Rostbratwurst – 3,40 € (regional)

        Preise für Studierende

        \(brand)
        """)
        #expect(share.title == "Mensa Ehrenberg · Do 29. Okt.")
    }

    @Test func planUsesPriceOfChosenGroupAndSkipsMissingPrice() {
        let meals = [
            meal("Mit Preis", price: prices(2.9, 4.4, 5.8)),
            meal("Ohne Preis", badges: ["Vegetarisch"], price: prices(2.9, nil, nil))
        ]
        let share = MensaPlanShare(venue: .mensaEhrenberg, day: thursday, allMeals: meals, priceGroup: .bedienstete, locale: de)
        #expect(share.text == """
        Mensa Ehrenberg · Donnerstag, 29. Oktober
        Mittagsangebot

        • Mit Preis – 4,40 €
        • Ohne Preis (vegetarisch)

        Preise für Bedienstete

        \(brand)
        """)
    }

    @Test func planIgnoresFilterAndOtherVenues() {
        // Der Speiseplan kennt keine Filter: Auch ein Gericht mit Allergenen steht drin. Andere Mensen nicht.
        let meals = lunchMeals + [
            meal("Mit Sellerie", allergies: ["Sellerie"], price: prices(1)),
            meal("Anderswo", canteen: "Cafeteria Röntgenbau", price: prices(1))
        ]
        let share = MensaPlanShare(venue: .mensaEhrenberg, day: thursday, allMeals: meals, priceGroup: .studierende, locale: de)
        #expect(share.text.contains("• Mit Sellerie – 1,00 €"))
        #expect(!share.text.contains("Anderswo"))
    }

    @Test func planDinnerOfCafeteriaOnlyHasDinnerMeals() {
        let meals = [
            meal("Mittagsgericht", category: "Mittagessen", canteen: "Cafeteria Mensa Ehrenberg", price: prices(3)),
            meal("Flammkuchen", category: "Abendessen", canteen: "Cafeteria Mensa Ehrenberg", price: prices(3.2))
        ]
        let share = MensaPlanShare(
            venue: .cafeteriaEhrenberg, day: thursday, mealtime: .dinner, allMeals: meals, priceGroup: .studierende,
            hours: "16:30–19:30", locale: de
        )
        #expect(share.text.hasPrefix("Cafeteria Ehrenberg · Donnerstag, 29. Oktober\nAbendessen, 16:30–19:30 Uhr\n\n• Flammkuchen – 3,20 €\n"))
        #expect(!share.text.contains("Mittagsgericht"))
    }

    @Test func planHoursFromOpeningHours() {
        let hours = [
            OpeningHour(weekday: "thu", opensAt: "11:00", closesAt: "14:00"),
            OpeningHour(weekday: "fri", opensAt: "11:00", closesAt: "13:30")
        ]
        #expect(MensaPlanShare.hours(for: .lunch, day: thursday, openingHours: hours) == "11:00–14:00")
        #expect(MensaPlanShare.hours(for: .dinner, day: thursday, openingHours: hours) == "16:30–14:00")
        #expect(MensaPlanShare.hours(for: .lunch, day: thursday.addingTimeInterval(-86_400 * 3), openingHours: hours) == nil)
    }

    // MARK: - Gericht

    @Test func mealMatchesExample() {
        let linsenDal = meal(
            "Linsen-Dal", description: "Basmatireis, Mango-Chutney", badges: ["Vegan", "Vegetarisch"], categories: ["Regional"],
            allergies: ["Sellerie", "Senf", "Sellerie"], additives: ["Mit Antioxidationsmittel"],
            price: prices(2.9, 4.4, 5.8), co2: 420
        )
        let share = MensaMealShare(meal: linsenDal, priceGroup: .studierende, locale: de)
        #expect(share.text == """
        Linsen-Dal
        Basmatireis, Mango-Chutney
        Mensa Ehrenberg · Essen 1 · Do 29. Okt.
        Vegan · Regional

        Studierende 2,90 € · Bedienstete 4,40 € · Gäste 5,80 €
        Allergene: Sellerie, Senf
        Zusatzstoffe: Mit Antioxidationsmittel
        ≈ 420 g CO₂ pro Portion

        \(brand)
        """)
        #expect(share.title == "Linsen-Dal · Mensa Ehrenberg")
    }

    @Test func mealPutsOwnPriceGroupFirstAndSkipsMissingPrice() {
        let share = MensaMealShare(meal: meal("Suppe", price: prices(2.9, nil, 5.8)), priceGroup: .gaeste, locale: de)
        #expect(share.text == """
        Suppe
        Mensa Ehrenberg · Essen 1 · Do 29. Okt.

        Gäste 5,80 € · Studierende 2,90 €

        \(brand)
        """)
    }

    // MARK: - Veranstaltung

    private func berlin(_ day: Int, _ hour: Int, month: Int = 10) -> Date {
        EventKalender.kalender.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? .now
    }

    private func party(
        status: EventStatus = .findetStatt,
        ende: Date? = nil,
        beschreibung: String? = "Kürbisse, Kunstblut und DJs bis zum Morgengrauen. Das beste Kostüm gewinnt einen Monat freien Eintritt.",
        infoURL: URL? = nil,
        ticketURL: URL? = URL(string: "https://veranstalter.example/tickets")
    ) -> CampusEvent {
        CampusEvent(
            id: "e1", titel: "Halloween-Party", beginn: berlin(30, 21), ende: ende ?? berlin(31, 3), status: status,
            ort: "Studi-Club", adresse: "Max-Planck-Ring 6, 98693 Ilmenau", veranstalter: "Studi-Club",
            beschreibung: beschreibung, infoURL: infoURL, ticketURL: ticketURL
        )
    }

    @Test func eventMatchesExample() {
        let share = EventShare(event: party(), locale: de)
        #expect(share.text == """
        Halloween-Party
        Freitag, 30. Oktober · 21:00–03:00 Uhr
        Studi-Club, Max-Planck-Ring 6, 98693 Ilmenau
        Veranstalter: Studi-Club

        Kürbisse, Kunstblut und DJs bis zum Morgengrauen. Das beste Kostüm gewinnt einen Monat freien Eintritt.

        Tickets: https://veranstalter.example/tickets

        \(brand)
        """)
        #expect(share.title == "Halloween-Party · Fr 30. Okt.")
    }

    @Test func cancelledEventStartsWithFaelltAusAndHasNoDescription() {
        let text = EventShare(event: party(status: .abgesagt), locale: de).text
        #expect(text.hasPrefix("Fällt aus: Halloween-Party\nFreitag, 30. Oktober · 21:00–03:00 Uhr\n"))
        #expect(!text.contains("Kürbisse"))
    }

    @Test func unconfirmedEventNotesItBehindTheTime() {
        let text = EventShare(event: party(status: .unbestaetigt), locale: de).text
        #expect(text.contains("Freitag, 30. Oktober · 21:00–03:00 Uhr (Termin noch nicht bestätigt)\n"))
    }

    @Test func eventWithoutEndSaysAbUhr() {
        var event = party()
        event.ende = nil
        #expect(EventShare(event: event, locale: de).text.contains("Freitag, 30. Oktober · ab 21:00 Uhr\n"))
    }

    @Test func eventLinkIsTicketsThenInfoThenNone() {
        let info = URL(string: "https://veranstalter.example/info")
        let tickets = EventShare(event: party(infoURL: info), locale: de).text
        #expect(tickets.contains("Tickets: https://veranstalter.example/tickets"))
        #expect(!tickets.contains("Infos:"))

        let onlyInfo = EventShare(event: party(infoURL: info, ticketURL: nil), locale: de).text
        #expect(onlyInfo.contains("\n\nInfos: https://veranstalter.example/info\n\n\(brand)"))

        let none = EventShare(event: party(ticketURL: nil), locale: de).text
        #expect(!none.contains("Tickets:") && !none.contains("Infos:"))
    }

    @Test func eventDescriptionIsCutAtWordEndAfter280Characters() {
        let words = Array(repeating: "Wörter", count: 80).joined(separator: " ")
        let text = EventShare(event: party(beschreibung: words, ticketURL: nil), locale: de).text
        let description = text.components(separatedBy: "\n\n")[1]
        #expect(description.count <= 280)
        #expect(description.hasSuffix("Wörter…"))
        #expect(description.count > 270)

        let exact = String(repeating: "a", count: 280)
        #expect(ShareText.shortened(exact) == exact)
        #expect(ShareText.shortened(exact + "b").count == 280)
    }

    @Test func eventWithoutOptionalFieldsOmitsTheirLines() {
        let event = CampusEvent(id: "e2", titel: "Sprechstunde", beginn: berlin(30, 10), ende: berlin(30, 12))
        #expect(EventShare(event: event, locale: de).text == """
        Sprechstunde
        Freitag, 30. Oktober · 10:00–12:00 Uhr

        \(brand)
        """)
    }

    // MARK: - Medium

    private func catalogDetail(items: String, status: String = "available", catalogUrl: String? = "https://katalog.example/titel/1") throws -> LibraryMediaDetail {
        let url = catalogUrl.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"id":"med_1","title":"Regelungstechnik für Ingenieure","subtitle":"Analyse, Simulation und Entwurf von Regelkreisen",
         "authors":["Reuter, Manfred","Zacher, Serge"],"mediaType":"print_book","edition":"16. Auflage","year":"2022",
         "catalogUrl":\(url),"items":[\(items)],"availabilityStatus":"\(status)"}
        """
        return try LibraryCatalogService.decoder.decode(LibraryMediaDetail.self, from: Data(json.utf8))
    }

    private let firstItem = """
    {"label":"ZQ 5000 R444(16)-1","location":{"id":"x","code":"2","name":"Lehrbuchsammlung, 2. OG"},"status":"on_loan"},
    {"label":"ZQ 5000 R444(16)-2","location":{"id":"y","code":"3","name":"Magazin"},"status":"available"}
    """

    @Test func mediumMatchesExample() throws {
        let share = LibraryMediaShare(detail: try catalogDetail(items: firstItem), locale: de)
        #expect(share.text == """
        Aus dem Katalog der UB Ilmenau:
        Regelungstechnik für Ingenieure
        Analyse, Simulation und Entwurf von Regelkreisen
        Manfred Reuter, Serge Zacher · 16. Auflage, 2022
        Lehrbuchsammlung, 2. OG · ZQ 5000 R444(16)

        https://katalog.example/titel/1

        \(brand)
        """)
        #expect(share.title == "Regelungstechnik für Ingenieure")
    }

    @Test func mediumShowsNoAvailability() throws {
        let text = LibraryMediaShare(detail: try catalogDetail(items: firstItem), locale: de).text.lowercased()
        for word in ["ausleihbar", "ausgeliehen", "verfügbar", "token"] {
            #expect(!text.contains(word))
        }
    }

    @Test func onlineMediumSaysOnlineImCampusnetz() throws {
        let share = LibraryMediaShare(detail: try catalogDetail(items: "", status: "online"), locale: de)
        #expect(share.text.contains("Manfred Reuter, Serge Zacher · 16. Auflage, 2022\nOnline im Campusnetz\n\nhttps://katalog.example/titel/1\n"))
    }

    @Test func mediumWithoutItemsOrLinkOmitsTheirLines() throws {
        let text = LibraryMediaShare(detail: try catalogDetail(items: "", status: "unknown", catalogUrl: nil), locale: de).text
        #expect(text == """
        Aus dem Katalog der UB Ilmenau:
        Regelungstechnik für Ingenieure
        Analyse, Simulation und Entwurf von Regelkreisen
        Manfred Reuter, Serge Zacher · 16. Auflage, 2022

        \(brand)
        """)
    }

    @Test func signatureLosesCopySuffix() {
        #expect(LibraryMediaShare.signature("ZQ 5000 R444(16)-1") == "ZQ 5000 R444(16)")
        #expect(LibraryMediaShare.signature("ZQ 5000 R444(16)") == "ZQ 5000 R444(16)")
        #expect(LibraryMediaShare.signature("  ") == nil)
    }

    // MARK: - Marke, Sprache, Form

    @Test func brandComesFromOneConstant() {
        #expect(ShareBranding.domain == "campus-ilmenau.de")
        #expect(ShareBranding.line(locale: de) == brand)
        #expect(ShareBranding.line(locale: en) == "Shared with Campus Ilmenau – campus-ilmenau.de")
    }

    @Test func englishTextsUseEnglishWordsAndFormats() {
        let plan = MensaPlanShare(
            venue: .mensaEhrenberg, day: thursday, allMeals: lunchMeals, priceGroup: .studierende, hours: "11:00–14:00", locale: en
        )
        #expect(plan.text.contains("Mensa Ehrenberg · Thursday, October 29\nLunch menu, 11:00–14:00\n"))
        #expect(plan.text.contains("• Linsen-Dal – $2.90") || plan.text.contains("• Linsen-Dal – €2.90"))
        #expect(plan.text.contains("(vegan, regional)"))
        #expect(plan.text.contains("Prices for students"))
        #expect(plan.text.hasSuffix("Shared with Campus Ilmenau – campus-ilmenau.de"))

        let event = EventShare(event: party(status: .abgesagt), locale: en).text
        #expect(event.hasPrefix("Cancelled: Halloween-Party\nFriday, October 30 · 21:00–03:00\n"))
        #expect(event.contains("Organizer: Studi-Club"))
    }

    @Test func textsHaveNoMoreThanOneBlankLineInARowAndEndWithBrand() throws {
        let texts = [
            MensaPlanShare(venue: .mensaEhrenberg, day: thursday, allMeals: lunchMeals, priceGroup: .studierende, locale: de).text,
            MensaMealShare(meal: meal("Suppe"), priceGroup: .studierende, locale: de).text,
            EventShare(event: party(beschreibung: "Eins\n\n\n\nZwei"), locale: de).text,
            LibraryMediaShare(detail: try catalogDetail(items: firstItem), locale: de).text
        ]
        for text in texts {
            #expect(!text.contains("\n\n\n"))
            #expect(text.hasSuffix(brand))
            #expect(!text.contains("**") && !text.contains("Heute"))
        }
    }

    // MARK: - Menü der Teilen-Taste

    @Test func planMenuCaptionNamesVenueDayAndMealtime() {
        let today = thursday
        let plan = MensaPlanShare(venue: .mensaEhrenberg, day: today, allMeals: lunchMeals, priceGroup: .studierende, locale: de)
        #expect(plan.menuCaption(now: today) == "Mensa Ehrenberg · Heute · Mittag")

        let tomorrow = today.addingTimeInterval(86_400)
        let dinner = MensaPlanShare(
            venue: .cafeteriaEhrenberg, day: tomorrow, mealtime: .dinner, allMeals: [], priceGroup: .studierende, locale: de
        )
        #expect(dinner.menuCaption(now: today) == "Cafeteria Ehrenberg · Morgen · Abendessen")

        // Abendessen gibt es nur bei der Cafeteria Ehrenberg; bei den anderen Mensen steht „Mittag“.
        let other = MensaPlanShare(venue: .nanoteria, day: today, mealtime: .dinner, allMeals: [], priceGroup: .studierende, locale: de)
        #expect(other.menuCaption(now: today) == "Cafeteria Nanoteria · Heute · Mittag")
    }

    @Test func planWithoutMealsHasNothingToShare() {
        // Ohne Angebot ist die Teilen-Taste im Speiseplan deaktiviert; sie prüft genau das.
        let empty = MensaPlanShare(venue: .roentgenbau, day: thursday, allMeals: lunchMeals, priceGroup: .studierende, locale: de)
        #expect(empty.meals.isEmpty)
    }

    @Test func mealAndEventMenuCaptions() {
        let dal = meal("Linsen-Dal", price: prices(2.9))
        #expect(MensaMealShare(meal: dal, priceGroup: .studierende, locale: de).menuCaption == "Linsen-Dal · alle Angaben")
        #expect(EventShare(event: party(), locale: de).menuCaption == "Halloween-Party · Fr 30. Okt.")
    }

    // MARK: - Bibliothek ohne geladenes Detail

    @Test func mediumTextWorksBeforeTheDetailIsLoaded() throws {
        let detail = try catalogDetail(items: firstItem)
        // Nur die Daten aus der Trefferliste: kein Standort, aber Titel, Personen und Link.
        let text = LibraryMediaShare(media: detail.media, detail: nil, locale: de).text
        #expect(text == """
        Aus dem Katalog der UB Ilmenau:
        Regelungstechnik für Ingenieure
        Analyse, Simulation und Entwurf von Regelkreisen
        Manfred Reuter, Serge Zacher · 16. Auflage, 2022

        https://katalog.example/titel/1

        \(brand)
        """)
        #expect(LibraryMediaShare(media: detail.media, detail: detail, locale: de).text.contains("Lehrbuchsammlung, 2. OG · ZQ 5000 R444(16)"))
    }

    // MARK: - Bild als Datei

    @Test func imageFileIsWrittenUnderItsNameAndReplacedByNewerOnes() throws {
        let first = try ShareImageFile.write(Data([1, 2, 3]), named: "Datei-Test.png")
        #expect(first.lastPathComponent == "Datei-Test.png")
        #expect(try Data(contentsOf: first) == Data([1, 2, 3]))
        let second = try ShareImageFile.write(Data([4, 5]), named: "Datei-Test.png")
        #expect(second == first)
        #expect(try Data(contentsOf: second) == Data([4, 5]))
        try? FileManager.default.removeItem(at: first)
    }
}
