import Foundation
import Testing
@testable import Campus_Ilmenau

@MainActor
struct EventsTests {
    // MARK: - Hilfen

    /// Zeitpunkt in Berlin, z. B. `berlin(2026, 11, 5, 12)`.
    private func berlin(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        EventKalender.kalender.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Donnerstag, 5. November 2026, 12:00 in Berlin.
    private var jetzt: Date { berlin(2026, 11, 5, 12) }

    private func dekodiere(_ json: String) throws -> CampusEvent {
        try LibraryCatalogService.decoder.decode(CampusEvent.self, from: Data(json.utf8))
    }

    private func event(
        _ beginn: Date, bis ende: Date? = nil, ganztaegig: Bool = false,
        status: EventStatus = .findetStatt, ort: String? = nil, veranstalter: String? = nil, kategorie: String? = nil
    ) -> CampusEvent {
        CampusEvent(
            id: "evt_1", titel: "Titel", beginn: beginn, ende: ende, ganztaegig: ganztaegig, status: status,
            ort: ort, veranstalter: veranstalter, kategorie: kategorie
        )
    }

    private func items(_ anfrage: EventFilter.Anfrage) -> [String: String] {
        Dictionary(anfrage.items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - JSON

    /// Wie die Dev-API ein Event schickt (gekürzt).
    private let vollstaendig = """
    {"id":"evt_dec1b86b","object":"event","title":"ILSC e.V. | Whisky-Stube","category":"VERANSTALTUNG",
     "startAt":"2026-10-26T18:00:00.000Z","endAt":"2026-10-26T21:00:00.000Z","location":"bi-Club",
     "locationAddress":"98693 Ilmenau","sourceUrl":"https://example.org/info","ticketUrl":"https://example.org/tickets",
     "imageUrl":"https://example.org/plakat.jpg","description":"Ganz entspannt.\\n\\nMit Bier.","status":"scheduled",
     "allDay":false,"startDate":null,"endDate":null,"source":"ilmenau-live",
     "organizer":{"id":"ilsc","name":"ILSC"},"createdAt":"2026-10-27T08:47:34.662Z","updatedAt":"2026-10-27T08:47:34.662Z"}
    """

    @Test func decodesAFullEvent() throws {
        let event = try dekodiere(vollstaendig)
        #expect(event.id == "evt_dec1b86b")
        #expect(event.titel == "ILSC e.V. | Whisky-Stube")
        #expect(event.beginn == LibraryDateParsing.date(from: "2026-10-26T18:00:00.000Z"))
        #expect(event.ende == LibraryDateParsing.date(from: "2026-10-26T21:00:00.000Z"))
        #expect(!event.ganztaegig)
        #expect(event.status == .findetStatt)
        #expect(event.ort == "bi-Club")
        #expect(event.adresse == "98693 Ilmenau")
        #expect(event.veranstalter == "ILSC")
        #expect(event.veranstalterID == "ilsc")
        #expect(event.beschreibung == "Ganz entspannt.\n\nMit Bier.")
        #expect(event.bildURL?.absoluteString == "https://example.org/plakat.jpg")
        #expect(event.infoURL?.absoluteString == "https://example.org/info")
        #expect(event.ticketURL?.absoluteString == "https://example.org/tickets")
        #expect(event.kategorie == "Veranstaltung")
    }

    @Test func decodesAMinimalEvent() throws {
        let event = try dekodiere("{\"id\":\"evt_1\",\"title\":\"Nur Titel\",\"startAt\":\"2026-11-05T18:00:00.000Z\"}")
        #expect(event.titel == "Nur Titel")
        #expect(event.status == .findetStatt)          // Status fehlt: findet statt
        #expect(event.ende == nil)
        #expect(!event.ganztaegig)
        #expect(event.ort == nil && event.adresse == nil && event.veranstalter == nil)
        #expect(event.beschreibung == nil)
        #expect(event.bildURL == nil && event.infoURL == nil && event.ticketURL == nil)
        #expect(event.kategorie == nil)
    }

    @Test func nullEmptyAndBrokenFieldsAreTolerated() throws {
        let json = """
        {"id":"evt_1","title":"T","startAt":"2026-11-05T18:00:00Z","endAt":null,"location":"  ","locationAddress":null,
         "description":"","organizer":null,"sourceUrl":"","ticketUrl":"kein url mit leerzeichen","imageUrl":null,"allDay":null,"category":null}
        """
        let event = try dekodiere(json)
        #expect(event.ende == nil)
        #expect(event.ort == nil)
        #expect(event.beschreibung == nil)
        #expect(event.veranstalter == nil)
        #expect(event.infoURL == nil)
        #expect(event.ticketURL == nil)
        #expect(!event.ganztaegig)
        #expect(event.beginn == LibraryDateParsing.date(from: "2026-11-05T18:00:00Z"))   // auch ohne Millisekunden
    }

    @Test func statusMapsAndUnknownValuesFindPlace() throws {
        func status(_ wert: String?) throws -> EventStatus {
            let teil = wert.map { ",\"status\":\"\($0)\"" } ?? ""
            return try dekodiere("{\"id\":\"e\",\"title\":\"T\",\"startAt\":\"2026-11-05T18:00:00Z\"\(teil)}").status
        }
        #expect(try status("scheduled") == .findetStatt)
        #expect(try status("tentative") == .unbestaetigt)
        #expect(try status("cancelled") == .abgesagt)
        #expect(try status("CANCELED") == .abgesagt)
        #expect(try status("postponed") == .findetStatt)     // unbekannt
        #expect(try status("") == .findetStatt)
        #expect(try status(nil) == .findetStatt)
    }

    @Test func categoriesAreNamedForDisplay() throws {
        let frist = try dekodiere("{\"id\":\"e\",\"title\":\"Anmeldeschluss\",\"startAt\":\"2026-11-05T18:00:00Z\",\"category\":\"FRIST\"}")
        #expect(frist.kategorie == "Frist")
        #expect(frist.istFrist)
        #expect(try dekodiere(vollstaendig).istFrist == false)
    }

    @Test func missingTitleOrStartIsAnError() {
        #expect(throws: (any Error).self) { try dekodiere("{\"id\":\"e\",\"startAt\":\"2026-11-05T18:00:00Z\"}") }
        #expect(throws: (any Error).self) { try dekodiere("{\"id\":\"e\",\"title\":\"T\"}") }
        #expect(throws: (any Error).self) { try dekodiere("{\"id\":\"e\",\"title\":\"T\",\"startAt\":\"morgen\"}") }
    }

    @Test func eventSurvivesAnEncodeDecodeRoundTrip() throws {
        let original = try dekodiere(vollstaendig)
        let data = try JSONEncoder().encode(original)
        let kopie = try JSONDecoder().decode(CampusEvent.self, from: data)
        #expect(kopie == original)
    }

    @Test func organizersDecodeWithCount() throws {
        let json = "{\"id\":\"baracke5\",\"object\":\"organizer\",\"name\":\"Baracke5\",\"upcomingEventCount\":7}"
        let veranstalter = try LibraryCatalogService.decoder.decode(Veranstalter.self, from: Data(json.utf8))
        #expect(veranstalter == Veranstalter(id: "baracke5", name: "Baracke5", anzahlKommende: 7))
        let nurName = try LibraryCatalogService.decoder.decode(Veranstalter.self, from: Data("{\"name\":\"Kleinod\"}".utf8))
        #expect(nurName.anzahlKommende == 0)
        #expect(nurName.id == "Kleinod")
    }

    // MARK: - Abgeleitete Werte

    @Test func singleDayEventIsNotMultiDay() {
        let abend = event(berlin(2026, 11, 5, 19), bis: berlin(2026, 11, 5, 23))
        #expect(!abend.istMehrtaegig)
        #expect(abend.laeuftAm(berlin(2026, 11, 5, 8)))
        #expect(!abend.laeuftAm(berlin(2026, 11, 6)))
        #expect(!abend.laeuftAm(berlin(2026, 11, 4)))
    }

    @Test func nightEventPastMidnightStaysOnItsDay() {
        let nacht = event(berlin(2026, 10, 30, 21), bis: berlin(2026, 10, 31, 3))
        #expect(!nacht.istMehrtaegig)
        #expect(nacht.letzterTag == berlin(2026, 10, 30))
        #expect(!nacht.laeuftAm(berlin(2026, 10, 31)))

        let bisMitternacht = event(berlin(2026, 10, 30, 21), bis: berlin(2026, 10, 31, 0))
        #expect(!bisMitternacht.istMehrtaegig)

        // Bis 07:00 am Folgetag ist keine Nachtveranstaltung mehr.
        let langeNacht = event(berlin(2026, 10, 30, 21), bis: berlin(2026, 10, 31, 7))
        #expect(langeNacht.istMehrtaegig)
    }

    @Test func allDayMultiDayEventUsesTheExclusiveEnd() throws {
        // Wie die API: 2.–8. Nov., Ende exklusiv Mitternacht Berlin.
        let cgw = event(
            LibraryDateParsing.date(from: "2026-11-01T23:00:00.000Z")!,
            bis: LibraryDateParsing.date(from: "2026-11-08T23:00:00.000Z")!,
            ganztaegig: true
        )
        #expect(cgw.ersterTag == berlin(2026, 11, 2))
        #expect(cgw.letzterTag == berlin(2026, 11, 8))
        #expect(cgw.istMehrtaegig)
        #expect(cgw.laeuftAm(berlin(2026, 11, 2, 15)))
        #expect(cgw.laeuftAm(berlin(2026, 11, 8, 23, 59)))
        #expect(!cgw.laeuftAm(berlin(2026, 11, 1, 12)))
        #expect(!cgw.laeuftAm(berlin(2026, 11, 9)))
    }

    @Test func allDaySingleDayIsNotMultiDay() {
        let tag = event(berlin(2026, 11, 5), bis: berlin(2026, 11, 6), ganztaegig: true)
        #expect(!tag.istMehrtaegig)
        #expect(tag.letzterTag == berlin(2026, 11, 5))
    }

    @Test func eventWithoutEndIsASingleDay() {
        let offen = event(berlin(2026, 11, 5, 20))
        #expect(!offen.istMehrtaegig)
        #expect(offen.laeuftAm(berlin(2026, 11, 5)))
    }

    @Test func dayBoundariesFollowBerlinNotUTC() {
        // 23:30 UTC ist in Berlin schon der nächste Tag.
        let spaet = event(LibraryDateParsing.date(from: "2026-11-05T23:30:00.000Z")!)
        #expect(spaet.ersterTag == berlin(2026, 11, 6))
    }

    @Test func organizerIsHiddenWhenItEqualsThePlace() {
        #expect(event(jetzt, ort: "Baracke5", veranstalter: "Baracke5").veranstalterAnzeigen == nil)
        #expect(event(jetzt, ort: " baracke5 ", veranstalter: "Baracke5").veranstalterAnzeigen == nil)
        #expect(event(jetzt, ort: "bi-Club", veranstalter: "ILSC").veranstalterAnzeigen == "ILSC")
        #expect(event(jetzt, ort: nil, veranstalter: "ILSC").veranstalterAnzeigen == "ILSC")
        #expect(event(jetzt, ort: "bi-Club", veranstalter: nil).veranstalterAnzeigen == nil)
        #expect(event(jetzt, veranstalter: "  ").veranstalterAnzeigen == nil)
    }

    @Test func deadlineIsRecognizedByCategory() {
        #expect(event(jetzt, kategorie: "Frist").istFrist)
        #expect(event(jetzt, kategorie: "frist").istFrist)
        #expect(!event(jetzt, kategorie: "Veranstaltung").istFrist)
        #expect(!event(jetzt).istFrist)
    }

    // MARK: - Filter

    @Test func withoutTimeOrDayTheListStartsToday() {
        let anfrage = EventFilter.abHeute.anfrage(jetzt: jetzt)
        // Berliner Mitternacht ist am Vortag um 23:00 UTC; deshalb zählt der Vortag als `from`.
        #expect(items(anfrage)["from"] == "2026-11-04")
        #expect(items(anfrage)["to"] == nil)
        #expect(items(anfrage)["date"] == nil)
        #expect(anfrage.vonGrenze == berlin(2026, 11, 5))
        #expect(anfrage.laufendeAm == berlin(2026, 11, 5))
    }

    @Test func rangeSendsFromAndToAndTrimsBothEnds() {
        let filter = EventFilter(zeitraum: .init(von: berlin(2026, 11, 8, 15), bis: berlin(2026, 11, 10, 9)))
        let anfrage = filter.anfrage(jetzt: jetzt)
        #expect(items(anfrage)["from"] == "2026-11-07")
        #expect(items(anfrage)["to"] == "2026-11-10")        // exklusiv: schließt den Berliner 9. ein
        #expect(anfrage.vonGrenze == berlin(2026, 11, 8))
        #expect(anfrage.bisGrenze == berlin(2026, 11, 10))
    }

    @Test func tonightAndRangeDoNotMix() {
        let filter = EventFilter(zeitraum: .init(von: berlin(2026, 11, 8)), heuteAbend: true)
        let anfrage = filter.anfrage(jetzt: jetzt)
        #expect(items(anfrage)["evening"] == "true")
        #expect(items(anfrage)["date"] == "2026-11-05")      // kein Tag gesetzt: heute
        #expect(items(anfrage)["from"] == nil)
        #expect(items(anfrage)["to"] == nil)
        #expect(anfrage.laufendeAm == nil)
        #expect(filter.zeitfilter(jetzt: jetzt) == .abend(berlin(2026, 11, 5)))
    }

    @Test func tonightUsesTheChosenDay() {
        let filter = EventFilter(tag: berlin(2026, 11, 7, 14), heuteAbend: true)
        let anfrage = filter.anfrage(jetzt: jetzt)
        #expect(items(anfrage)["date"] == "2026-11-07")
        #expect(items(anfrage)["evening"] == "true")
    }

    @Test func aDayWinsOverARange() {
        let filter = EventFilter(zeitraum: .init(von: berlin(2026, 11, 1), bis: berlin(2026, 11, 30)), tag: berlin(2026, 11, 6))
        let anfrage = filter.anfrage(jetzt: jetzt)
        #expect(items(anfrage)["date"] == "2026-11-06")
        #expect(items(anfrage)["evening"] == nil)
        #expect(items(anfrage)["from"] == nil)
        #expect(anfrage.vonGrenze == nil)
    }

    @Test func organizerCategoryAndCancelledAreSent() {
        // Die API filtert nach der ID des Veranstalters, nicht nach dem Namen („Café Bohne“ gibt Fehler 400)
        let filter = EventFilter(veranstalter: "cafe-bohne", abgesagteAusblenden: true, kategorie: "Frist")
        let anfrage = filter.anfrage(jetzt: jetzt)
        #expect(items(anfrage)["organizer"] == "cafe-bohne")
        #expect(items(anfrage)["category"] == "Frist")
        #expect(items(anfrage)["include_cancelled"] == "false")

        let ohne = EventFilter.abHeute.anfrage(jetzt: jetzt)
        #expect(items(ohne)["include_cancelled"] == "true")   // immer ausdrücklich gesetzt
        #expect(items(ohne)["organizer"] == nil)
        #expect(items(ohne)["category"] == nil)
        #expect(items(EventFilter(veranstalter: "  ").anfrage(jetzt: jetzt))["organizer"] == nil)
    }

    // MARK: - Service

    private func liste(_ events: [String], hasMore: Bool = false, total: Int? = nil, page: Int = 1) -> String {
        "{\"object\":\"list\",\"has_more\":\(hasMore),\"total_count\":\(total ?? events.count),\"page\":\(page),\"per_page\":100,\"data\":[\(events.joined(separator: ","))]}"
    }

    private func json(
        _ id: String, _ start: String, end: String? = nil, allDay: Bool = false, title: String = "Titel", extra: String = ""
    ) -> String {
        let ende = end.map { ",\"endAt\":\"\($0)\"" } ?? ""
        return "{\"id\":\"\(id)\",\"title\":\"\(title)\",\"startAt\":\"\(start)\"\(ende),\"allDay\":\(allDay)\(extra)}"
    }

    @Test func listSendsTheDocumentedParameters() async throws {
        let h = Harness()
        let service = h.eventsService(json: liste([]))
        _ = try await service.liste(filter: EventFilter(veranstalter: "baracke5"), seite: 3, jetzt: jetzt)
        let hauptanfrage = try #require(h.requestURLs.first)
        #expect(hauptanfrage.path == "/develop/v1/events")
        #expect(h.queryValue("page") == "3" || hauptanfrage.query?.contains("page=3") == true)
        let query = hauptanfrage.query ?? ""
        #expect(query.contains("per_page=100"))
        #expect(query.contains("from=2026-11-04"))
        #expect(query.contains("organizer=baracke5"))
        #expect(query.contains("include_cancelled=true"))
        #expect(h.requestURLs.count == 1)   // Seite 3 holt keine laufenden dazu
    }

    @Test func listTrimsEventsBeforeTodayAndKeepsPagingInfo() async throws {
        let h = Harness()
        let body = liste([
            json("evt_gestern", "2026-11-04T20:00:00.000Z"),     // 21:00 gestern Berlin: durch das breitere Fenster dabei
            json("evt_heute", "2026-11-05T18:00:00.000Z"),
            json("evt_morgen", "2026-11-06T19:00:00.000Z")
        ], hasMore: true, total: 250)
        let seite = try await h.eventsService(json: body).liste(filter: .abHeute, seite: 2, jetzt: jetzt)
        #expect(seite.events.map(\.id) == ["evt_heute", "evt_morgen"])
        #expect(seite.hatWeitere)
        #expect(seite.gesamt == 250)
    }

    @Test func listTrimsTheRangeEndInBerlinTime() async throws {
        let h = Harness()
        let body = liste([
            json("evt_drin", "2026-11-09T22:30:00.000Z"),       // 9.11. 23:30 Berlin: noch drin
            json("evt_raus", "2026-11-09T23:30:00.000Z")        // 10.11. 00:30 Berlin: schon draußen
        ])
        let filter = EventFilter(zeitraum: .init(von: berlin(2026, 11, 8), bis: berlin(2026, 11, 10)))
        let seite = try await h.eventsService(json: body).liste(filter: filter, seite: 1, jetzt: jetzt)
        #expect(seite.events.map(\.id) == ["evt_drin"])
    }

    @Test func firstPageAddsRunningMultiDayEvents() async throws {
        let h = Harness()
        let service = h.eventsService(json: liste([json("evt_heute", "2026-11-05T18:00:00.000Z")]))
        // Die zweite Abfrage (`date=`) liefert die laufende ganztägige Veranstaltung und eine, die erst heute beginnt.
        h.route("/develop/v1/events", queryContains: "date=2026-11-05", json: liste([
            json("evt_cgw", "2026-11-01T23:00:00.000Z", end: "2026-11-08T23:00:00.000Z", allDay: true, title: "CGW"),
            json("evt_heute", "2026-11-05T18:00:00.000Z")
        ]))
        let seite = try await service.liste(filter: .abHeute, seite: 1, jetzt: jetzt)
        #expect(seite.events.map(\.id) == ["evt_cgw", "evt_heute"])      // laufende zuerst, nach Beginn sortiert
        #expect(h.requestURLs.count == 2)
    }

    @Test func runningLookupFailureDoesNotBreakTheList() async throws {
        let h = Harness()
        let service = h.eventsService(json: liste([json("evt_heute", "2026-11-05T18:00:00.000Z")]))
        h.route("/develop/v1/events", queryContains: "date=2026-11-05", status: 503, json: "{}")
        let seite = try await service.liste(filter: .abHeute, seite: 1, jetzt: jetzt)
        #expect(seite.events.map(\.id) == ["evt_heute"])
    }

    @Test func dayFilterAsksOnlyOnce() async throws {
        let h = Harness()
        let service = h.eventsService(json: liste([json("evt_1", "2026-11-06T19:00:00.000Z")]))
        _ = try await service.liste(filter: EventFilter(tag: berlin(2026, 11, 6)), jetzt: jetzt)
        #expect(h.requestURLs.count == 1)
        #expect(h.requestURLs.first?.query?.contains("date=2026-11-06") == true)
    }

    @Test func detailLoadsOneEventAndMissingOneIsNotFound() async throws {
        let h = Harness()
        let service = h.eventsService(json: vollstaendig)
        let event = try await service.detail(id: "evt_dec1b86b")
        #expect(event.titel == "ILSC e.V. | Whisky-Stube")
        #expect(h.requestURLs.last?.path == "/develop/v1/events/evt_dec1b86b")

        let fehlt = h.eventsService(status: 404, json: Sample.error(code: "resource_missing", message: "No campus event", param: "id"))
        do {
            _ = try await fehlt.detail(id: "evt_weg")
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let error as EventsAPIError {
            guard case .notFound = error else { Issue.record("Falscher Fehler: \(error)"); return }
            #expect(error.errorDescription == "Veranstaltung nicht gefunden")
        }
    }

    @Test func organizersAreFilteredAndSortedAlphabetically() async throws {
        let h = Harness()
        let body = """
        {"object":"list","has_more":false,"total_count":5,"data":[
         {"id":"jazzclub","name":"Jazzclub","upcomingEventCount":9},
         {"id":"cafe-bohne","name":"Café Bohne","upcomingEventCount":10},
         {"id":"alt","name":"Ohne Kommende","upcomingEventCount":0},
         {"id":"baracke5","name":"Baracke5","upcomingEventCount":7},
         {"id":"ilsc","name":"ilsc","upcomingEventCount":32}]}
        """
        let veranstalter = try await h.eventsService(json: body).veranstalter()
        #expect(veranstalter.map(\.name) == ["Baracke5", "Café Bohne", "ilsc", "Jazzclub"])
        #expect(veranstalter.first?.anzahlKommende == 7)
        #expect(h.requestURLs.last?.path == "/develop/v1/events/organizers")
    }

    @Test func serverErrorsKeepTheirCodeAndNetworkErrorsAreWrapped() async {
        let h = Harness()
        let service = h.eventsService(status: 400, json: Sample.error(code: "invalid_parameter_format", message: "Invalid ISO date", param: "from"))
        do {
            _ = try await service.liste(filter: .abHeute, jetzt: jetzt)
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let EventsAPIError.apiError(status, code, _, param) {
            #expect(status == 400)
            #expect(code == "invalid_parameter_format")
            #expect(param == "from")
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }

        let offline = EventsService(baseURL: "https://offline-\(UUID().uuidString.lowercased()).test/develop", session: {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [LibraryStubProtocol.self]
            return URLSession(configuration: configuration)
        }())
        do {
            _ = try await offline.veranstalter()
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let error as EventsAPIError {
            guard case .networkError = error else { Issue.record("Falscher Fehler: \(error)"); return }
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
    }

    @Test func organizerNamesWithSpacesAndUmlautsAreEncoded() async throws {
        let h = Harness()
        let service = h.eventsService(json: liste([]))
        _ = try await service.liste(filter: EventFilter(veranstalter: "Kulturelle Koordinierung (KuKo)"), jetzt: jetzt)
        let raw = try #require(h.requestURLs.first?.absoluteString)
        #expect(raw.contains("organizer=Kulturelle%20Koordinierung%20%28KuKo%29"))
    }

    // MARK: - Merk-Store

    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("EventsMerk-\(UUID().uuidString).json")
    }

    @Test func togglingRemembersAndForgets() {
        let store = EventsMerkStore(fileURL: nil)
        #expect(!store.istGemerkt("evt_1"))
        #expect(store.umschalten("evt_1"))
        #expect(store.istGemerkt("evt_1"))
        #expect(store.ids == ["evt_1"])
        #expect(!store.umschalten("evt_1"))
        #expect(store.ids.isEmpty)
    }

    @Test func rememberedEventsSurviveANewStoreInstance() {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = EventsMerkStore(fileURL: file)
        store.umschalten("evt_1")
        store.umschalten("evt_2")
        store.umschalten("evt_1")
        #expect(EventsMerkStore(fileURL: file).ids == ["evt_2"])
    }

    @Test func brokenOrMissingFileGivesAnEmptyStore() throws {
        #expect(EventsMerkStore(fileURL: tempFile()).ids.isEmpty)
        let kaputt = tempFile()
        defer { try? FileManager.default.removeItem(at: kaputt) }
        try Data("kein JSON".utf8).write(to: kaputt)
        let store = EventsMerkStore(fileURL: kaputt)
        #expect(store.ids.isEmpty)
        store.umschalten("evt_1")
        #expect(EventsMerkStore(fileURL: kaputt).ids == ["evt_1"])
    }

    // MARK: - Zeittexte

    private var formatter: EventZeitFormatter { EventZeitFormatter(jetzt: jetzt) }

    @Test func listTimeLineForTimedEvents() {
        #expect(formatter.zeitzeile(event(berlin(2026, 11, 5, 19), bis: berlin(2026, 11, 5, 23))) == "19:00–23:00 Uhr")
        #expect(formatter.zeitzeile(event(berlin(2026, 11, 5, 20))) == "Ab 20:00 Uhr")
        // Ende nicht nach dem Beginn: wie ohne Ende.
        #expect(formatter.zeitzeile(event(berlin(2026, 11, 5, 20), bis: berlin(2026, 11, 5, 20))) == "Ab 20:00 Uhr")
        #expect(formatter.zeitzeile(event(berlin(2026, 11, 5, 8, 5), bis: berlin(2026, 11, 5, 9))) == "08:05–09:00 Uhr")
    }

    @Test func listTimeLineAroundMidnight() {
        #expect(formatter.zeitzeile(event(berlin(2026, 11, 5, 21), bis: berlin(2026, 11, 6, 0))) == "21:00–00:00 Uhr")
        #expect(formatter.zeitzeile(event(berlin(2026, 11, 5, 21), bis: berlin(2026, 11, 6, 3))) == "21:00–03:00 Uhr")
        #expect(formatter.zeitzeile(event(berlin(2026, 11, 5, 0), bis: berlin(2026, 11, 5, 2))) == "00:00–02:00 Uhr")
        #expect(formatter.zeitzeile(event(berlin(2026, 11, 5, 0, 30))) == "Ab 00:30 Uhr")
    }

    @Test func listTimeLineUsesBerlinNotUTC() {
        let utc = LibraryDateParsing.date(from: "2026-11-05T18:00:00.000Z")!       // 19:00 Berlin (Winterzeit)
        #expect(formatter.zeitzeile(event(utc)) == "Ab 19:00 Uhr")
        let sommer = LibraryDateParsing.date(from: "2026-07-05T18:00:00.000Z")!    // 20:00 Berlin (Sommerzeit)
        #expect(formatter.zeitzeile(event(sommer)) == "Ab 20:00 Uhr")
    }

    @Test func listTimeLineForAllDayAndMultiDay() {
        #expect(formatter.zeitzeile(event(berlin(2026, 11, 5), bis: berlin(2026, 11, 6), ganztaegig: true)) == "Ganztägig")

        let cgw = event(berlin(2026, 10, 28), bis: berlin(2026, 11, 2), ganztaegig: true)    // Mi 28. Okt. – So 1. Nov.
        #expect(formatter.zeitzeile(cgw) == "Läuft seit Mi 28. Okt. · bis So 1. Nov.")
        // Unter dem Starttag selbst „läuft“ sie noch nicht seit.
        #expect(formatter.zeitzeile(cgw, bezugstag: berlin(2026, 10, 28)) == "Mi 28. Okt. – So 1. Nov.")
        // Mehrtägig mit Uhrzeit.
        let festival = event(berlin(2026, 11, 6, 20), bis: berlin(2026, 11, 8, 14))
        #expect(formatter.zeitzeile(festival, bezugstag: berlin(2026, 11, 6)) == "Ab 20:00 Uhr · bis So 8. Nov.")
        #expect(formatter.zeitzeile(festival, bezugstag: berlin(2026, 11, 7)) == "Läuft seit Fr 6. Nov. · bis So 8. Nov.")
    }

    @Test func sectionTitles() {
        #expect(formatter.abschnittstitel(fuer: berlin(2026, 11, 5, 17)) == "Heute · Donnerstag")
        #expect(formatter.abschnittstitel(fuer: berlin(2026, 11, 6)) == "Morgen · Freitag")
        #expect(formatter.abschnittstitel(fuer: berlin(2026, 11, 8)) == "Sonntag, 8. Nov.")
        #expect(formatter.abschnittstitel(fuer: berlin(2026, 12, 24)) == "Donnerstag, 24. Dez.")
        // Auch über den Monatswechsel.
        let amLetztenTag = EventZeitFormatter(jetzt: berlin(2026, 10, 31, 22))
        #expect(amLetztenTag.abschnittstitel(fuer: berlin(2026, 11, 1)) == "Morgen · Sonntag")
        #expect(amLetztenTag.abschnittstitel(fuer: berlin(2026, 10, 30)) == "Freitag, 30. Okt.")
    }

    @Test func detailDateAndTime() {
        let nacht = formatter.datumUndZeit(event(berlin(2026, 10, 30, 21), bis: berlin(2026, 10, 31, 3)))
        #expect(nacht.datum == "Freitag, 30. Oktober")
        #expect(nacht.zeit == "21:00 – 03:00 Uhr")

        let offen = formatter.datumUndZeit(event(berlin(2026, 10, 30, 21)))
        #expect(offen.datum == "Freitag, 30. Oktober")
        #expect(offen.zeit == "Ab 21:00 Uhr")

        let ganztag = formatter.datumUndZeit(event(berlin(2026, 11, 5), bis: berlin(2026, 11, 6), ganztaegig: true))
        #expect(ganztag.datum == "Donnerstag, 5. November")
        #expect(ganztag.zeit == "Ganztägig")
    }

    @Test func detailForMultiDayEvents() {
        let cgw = event(berlin(2026, 10, 28), bis: berlin(2026, 11, 2), ganztaegig: true)
        let laeuft = EventZeitFormatter(jetzt: berlin(2026, 10, 30, 12)).datumUndZeit(cgw)
        #expect(laeuft.datum == "Mi 28. Okt. – So 1. Nov.")
        #expect(laeuft.zeit == "Ganztägig · läuft gerade")

        let vorbei = EventZeitFormatter(jetzt: berlin(2026, 11, 5)).datumUndZeit(cgw)
        #expect(vorbei.zeit == "Ganztägig")
        let spaeter = EventZeitFormatter(jetzt: berlin(2026, 10, 20)).datumUndZeit(cgw)
        #expect(spaeter.zeit == "Ganztägig")

        let festival = formatter.datumUndZeit(event(berlin(2026, 11, 6, 20), bis: berlin(2026, 11, 8, 14)))
        #expect(festival.datum == "Fr 6. Nov. – So 8. Nov.")
        #expect(festival.zeit == "Ab 20:00 Uhr · bis 14:00 Uhr")
    }
}
