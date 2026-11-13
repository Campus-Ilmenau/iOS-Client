import Testing
import Foundation
@testable import Campus_Ilmenau

// MARK: - Fixtures

/// Donnerstag, 29. Oktober 2026 (Berlin) zu einer Uhrzeit; `tag: 1` ist Freitag.
@MainActor
private func zeit(_ uhr: String, tag: Int = 0) -> Date { EventsVorschauQuelle.zeit(tag, uhr) }

@MainActor
private func gericht(
    _ name: String, mensa: String, gruppe: String = "Mittag", badges: [String] = [], preis: Double = 2.9
) -> MensaMeal {
    MensaMeal(
        id: "\(mensa)-\(name)", category: gruppe, name: name, description: nil,
        price: MensaMealPrice(student: preis, staff: 3.9, guest: 4.9, currency: "EUR"),
        allergies: [], badges: badges, additives: [], categories: [], co2GramPerPortion: nil, components: [],
        canteenName: mensa, date: zeit("12:00")
    )
}

@MainActor
private func oeffnung(_ name: String, von: String, bis: String) -> Canteen {
    let tage = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    return Canteen(
        rscId: nil, name: name, hasMenu: true, city: nil, address: nil,
        openingHours: tage.map { OpeningHour(weekday: $0, opensAt: von, closesAt: bis) }
    )
}

@MainActor private let mensenListe = [
    oeffnung("Mensa Ehrenberg", von: "11:00", bis: "14:00"),
    oeffnung("Cafeteria Mensa Ehrenberg", von: "08:00", bis: "15:00"),
    oeffnung("Cafeteria NANOteria", von: "08:00", bis: "15:00"),
    oeffnung("Cafeteria Röntgenbau", von: "08:00", bis: "14:00")
]

/// Normalfall: Mittag in allen vier Mensen, Abendessen in der Cafeteria Ehrenberg.
@MainActor
private func beispielSpeiseplan(abendessenIn: [String] = ["Cafeteria Mensa Ehrenberg"]) -> [MensaMeal] {
    var liste = [
        gericht("Linsen-Dal", mensa: "Mensa Ehrenberg", badges: ["Vegan"]),
        gericht("Schnitzel", mensa: "Mensa Ehrenberg", preis: 3.8),
        gericht("Pasta", mensa: "Mensa Ehrenberg", badges: ["Vegan"]),
        gericht("Bowl", mensa: "Cafeteria Mensa Ehrenberg"),
        gericht("Curry", mensa: "Cafeteria NANOteria", badges: ["Vegan"]),
        gericht("Spätzle", mensa: "Cafeteria NANOteria", badges: ["Vegetarisch"]),
        gericht("Chili", mensa: "Cafeteria NANOteria"),
        gericht("Couscous", mensa: "Cafeteria Röntgenbau")
    ]
    for ort in abendessenIn {
        liste.append(gericht("Flammkuchen", mensa: ort, gruppe: "Abendessen"))
        liste.append(gericht("Gemüse-Bowl", mensa: ort, gruppe: "Abendessen", badges: ["Vegan"]))
    }
    return liste
}

@MainActor
private func morgenPlan() -> [MensaMeal] {
    [gericht("Reispfanne", mensa: "Mensa Ehrenberg"), gericht("Reispfanne", mensa: "Cafeteria NANOteria")]
}

@MainActor
private final class MensaQuelleStub: HeuteMensaDatenquelle {
    var heute: [MensaMeal]? = beispielSpeiseplan()
    var morgen: [MensaMeal]? = morgenPlan()
    var canteens: [Canteen]? = mensenListe
    private(set) var tage: [Date] = []

    func speiseplan(am tag: Date) async throws -> [MensaMeal] {
        tage.append(tag)
        let istHeute = HeuteUhr.istGleicherTag(tag, zeit("12:00"))
        guard let liste = istHeute ? heute : morgen else { throw URLError(.notConnectedToInternet) }
        return liste
    }

    func mensen() async throws -> [Canteen] {
        guard let canteens else { throw URLError(.notConnectedToInternet) }
        return canteens
    }
}

@MainActor
private final class EventsQuelleStub: EventsDatenquelle {
    var abend: [CampusEvent]? = []
    var morgen: [CampusEvent]? = []
    private(set) var filter: [EventFilter] = []

    func liste(filter: EventFilter, seite: Int, jetzt: Date) async throws -> EventSeite {
        self.filter.append(filter)
        guard let events = filter.heuteAbend ? abend : morgen else { throw EventsAPIError.invalidResponse }
        return EventSeite(events: events, seite: seite, hatWeitere: false, gesamt: events.count)
    }

