import Foundation
import Testing
@testable import Campus_Ilmenau

@MainActor
private func eventually(timeout: Duration = .seconds(3), _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(25))
    }
    return condition()
}

@MainActor
struct LibraryTitleTests {
    // MARK: - Beispiele

    private func detail(_ json: String) throws -> LibraryMediaDetail {
        try LibraryCatalogService.decoder.decode(LibraryMediaDetail.self, from: Data(json.utf8))
    }

    /// Titel mit den gewünschten Exemplaren und Gesamtstatus.
    private func detail(status: String, items: String, extra: String = "") throws -> LibraryMediaDetail {
        try detail("""
        {"id":"med_1","title":"Regelungstechnik","authors":["Lunze, Jan"],"mediaType":"print_book","language":"ger",
         "items":[\(items)],"availabilityStatus":"\(status)"\(extra)}
        """)
    }

    private func item(_ status: String, due: String? = nil, queue: Int? = nil, reserve: String? = nil, plan: String? = nil) -> String {
        let dueJSON = due.map { "\"\($0)\"" } ?? "null"
        let queueJSON = queue.map(String.init) ?? "null"
        let reserveJSON = reserve.map { "\"\($0)\"" } ?? "null"
        let planJSON = plan.map { "\"\($0)\"" } ?? "null"
        return """
        {"label":"SIG 1","location":{"id":"x","code":"2","name":"Freihand","floorPlanUrl":\(planJSON)},
         "status":"\(status)","dueDate":\(dueJSON),"reserveUrl":\(reserveJSON),"queue":\(queueJSON)}
        """
    }

    private func media(_ json: String = Sample.book) throws -> LibraryMedia {
        try LibraryCatalogService.decoder.decode(LibraryMedia.self, from: Data(json.utf8))
    }

    /// Merkliste nur im Speicher, damit die Tests sich nicht beeinflussen.
    private func merklisteStore() -> BibMerklisteStore {
        BibMerklisteStore(fileURL: nil, legacyDefaults: nil)
    }

    // MARK: - Gesamtstatus

    @Test func statusBlockForAvailable() throws {
        let block = try detail(status: "available", items: [item("available"), item("available"), item("on_loan")].joined(separator: ",")).statusBlock
        #expect(block == LibraryStatusBlock(title: "Ausleihbar", subtitle: "2 von 3 Exemplaren stehen im Regal", tone: .green))

        let single = try detail(status: "available", items: item("available")).statusBlock
        #expect(single.subtitle == "Das Exemplar steht im Regal")
    }

    @Test func statusBlockForAllOnLoan() throws {
        let items = [item("on_loan", due: "2026-11-12", queue: 2), item("on_loan", due: "2026-11-26", queue: 1)].joined(separator: ",")
        let block = try detail(status: "on_loan", items: items).statusBlock
        #expect(block.title == "Alle Exemplare ausgeliehen")
        #expect(block.subtitle == "Frühestens zurück am 12. Nov. · 3 Vormerkungen")
        #expect(block.tone == .neutral)

        let noData = try detail(status: "on_loan", items: item("on_loan")).statusBlock
        #expect(noData.title == "Ausgeliehen")
        #expect(noData.subtitle == "Im UB-Katalog siehst du, wann es zurück ist.")
    }

