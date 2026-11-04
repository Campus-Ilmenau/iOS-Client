import Foundation
import Testing
@testable import Campus_Ilmenau

struct MensaDetailTests {
    private func meal(
        name: String = "Linsen-Dal",
        badges: [String] = [],
        categories: [String] = [],
        allergies: [String] = [],
        additives: [String] = [],
        components: [MensaMealComponent] = [],
        price: MensaMealPrice = MensaMealPrice(student: 2.9, staff: 4.4, guest: nil, currency: "€")
    ) -> MensaMeal {
        MensaMeal(
            id: "x", category: "Mittagessen", name: name, description: nil, price: price,
            allergies: allergies, badges: badges, additives: additives, categories: categories,
            co2GramPerPortion: nil, components: components, canteenName: "Mensa Ehrenberg", date: .now
        )
    }

    // MARK: - Preise

    @Test func pricesUseGermanFormatAndDashForMissing() {
        let price = MensaMealPrice(student: 2.9, staff: 4.4, guest: nil, currency: "€")
        #expect(price.formatted(for: .studierende).replacingOccurrences(of: "\u{00A0}", with: " ") == "2,90 €")
        #expect(price.formatted(for: .bedienstete).replacingOccurrences(of: "\u{00A0}", with: " ") == "4,40 €")
        #expect(price.formatted(for: .gaeste) == "–")
    }

    // MARK: - Chips

    @Test func veganMealShowsOnlyVeganInList() {
        let chips = meal(badges: ["Vegan", "Vegetarisch"]).listChips
        #expect(chips.map(\.title) == ["Vegan"])
    }

    @Test func detailAddsOtherCategoriesAsNeutralChips() {
        let chips = meal(badges: ["Vegan"], categories: ["Regional", "Kinderessen", "Vegan", "Kinderessen"]).detailChips
        #expect(chips.map(\.title) == ["Vegan", "Regional", "Kinderessen"])
        #expect(chips.last?.variant == .neutral)
    }

    @Test func duplicateAllergensAndAdditivesAreShownOnce() {
        let m = meal(allergies: ["Sellerie", "Sellerie", "Weizen"], additives: ["Farbstoff", "Farbstoff"])
        #expect(m.uniqueAllergies == ["Sellerie", "Weizen"])
        #expect(m.uniqueAdditives == ["Farbstoff"])
    }

    // MARK: - Bestandteile

    @Test func componentCodesAreSplitIntoAllergensAndAdditives() {
        let m = meal(
            allergies: ["Sellerie"],
            additives: ["Antioxidationsmittel"],
            components: [
                MensaMealComponent(name: "Mango-Chutney", codes: ["Senf", "Antioxidationsmittel", "Vegan", "Knoblauch"]),
                MensaMealComponent(name: "Basmatireis", codes: ["Ohne Zusatzstoffe", "Vegan"])
            ]
        )
        let infos = m.componentInfos
        #expect(infos[0].allergens == ["Senf"])
        #expect(infos[0].additives == ["Antioxidationsmittel"])
        #expect(infos[0].infoText == "Allergene: Senf · Zusatzstoffe: Antioxidationsmittel")
        // Symbole und „Ohne Zusatzstoffe“ zählen nicht.
        #expect(infos[1].infoText == "Keine weiteren Angaben")
    }

    // MARK: - Öffnungszeiten

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private var ehrenbergHours: [OpeningHour] {
        ["mon", "tue", "wed", "thu"].map { OpeningHour(weekday: $0, opensAt: "11:00", closesAt: "14:00") }
            + [OpeningHour(weekday: "fri", opensAt: "11:00", closesAt: "13:30")]
    }

    private var cafeteriaHours: [OpeningHour] {
        ["mon", "tue", "wed", "thu"].map { OpeningHour(weekday: $0, opensAt: "08:00", closesAt: "20:00") }
            + [OpeningHour(weekday: "fri", opensAt: "08:00", closesAt: "19:30"),
               OpeningHour(weekday: "sat", opensAt: "11:30", closesAt: "14:00")]
    }