    func veranstalter() async throws -> [Veranstalter] { [] }
    func detail(id: String) async throws -> CampusEvent { throw EventsAPIError.notFound }
}

@MainActor
private struct HinweiseStub: HinweiseQuelle {
    var liste: [Hinweis]?
    func hinweise(jetzt: Date) async throws -> [Hinweis] {
        guard let liste else { throw URLError(.timedOut) }
        return liste
    }
}

@MainActor
private func event(_ id: String, _ titel: String, von: String, bis: String? = nil, tag: Int = 0,
                   veranstalter: String? = "Studi-Club", ort: String? = "Club") -> CampusEvent {
    CampusEvent(
        id: id, titel: titel, beginn: zeit(von, tag: tag), ende: bis.map { zeit($0, tag: tag) },
        ort: ort, veranstalter: veranstalter
    )
}

@MainActor private let spieleabend = event("1", "Spieleabend", von: "19:00", bis: "23:00")
@MainActor private let party = event("2", "Halloween-Party", von: "21:00", tag: 1)

@MainActor
private struct Aufbau {
    let mensa = MensaQuelleStub()
    let events = EventsQuelleStub()
    var hinweise: [Hinweis]? = []
    let defaults = UserDefaults(suiteName: "HeuteModelTests-\(UUID().uuidString)") ?? .standard

    func modell(_ uhr: String, mensa venue: MensaVenue, hinweise: [Hinweis]? = nil, filter: MensaFilter = MensaFilter()) -> HeuteModel {
        let speicher = HeuteMensaSpeicher(defaults: defaults)
        speicher.venue = venue
        let jetzt = zeit(uhr)
        return HeuteModel(
            now: { jetzt },
            mensaQuelle: mensa,
            eventsQuelle: events,
            hinweiseQuelle: HinweiseStub(liste: hinweise ?? self.hinweise),
            mensaSpeicher: speicher,
            ausblendSpeicher: HinweiseAusblendSpeicher(defaults: defaults),
            preisgruppe: { .studierende },
            mensaFilter: { filter },
            zeitlimit: .seconds(2),
            // Diese Tests prüfen Inhalte, nicht die Zeit: Die Uhr läuft nie vor, das Limit greift nie. Mit der echten Uhr
            // kippte ein Lauf auf einem ausgelasteten Rechner in „Zeitablauf“ (leere Karten, dann Index außerhalb).
            clock: ManualClock()
        )
    }
}

@MainActor
private func geladen(_ uhr: String, mensa venue: MensaVenue, _ vorgabe: Aufbau? = nil) async -> HeuteModel {
    let aufbau = vorgabe ?? Aufbau()
    aufbau.events.abend = [spieleabend]
    aufbau.events.morgen = [party]
    let modell = aufbau.modell(uhr, mensa: venue)
    await modell.laden()
    return modell
}

// MARK: - Phase und Begrüßung

@MainActor
struct TagesphaseTests {
    @Test(arguments: [
        ("00:00", Tagesphase.morgen), ("10:29", .morgen), ("10:30", .mittag), ("13:59", .mittag),
        ("14:00", .nachmittag), ("16:29", .nachmittag), ("16:30", .abend), ("19:29", .abend), ("19:30", .nacht),
        ("23:59", .nacht)
    ])
    func phaseAtBoundaries(uhr: String, erwartet: Tagesphase) {
        #expect(Tagesphase(zeit(uhr)) == erwartet)
    }

    @Test(arguments: [
        ("00:00", "Guten Morgen"), ("05:00", "Guten Morgen"), ("10:59", "Guten Morgen"), ("11:00", "Mahlzeit!"),
        ("13:59", "Mahlzeit!"), ("14:00", "Hallo!"), ("17:59", "Hallo!"), ("18:00", "Guten Abend"), ("23:59", "Guten Abend")
    ])
    func greetingAtBoundaries(uhr: String, erwartet: String) {
        #expect(Begruessung(zeit(uhr)).text == erwartet)
    }

    @Test func phaseUsesBerlinTimeNotDeviceTime() {
        // 22:00 UTC am 29.10. ist 23:00 in Berlin (MEZ, die Sommerzeit endete am 25.10.)
        let utc = Date(timeIntervalSince1970: 1_793_311_200) // 2026-10-29 22:00 UTC
        #expect(HeuteUhr.minuten(utc) == 23 * 60)
        #expect(Tagesphase(utc) == .nacht)
    }