    @Test func statusBlockForReferenceOnlyOnlineAndUnknown() throws {
        let reference = try detail(status: "reference_only", items: item("reference_only")).statusBlock
        #expect(reference == LibraryStatusBlock(title: "Nur vor Ort nutzbar", subtitle: "Im Lesesaal, nicht ausleihbar", tone: .blue))

        let online = try detail(status: "online", items: item("online")).statusBlock
        #expect(online == LibraryStatusBlock(title: "Online verfügbar", subtitle: "Im Campusnetz oder über VPN lesen", tone: .green))

        // Leere Exemplarliste: Verfügbarkeit nicht abrufbar.
        let unknown = try detail(status: "unknown", items: "").statusBlock
        #expect(unknown == LibraryStatusBlock(
            title: "Verfügbarkeit gerade nicht abrufbar",
            subtitle: "Im UB-Katalog siehst du den aktuellen Stand.",
            tone: .neutral
        ))
    }

    // MARK: - Aktionen

    @Test func reserveOnlyWhenAllOnLoanAndURLExists() throws {
        let withURL = try detail(status: "on_loan", items: item("on_loan", reserve: "https://opac.example/reserve"))
        #expect(withURL.primaryAction == .reserve(URL(string: "https://opac.example/reserve")!))
        #expect(withURL.primaryAction?.title == "Vormerken")

        let withoutURL = try detail(status: "on_loan", items: item("on_loan"))
        #expect(withoutURL.primaryAction == nil)

        let available = try detail(status: "available", items: item("available", reserve: "https://opac.example/reserve"))
        #expect(available.primaryAction == nil)
    }

    @Test func readOnlineNeedsAnOnlineURL() throws {
        let with = try detail(status: "online", items: item("online"), extra: ",\"onlineUrl\":\"https://example.org/lesen\"")
        #expect(with.primaryAction == .readOnline(URL(string: "https://example.org/lesen")!))
        #expect(with.primaryAction?.title == "Online lesen")

        let without = try detail(status: "online", items: item("online"))
        #expect(without.primaryAction == nil)
    }

    // MARK: - Exemplare

    @Test func itemRowsFollowTheMockup() throws {
        let rows = try detail(status: "on_loan", items: [
            item("available", plan: "https://example.org/plan.png"),
            item("on_loan", due: "2026-11-12", queue: 2),
            item("on_loan", due: "2026-11-26", queue: 1),
            item("reference_only"),
            item("online"),
            item("unknown")
        ].joined(separator: ",")).rows

        #expect(rows[0].chipText == "Ausleihbar")
        #expect(rows[0].extra == nil)
        #expect(rows[0].floorPlanURL?.absoluteString == "https://example.org/plan.png")
        #expect(rows[0].place == "Freihand")
        #expect(rows[0].signature == "SIG 1")

        #expect(rows[1].chipText == "Ausgeliehen")
        #expect(rows[1].extra == "Zurück bis 12. Nov. · 2 Vormerkungen")
        #expect(rows[2].extra == "Zurück bis 26. Nov. · 1 Vormerkung")
        #expect(rows[1].floorPlanURL == nil)

        #expect(rows[3].chipText == "Nur vor Ort")
        #expect(rows[3].extra == "Nicht ausleihbar, im Lesesaal nutzbar")
        #expect(rows[4].chipText == "Online")
        #expect(rows[4].extra == "Außerhalb des Campus über VPN")
        #expect(rows[5].chipText == "Unbekannt")
    }

    @Test func itemWithoutLocationHasAFallbackPlace() throws {
        let json = "{\"label\":\"X 1\",\"location\":null,\"status\":\"available\"}"
        let row = try LibraryCatalogService.decoder.decode(LibraryItem.self, from: Data(json.utf8)).row
        #expect(row.place == "Exemplar")
    }

    // MARK: - Kopf und Angaben

    @Test func headerLines() throws {
        let book = try media(Sample.book)
        #expect(book.kindLabel == "Buch · Deutsch")
        #expect(book.editionLine == "2018 · Hanser")   // ohne Auflage entfällt sie
        #expect(book.personsLine == "Luigi Lo Iacono, Stephan Wiefling")
        #expect(book.shareURL?.absoluteString == "https://opac.lbs-ilmenau.gbv.de/DB=1/PPNSET?PPN=1009895648")

        let bare = try media("{\"id\":\"med_9\",\"title\":\"Nur Titel\",\"mediaType\":\"journal\"}")
        #expect(bare.kindLabel == "Zeitschrift")
        #expect(bare.editionLine == "")
        #expect(bare.personsLine == "")
        #expect(bare.shareURL == nil)
    }

    @Test func factsKeepOnlyFieldsWithData() throws {
        let facts = try media(Sample.book).facts
        #expect(facts.isbn == "978-3-446-45486-6")
        #expect(facts.language == "Deutsch")
        #expect(facts.publisher == "Hanser")
        #expect(facts.rvk == "ST 250")
        #expect(facts.subjects == ["Java", "Python"])
        #expect(facts.abstract == nil)
        #expect(!facts.isEmpty)

        let empty = try media("{\"id\":\"med_9\",\"title\":\"Leer\",\"isbns\":[\" \"],\"subjects\":[\"\"],\"abstract\":\"  \"}").facts
        #expect(empty.isEmpty)
    }

    @Test func isbnListIsShortened() throws {
        let book = try media("{\"id\":\"med_9\",\"title\":\"T\",\"isbns\":[\"1\",\"2\",\"3\"]}")
        #expect(book.facts.isbn == "1, 2")
    }

    @Test func tableOfContentsTextIsShortened() throws {
        let long = String(repeating: "Kapitel ", count: 600)
        let toc = try LibraryCatalogService.decoder.decode(
            LibraryTableOfContents.self,
            from: Data("{\"text\":\"\(long)\",\"entries\":[]}".utf8)
        )
        #expect(toc.shortText?.count ?? 0 <= LibraryTableOfContents.textLimit + 2)
        #expect(toc.shortText?.hasSuffix("…") == true)
    }

    // MARK: - Merkliste

    @Test func bookmarkPutsTheTitleOnTheListAndTellsThePerson() throws {
        let store = merklisteStore()
        let model = LibraryTitleModel(media: try media(), searchId: nil, merkliste: store)
        #expect(!model.istGemerkt)

        model.toggleMerken()
        #expect(model.istGemerkt)
        #expect(store.istGemerkt("med_1009895648"))
        #expect(store.eintraege.first?.titel == "Programmieren trainieren")
        #expect(store.eintraege.first?.personen == "Luigi Lo Iacono, Stephan Wiefling")
        #expect(model.toastMessage == "Auf die Merkliste gesetzt")
        #expect(model.toastActionTitle == "Anzeigen")
        #expect(model.showsToast)

        model.toggleMerken()
        #expect(!store.istGemerkt("med_1009895648"))
        #expect(model.toastMessage == "Von der Merkliste entfernt")
        #expect(model.toastActionTitle == nil)
    }

    @Test func showToastActionOpensTheList() throws {
        let model = LibraryTitleModel(media: try media(), searchId: nil, merkliste: merklisteStore())
        model.toggleMerken()
        #expect(!model.opensMerkliste)
        model.performToastAction()
        #expect(model.opensMerkliste)
        #expect(!model.showsToast)
    }

    @Test func eachMessageRestartsTheToastTimer() throws {
        let model = LibraryTitleModel(media: try media(), searchId: nil, merkliste: merklisteStore())
        model.toggleMerken()
        let first = model.toastToken
        model.toggleMerken()
        #expect(model.toastToken > first)
    }

    @Test func loadedDetailCompletesTheBookmarkedEntry() async throws {
        let h = Harness()
        let service = h.service(json: Sample.detail)
        let store = merklisteStore()
        // Titel ohne Angaben gemerkt (z. B. aus der Ausleihliste), das Detail ergänzt sie.
        let bare = LibraryMedia(id: "med_1", ppn: "1", title: "Titel")
        let model = LibraryTitleModel(media: bare, searchId: nil, service: service, merkliste: store)
        model.toggleMerken()
        let gemerktAm = try #require(store.eintraege.first?.gemerktAm)
        await model.load()
        #expect(store.eintraege.first?.titel == "Regelungstechnik 1")
        #expect(store.eintraege.first?.gemerktAm == gemerktAm)
    }

    @Test func missingTitleOffersToRemoveItFromTheList() async throws {
        let h = Harness()
        let service = h.service(status: 404, json: Sample.error(code: "resource_missing", message: "No media", param: "id"))
        let store = merklisteStore()
        let model = LibraryTitleModel(media: try media(), searchId: nil, service: service, merkliste: store)
        model.toggleMerken()
        await model.load()
        #expect(model.phase == .notFound)
        #expect(model.istGemerkt)

        model.vonMerklisteEntfernen()
        #expect(!store.istGemerkt("med_1009895648"))
        #expect(model.toastMessage == "Von der Merkliste entfernt")
    }

    // MARK: - Laden

    /// Anfragen an die Titel-Seite. Nach dem Laden ersetzt das Detail die Listendaten, die ID kann dann abweichen.
    private func mediaRequests(_ h: Harness) -> [URL] {
        h.requestURLs.filter { $0.path.hasPrefix("/develop/v1/library/media/") }
    }

    private func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    @Test func loadSendsSearchIDAndFeatures() async throws {
        let h = Harness()
        let service = h.service(json: Sample.detail)
        h.route("/develop/v1/library/features", json: "{\"object\":\"library_features\",\"contents\":true}")
        let model = LibraryTitleModel(media: try media(), searchId: "srch_42", service: service, merkliste: merklisteStore())

        #expect(model.phase == .loading)
        await model.load()

        #expect(model.phase == .loaded)
        #expect(model.detail?.items.count == 2)
        #expect(model.media.title == "Regelungstechnik 1")   // die Daten des Details ersetzen die der Liste
        let request = try #require(mediaRequests(h).first)
        #expect(query(request, "search_id") == "srch_42")
        #expect(query(request, "track") == nil)
        #expect(model.contentsEnabled)
        #expect(model.showsContents)
        #expect(model.tocOpen)       // das Inhaltsverzeichnis ist zuerst aufgeklappt
        #expect(!model.blurbOpen)
    }

    @Test func contentsStayHiddenWhenFeaturesDoNotAllowThem() async throws {
        let h = Harness()
        let service = h.service(json: Sample.detail)
        h.route("/develop/v1/library/features", json: "{\"object\":\"library_features\",\"contents\":false}")
        let model = LibraryTitleModel(media: try media(), searchId: nil, service: service, merkliste: merklisteStore())
        await model.load()
        #expect(model.detail?.hasContents == true)
        #expect(!model.contentsEnabled)
        #expect(!model.showsContents)
    }

    @Test func reloadingDoesNotCountAsANewView() async throws {
        let h = Harness()
        let service = h.service(json: Sample.detail)
        h.route("/develop/v1/library/features", json: "{\"object\":\"library_features\",\"contents\":true}")
        let model = LibraryTitleModel(media: try media(), searchId: "srch_42", service: service, merkliste: merklisteStore())
        await model.load()
        await model.refresh()

        let requests = mediaRequests(h)
        guard requests.count == 2 else {
            Issue.record("Erwartet waren 2 Anfragen, es waren \(requests.count).")
            return
        }
        #expect(query(requests[0], "track") == nil)
        #expect(query(requests[1], "track") == "false")
        #expect(query(requests[1], "search_id") == "srch_42")
    }

    @Test func missingTitleShowsNotFound() async throws {
        let h = Harness()
        let service = h.service(status: 404, json: Sample.error(code: "resource_missing", message: "No media", param: "id"))
        let model = LibraryTitleModel(media: try media(), searchId: nil, service: service, merkliste: merklisteStore())
        await model.load()
        #expect(model.phase == .notFound)
        #expect(model.detail == nil)
    }

    @Test func catalogUnavailableShowsFailureAndRetryRecovers() async throws {
        let h = Harness()
        let service = h.service(
            status: 503, json: Sample.error(code: "catalog_unavailable", message: "x", type: "api_error")
        )
        let model = LibraryTitleModel(media: try media(), searchId: nil, service: service, merkliste: merklisteStore())
        await model.load()
        #expect(model.phase == .failed("Katalog gerade nicht erreichbar"))

        _ = h.service(json: Sample.detail)
        await model.refresh()
        #expect(model.phase == .loaded)
        #expect(model.detail != nil)
    }

    @Test func failedReloadKeepsTheShownTitle() async throws {
        let h = Harness()
        let service = h.service(json: Sample.detail)
        let model = LibraryTitleModel(media: try media(), searchId: nil, service: service, merkliste: merklisteStore())
        await model.load()
        #expect(model.phase == .loaded)

        _ = h.service(status: 503, json: Sample.error(code: "catalog_unavailable", message: "x", type: "api_error"))
        await model.refresh()
        #expect(model.phase == .loaded)
        #expect(model.detail != nil)
        #expect(model.toastMessage == "Aktualisieren fehlgeschlagen")
    }

    @Test func staleResponseShowsANoticeWithTheFetchTime() async throws {
        let h = Harness()
        let service = h.service(headers: ["X-Cache-Status": "stale"], json: Sample.detail)
        let model = LibraryTitleModel(media: try media(), searchId: nil, service: service, merkliste: merklisteStore())
        await model.load()
        #expect(model.isStale)
        let fetched = try #require(model.media.fetchedAt)
        #expect(model.staleNotice == "Stand von \(LibrarySearchModel.timeText(fetched)) – der Katalog antwortet gerade langsam. Verfügbarkeit kann sich geändert haben.")
    }

    // MARK: - Browser und Zwischenablage

    @Test func onlyWebAddressesOpenInTheBrowserWindow() throws {
        let model = LibraryTitleModel(media: try media(), searchId: nil, merkliste: merklisteStore())
        model.open(URL(string: "tel:+49123"))
        #expect(model.externalLink == nil)
        model.open(nil)
        #expect(model.externalLink == nil)

        model.open(URL(string: "https://opac.example/reserve"))
        #expect(model.externalLink?.url.absoluteString == "https://opac.example/reserve")
    }

    @Test func openingTheReserveLinkShowsNoSuccessMessage() throws {
        let model = LibraryTitleModel(media: try media(), searchId: nil, merkliste: merklisteStore())
        model.open(URL(string: "https://opac.example/reserve"))
        // Die App erfährt nicht, ob das Vormerken geklappt hat.
        #expect(model.toastMessage == "")
        #expect(!model.showsToast)
    }

    @Test func copyingASignatureTellsThePerson() throws {
        let model = LibraryTitleModel(media: try media(), searchId: nil, merkliste: merklisteStore())
        model.copySignature("ZQ 5000 R444(16)-1")
        #expect(model.toastMessage == "Signatur kopiert")
        #expect(model.showsToast)
    }
}