    @Test func weekRowsMergeDaysWithEqualHours() {
        let rows = MensaOpeningHours.weekRows(for: ehrenbergHours)
        #expect(rows.map(\.label) == ["Montag – Donnerstag", "Freitag", "Samstag, Sonntag"])
        #expect(rows.map(\.value) == ["11:00–14:00", "11:00–13:30", "geschlossen"])
    }

    @Test func weekRowsKeepSaturdayWhenOpen() {
        let rows = MensaOpeningHours.weekRows(for: cafeteriaHours)
        #expect(rows.map(\.label) == ["Montag – Donnerstag", "Freitag", "Samstag", "Sonntag"])
    }

    @Test func todayTextFollowsTheWeekday() {
        // 4. November 2026 ist ein Mittwoch, der 6. ein Freitag, der 8. ein Sonntag.
        #expect(MensaOpeningHours.todayText(for: ehrenbergHours, now: date(day: 4, hour: 9, minute: 0), calendar: calendar) == "11:00–14:00 Uhr")
        #expect(MensaOpeningHours.todayText(for: ehrenbergHours, now: date(day: 6, hour: 9, minute: 0), calendar: calendar) == "11:00–13:30 Uhr")
        #expect(MensaOpeningHours.todayText(for: ehrenbergHours, now: date(day: 8, hour: 9, minute: 0), calendar: calendar) == "heute geschlossen")
    }

    @Test func stateOpenClosingSoonAndClosed() {
        func state(_ hour: Int, _ minute: Int, day: Int = 4) -> MensaOpeningHours.State {
            MensaOpeningHours.state(for: ehrenbergHours, now: date(day: day, hour: hour, minute: minute), calendar: calendar)
        }
        #expect(state(10, 59) == .closed)
        #expect(state(11, 0) == .open)
        #expect(state(13, 30) == .open)          // genau 30 Minuten vor Schluss: noch nicht „gleich zu“
        #expect(state(13, 31) == .closingSoon)
        #expect(state(13, 59) == .closingSoon)
        #expect(state(14, 0) == .closed)
        #expect(state(12, 0, day: 8) == .closed) // Sonntag
        #expect(MensaOpeningHours.state(for: [], now: date(day: 4, hour: 12, minute: 0), calendar: calendar) == .closed)
    }

    @Test func dinnerTextUsesClosingTimes() {
        #expect(MensaOpeningHours.dinnerText(for: cafeteriaHours) == "bis 20:00 Uhr, Freitag bis 19:30 Uhr")
        #expect(MensaOpeningHours.dinnerText(for: [OpeningHour(weekday: "mon", opensAt: "08:00", closesAt: "20:00"),
                                                   OpeningHour(weekday: "fri", opensAt: "08:00", closesAt: "20:00")]) == "bis 20:00 Uhr")
    }

    // MARK: - Favoriten

    private func makeDefaults() -> UserDefaults {
        let suite = "MensaDetailTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func favoritesAreStoredByNameAndSurviveRestart() {
        let defaults = makeDefaults()
        let store = MensaFavoriteStore(defaults: defaults)
        let dal = meal(name: "Linsen-Dal")
        #expect(!store.isFavorite(dal))

        store.setFavorite(true, for: dal)
        #expect(store.isFavorite(dal))
        // Neue Instanz, gleiche Daten: bleibt gemerkt. Groß- und Kleinschreibung spielt keine Rolle.
        #expect(MensaFavoriteStore(defaults: defaults).isFavorite(meal(name: "  linsen-dal ")))
        #expect(!MensaFavoriteStore(defaults: defaults).isFavorite(meal(name: "Pasta")))

        store.setFavorite(false, for: dal)
        #expect(!MensaFavoriteStore(defaults: defaults).isFavorite(dal))
    }

    @Test func settingFavoriteTwiceKeepsOneEntry() {
        let defaults = makeDefaults()
        let store = MensaFavoriteStore(defaults: defaults)
        let dal = meal(name: "Linsen-Dal")
        store.setFavorite(true, for: dal)
        store.setFavorite(true, for: dal)
        #expect(defaults.stringArray(forKey: MensaFavoriteStore.key)?.count == 1)
    }
}