    @Test func nextChangeIsTheNextBoundaryOrMidnight() {
        #expect(Tagesphase.naechsterWechsel(nach: zeit("08:15")) == zeit("10:30"))
        #expect(Tagesphase.naechsterWechsel(nach: zeit("10:30")) == zeit("11:00"))
        #expect(Tagesphase.naechsterWechsel(nach: zeit("17:40")) == zeit("18:00"))
        #expect(Tagesphase.naechsterWechsel(nach: zeit("21:30")) == zeit("00:00", tag: 1))
    }
}

// MARK: - Jetzt-Karte

@MainActor
struct HeuteJetztKarteTests {
    @Test func morningShowsChosenMensaWithTwoMealsPreview() async throws {
        let modell = await geladen("08:15", mensa: .nanoteria)
        let karte = try #require(modell.jetztKarte)
        #expect(karte.ueberschrift == "Heute")
        #expect(karte.kicker == "Jetzt geöffnet · bis 15:00")
        #expect(karte.titel == "Cafeteria Nanoteria")
        #expect(karte.unterzeile == "Vorschau auf das Mittagsangebot")
        #expect(karte.zeilen.map(\.name) == ["Curry", "Spätzle"])
        #expect(karte.mensaAendernSichtbar)
    }

    @Test func morningBeforeOpeningSaysOpensAt() async throws {
        let modell = await geladen("08:15", mensa: .mensaEhrenberg)
        #expect(modell.jetztKarte?.kicker == "Heute · ab 11:00")
    }

    @Test func noonShowsThreeMealsWithChipsAndPrice() async throws {
        let modell = await geladen("11:45", mensa: .mensaEhrenberg)
        let karte = try #require(modell.jetztKarte)
        #expect(karte.ueberschrift == "Jetzt")
        #expect(karte.kicker == "Jetzt geöffnet · bis 14:00")
        #expect(karte.unterzeile == "Mittagsangebot")
        #expect(karte.zeilen.map(\.name) == ["Linsen-Dal", "Schnitzel", "Pasta"])
        #expect(karte.zeilen[0].chips.map(\.title) == ["Vegan"])
        #expect(karte.zeilen[1].rechts?.hasPrefix("3,80") == true)
        #expect(karte.ziel == .speiseplan(.mensaEhrenberg))
    }

    @Test func noonAfterClosingIsClosedToday() async throws {
        let aufbau = Aufbau()
        aufbau.mensa.canteens = [oeffnung("Mensa Ehrenberg", von: "11:00", bis: "11:30")]
        let modell = aufbau.modell("11:45", mensa: .mensaEhrenberg)
        await modell.laden()
        #expect(modell.jetztKarte?.kicker == "Heute geschlossen")
    }

    @Test func noonOfCafeteriaEhrenbergSkipsDinnerMeals() async throws {
        let modell = await geladen("11:45", mensa: .cafeteriaEhrenberg)
        #expect(modell.jetztKarte?.zeilen.map(\.name) == ["Bowl"])
    }

    @Test func afternoonWithEhrenbergShowsDinnerAt1630() async throws {
        let modell = await geladen("15:10", mensa: .cafeteriaEhrenberg)
        let karte = try #require(modell.jetztKarte)
        #expect(karte.ueberschrift == "Gleich")
        #expect(karte.kicker == "Heute ab 16:30")
        #expect(karte.titel == "Abendessen in der Mensa Ehrenberg")
        #expect(karte.unterzeile == "Cafeteria")
        #expect(karte.zeilen.map(\.name) == ["Flammkuchen", "Gemüse-Bowl"])
        #expect(karte.linkText == "Zum Abendangebot")
    }

    @Test func afternoonWithOtherMensaGivesTip() async throws {
        let modell = await geladen("15:10", mensa: .nanoteria)
        let karte = try #require(modell.jetztKarte)
        #expect(karte.kicker == "Cafeteria Nanoteria hat geschlossen")
        #expect(karte.titel == "Abendessen in der Mensa Ehrenberg")
        #expect(karte.unterzeile == "Tipp · ab 16:30 in der Cafeteria")
        #expect(karte.mensaAendernSichtbar)
    }

    @Test func eveningWithEhrenbergIsOpenNow() async throws {
        let modell = await geladen("17:40", mensa: .cafeteriaEhrenberg)
        let karte = try #require(modell.jetztKarte)
        #expect(karte.ueberschrift == "Jetzt")
        #expect(karte.kicker == "Jetzt geöffnet · Abendessen")
        #expect(karte.titel == "Mensa Ehrenberg")
        #expect(karte.unterzeile == "Cafeteria")
    }

