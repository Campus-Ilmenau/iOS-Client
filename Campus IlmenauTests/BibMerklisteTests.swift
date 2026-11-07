import Foundation
import Testing
@testable import Campus_Ilmenau

@MainActor
struct BibMerklisteTests {
    // MARK: - Hilfen

    private func titel(_ id: String, name: String = "Titel", age: TimeInterval = 0) -> GemerkterTitel {
        GemerkterTitel(
            id: id, titel: name, personen: "Jan Lunze", jahr: "2020", medientyp: "print_book",
            coverURL: nil, gemerktAm: Date(timeIntervalSinceNow: -age)
        )
    }

    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Merkliste-\(UUID().uuidString).json")
    }

    private func memoryStore() -> BibMerklisteStore {
        BibMerklisteStore(fileURL: nil, legacyDefaults: nil)
    }

    // MARK: - Merken

    @Test func rememberingAddsTheNewestOnTop() {
        let store = memoryStore()
        store.merken(titel("med_1", age: 20))
        store.merken(titel("med_2", age: 10))
        store.merken(titel("med_3", age: 0))
        #expect(store.eintraege.map(\.id) == ["med_3", "med_2", "med_1"])
        #expect(store.anzahl == 3)
        #expect(store.istGemerkt("med_2"))
        #expect(!store.istGemerkt("med_9"))
    }

    @Test func rememberingTwiceKeepsOneEntry() {
        let store = memoryStore()
        let first = titel("med_1", name: "Erster", age: 10)
        store.merken(first)
        store.merken(titel("med_1", name: "Anders", age: 0))
        #expect(store.eintraege.count == 1)
        #expect(store.eintraege.first?.titel == "Erster")                       // der vorhandene Eintrag bleibt
        #expect(store.eintraege.first?.gemerktAm == first.gemerktAm)
    }

    @Test func entriesAreSortedByDateNotByInsertionOrder() {
        let store = memoryStore()
        store.merken(titel("med_new", age: 0))
        store.merken(titel("med_old", age: 100))   // später eingefügt, aber älter
        #expect(store.eintraege.map(\.id) == ["med_new", "med_old"])
    }

    // MARK: - Entfernen und Widerrufen

    @Test func removingReturnsTheEntryWithItsOldPosition() throws {
        let store = memoryStore()
        for (index, id) in ["med_a", "med_b", "med_c", "med_d"].enumerated() {
            store.merken(titel(id, age: Double(100 - index)))   // d ist die neueste
        }
        #expect(store.eintraege.map(\.id) == ["med_d", "med_c", "med_b", "med_a"])

        let removed = try #require(store.entfernen("med_c"))
        #expect(removed.eintrag.id == "med_c")
        #expect(removed.position == 1)
        #expect(store.eintraege.map(\.id) == ["med_d", "med_b", "med_a"])
        #expect(store.entfernen("med_c") == nil)       // zweites Entfernen: nichts
    }

    @Test func restoringPutsTheEntryBackWhereItWas() throws {
        let store = memoryStore()
        for (index, id) in ["med_a", "med_b", "med_c"].enumerated() {
            store.merken(titel(id, age: Double(100 - index)))
        }
        let removed = try #require(store.entfernen("med_b"))
        store.wiederherstellen(removed)
        #expect(store.eintraege.map(\.id) == ["med_c", "med_b", "med_a"])

        // Auch an die oberste und die letzte Stelle.
        let top = try #require(store.entfernen("med_c"))
        let bottom = try #require(store.entfernen("med_a"))
        store.wiederherstellen(bottom.eintrag, an: bottom.position)
        store.wiederherstellen(top.eintrag, an: top.position)
        #expect(store.eintraege.map(\.id).first == "med_c")
    }

    @Test func restoringDoesNotCreateDuplicates() throws {
        let store = memoryStore()
        store.merken(titel("med_1"))
        let removed = try #require(store.entfernen("med_1"))
        store.merken(titel("med_1", name: "Neu gemerkt"))     // inzwischen wieder gemerkt
        store.wiederherstellen(removed)
        #expect(store.eintraege.count == 1)
        #expect(store.eintraege.first?.titel == "Neu gemerkt")
    }

    @Test func restoringClampsAPositionBeyondTheEnd() throws {
        let store = memoryStore()
        store.merken(titel("med_1"))
        store.wiederherstellen(titel("med_2"), an: 99)
        #expect(store.eintraege.map(\.id) == ["med_1", "med_2"])
        store.wiederherstellen(titel("med_3"), an: -5)
        #expect(store.eintraege.first?.id == "med_3")
    }

    @Test func removingAllEmptiesTheList() {
        let store = memoryStore()
        store.merken(titel("med_1"))
        store.merken(titel("med_2", age: 5))
        store.alleEntfernen()
        #expect(store.eintraege.isEmpty)
        #expect(store.anzahl == 0)
        store.alleEntfernen()   // auf einer leeren Liste passiert nichts
        #expect(store.eintraege.isEmpty)
    }

    @Test func updatingKeepsDateAndPosition() {
        let store = memoryStore()
        let old = titel("med_1", name: "Alt", age: 50)
        store.merken(old)
        store.merken(titel("med_2", age: 0))
        store.aktualisieren(GemerkterTitel(id: "med_1", titel: "Neu", personen: "A B", gemerktAm: .now))
        #expect(store.eintraege.map(\.id) == ["med_2", "med_1"])
        #expect(store.eintraege.last?.titel == "Neu")
        #expect(store.eintraege.last?.gemerktAm == old.gemerktAm)
        store.aktualisieren(titel("med_9"))   // unbekannte ID wird nicht angelegt
        #expect(store.eintraege.count == 2)
    }

    // MARK: - Speichern

    @Test func listSurvivesANewStoreInstance() throws {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        let store = BibMerklisteStore(fileURL: file, legacyDefaults: nil)
        store.merken(GemerkterTitel(
            id: "med_1", titel: "Regelungstechnik 1", personen: "Jan Lunze", jahr: "2020",
            medientyp: "ebook", coverURL: URL(string: "https://example.org/cover.jpg"), gemerktAm: Date(timeIntervalSinceNow: -60)
        ))
        store.merken(titel("med_2"))
        _ = store.entfernen("med_2")

        let reloaded = BibMerklisteStore(fileURL: file, legacyDefaults: nil)
        #expect(reloaded.eintraege.map(\.id) == ["med_1"])
        let entry = try #require(reloaded.eintraege.first)
        #expect(entry.titel == "Regelungstechnik 1")
        #expect(entry.personen == "Jan Lunze")
        #expect(entry.jahr == "2020")
        #expect(entry.medientyp == "ebook")
        #expect(entry.coverURL?.absoluteString == "https://example.org/cover.jpg")
        #expect(abs(entry.gemerktAm.timeIntervalSinceNow + 60) < 5)
    }

    @Test func emptyingIsAlsoPersisted() {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = BibMerklisteStore(fileURL: file, legacyDefaults: nil)
        store.merken(titel("med_1"))
        store.alleEntfernen()
        #expect(BibMerklisteStore(fileURL: file, legacyDefaults: nil).eintraege.isEmpty)
    }

    @Test func missingOrBrokenFileGivesAnEmptyList() throws {
        #expect(BibMerklisteStore(fileURL: tempFile(), legacyDefaults: nil).eintraege.isEmpty)

        let broken = tempFile()
        defer { try? FileManager.default.removeItem(at: broken) }
        try Data("kein JSON".utf8).write(to: broken)
        let store = BibMerklisteStore(fileURL: broken, legacyDefaults: nil)
        #expect(store.eintraege.isEmpty)
        store.merken(titel("med_1"))     // danach lässt sich wieder speichern
        #expect(BibMerklisteStore(fileURL: broken, legacyDefaults: nil).anzahl == 1)
    }

    @Test func storedFileHoldsNoAvailabilityStatus() throws {
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file) }
        BibMerklisteStore(fileURL: file, legacyDefaults: nil).merken(titel("med_1"))
        let text = String(decoding: try Data(contentsOf: file), as: UTF8.self).lowercased()
        #expect(!text.contains("status"))
        #expect(!text.contains("available"))
    }

    // MARK: - Übernahme der früheren Favoriten

    @Test func earlierFavoritesAreTakenOverAndThenRemoved() throws {
        let suite = "BibMerklisteTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["med_1", "med_2", "med_3"], forKey: BibMerklisteStore.legacyKey)   // zuletzt gemerkt: med_3

        let store = BibMerklisteStore(fileURL: nil, legacyDefaults: defaults)
        #expect(store.eintraege.map(\.id) == ["med_3", "med_2", "med_1"])
        #expect(store.eintraege.allSatisfy { $0.istUnvollstaendig })
        #expect(defaults.stringArray(forKey: BibMerklisteStore.legacyKey) == nil)
        #expect(store.eintraege.first?.anzeigeTitel == "Titel 3")   // bis die Angaben nachkommen
    }

    @Test func migrationDoesNotDuplicateAndFillsIncompleteEntries() throws {
        let suite = "BibMerklisteTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let file = tempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        BibMerklisteStore(fileURL: file, legacyDefaults: nil).merken(titel("med_1", name: "Schon da"))
        defaults.set(["med_1", "med_2"], forKey: BibMerklisteStore.legacyKey)
        let store = BibMerklisteStore(fileURL: file, legacyDefaults: defaults)
        #expect(store.eintraege.count == 2)
        #expect(store.eintraege.first { $0.id == "med_1" }?.titel == "Schon da")

        // Merkt man einen unvollständigen Eintrag erneut mit Angaben, werden sie ergänzt.
        store.merken(titel("med_2", name: "Jetzt mit Titel"))
        #expect(store.eintraege.first { $0.id == "med_2" }?.titel == "Jetzt mit Titel")
    }

    // MARK: - Modell

    @Test func entryFromCatalogTitleKeepsOnlyWhatTheListNeeds() throws {
        let json = """
        {"id":"med_9","title":"Titel","authors":["Lunze, Jan","Reuter, Manfred"],"year":"2020","mediaType":"ebook",
         "cover":{"status":"found","url":"/v1/library/media/med_9/cover"}}
        """
        let media = try LibraryCatalogService.decoder.decode(LibraryMedia.self, from: Data(json.utf8))
        let entry = GemerkterTitel(media: media, coverURL: URL(string: "https://api.example/cover"))
        #expect(entry.id == "med_9")
        #expect(entry.personen == "Jan Lunze, Manfred Reuter")
        #expect(entry.untertitel == "Jan Lunze, Manfred Reuter · 2020")
        #expect(entry.medientyp == "ebook")
        #expect(entry.mediaType == .ebook)
        #expect(entry.alsMedia.ppn == "9")
    }

    @Test func subtitleSkipsEmptyParts() {
        #expect(GemerkterTitel(id: "med_1", titel: "T", personen: "", jahr: "2024").untertitel == "2024")
        #expect(GemerkterTitel(id: "med_1", titel: "T", personen: "A B", jahr: nil).untertitel == "A B")
        #expect(GemerkterTitel(id: "med_1", titel: "T").untertitel == "")
    }

    @Test func chipTextsFollowTheCatalog() {
        #expect(LibraryAvailabilityStatus.available.chipText == "Ausleihbar")
        #expect(LibraryAvailabilityStatus.online.chipText == "Online")
        #expect(LibraryAvailabilityStatus.onLoan.chipText == "Ausgeliehen")
        #expect(LibraryAvailabilityStatus.referenceOnly.chipText == "Nur vor Ort")
        #expect(LibraryAvailabilityStatus.unknown.chipText == "Unbekannt")
        #expect(LibraryAvailabilityStatus.available.chipVariant == .green)
        #expect(LibraryAvailabilityStatus.online.chipVariant == .green)
        #expect(LibraryAvailabilityStatus.onLoan.chipVariant == .neutral)
        #expect(LibraryAvailabilityStatus.referenceOnly.chipVariant == .blue)
        #expect(LibraryAvailabilityStatus.unknown.chipVariant == .neutral)
    }

    // MARK: - Status laden

    private func availabilityJSON(_ ids: [String], status: String = "available") -> String {
        let data = ids.map { "{\"id\":\"\($0)\",\"availabilityStatus\":\"\(status)\",\"items\":[]}" }.joined(separator: ",")
        return "{\"object\":\"list\",\"data\":[\(data)]}"
    }

    private func idsInRequests(_ h: Harness) -> [[String]] {
        h.requestURLs.map { url in
            let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "ids" }?.value ?? ""
            return value.split(separator: ",").map(String.init)
        }
    }

    @Test func statusIsLoadedInPacketsOfTwentyInParallel() async {
        let h = Harness()
        let ids = (1...45).map { "med_\($0)" }
        let service = h.service(json: availabilityJSON(ids))
        let status = BibMerklisteStatus()
        #expect(status.status(for: "med_1") == nil)     // lädt noch → Chip „…“

        await status.load(ids: ids, using: service)

        #expect(idsInRequests(h).map(\.count).sorted() == [5, 20, 20])
        #expect(status.status(for: "med_1") == .available)
        #expect(status.status(for: "med_45") == .available)
        #expect(!status.isLoading)
    }

    @Test func eachIDIsAskedOnlyOnce() async {
        let h = Harness()
        let service = h.service(json: availabilityJSON(["med_1"]))
        let status = BibMerklisteStatus()
        await status.load(ids: ["med_1", "med_1", "med_1"], using: service)
        #expect(idsInRequests(h) == [["med_1"]])
    }

    @Test func failureShowsUnknownAndKeepsEveryEntry() async {
        let h = Harness()
        let service = h.service(status: 503, json: Sample.error(code: "catalog_unavailable", message: "x", type: "api_error"))
        let status = BibMerklisteStatus()
        await status.load(ids: ["med_1", "med_2"], using: service)
        #expect(status.status(for: "med_1") == .unknown)
        #expect(status.status(for: "med_2") == .unknown)
    }

    @Test func idMissingInTheAnswerCountsAsUnknown() async {
        let h = Harness()
        let service = h.service(json: availabilityJSON(["med_1"]))
        let status = BibMerklisteStatus()
        await status.load(ids: ["med_1", "med_2"], using: service)
        #expect(status.status(for: "med_1") == .available)
        #expect(status.status(for: "med_2") == .unknown)
    }

    @Test func reloadingRefreshesTheStatus() async {
        let h = Harness()
        let service = h.service(json: availabilityJSON(["med_1"], status: "available"))
        let status = BibMerklisteStatus()
        await status.load(ids: ["med_1"], using: service)
        #expect(status.status(for: "med_1") == .available)

        _ = h.service(json: availabilityJSON(["med_1"], status: "on_loan"))
        await status.load(ids: ["med_1"], using: service)
        #expect(status.status(for: "med_1") == .onLoan)
    }

    @Test func emptyListSendsNoRequest() async {
        let h = Harness()
        let service = h.service(json: availabilityJSON([]))
        await BibMerklisteStatus().load(ids: [], using: service)
        #expect(h.requestURLs.isEmpty)
    }

    // MARK: - Signatur und Standort

    private func verfuegbarkeit(_ items: String) throws -> LibraryAvailability {
        let json = "{\"id\":\"med_1\",\"availabilityStatus\":\"available\",\"items\":[\(items)]}"
        return try LibraryCatalogService.decoder.decode(LibraryAvailability.self, from: Data(json.utf8))
    }

    private func exemplar(_ label: String, _ status: String, standort: String? = "Lehrbuchsammlung", plan: String? = nil) -> String {
        let ort = standort.map { name in
            let planTeil = plan.map { ",\"floorPlanUrl\":\"\($0)\"" } ?? ""
            return ",\"location\":{\"id\":\"1\",\"code\":\"53\",\"name\":\"\(name)\"\(planTeil)}"
        } ?? ""
        return "{\"label\":\"\(label)\",\"status\":\"\(status)\"\(ort)}"
    }

    @Test func exemplarTakesSignatureLocationAndFloorPlan() throws {
        let item = exemplar("ST 130 R434", "available", plan: "https://example.org/plan")
        let ergebnis = try #require(BibMerklisteExemplar(availability: try verfuegbarkeit(item)))
        #expect(ergebnis.signatur == "ST 130 R434")
        #expect(ergebnis.standort == "Lehrbuchsammlung")
        #expect(ergebnis.lageplan == URL(string: "https://example.org/plan"))
        #expect(ergebnis.weitere == 0)
    }

    @Test func exemplarPrefersAnAvailableCopyAndCountsTheOthers() throws {
        let items = [
            exemplar("ST 1 (1)", "on_loan", standort: "Magazin"),
            exemplar("ST 1 (2)", "available", standort: "Lehrbuchsammlung"),
            exemplar("ST 1 (3)", "reference_only", standort: "Lesesaal")
        ].joined(separator: ",")
        let ergebnis = try #require(BibMerklisteExemplar(availability: try verfuegbarkeit(items)))
        #expect(ergebnis.signatur == "ST 1 (2)")
        #expect(ergebnis.standort == "Lehrbuchsammlung")
        #expect(ergebnis.weitere == 2)
    }

    @Test func exemplarFallsBackToReferenceThenLoanThenFirst() throws {
        let nurLesesaal = [exemplar("A", "on_loan", standort: "Magazin"), exemplar("B", "reference_only", standort: "Lesesaal")]
        #expect(BibMerklisteExemplar(availability: try verfuegbarkeit(nurLesesaal.joined(separator: ",")))?.signatur == "B")
        let ausgeliehen = [exemplar("C", "unknown"), exemplar("D", "on_loan")]
        #expect(BibMerklisteExemplar(availability: try verfuegbarkeit(ausgeliehen.joined(separator: ",")))?.signatur == "D")
        let unbekannt = [exemplar("E", "unknown"), exemplar("F", "unknown")]
        #expect(BibMerklisteExemplar(availability: try verfuegbarkeit(unbekannt.joined(separator: ",")))?.signatur == "E")
    }

    @Test func exemplarDropsFloorPlansThatAreNotWebLinks() throws {
        let item = exemplar("ST 1", "available", plan: "javascript:alert(1)")
        #expect(BibMerklisteExemplar(availability: try verfuegbarkeit(item))?.lageplan == nil)
    }

    @Test func exemplarWithoutSignatureShowsOnlyTheLocation() throws {
        let item = exemplar("  ", "available", standort: "Lesesaal")
        let ergebnis = try #require(BibMerklisteExemplar(availability: try verfuegbarkeit(item)))
        #expect(ergebnis.signatur == nil)
        #expect(ergebnis.standort == "Lesesaal")
    }

    @Test func titlesWithoutSignatureAndLocationHaveNoExemplar() throws {
        // z. B. E-Books: ein Exemplar „online“ ohne Signatur und Standort
        #expect(BibMerklisteExemplar(availability: try verfuegbarkeit(exemplar("", "online", standort: nil))) == nil)
        #expect(BibMerklisteExemplar(availability: try verfuegbarkeit("")) == nil)
    }

    @Test func loadingStoresTheExemplarPerTitle() async {
        let h = Harness()
        let item = exemplar("ST 130", "available")
        let json = "{\"object\":\"list\",\"data\":[{\"id\":\"med_1\",\"availabilityStatus\":\"available\",\"items\":[\(item)]}]}"
        let service = h.service(json: json)
        let status = BibMerklisteStatus()
        await status.load(ids: ["med_1"], using: service)
        #expect(status.exemplar(for: "med_1")?.signatur == "ST 130")
        #expect(status.exemplar(for: "med_2") == nil)
    }
}
