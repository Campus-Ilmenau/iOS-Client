import Foundation
import Testing
@testable import Campus_Ilmenau

/// Wartet, bis eine Bedingung gilt, statt feste Pausen zu setzen. Ohne Frist in echter Zeit (siehe `warteBis`).
@MainActor
private func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    await warteBis(condition)
    return true
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LibrarySearchModelTests {
    // MARK: - Kopfzeilen nach der Tabelle in Uebergabe.md

    @Test func localHeaderWithCorrectedQuery() {
        let model = LibrarySearchModel.preview(.bestand)
        #expect(model.header?.line1 == "Ergebnisse für „regelungstechnik ingenieure“")
        #expect(model.header?.line2 == "14 Treffer im Bestand der UB Ilmenau")
        #expect(model.sections.count == 1)
        #expect(model.sections.first?.fromCatalog == false)
        #expect(model.loadMoreCount == 8)   // 14 Treffer, 6 geladen
    }

    @Test func localHeaderWithoutCorrectionShowsTheCount() {
        let model = LibrarySearchModel.preview(.bestand)
        let response = model.response
        #expect(response?.correctedQuery != nil)
        // Ohne Korrektur: „14 Treffer“ in Zeile 1.
        model.response = LibrarySearchResponse.testResponse(total: 14, corrected: nil)
        #expect(model.header?.line1 == "14 Treffer")
    }

    @Test func mixedHeaderAndTwoSections() {
        let model = LibrarySearchModel.preview(.gemischt)
        #expect(model.header?.line1 == "5 Treffer")
        #expect(model.header?.line2 == "Wenig im Bestand der UB – ergänzt aus dem Gesamtkatalog")
        let sections = model.sections
        #expect(sections.map(\.title) == ["Bestand der UB Ilmenau", "Aus dem Gesamtkatalog"])
        #expect(sections.map(\.fromCatalog) == [false, true])
        #expect(sections.map(\.items.count) == [3, 2])
        #expect(model.offersMixedEnd)
        #expect(model.loadMoreCount == nil)   // gemischte Listen enden nach Seite 1
        #expect(!model.offersCatalogContinuation)
    }

    @Test func catalogSuggestedHeaderOffersContinuation() {
        let model = LibrarySearchModel.preview(.verbundZuLangsam)
        #expect(model.header?.line1 == "3 Treffer im Bestand der UB Ilmenau")
        #expect(model.header?.line2 == "Der Gesamtkatalog hat nicht rechtzeitig geantwortet.")
        #expect(model.offersCatalogContinuation)
        #expect(!model.offersMixedEnd)
    }

    @Test func fieldSearchHeaderSummarizesTheFields() {
        let model = LibrarySearchModel.preview(.feldsuche)
        #expect(model.header?.line1 == "23 Treffer im Gesamtkatalog")
        #expect(model.header?.line2 == "Person „Zacher“ · E-Book · 2015–2024 · neueste zuerst")
        #expect(model.sections.first?.fromCatalog == true)   // Chip „Gesamtkatalog“ an jedem Treffer
        #expect(model.isCatalogOnlySearch)
        #expect(model.loadMoreCount == 20)
    }

    @Test func contentSearchHeaderNeedsTheFeatureFlag() {
        let model = LibrarySearchModel.preview(.inhaltssuche)
        #expect(model.header?.line2 == "Auch in Inhaltsverzeichnissen und Klappentexten gesucht")
        #expect(model.searchedInContents)
        #expect(model.items.allSatisfy { $0.match?.snippet != nil })

        model.contentsEnabled = false
        #expect(model.header?.line2 == "2 Treffer im Bestand der UB Ilmenau")
    }

    @Test func emptyStateTextAndCatalogOffer() {
        let model = LibrarySearchModel.preview(.keineTreffer)
        #expect(model.phase == .empty)
        #expect(model.emptyQueryText == "quantenregelung")
        #expect(model.offersCatalogForEmpty)
        model.catalogTried = true
        #expect(!model.offersCatalogForEmpty)
    }

    @Test func staleNoticeUsesTheOldestFetchTime() {
        let model = LibrarySearchModel.preview(.veraltet)
        #expect(model.staleNotice == "Stand von 10:12 – der Katalog antwortet gerade langsam. Verfügbarkeit kann sich geändert haben.")
        model.staleSince = nil
        #expect(model.staleNotice == "Der Katalog antwortet gerade langsam. Verfügbarkeit kann sich geändert haben.")
        model.isStale = false
        #expect(model.staleNotice == nil)
    }

    @Test func fieldSummaryVariants() {
        #expect(LibrarySearchModel.fieldSummary(LibrarySearchQuery(title: "Mechanik", yearFrom: "2015"))
                == "Titel „Mechanik“ · ab 2015 · neueste zuerst")
        #expect(LibrarySearchModel.fieldSummary(LibrarySearchQuery(isbn: "978-3", mediaType: .all, yearTo: "2020"))
                == "ISBN 978-3 · Alle · bis 2020 · neueste zuerst")
        #expect(LibrarySearchModel.fieldSummary(LibrarySearchQuery(subject: "Regelung", mediaType: .printBook))
                == "Schlagwort „Regelung“ · Gedruckt · neueste zuerst")
    }

    @Test func personNamesAreTurnedAround() {
        #expect(LibraryPersonName.display("Lunze, Jan") == "Jan Lunze")
        #expect(LibraryPersonName.display("Lo Iacono, Luigi") == "Luigi Lo Iacono")
        #expect(LibraryPersonName.display("Springer Verlag") == "Springer Verlag")
        #expect(LibraryPersonName.list(["A, B", "C, D", "E, F", "G, H"]) == "B A, D C, F E u. a.")
        #expect(LibraryPersonName.list([]) == "")
    }

    // MARK: - Eingaben

    @Test func fieldsCountOnlyWhileThePanelIsOpen() {
        let model = LibrarySearchModel()
        model.text = "regelung"
        model.author = "Zacher"
        model.yearFrom = "2015"

        let closed = model.currentQuery()
        #expect(closed?.author == "")
        #expect(closed?.yearFrom == "")
        #expect(closed?.mediaType == .printBook)   // „Gedruckt“ ist die Voreinstellung der Pills

        model.advancedOpen = true
        let open = model.currentQuery()
        #expect(open?.author == "Zacher")
        #expect(open?.yearFrom == "2015")
        #expect(open?.isFieldSearch == true)
    }

    @Test func inputLengthsAreLimited() {
        let model = LibrarySearchModel()
        model.text = String(repeating: "a", count: 250)
        #expect(model.text.count == 200)
        model.yearFrom = "20155"
        #expect(model.yearFrom == "2015")
    }

    @Test func noTermMeansNoQuery() {
        let model = LibrarySearchModel()
        #expect(model.currentQuery() == nil)
        model.text = "   "
        #expect(model.currentQuery() == nil)
    }

    // MARK: - Ablauf mit Netzwerk-Stub

    @Test func debounceCollapsesQuickTypingIntoOneRequest() async {
        let h = Harness()
        let json = Sample.list(data: [Sample.book], total: 1)
        let clock = ManualClock()
        let model = LibrarySearchModel(service: h.service(json: json), clock: clock)

        // Vier Eingaben im Abstand von 100 ms: Jede neue setzt die Pause von 700 ms zurück.
        for text in ["j", "ja", "jav", "java"] {
            model.text = text
            model.textChanged()
            await clock.advance(by: .milliseconds(100))
        }
        #expect(h.requestURLs.isEmpty)   // noch in der Pause
        await clock.warte(bisFrist: .milliseconds(1000))   // letzte Eingabe bei 300 ms + 700 ms
        await clock.advance(by: .milliseconds(599))
        #expect(h.requestURLs.isEmpty)   // 699 ms nach der letzten Eingabe
        await clock.advance(by: .milliseconds(1))   // 700 ms: die Suche startet

        #expect(await eventually { model.phase == .results })
        #expect(h.requestURLs.count == 1)
        #expect(h.queryValue("q") == "java")
        #expect(h.queryValue("type") == "print_book")
        #expect(h.queryValue("in") == nil)
        #expect(model.items.count == 1)
    }

    @Test func submitSearchesImmediatelyAndKeepsTheSearchID() async {
        let h = Harness()
        let model = LibrarySearchModel(service: h.service(json: Sample.list(data: [Sample.book], total: 1)))
        model.text = "java"
        model.submit()

        #expect(model.phase == .loading)
        #expect(await eventually { model.phase == .results })
        // search_id gilt je Treffer und geht beim Öffnen eines Titels mit.
        #expect(model.searchID(for: model.items[0]) == "srch_d03b1191")

        // Die nächste Suche hebt die alte ID nicht auf.
        _ = h.service(json: Sample.list(data: [Sample.catalogBook], total: 1).replacingOccurrences(of: "srch_d03b1191", with: "srch_neu"))
        model.text = "python"
        model.submit()
        #expect(await eventually { model.items.first?.id == "med_2000000002" })
        #expect(model.searchIDs["med_1009895648"] == nil)
        #expect(model.searchID(for: model.items[0]) == "srch_neu")
    }

    @Test func clearingTheFieldReturnsToStartWithoutRequest() async {
        let h = Harness()
        let model = LibrarySearchModel(service: h.service(json: Sample.list(data: [Sample.book], total: 1)))
        model.text = "java"
        model.submit()
        #expect(await eventually { model.phase == .results })

        model.clearText()
        #expect(model.phase == .start)
        #expect(model.items.isEmpty)
        #expect(model.searchIDs.isEmpty)
        #expect(h.requestURLs.count == 1)
    }

    @Test func failureShowsRetryAndRetryRecovers() async {
        let h = Harness()
        let clock = ManualClock()
        let model = LibrarySearchModel(service: h.service(
            status: 503, json: Sample.error(code: "catalog_unavailable", message: "x", type: "api_error")
        ), clock: clock)
        model.text = "java"
        model.submit()
        #expect(await eventually { if case .failed = model.phase { true } else { false } })

        _ = h.service(json: Sample.list(data: [Sample.book], total: 1))
        model.retry()
        #expect(await eventually { model.phase == .results })
        #expect(h.requestURLs.count == 2)
    }

    @Test func choosingAMediaTypeSearchesAgain() async {
        let h = Harness()
        let model = LibrarySearchModel(service: h.service(json: Sample.list(data: [Sample.book], total: 1)))
        model.selectKind(.ebook)   // ohne Suchbegriff passiert nichts
        #expect(h.requestURLs.isEmpty)
        model.kind = .printBook
        model.text = "java"
        model.submit()
        #expect(await eventually { model.phase == .results })

        model.selectKind(.journal)
        #expect(await eventually { h.requestURLs.count == 2 })
        #expect(h.queryValue("type") == "journal")
    }

    @Test func advancedSearchValidatesYearsBeforeSending() async {
        let h = Harness()
        let model = LibrarySearchModel(service: h.service(json: Sample.list(data: [], total: 0, source: nil)))
        model.advancedOpen = true
        model.author = "Zacher"
        model.yearFrom = "2030"
        model.yearTo = "2020"
        model.submit()
        #expect(model.formError == "„von“ darf nicht nach „bis“ liegen.")
        #expect(h.requestURLs.isEmpty)
        #expect(model.phase == .start)

        model.yearFrom = "2015"
        model.yearTo = "2024"
        model.submit()
        #expect(model.formError == nil)
        #expect(await eventually { h.requestURLs.count == 1 })
        #expect(h.queryValue("author") == "Zacher")
        #expect(h.queryValue("year_from") == "2015")
    }

    @Test func loadMoreAppendsTheNextPageWithoutDuplicates() async {
        let h = Harness()
        let first = Sample.list(data: [Sample.book], total: 3, hasMore: true)
        let model = LibrarySearchModel(service: h.service(json: first))
        model.text = "java"
        model.submit()
        #expect(await eventually { model.phase == .results })
        #expect(model.loadMoreCount == 2)

        // Seite 2 enthält den ersten Treffer noch einmal und einen neuen.
        _ = h.service(json: Sample.list(data: [Sample.book, Sample.catalogBook], total: 3, hasMore: false))
        await model.loadMore()
        #expect(h.queryValue("page") == "2")
        #expect(model.items.map(\.id) == ["med_1009895648", "med_2000000002"])
        #expect(model.loadMoreCount == nil)
    }

    @Test func continuingInCatalogAddsASectionWithoutShownTitles() async {
        let h = Harness()
        let mixed = Sample.list(data: [Sample.book, Sample.mixedCatalogHit], total: 2, source: "mixed", catalogChecked: true)
        let model = LibrarySearchModel(service: h.service(json: mixed))
        model.text = "regelung"
        model.submit()
        #expect(await eventually { model.phase == .results })
        #expect(model.offersMixedEnd)

        let catalog = Sample.list(
            data: [Sample.mixedCatalogHit, Sample.catalogBook], total: 40, hasMore: true, source: "catalog"
        )
        _ = h.service(json: catalog)
        await model.continueInCatalog()

        #expect(h.queryValue("in") == "catalog")
        #expect(h.queryValue("page") == "1")
        #expect(model.continuationItems.map(\.id) == ["med_2000000002"])   // der schon gezeigte Treffer entfällt
        #expect(model.sections.map(\.title) == ["Bestand der UB Ilmenau", "Aus dem Gesamtkatalog", "Weitere aus dem Gesamtkatalog"])
        #expect(!model.offersMixedEnd)
        #expect(model.catalogTried)
        #expect(model.header?.line2 == "Ergänzt um 40 Treffer aus dem Gesamtkatalog")
        #expect(model.loadMoreCountInCatalog != nil)
    }

    @Test func catalogFromAnEmptyResultBecomesTheList() async {
        let h = Harness()
        let model = LibrarySearchModel(service: h.service(json: Sample.list(data: [], total: 0)))
        model.text = "quantenregelung"
        model.submit()
        #expect(await eventually { model.phase == .empty })
        #expect(model.offersCatalogForEmpty)

        _ = h.service(json: Sample.list(data: [Sample.catalogBook], total: 1, source: "catalog"))
        await model.continueInCatalog()
        #expect(model.phase == .results)
        #expect(model.header?.line1 == "1 Treffer im Gesamtkatalog")
        #expect(model.sections.map(\.title) == [nil])
        #expect(model.sections.first?.fromCatalog == true)
    }

    @Test func availabilityIsRequestedInBatchesOfTwenty() async {
        let h = Harness()
        let clock = ManualClock()
        let model = LibrarySearchModel(service: h.service(json: "{\"object\":\"list\",\"data\":[]}"), clock: clock)
        for number in 1...25 { model.requestAvailability(for: "med_\(number)") }
        model.requestAvailability(for: "med_1")   // doppelt: wird nicht noch einmal gefragt

        // Die Karten werden 80 ms lang gesammelt, dann gehen sie in Stapeln los.
        await clock.warte(bisFrist: .milliseconds(80))
        await clock.advance(by: .milliseconds(80))
        #expect(await eventually { model.availability.count == 25 })
        let counts = h.requestURLs.compactMap { url -> Int? in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "ids" }?.value?.split(separator: ",").count
        }
        #expect(counts.sorted() == [5, 20])
        // Ohne Antwort zur ID bleibt „Status unbekannt“ statt eines endlosen Platzhalters.
        #expect(model.availability["med_3"]?.status == .unknown)
    }

    @Test func availabilityFailureFallsBackToUnknown() async {
        let h = Harness()
        let clock = ManualClock()
        let model = LibrarySearchModel(service: h.service(
            status: 503, json: Sample.error(code: "catalog_unavailable", message: "x", type: "api_error")
        ), clock: clock)
        model.requestAvailability(for: "med_1")
        await clock.warte(bisFrist: .milliseconds(80))
        await clock.advance(by: .milliseconds(80))
        #expect(await eventually { model.availability["med_1"] != nil })
        #expect(model.availability["med_1"]?.status == .unknown)
    }

    @Test func staleAvailabilityMarksTheList() async {
        let h = Harness()
        let clock = ManualClock()
        let model = LibrarySearchModel(service: h.service(
            headers: ["X-Cache-Status": "stale"], json: "{\"object\":\"list\",\"data\":[]}"
        ), clock: clock)
        model.requestAvailability(for: "med_1")
        await clock.warte(bisFrist: .milliseconds(80))
        await clock.advance(by: .milliseconds(80))
        #expect(await eventually { model.isStale })
        #expect(model.staleNotice != nil)
    }
}

extension LibrarySearchResponse {
    /// Antwort für Tests der Kopfzeile.
    static func testResponse(total: Int, corrected: String?) -> LibrarySearchResponse {
        let json = Sample.list(data: [], total: total, corrected: corrected)
        // swiftlint:disable:next force_try
        return try! LibraryCatalogService.decoder.decode(LibrarySearchResponse.self, from: Data(json.utf8))
    }
}