    @Test func eveningWithOtherMensaGivesTip() async throws {
        let modell = await geladen("17:40", mensa: .roentgenbau)
        let karte = try #require(modell.jetztKarte)
        #expect(karte.kicker == "Cafeteria Röntgenbau hat geschlossen")
        #expect(karte.titel == "Abendessen in der Mensa Ehrenberg")
        #expect(karte.unterzeile == "Tipp · jetzt geöffnet")
    }

    @Test func nightShowsRunningEventWithNextOne() async throws {
        let modell = await geladen("21:30", mensa: .cafeteriaEhrenberg)
        let karte = try #require(modell.jetztKarte)
        #expect(karte.ueberschrift == "Jetzt")
        #expect(karte.kicker == "Läuft gerade · seit 19:00")
        #expect(karte.titel == "Spieleabend")
        #expect(karte.unterzeile == "Club · Studi-Club")
        #expect(karte.zeilen.map(\.name) == ["Danach: Halloween-Party"])
        #expect(karte.zeilen.first?.rechts == "Fr 21:00")
        #expect(karte.linkText == "Alle Veranstaltungen")
        #expect(karte.ziel == .alleEvents)
        #expect(karte.stil == .event)
        #expect(!karte.mensaAendernSichtbar)
    }

    @Test func nightWithOtherMensaIsTheSame() async throws {
        let modell = await geladen("21:30", mensa: .nanoteria)
        #expect(modell.jetztKarte?.titel == "Spieleabend")
        #expect(modell.jetztKarte?.mensaAendernSichtbar == false)
    }

    @Test func eventWithoutEndRunsUntilMidnight() async throws {
        let aufbau = Aufbau()
        aufbau.events.abend = [event("3", "Open Stage", von: "20:00")]
        let modell = aufbau.modell("23:45", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.jetztKarte?.titel == "Open Stage")
    }

    @Test func nightWithNothingRunningShowsTheNextEventOfTheEvening() async throws {
        let aufbau = Aufbau()
        aufbau.events.abend = [event("4", "Kino", von: "22:00", bis: "00:30")]
        let modell = aufbau.modell("21:30", mensa: .nanoteria)
        await modell.laden()
        let karte = try #require(modell.jetztKarte)
        #expect(karte.titel == "Kino")
        #expect(karte.kicker == "Heute · ab 22:00")
        #expect(!karte.mensaAendernSichtbar)
    }

    @Test func nightWithoutEventsShowsLunchTomorrow() async throws {
        let aufbau = Aufbau()
        let modell = aufbau.modell("21:30", mensa: .nanoteria)
        await modell.laden()
        let karte = try #require(modell.jetztKarte)
        #expect(karte.titel == "Cafeteria Nanoteria")
        #expect(karte.kicker == "Morgen · ab 08:00")
        #expect(karte.zeilen.map(\.name) == ["Reispfanne"])
        #expect(karte.mensaAendernSichtbar)
    }

    @Test func cancelledEventDoesNotRun() async throws {
        let aufbau = Aufbau()
        aufbau.events.abend = [CampusEvent(id: "5", titel: "Fällt aus", beginn: zeit("19:00"), ende: zeit("23:00"), status: .abgesagt)]
        let modell = aufbau.modell("21:30", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.jetztKarte?.titel == "Cafeteria Nanoteria")
    }
}

// MARK: - Abendessen adaptiv

@MainActor
struct HeuteAbendessenTests {
    @Test func dinnerInMensaEhrenbergDuringExamPeriod() async throws {
        let aufbau = Aufbau()
        aufbau.mensa.heute = beispielSpeiseplan(abendessenIn: ["Mensa Ehrenberg"])
        let modell = aufbau.modell("17:40", mensa: .mensaEhrenberg)
        await modell.laden()
        let karte = try #require(modell.jetztKarte)
        #expect(karte.kicker == "Jetzt geöffnet · Abendessen")
        #expect(karte.unterzeile == "Mensa")
        #expect(karte.ziel == .speiseplan(.mensaEhrenberg))
    }

    @Test func mensaAndCafeteriaEhrenbergCountAsOneHouse() async throws {
        let aufbau = Aufbau()
        aufbau.mensa.heute = beispielSpeiseplan(abendessenIn: ["Mensa Ehrenberg"])
        let modell = aufbau.modell("15:10", mensa: .cafeteriaEhrenberg)
        await modell.laden()
        #expect(modell.jetztKarte?.kicker == "Heute ab 16:30")
        #expect(modell.jetztKarte?.unterzeile == "Mensa")

        // Standardmensa und Abendessen in der Cafeteria: kein „geschlossen“-Tipp
        let standard = await geladen("15:10", mensa: .mensaEhrenberg)
        #expect(standard.jetztKarte?.kicker == "Heute ab 16:30")
        #expect(standard.jetztKarte?.unterzeile == "Cafeteria")
    }

    @Test func twoDinnerPlacesPreferTheChosenOne() async throws {
        let aufbau = Aufbau()
        aufbau.mensa.heute = beispielSpeiseplan(abendessenIn: ["Cafeteria Mensa Ehrenberg", "Cafeteria Röntgenbau"])
        let gewaehlt = aufbau.modell("17:40", mensa: .roentgenbau)
        await gewaehlt.laden()
        #expect(gewaehlt.jetztKarte?.kicker == "Jetzt geöffnet · Abendessen")
        #expect(gewaehlt.jetztKarte?.ziel == .speiseplan(.roentgenbau))

        let andere = aufbau.modell("17:40", mensa: .nanoteria)
        await andere.laden()
        #expect(andere.jetztKarte?.ziel == .speiseplan(.cafeteriaEhrenberg))
        #expect(andere.jetztKarte?.kicker == "Cafeteria Nanoteria hat geschlossen")
    }

    @Test func noDinnerToday_fallsBackToChosenMensaAndHidesDinnerTermin() async throws {
        let aufbau = Aufbau()
        aufbau.mensa.heute = beispielSpeiseplan(abendessenIn: [])
        let modell = aufbau.modell("15:10", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.jetztKarte?.titel == "Cafeteria Nanoteria")
        #expect(modell.alsNaechstes.contains { $0.id == "abendessen" } == false)
    }
}

// MARK: - Als Nächstes

@MainActor
struct HeuteAlsNaechstesTests {
    @Test func morningListsMensaTimesThenDinner() async {
        let modell = await geladen("08:15", mensa: .mensaEhrenberg)
        #expect(modell.alsNaechstes.map(\.titel) == ["Öffnet", "Schließt", "Abendessen"])
        #expect(modell.alsNaechstes.map(\.zeit) == ["11:00", "14:00", "16:30"])
    }

    @Test func morningDoesNotListPastOpening() async {
        let modell = await geladen("08:15", mensa: .nanoteria)
        #expect(modell.alsNaechstes.map(\.titel) == ["Schließt", "Abendessen", "Spieleabend"])
    }

    @Test func noonListsClosingDinnerAndEvent() async {
        let modell = await geladen("11:45", mensa: .mensaEhrenberg)
        let termine = modell.alsNaechstes
        #expect(termine.map(\.titel) == ["Schließt", "Abendessen", "Spieleabend"])
        #expect(termine[0].farbe == .brandOrange)
        #expect(termine[1].unterzeile == "Mensa Ehrenberg · Cafeteria")
        #expect(termine[2].farbe == .blue)
        #expect(termine[2].zeit == "19:00")
    }

    @Test func afternoonListsDinnerAndEvent() async {
        let modell = await geladen("15:10", mensa: .nanoteria)
        #expect(modell.alsNaechstes.map(\.titel) == ["Abendessen", "Spieleabend"])
    }

    @Test func eveningListsEventAndLunchTomorrow() async {
        let modell = await geladen("17:40", mensa: .nanoteria)
        let termine = modell.alsNaechstes
        #expect(termine.map(\.titel) == ["Spieleabend", "Mittag: Reispfanne"])
        #expect(termine[1].zeit == "Fr")
        #expect(termine[1].unterzeile == "Cafeteria Nanoteria · morgen ab 08:00")
    }

    @Test func nightListsLunchTomorrowAndNextEvent() async {
        let modell = await geladen("21:30", mensa: .mensaEhrenberg)
        let termine = modell.alsNaechstes
        #expect(termine.map(\.titel) == ["Mittag: Reispfanne", "Halloween-Party"])
        #expect(termine[1].zeit == "Fr")
        #expect(termine[1].unterzeile == "Studi-Club · 21:00")
    }

    @Test func neverMoreThanThree() async {
        for uhr in ["08:15", "11:45", "15:10", "17:40", "21:30"] {
            let modell = await geladen(uhr, mensa: .nanoteria)
            #expect(modell.alsNaechstes.count <= 3)
        }
    }

    @Test func containsNoLiveData() async {
        for uhr in ["08:15", "11:45", "15:10", "17:40", "21:30"] {
            let modell = await geladen(uhr, mensa: .cafeteriaEhrenberg)
            let text = modell.alsNaechstes.map { $0.titel + $0.unterzeile }.joined().lowercased()
            #expect(!text.contains("guthaben") && !text.contains("ausleih"))
        }
    }
}

// MARK: - Reihenfolge und Heute Abend

@MainActor
struct HeuteReihenfolgeTests {
    @Test(arguments: [("08:15", false), ("11:45", false), ("14:59", false), ("15:00", true), ("17:40", true), ("19:29", true), ("19:30", false), ("21:30", false)])
    func eventsFirstFrom1500ButNotAtNight(uhr: String, erwartet: Bool) async {
        let modell = await geladen(uhr, mensa: .cafeteriaEhrenberg)
        #expect(modell.eventsZuerst == erwartet)
    }

    @Test func tonightListsEventsAtMostThree() async {
        let aufbau = Aufbau()
        aufbau.events.abend = (1...5).map { event("e\($0)", "E\($0)", von: "20:00") }
        let modell = aufbau.modell("17:40", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.heuteAbend.count == 3)
    }

    @Test func atNightTheRunningEventIsNotRepeatedBelow() async {
        let aufbau = Aufbau()
        aufbau.events.abend = [spieleabend, event("6", "Kino", von: "22:00")]
        let modell = aufbau.modell("21:30", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.heuteAbend.map(\.titel) == ["Kino"])
    }

    @Test func atNightTheNextEventShownInTheCardIsNotRepeatedBelow() async {
        let aufbau = Aufbau()
        aufbau.events.abend = [event("7", "Kino", von: "22:00", bis: "00:30"), event("8", "Disco", von: "23:00")]
        let modell = aufbau.modell("21:30", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.jetztKarte?.titel == "Kino")
        #expect(modell.heuteAbend.map(\.titel) == ["Disco"])
    }

    @Test func runningEventBeforeNightStaysInTheList() async {
        let aufbau = Aufbau()
        aufbau.events.abend = [spieleabend]
        let modell = aufbau.modell("19:10", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.phase == .abend)
        #expect(modell.heuteAbend.map(\.titel) == ["Spieleabend"])
    }

    @Test func asksForTonightAndTomorrowWithoutCancelled() async {
        let aufbau = Aufbau()
        let modell = aufbau.modell("17:40", mensa: .nanoteria)
        await modell.laden()
        let filter = aufbau.events.filter
        #expect(filter.count == 2)
        #expect(filter.contains { $0.heuteAbend && $0.abgesagteAusblenden })
        #expect(filter.contains { !$0.heuteAbend && $0.tag == EventKalender.tag(zeit("12:00"), plus: 1) })
    }
}

// MARK: - Fehler einzelner Quellen

@MainActor
struct HeuteFehlerTests {
    @Test func failingMensaOnlyDropsTheMensaParts() async {
        let aufbau = Aufbau()
        aufbau.mensa.heute = nil
        aufbau.mensa.morgen = nil
        aufbau.events.abend = [spieleabend]
        let modell = aufbau.modell("11:45", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.jetztKarte == nil)
        // Die Öffnungszeiten laden noch, nur Speiseplan und Abendessen fehlen.
        #expect(modell.alsNaechstes.map(\.titel) == ["Schließt", "Spieleabend"])
        #expect(modell.heuteAbend.map(\.titel) == ["Spieleabend"])
    }

    @Test func failingOpeningHoursDropsTheMensaCard() async {
        let aufbau = Aufbau()
        aufbau.mensa.canteens = nil
        let modell = aufbau.modell("11:45", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.jetztKarte == nil)
        #expect(modell.alsNaechstes.map(\.titel) == ["Abendessen"])
    }

    @Test func failingEventsKeepsMensaAndHidesEventSections() async throws {
        let aufbau = Aufbau()
        aufbau.events.abend = nil
        aufbau.events.morgen = nil
        let modell = aufbau.modell("11:45", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.jetztKarte?.zeilen.count == 3)
        #expect(modell.heuteAbend.isEmpty)
        #expect(modell.alsNaechstes.map(\.titel) == ["Schließt", "Abendessen"])
    }

    @Test func nightWithFailingEventsFallsBackToLunchTomorrow() async throws {
        let aufbau = Aufbau()
        aufbau.events.abend = nil
        aufbau.events.morgen = nil
        let modell = aufbau.modell("21:30", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.jetztKarte?.unterzeile == "Mittagsangebot morgen")
        #expect(modell.alsNaechstes.map(\.titel) == ["Mittag: Reispfanne"])
    }

    @Test func failingTomorrowOnlyDropsTomorrowParts() async {
        let aufbau = Aufbau()
        aufbau.mensa.morgen = nil
        aufbau.events.abend = [spieleabend]
        let modell = aufbau.modell("17:40", mensa: .nanoteria)
        await modell.laden()
        #expect(modell.alsNaechstes.map(\.titel) == ["Spieleabend"])
        #expect(modell.jetztKarte != nil)
    }

    @Test func everythingFailingStillFinishesWithEmptyPage() async {
        let aufbau = Aufbau()
        aufbau.mensa.heute = nil
        aufbau.mensa.morgen = nil
        aufbau.mensa.canteens = nil
        aufbau.events.abend = nil
        aufbau.events.morgen = nil
        let modell = aufbau.modell("21:30", mensa: .nanoteria, hinweise: nil)
        await modell.laden()
        #expect(modell.jetztKarte == nil)
        #expect(modell.alsNaechstes.isEmpty)
        #expect(modell.heuteAbend.isEmpty)
        #expect(modell.hinweise.isEmpty)
    }
}

// MARK: - Hinweise, Mensa-Wahl, Uhr

@MainActor
struct HeuteZustandTests {
    private let hinweise = [
        Hinweis(id: "a", kategorie: "Studium", titel: "A", text: "", prioritaet: 1),
        Hinweis(id: "b", kategorie: "Studium", titel: "B", text: "", prioritaet: 3),
        Hinweis(id: "c", kategorie: "Studium", titel: "C", text: "", prioritaet: 2),
        Hinweis(id: "alt", kategorie: "Studium", titel: "Alt", text: "", bis: zeit("08:00"), prioritaet: 9),
        Hinweis(id: "spaeter", kategorie: "Studium", titel: "Später", text: "", von: zeit("12:00"), prioritaet: 9)
    ]

    @Test func showsAtMostTwoByPriorityAndRespectsPeriod() async {
        let modell = Aufbau().modell("08:15", mensa: .nanoteria, hinweise: hinweise)
        await modell.laden()
        #expect(modell.hinweise.map(\.id) == ["b", "c"])
    }

    @Test func dismissedHinweisStaysGoneAfterRestart() async {
        let aufbau = Aufbau()
        let modell = aufbau.modell("08:15", mensa: .nanoteria, hinweise: hinweise)
        await modell.laden()
        modell.blendeHinweisAus("b")
        #expect(modell.hinweise.map(\.id) == ["c", "a"])

        let neu = aufbau.modell("08:15", mensa: .nanoteria, hinweise: hinweise)
        await neu.laden()
        #expect(neu.hinweise.map(\.id) == ["c", "a"])
    }

    @Test func noHinweiseSourceMeansNoSection() async {
        let modell = await geladen("08:15", mensa: .nanoteria)
        #expect(modell.hinweise.isEmpty)
    }

    @Test func chosenMensaIsRemembered() async {
        let aufbau = Aufbau()
        let modell = aufbau.modell("11:45", mensa: .nanoteria)
        modell.waehleMensa(.roentgenbau)
        #expect(HeuteMensaSpeicher(defaults: aufbau.defaults).venue == .roentgenbau)
        await modell.laden()
        #expect(modell.jetztKarte?.titel == "Cafeteria Röntgenbau")
    }

    @Test func startsWithMensaEhrenberg() {
        let defaults = UserDefaults(suiteName: "HeuteModelTests-\(UUID().uuidString)") ?? .standard
        #expect(HeuteMensaSpeicher(defaults: defaults).venue == .mensaEhrenberg)
    }

    @Test func injectedClockDrivesThePhaseAndReload() async {
        @MainActor final class Uhr { var jetzt = zeit("08:15") }
        let uhr = Uhr()
        let aufbau = Aufbau()
        let modell = HeuteModel(
            now: { uhr.jetzt }, mensaQuelle: aufbau.mensa, eventsQuelle: aufbau.events,
            mensaSpeicher: HeuteMensaSpeicher(defaults: aufbau.defaults),
            ausblendSpeicher: HinweiseAusblendSpeicher(defaults: aufbau.defaults), mensaFilter: { MensaFilter() }, zeitlimit: .seconds(2), clock: ManualClock()
        )
        await modell.laden()
        #expect(modell.phase == .morgen)
        #expect(modell.begruessung.text == "Guten Morgen")

        uhr.jetzt = zeit("08:20")
        await modell.aktualisieren()
        #expect(aufbau.mensa.tage.count == 2, "Frische Daten: kein neuer Abruf")

        uhr.jetzt = zeit("11:45")
        await modell.aktualisieren()
        #expect(modell.phase == .mittag)
        #expect(modell.begruessung.text == "Mahlzeit!")
        #expect(aufbau.mensa.tage.count == 4, "Daten älter als 10 Minuten: neu laden")

        uhr.jetzt = zeit("08:00", tag: 1)
        await modell.aktualisieren()
        #expect(aufbau.mensa.tage.count == 6, "Neuer Tag: Speiseplan wird neu geladen")
    }

    @Test func reloadsOnPhaseChangeEvenWithinTenMinutes() async {
        @MainActor final class Uhr { var jetzt = zeit("10:29") }
        let uhr = Uhr()
        let aufbau = Aufbau()
        let modell = HeuteModel(
            now: { uhr.jetzt }, mensaQuelle: aufbau.mensa, eventsQuelle: aufbau.events,
            mensaSpeicher: HeuteMensaSpeicher(defaults: aufbau.defaults),
            ausblendSpeicher: HinweiseAusblendSpeicher(defaults: aufbau.defaults), mensaFilter: { MensaFilter() }, zeitlimit: .seconds(2), clock: ManualClock()
        )
        await modell.laden()
        #expect(aufbau.mensa.tage.count == 2)

        uhr.jetzt = zeit("10:31") // zwei Minuten später, aber neue Phase (mittag)
        await modell.aktualisieren()
        #expect(modell.phase == .mittag)
        #expect(aufbau.mensa.tage.count == 4)
    }

    @Test func reloadsAfterTenMinutesButNotBefore() async {
        @MainActor final class Uhr { var jetzt = zeit("12:00") }
        let uhr = Uhr()
        let aufbau = Aufbau()
        let modell = HeuteModel(
            now: { uhr.jetzt }, mensaQuelle: aufbau.mensa, eventsQuelle: aufbau.events,
            mensaSpeicher: HeuteMensaSpeicher(defaults: aufbau.defaults),
            ausblendSpeicher: HinweiseAusblendSpeicher(defaults: aufbau.defaults), mensaFilter: { MensaFilter() }, zeitlimit: .seconds(2), clock: ManualClock()
        )
        await modell.laden()
        uhr.jetzt = zeit("12:09")
        await modell.szeneWurdeAktiv()
        #expect(aufbau.mensa.tage.count == 2, "9 Minuten, gleiche Phase: kein neuer Abruf")
        uhr.jetzt = zeit("12:11")
        await modell.szeneWurdeAktiv()
        #expect(aufbau.mensa.tage.count == 4, "Älter als 10 Minuten: neu laden")
    }

    @Test func nextMinuteIsTheStartOfTheNextFullMinute() {
        #expect(HeuteModel.naechsteMinute(nach: zeit("11:45")) == zeit("11:46"))
        #expect(HeuteModel.naechsteMinute(nach: zeit("11:45").addingTimeInterval(37)) == zeit("11:46"))
        #expect(HeuteModel.naechsteMinute(nach: zeit("23:59").addingTimeInterval(59.9)) == zeit("00:00", tag: 1))
    }

    @Test func observingTicksEveryMinuteAndUpdatesTheClock() async throws {
        @MainActor final class Uhr { var jetzt = Date.now }
        let uhr = Uhr()
        let aufbau = Aufbau()
        let clock = ManualClock()
        let modell = HeuteModel(
            now: { uhr.jetzt }, mensaQuelle: aufbau.mensa, eventsQuelle: aufbau.events,
            mensaSpeicher: HeuteMensaSpeicher(defaults: aufbau.defaults),
            ausblendSpeicher: HinweiseAusblendSpeicher(defaults: aufbau.defaults), mensaFilter: { MensaFilter() }, zeitlimit: .seconds(2),
            clock: clock
        )
        // Knapp vor der vollen Minute: der Wecker klingelt nach 0,6 s (Uhr des Tests, nicht echte Zeit).
        let minute = HeuteModel.naechsteMinute(nach: .now)
        uhr.jetzt = minute.addingTimeInterval(-0.6)
        let aufgabe = Task { await modell.beobachten() }
        await clock.warteBisTimer()
        let vorher = modell.jetzt
        uhr.jetzt = minute.addingTimeInterval(1) // die Zeit ist weitergelaufen
        await clock.advance(by: .seconds(1))
        await warteBis { modell.jetzt > vorher }
        aufgabe.cancel()
        #expect(modell.jetzt > vorher, "Die Uhr im Kopf muss ohne Zutun weiterlaufen")
    }

    @Test func nextChangeContainsMensaTimesAndEvents() async {
        let modell = await geladen("11:45", mensa: .roentgenbau)
        #expect(modell.naechsterWechsel == zeit("14:00"))
        let nacht = await geladen("19:40", mensa: .roentgenbau)
        #expect(nacht.naechsterWechsel == zeit("23:00"))
    }
}
