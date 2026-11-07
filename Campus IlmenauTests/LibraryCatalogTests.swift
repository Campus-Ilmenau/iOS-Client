import Foundation
import Testing
@testable import Campus_Ilmenau

// MARK: - Stub für das Netzwerk

/// Antwortet pro Host mit einer festen Antwort und merkt sich die Anfragen. Jeder Test nutzt einen eigenen Host,
/// damit parallele Tests sich nicht in die Quere kommen.
final class StubRegistry: @unchecked Sendable {
    struct Stub {
        var status: Int
        var headers: [String: String]
        var body: Data
    }

    private let lock = NSLock()
    private var stubs: [String: Stub] = [:]
    /// Antworten je Host und Pfad; sie gehen der Antwort des Hosts vor.
    private var routes: [String: [String: Stub]] = [:]
    /// Antworten je Host und Pfad, nur wenn die Query den Text enthält (z. B. `date=2026-11-05`).
    private var queryRoutes: [String: [(path: String, fragment: String, stub: Stub)]] = [:]
    private var requests: [String: [URL]] = [:]

    func set(_ stub: Stub, host: String) {
        lock.lock(); defer { lock.unlock() }
        stubs[host] = stub
    }

    func setRoute(_ stub: Stub, path: String, host: String) {
        lock.lock(); defer { lock.unlock() }
        routes[host, default: [:]][path] = stub
    }

    func setRoute(_ stub: Stub, path: String, queryContains fragment: String, host: String) {
        lock.lock(); defer { lock.unlock() }
        queryRoutes[host, default: []].append((path, fragment, stub))
    }

    func stub(host: String, path: String = "", query: String = "") -> Stub? {
        lock.lock(); defer { lock.unlock() }
        if let match = queryRoutes[host]?.first(where: { $0.path == path && query.contains($0.fragment) }) {
            return match.stub
        }
        return routes[host]?[path] ?? stubs[host]
    }

    func record(_ url: URL, host: String) {
        lock.lock(); defer { lock.unlock() }
        requests[host, default: []].append(url)
    }

    func urls(host: String) -> [URL] {
        lock.lock(); defer { lock.unlock() }
        return requests[host] ?? []
    }
}

let registry = StubRegistry()

final class LibraryStubProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host, let stub = registry.stub(host: host, path: url.path, query: url.query ?? "") else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        registry.record(url, host: host)
        let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: stub.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

struct Harness {
    let host = "t-\(UUID().uuidString.lowercased()).test"

    @MainActor
    func service(
        status: Int = 200,
        headers: [String: String] = [:],
        json: String = "{}",
        body: Data? = nil
    ) -> LibraryCatalogService {
        var allHeaders = headers
        if allHeaders["Content-Type"] == nil { allHeaders["Content-Type"] = "application/json; charset=utf-8" }
        registry.set(.init(status: status, headers: allHeaders, body: body ?? Data(json.utf8)), host: host)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LibraryStubProtocol.self]
        return LibraryCatalogService(baseURL: "https://\(host)/develop", session: URLSession(configuration: configuration))
    }

    var requestURLs: [URL] { registry.urls(host: host) }

    /// Eigene Antwort für einen Pfad, wenn die Query einen Text enthält (z. B. `date=2026-11-05`).
    func route(_ path: String, queryContains fragment: String, status: Int = 200, json: String) {
        registry.setRoute(
            .init(status: status, headers: ["Content-Type": "application/json; charset=utf-8"], body: Data(json.utf8)),
            path: path,
            queryContains: fragment,
            host: host
        )
    }

    /// Wie `service`, für die Events-API.
    @MainActor
    func eventsService(status: Int = 200, json: String = "{}") -> EventsService {
        registry.set(
            .init(status: status, headers: ["Content-Type": "application/json; charset=utf-8"], body: Data(json.utf8)),
            host: host
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LibraryStubProtocol.self]
        return EventsService(baseURL: "https://\(host)/develop", session: URLSession(configuration: configuration))
    }

    /// Eigene Antwort für einen Pfad (z. B. `/develop/v1/library/features`).
    func route(_ path: String, status: Int = 200, json: String) {
        registry.setRoute(
            .init(status: status, headers: ["Content-Type": "application/json; charset=utf-8"], body: Data(json.utf8)),
            path: path,
            host: host
        )
    }

    func queryValue(_ name: String) -> String? {
        guard let url = requestURLs.last,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        return items.first { $0.name == name }?.value
    }
}

// MARK: - Beispiel-JSON

enum Sample {
    /// Titel aus der Dev-API (gekürzt).
    static let book = """
    {"id":"med_1009895648","object":"media","ppn":"1009895648","mediaType":"print_book",
     "title":"Programmieren trainieren","subtitle":"mit über 120 Workouts in Java und Python",
     "authors":["Lo Iacono, Luigi","Wiefling, Stephan"],"edition":null,"year":"2018","publisher":"Hanser",
     "isbns":["978-3-446-45486-6"],"language":"ger","subjects":["Java","Python"],"rvk":["ST 250"],
     "onlineUrl":null,"catalogUrl":"https://opac.lbs-ilmenau.gbv.de/DB=1/PPNSET?PPN=1009895648","abstract":null,
     "links":[{"kind":"table_of_contents","url":"https://www.gbv.de/dms/tib-ub-hannover/1009895648.pdf","mimeType":"pdf/application"}],
     "fetchedAt":"2026-10-29T00:06:54.519Z",
     "cover":{"status":"found","url":"/v1/library/media/med_1009895648/cover","width":335,"height":500},
     "match":{"fields":["title","subject","toc"],"stage":"exact"}}
    """

    static func list(
        data: [String],
        total: Int,
        hasMore: Bool = false,
        source: String? = "local",
        corrected: String? = nil,
        catalogChecked: Bool = false,
        catalogTotal: String = "null",
        suggested: Bool = false
    ) -> String {
        let correctedJSON = corrected.map { "\"\($0)\"" } ?? "null"
        let sourceJSON = source.map { "\"scope\":\"\($0)\",\"source\":\"\($0)\"," } ?? ""
        return """
        {"object":"list","url":"/v1/library/search?q=java","has_more":\(hasMore),"total_count":\(total),"page":1,"per_page":20,
         "data":[\(data.joined(separator: ","))],\(sourceJSON)"corrected_query":\(correctedJSON),
         "catalog_checked":\(catalogChecked),"catalog_total":\(catalogTotal),"catalog_suggested":\(suggested),
         "search_id":"srch_d03b1191"}
        """
    }

    /// Titel, der nur im Gesamtkatalog steht (Form wie im Bestand; ob die API Verbund-Treffer kennzeichnet, ist offen).
    static let catalogBook = """
    {"id":"med_2000000002","object":"media","ppn":"2000000002","mediaType":"ebook","title":"Java im Verbund",
     "authors":[],"isbns":[],"subjects":[],"rvk":[],"links":[],"onlineUrl":"https://example.org/read",
     "catalogUrl":null,"cover":{"status":"none","url":null,"width":null,"height":null}}
    """

    static let detail = """
    {"id":"med_1","object":"media","ppn":"1","mediaType":"print_book","title":"Regelungstechnik 1","subtitle":null,
     "authors":["Lunze, Jan"],"edition":"12. Auflage","year":"2020","publisher":"Springer","isbns":[],"language":"ger",
     "subjects":[],"rvk":["ZQ 5200"],"onlineUrl":null,"catalogUrl":"https://opac.example/PPN=1","abstract":null,"links":[],
     "fetchedAt":"2026-10-29T00:06:54.519Z",
     "items":[
       {"label":"MSR 300 L971","location":{"id":"inf","code":"53","name":"52/53 INF","floorPlanUrl":"https://example.org/plan.png"},
        "status":"on_loan","dueDate":"2026-11-05","reserveUrl":"https://opac.example/reserve?1","queue":3},
       {"label":"MSR 300 L971(2)","location":{"id":"inf","code":"53","name":"52/53 INF","floorPlanUrl":null},
        "status":"on_loan","dueDate":"2026-11-12","reserveUrl":null,"queue":null}],
     "availabilityStatus":"on_loan",
     "cover":{"status":"pending","url":"/v1/library/media/med_1/cover","width":null,"height":null},
     "contentsStatus":"available",
     "contents":{"tableOfContents":{"text":"Inhalt","entries":[
        {"number":"1","title":"Einführung","page":"3","level":1},
        {"number":"1.1","title":"Grundbegriffe","page":"4","level":2}],
        "sourceUrl":"https://example.org/toc.pdf","extractedAt":"2026-10-29T00:30:51.947Z"},
       "blurb":{"text":"Das Standardwerk."}}}
    """

    static func error(code: String, message: String, param: String? = nil, type: String = "invalid_request_error") -> String {
        let paramJSON = param.map { ",\"param\":\"\($0)\"" } ?? ""
        return "{\"error\":{\"type\":\"\(type)\",\"code\":\"\(code)\",\"message\":\"\(message)\"\(paramJSON),\"request_id\":\"req_1\"}}"
    }

    /// Treffer aus dem Gesamtkatalog in einer gemischten Antwort: `match.stage == "catalog"`, keine Felder.
    static let mixedCatalogHit = """
    {"id":"med_2000000001","object":"media","ppn":"2000000001","mediaType":"print_book","title":"Java im Verbund",
     "authors":[],"isbns":[],"subjects":[],"rvk":[],"links":[],"onlineUrl":null,"catalogUrl":null,
     "fetchedAt":"2026-11-04T10:12:00.000Z",
     "cover":{"status":"none","url":null,"width":null,"height":null},
     "match":{"fields":[],"stage":"catalog"}}
    """

    /// Treffer der Inhaltssuche (`in=content`) mit Ausschnitt.
    static let contentHit = """
    {"id":"med_3","object":"media","ppn":"3","mediaType":"print_book","title":"Programmieren trainieren",
     "authors":[],"isbns":[],"subjects":[],"rvk":[],"links":[],"onlineUrl":null,"catalogUrl":null,
     "cover":{"status":"none","url":null,"width":null,"height":null},
     "match":{"fields":["toc","blurb"],"stage":"exact","snippet":"… W.6.23 Sudoku-Check 115 W.6.24 Medianfilter 116 …"}}
    """
}

// MARK: - Tests

@MainActor
struct LibraryCatalogTests {
    // MARK: Suche: Antworten

    @Test func localSearchDecodesHitsAndMetadata() async throws {
        let h = Harness()
        let json = Sample.list(data: [Sample.book], total: 12, hasMore: true)
        let result = try await h.service(headers: ["X-Cache-Status": "hit", "X-Request-Id": "req_abc"], json: json)
            .search(LibrarySearchQuery(text: "java"))

        let response = result.value
        #expect(response.source == .local)
        #expect(response.totalCount == 12)
        #expect(response.hasMore)
        #expect(response.page == 1 && response.perPage == 20)
        #expect(response.searchId == "srch_d03b1191")
        #expect(response.correctedQuery == nil)
        #expect(!response.catalogSuggested)

        let book = try #require(response.items.first)
        #expect(book.id == "med_1009895648")
        #expect(book.mediaType == .printBook)
        #expect(book.authors.count == 2)
        #expect(book.language == "ger")
        #expect(book.languageName == "Deutsch")
        #expect(book.cover.status == .found)
        #expect(book.match?.stage == .exact)
        #expect(book.match?.isInTableOfContents == true)
        #expect(book.fetchedAt != nil)
        #expect(book.links.first?.kind == "table_of_contents")

        #expect(!result.info.isStale)
        #expect(result.info.cacheStatus == "hit")
        #expect(result.info.requestId == "req_abc")
    }

    @Test func mixedSearchKeepsSourceAndCatalogFields() async throws {
        let h = Harness()
        let json = Sample.list(
            data: [Sample.book, Sample.mixedCatalogHit], total: 2, source: "mixed",
            catalogChecked: true, catalogTotal: "40"
        )
        let response = try await h.service(json: json).search(LibrarySearchQuery(text: "regelung")).value

        #expect(response.source == .mixed)
        #expect(response.catalogChecked)
        #expect(response.catalogTotal == 40)
        #expect(!response.hasMore)
        #expect(response.items.count == 2)
        // Katalog-Treffer sind einzeln markiert: `match.stage == catalog`, ohne Felder.
        let local = try #require(response.items.first)
        let catalogHit = try #require(response.items.last)
        #expect(catalogHit.match?.stage == .catalog)
        #expect(catalogHit.match?.fields.isEmpty == true)
        #expect(catalogHit.isMarkedAsCatalogHit)
        #expect(response.isFromCatalog(catalogHit))
        #expect(!response.isFromCatalog(local))
        #expect(catalogHit.cover.status == .absent)
    }

    @Test func missingOptionalFieldsGetFallbacks() async throws {
        let h = Harness()
        let response = try await h.service(json: Sample.list(data: [Sample.catalogBook], total: 1, source: nil)).search(LibrarySearchQuery(title: "java")).value
        let item = try #require(response.items.first)
        #expect(item.match == nil)
        #expect(item.cover.status == .absent)
        #expect(item.onlineUrl?.absoluteString == "https://example.org/read")
        #expect(item.catalogUrl == nil)
        #expect(item.authors.isEmpty)
    }

    @Test func mixedContinuesInCatalogWithoutDuplicates() async throws {
        let h = Harness()
        // Die Katalog-Liste enthält den schon gezeigten Katalog-Treffer noch einmal.
        let json = Sample.list(data: [Sample.mixedCatalogHit, Sample.catalogBook], total: 40, hasMore: true, source: "catalog")
        let query = LibrarySearchQuery(text: "java", page: 1)
        let continued = query.continuedInCatalog()
        #expect(continued.scope == .catalog)
        #expect(continued.page == 1)

        let response = try await h.service(json: json).search(continued).value
        #expect(h.queryValue("in") == "catalog")
        #expect(h.queryValue("page") == "1")
        #expect(response.source == .catalog)
        let fresh = response.items(excluding: ["med_2000000001"])
        #expect(fresh.count == 1)
        #expect(fresh.first?.title == "Java im Verbund")
        #expect(fresh.first.map(response.isFromCatalog) == true)
    }

    @Test func contentSearchCarriesSnippets() async throws {
        let h = Harness()
        let json = Sample.list(data: [Sample.contentHit], total: 15, hasMore: true)
        let response = try await h.service(json: json).search(LibrarySearchQuery(text: "Sudoku-Check", scope: .content)).value

        #expect(h.queryValue("in") == "content")
        let match = try #require(response.items.first?.match)
        #expect(match.snippet == "… W.6.23 Sudoku-Check 115 W.6.24 Medianfilter 116 …")
        #expect(match.isInTableOfContents)
        #expect(match.isInBlurb)
        #expect(match.fields == [.tableOfContents, .blurb])
    }

    @Test func matchStagesAndFieldsKnowAllDocumentedValues() {
        #expect(LibraryMatchStage(code: "relaxed") == .relaxed)
        #expect(LibraryMatchStage(code: "catalog") == .catalog)
        #expect(LibraryMatchStage(code: "neu") == .other("neu"))
        #expect(LibraryMatchField(code: "author") == .author)
        #expect(LibraryMatchField(code: "abstract") == .abstract)
        #expect(LibraryContentsStatus(code: "pending") == .pending)
        #expect(LibraryContentsStatus(code: "unavailable") == .unavailable)
        #expect(LibraryContentsStatus(code: "disabled") == .disabled)
    }

    @Test func catalogSuggestedIsReported() async throws {
        let h = Harness()
        let json = Sample.list(data: [Sample.book], total: 3, suggested: true)
        let response = try await h.service(json: json).search(LibrarySearchQuery(text: "regelung")).value

        #expect(response.catalogSuggested)
        #expect(!response.catalogChecked)
        #expect(response.totalCount == 3)
        #expect(response.source == .local)
    }

    @Test func emptyResultIsNotAnError() async throws {
        let h = Harness()
        let json = Sample.list(data: [], total: 0, catalogChecked: true, catalogTotal: "0")
        let response = try await h.service(json: json).search(LibrarySearchQuery(text: "xqzxqzxq")).value

        #expect(response.items.isEmpty)
        #expect(response.totalCount == 0)
        #expect(!response.hasMore)
        #expect(response.catalogTotal == 0)
    }

    @Test func correctedQueryAndStageAreDecoded() async throws {
        let h = Harness()
        let corrected = Sample.book.replacingOccurrences(of: "\"stage\":\"exact\"", with: "\"stage\":\"corrected\"")
        let json = Sample.list(data: [corrected], total: 13, corrected: "java")
        let response = try await h.service(json: json).search(LibrarySearchQuery(text: "javva")).value

        #expect(response.correctedQuery == "java")
        #expect(response.items.first?.match?.stage == .corrected)
    }

    @Test func fieldSearchResponseHasNoSource() async throws {
        let h = Harness()
        let json = Sample.list(data: [Sample.catalogBook], total: 13, hasMore: true, source: nil)
        let query = LibrarySearchQuery(author: "Zacher", mediaType: .ebook, yearFrom: "2015", yearTo: "2024")
        let response = try await h.service(json: json).search(query).value

        #expect(query.isFieldSearch)
        #expect(response.source == nil)
        #expect(response.items.first?.mediaType == .ebook)
    }

    // MARK: Suche: Hinweise und Fehler

    @Test func staleCacheStatusSetsHintAndAge() async throws {
        let h = Harness()
        let json = Sample.list(data: [Sample.book, Sample.mixedCatalogHit], total: 2)
        let result = try await h.service(headers: ["X-Cache-Status": "stale"], json: json)
            .search(LibrarySearchQuery(text: "java"))

        #expect(result.info.isStale)
        #expect(result.info.cacheStatus == "stale")
        #expect(result.value.items.count == 2)
        // „Stand von …“: der älteste Abruf der Liste (die API hat keinen Zeitstempel für die ganze Liste).
        #expect(result.value.oldestFetchedAt == LibraryDateParsing.date(from: "2026-10-29T00:06:54.519Z"))
    }

    @Test func catalogUnavailable503() async {
        let h = Harness()
        // Format laut API-Team: type api_error, ohne Retry-After.
        let service = h.service(
            status: 503,
            json: Sample.error(code: "catalog_unavailable", message: "Catalog is not reachable.", type: "api_error")
        )
        do {
            _ = try await service.search(LibrarySearchQuery(text: "java"))
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let LibraryAPIError.catalogUnavailable(retryAfter) {
            #expect(retryAfter == nil)
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
    }

    @Test func retryAfterIsReadWhenPresent() async {
        let h = Harness()
        let service = h.service(
            status: 503,
            headers: ["Retry-After": "7"],
            json: Sample.error(code: "catalog_unavailable", message: "x", type: "api_error")
        )
        do {
            _ = try await service.features()
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let LibraryAPIError.catalogUnavailable(retryAfter) {
            #expect(retryAfter == 7)
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
    }

    @Test func otherServerErrorsKeepTheirCode() async {
        let h = Harness()
        let service = h.service(status: 503, json: Sample.error(code: "maintenance", message: "Wartung", type: "api_error"))
        do {
            _ = try await service.features()
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let LibraryAPIError.apiError(status, code, _, _) {
            #expect(status == 503)
            #expect(code == "maintenance")
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
    }

    @Test func serviceUnavailableWithoutBodyIsAlsoCatalogUnavailable() async {
        let h = Harness()
        let service = h.service(status: 503, body: Data("<html>Bad Gateway</html>".utf8))
        do {
            _ = try await service.media(id: "med_1")
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let error as LibraryAPIError {
            guard case .catalogUnavailable(let retryAfter) = error else {
                Issue.record("Falscher Fehler: \(error)"); return
            }
            #expect(retryAfter == nil)
            #expect(error.errorDescription == "Katalog gerade nicht erreichbar")
            #expect(error.isRetryable)
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
    }

    @Test func badRequestCarriesTheParameter() async {
        let h = Harness()
        let service = h.service(
            status: 400,
            json: Sample.error(code: "invalid_parameter_format", message: "year_from must not be after year_to", param: "year_from")
        )
        do {
            _ = try await service.media(id: "med_x")
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let LibraryAPIError.badRequest(param, message) {
            #expect(param == "year_from")
            #expect(message.contains("year_from"))
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
    }

    @Test func notFound404() async {
        let h = Harness()
        let service = h.service(
            status: 404,
            json: Sample.error(code: "resource_missing", message: "No media with ID 'med_9' exists.", param: "id")
        )
        do {
            _ = try await service.media(id: "med_9999999999")
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let error as LibraryAPIError {
            guard case .notFound = error else { Issue.record("Falscher Fehler: \(error)"); return }
            #expect(error.errorDescription == "Titel nicht gefunden")
            #expect(!error.isRetryable)
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
    }

    @Test func offlineBecomesNetworkError() async {
        // Kein Stub für diesen Host: der Stub meldet „nicht verbunden“.
        let host = "t-offline-\(UUID().uuidString.lowercased()).test"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LibraryStubProtocol.self]
        let service = LibraryCatalogService(baseURL: "https://\(host)/develop", session: URLSession(configuration: configuration))
        do {
            _ = try await service.features()
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let error as LibraryAPIError {
            guard case .networkError = error else { Issue.record("Falscher Fehler: \(error)"); return }
            #expect(error.isRetryable)
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
    }

    // MARK: Eingabeprüfung

    @Test func invalidQueryIsRejectedBeforeSending() async {
        let h = Harness()
        let service = h.service(json: Sample.list(data: [], total: 0))
        do {
            _ = try await service.search(LibrarySearchQuery(text: "java", yearFrom: "2030", yearTo: "2020"))
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let LibraryAPIError.invalidQuery(issues) {
            #expect(issues.contains { $0.field == .yearFrom })
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
        #expect(h.requestURLs.isEmpty)
    }

    @Test func yearValidation() {
        func issues(_ from: String, _ to: String) -> [LibraryQueryField] {
            LibrarySearchQuery.validateYears(from: from, to: to).map(\.field)
        }
        // gültig
        #expect(issues("", "").isEmpty)
        #expect(issues("2015", "2024").isEmpty)
        #expect(issues("2015", "").isEmpty)
        #expect(issues("", "2024").isEmpty)
        #expect(issues("2020", "2020").isEmpty)
        #expect(issues("1900", "2050").isEmpty)        // genau 150 Jahre
        // nicht vierstellig
        #expect(issues("15", "") == [.yearFrom])
        #expect(issues("", "20245") == [.yearTo])
        #expect(issues("abcd", "") == [.yearFrom])
        #expect(issues("0999", "") == [.yearFrom])     // die API verlangt mindestens 1000
        #expect(issues("２０２０", "") == [.yearFrom])   // keine Ziffern aus anderen Schriften
        #expect(issues("20 20", "") == [.yearFrom])
        // von nach bis
        #expect(issues("2030", "2020") == [.yearFrom])
        // mehr als 150 Jahre
        #expect(issues("1800", "1951") == [.yearTo])
        // beide kaputt
        #expect(issues("x", "y") == [.yearFrom, .yearTo])
    }

    @Test func yearsAreTrimmedBeforeChecking() {
        #expect(LibrarySearchQuery.validateYears(from: " 2015 ", to: "2024\n").isEmpty)
    }

    @Test func textAndTermRules() {
        #expect(LibrarySearchQuery().validate().first?.field == .text)
        #expect(LibrarySearchQuery(text: "   ").validate().first?.field == .text)
        #expect(LibrarySearchQuery(text: "java").validate().isEmpty)
        #expect(LibrarySearchQuery(isbn: "978-3-446-45486-6").validate().isEmpty)
        #expect(LibrarySearchQuery(text: String(repeating: "a", count: 200)).validate().isEmpty)
        #expect(LibrarySearchQuery(text: String(repeating: "a", count: 201)).validate().count == 1)
        // Jahre allein sind kein Suchbegriff.
        #expect(LibrarySearchQuery(yearFrom: "2015", yearTo: "2020").validate().first?.field == .text)
    }

    // MARK: Anfragen

    @Test func fieldSearchBuildsTheQuery() async throws {
        let h = Harness()
        let service = h.service(json: Sample.list(data: [], total: 0, source: nil))
        let query = LibrarySearchQuery(
            title: "Regelung", author: "Lunze", isbn: "978-3-662-60746-0", subject: "Automatisierung",
            mediaType: .ebook, yearFrom: "2015", yearTo: "2024", page: 2
        )
        _ = try await service.search(query)

        #expect(h.queryValue("title") == "Regelung")
        #expect(h.queryValue("author") == "Lunze")
        #expect(h.queryValue("isbn") == "978-3-662-60746-0")
        #expect(h.queryValue("subject") == "Automatisierung")
        #expect(h.queryValue("type") == "ebook")
        #expect(h.queryValue("year_from") == "2015")
        #expect(h.queryValue("year_to") == "2024")
        #expect(h.queryValue("page") == "2")
        #expect(h.queryValue("per_page") == "20")
        #expect(h.queryValue("q") == nil)
        #expect(h.requestURLs.last?.path == "/develop/v1/library/search")
    }

    @Test func freeTextSendsOnlyQ() async throws {
        let h = Harness()
        _ = try await h.service(json: Sample.list(data: [], total: 0)).search(LibrarySearchQuery(text: " java "))
        #expect(h.queryValue("q") == "java")
        #expect(h.queryValue("type") == nil)
        #expect(h.queryValue("title") == nil)
        #expect(h.queryValue("year_from") == nil)
    }

    @Test func plusSignsAndUmlautsSurviveEncoding() async throws {
        let h = Harness()
        _ = try await h.service(json: Sample.list(data: [], total: 0)).search(LibrarySearchQuery(text: "C++ Übungen & mehr"))
        let raw = try #require(h.requestURLs.last?.absoluteString)
        #expect(raw.contains("q=C%2B%2B%20%C3%9Cbungen%20%26%20mehr"))
        #expect(h.queryValue("q") == "C++ Übungen & mehr")
    }

    @Test func nextPageKeepsTheSearch() {
        let query = LibrarySearchQuery(text: "java", mediaType: .printBook)
        let next = query.nextPage()
        #expect(next.page == 2)
        #expect(next.text == "java")
        #expect(next.mediaType == .printBook)
    }

    @Test func scopeIsSentAsIn() async throws {
        let h = Harness()
        let service = h.service(json: Sample.list(data: [], total: 0))
        _ = try await service.search(LibrarySearchQuery(text: "java", scope: .local))
        #expect(h.queryValue("in") == "local")
        _ = try await service.search(LibrarySearchQuery(text: "java"))
        #expect(h.queryValue("in") == nil)
        _ = try await service.search(LibrarySearchQuery(text: "java", scope: .catalog))
        #expect(h.queryValue("in") == "catalog")
    }

    @Test func localAndContentSearchSendOnlyTheText() async throws {
        let h = Harness()
        let service = h.service(json: Sample.list(data: [], total: 0))
        // Die API ignoriert Felder bei in=local/content ohne Fehler; die App sendet sie deshalb gar nicht.
        let query = LibrarySearchQuery(text: "java", title: "Regelung", author: "Lunze", scope: .local, mediaType: .all, yearFrom: "2015")
        _ = try await service.search(query)
        #expect(h.queryValue("q") == "java")
        #expect(h.queryValue("title") == nil)
        #expect(h.queryValue("author") == nil)
        // `type` und Jahre gelten in allen Fällen.
        #expect(h.queryValue("type") == "all")
        #expect(h.queryValue("year_from") == "2015")
        #expect(!query.isFieldSearch)
    }

    @Test func fieldsAloneAreNoTermForLocalSearch() {
        #expect(!LibrarySearchQuery(title: "java", scope: .local).validate().isEmpty)
        #expect(!LibrarySearchQuery(author: "Zacher", scope: .content).validate().isEmpty)
        #expect(LibrarySearchQuery(title: "java", scope: .catalog).validate().isEmpty)
        #expect(LibrarySearchQuery(title: "java").validate().isEmpty)
        #expect(LibrarySearchQuery(text: "java", scope: .local).validate().isEmpty)
    }

    @Test func freeTextAndFieldsMayBeCombinedWithoutScope() async throws {
        let h = Harness()
        _ = try await h.service(json: Sample.list(data: [], total: 0, source: nil))
            .search(LibrarySearchQuery(text: "regelung", author: "Lunze"))
        #expect(h.queryValue("q") == "regelung")
        #expect(h.queryValue("author") == "Lunze")
    }

    @Test func catalogSuggestedContinuesInCatalogFromPageOne() {
        let query = LibrarySearchQuery(text: "regelung", mediaType: .ebook, page: 3)
        let continued = query.continuedInCatalog()
        #expect(continued.scope == .catalog)
        #expect(continued.page == 1)
        #expect(continued.text == "regelung")
        #expect(continued.mediaType == .ebook)
    }

    // MARK: Verfügbarkeit

    @Test func availabilityIsReturnedByID() async throws {
        let h = Harness()
        let json = """
        {"object":"list","data":[
          {"id":"med_1","availabilityStatus":"available","items":[
            {"label":"INF 1","location":{"id":"inf","code":"53","name":"52/53 INF","floorPlanUrl":null},"status":"available","dueDate":null,"reserveUrl":null,"queue":null}]},
          {"id":"med_2","availabilityStatus":"on_loan","items":[
            {"label":"INF 2","location":null,"status":"on_loan","dueDate":"2026-11-05","reserveUrl":null,"queue":2},
            {"label":"INF 2(2)","location":null,"status":"on_loan","dueDate":"2026-11-02","reserveUrl":null,"queue":1}]},
          {"id":"med_3","availabilityStatus":"unknown","items":[]}]}
        """
        let result = try await h.service(json: json).availability(ids: ["med_1", "med_2", "med_3", "med_1"])

        #expect(h.queryValue("ids") == "med_1,med_2,med_3")   // doppelte IDs entfallen
        #expect(result.value["med_1"]?.status == .available)
        #expect(result.value["med_1"]?.availableCount == 1)
        #expect(result.value["med_2"]?.status == .onLoan)
        #expect(result.value["med_2"]?.totalQueue == 3)
        #expect(result.value["med_2"]?.earliestDueDate == LibraryDateParsing.date(from: "2026-11-02"))
        #expect(result.value["med_3"]?.status == .unknown)
        #expect(result.value["med_3"]?.items.isEmpty == true)
    }

    @Test func availabilityAllowsAtMostTwentyIDs() async throws {
        let h = Harness()
        let service = h.service(json: "{\"object\":\"list\",\"data\":[]}")

        let twenty = (1...20).map { "med_\($0)" }
        _ = try await service.availability(ids: twenty)
        #expect(h.requestURLs.count == 1)

        let twentyOne = (1...21).map { "med_\($0)" }
        do {
            _ = try await service.availability(ids: twentyOne)
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let LibraryAPIError.tooManyIDs(count) {
            #expect(count == 21)
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
        #expect(h.requestURLs.count == 1)   // die 21er-Anfrage wurde nicht gesendet
    }

    @Test func availabilityWithoutIDsSendsNothing() async throws {
        let h = Harness()
        let result = try await h.service().availability(ids: [])
        #expect(result.value.isEmpty)
        #expect(h.requestURLs.isEmpty)
    }

    // MARK: Detail

    @Test func detailDecodesItemsStatusAndContents() async throws {
        let h = Harness()
        let result = try await h.service(json: Sample.detail).media(id: "med_1", searchId: "srch_42", track: true)
        let detail = result.value

        #expect(detail.media.title == "Regelungstechnik 1")
        #expect(detail.media.edition == "12. Auflage")
        #expect(detail.media.cover.status == .pending)
        #expect(detail.availabilityStatus == .onLoan)
        #expect(detail.items.count == 2)

        let first = try #require(detail.items.first)
        #expect(first.label == "MSR 300 L971")
        #expect(first.location?.name == "52/53 INF")
        #expect(first.location?.code == "53")
        #expect(first.location?.floorPlanUrl?.absoluteString == "https://example.org/plan.png")
        #expect(first.status == .onLoan)
        #expect(first.queue == 3)
        #expect(first.reserveUrl?.absoluteString == "https://opac.example/reserve?1")
        #expect(first.statusText == "Ausgeliehen bis \(BibliothekFormat.shortDate(try #require(first.dueDate)))")
        #expect(detail.items.last?.location?.floorPlanUrl == nil)

        #expect(detail.availability.earliestDueDate == LibraryDateParsing.date(from: "2026-11-05"))
        #expect(detail.availability.totalQueue == 3)
        #expect(detail.contentsStatus == .available)
        #expect(detail.contents?.hasTableOfContents == true)
        #expect(detail.contents?.tableOfContents?.entries.map(\.level) == [1, 2])
        #expect(detail.contents?.tableOfContents?.entries.first?.page == "3")
        #expect(detail.contents?.blurb?.text == "Das Standardwerk.")
    }

    @Test func detailSendsSearchIdAndTrackFlag() async throws {
        let h = Harness()
        let service = h.service(json: Sample.detail)

        _ = try await service.media(id: "med_1", searchId: "srch_42")
        #expect(h.queryValue("search_id") == "srch_42")
        #expect(h.queryValue("track") == nil)
        #expect(h.requestURLs.last?.path == "/develop/v1/library/media/med_1")

        // Beim Neuladen einer offenen Seite: nicht noch einmal zählen.
        _ = try await service.media(id: "med_1", searchId: "srch_42", track: false)
        #expect(h.queryValue("track") == "false")

        _ = try await service.media(id: "med_1")
        #expect(h.queryValue("search_id") == nil)
    }

    @Test func detailWithoutItemsHasUnknownStatus() async throws {
        let h = Harness()
        let json = Sample.detail
            .replacingOccurrences(of: "\"availabilityStatus\":\"on_loan\"", with: "\"availabilityStatus\":\"unknown\"")
        let minimal = """
        {"id":"med_5","title":"Ohne Exemplare","items":[],"availabilityStatus":"unknown"}
        """
        let detail = try await h.service(json: minimal).media(id: "med_5").value
        #expect(detail.items.isEmpty)
        #expect(detail.availabilityStatus == .unknown)
        #expect(detail.media.authors.isEmpty)
        #expect(detail.media.cover.status == .absent)
        #expect(detail.contents == nil)
        _ = json
    }

    @Test func disabledContentsHaveNoContents() async throws {
        let h = Harness()
        let json = """
        {"id":"med_6","title":"Ohne Inhalte","items":[],"availabilityStatus":"unknown","contentsStatus":"disabled"}
        """
        let detail = try await h.service(json: json).media(id: "med_6").value
        #expect(detail.contentsStatus == .disabled)
        #expect(detail.contents == nil)
        #expect(!detail.hasContents)

        let full = try await Harness().service(json: Sample.detail).media(id: "med_1").value
        #expect(full.hasContents)
    }

    // MARK: Features

    @Test func featuresAreNotStored() async throws {
        let h = Harness()
        let on = try await h.service(json: "{\"object\":\"library_features\",\"contents\":true}").features().value
        #expect(on.contents)
        let off = try await h.service(json: "{\"object\":\"library_features\",\"contents\":false}").features().value
        #expect(!off.contents)
    }

    // MARK: Cover

    @Test func coverStatusDecidesWhetherToAsk() async throws {
        let h = Harness()
        let service = h.service(body: Data([0xFF, 0xD8, 0xFF]))
        #expect(try await service.fetchCover(for: .missing) == .missing)
        #expect(try await service.fetchCover(for: LibraryCover(status: .disabled, url: "/x", width: nil, height: nil)) == .missing)
        #expect(h.requestURLs.isEmpty)

        let found = LibraryCover(status: .found, url: "/v1/library/media/med_1/cover", width: 335, height: 500)
        let result = try await service.fetchCover(for: found)
        #expect(result == .image(Data([0xFF, 0xD8, 0xFF]), mimeType: "application/json; charset=utf-8"))
        #expect(h.requestURLs.last?.path == "/develop/v1/library/media/med_1/cover")
        #expect(service.coverURL(for: found)?.host == h.host)
    }

    @Test func pendingCoverIsA404WithCoverPendingCode() async throws {
        let pending = LibraryCover(status: .pending, url: "/v1/library/media/med_1/cover", width: nil, height: nil)

        // Laut API-Team: nie 202, sondern 404 mit code cover_pending und Retry-After 30.
        let h1 = Harness()
        let withHeader = h1.service(
            status: 404, headers: ["Retry-After": "30", "Cache-Control": "no-store"],
            json: Sample.error(code: "cover_pending", message: "Cover is being fetched.")
        )
        #expect(try await withHeader.fetchCover(for: pending) == .pending(retryAfter: 30))

        // Ohne Header gilt die Wartezeit der API.
        let h2 = Harness()
        let withoutHeader = h2.service(status: 404, json: Sample.error(code: "cover_pending", message: "Cover is being fetched."))
        #expect(try await withoutHeader.fetchCover(for: pending) == .pending(retryAfter: LibraryCatalogService.defaultCoverRetry))
    }

    @Test func missingCoverIsA404WithCoverMissingCode() async throws {
        let pending = LibraryCover(status: .pending, url: "/v1/library/media/med_1/cover", width: nil, height: nil)
        let h = Harness()
        let service = h.service(
            status: 404, headers: ["Cache-Control": "public, max-age=86400"],
            json: Sample.error(code: "cover_missing", message: "No cover is available for this title.")
        )
        #expect(try await service.fetchCover(for: pending) == .missing)
    }

    @Test func otherCoverErrorsAreThrown() async {
        let found = LibraryCover(status: .found, url: "/v1/library/media/med_1/cover", width: nil, height: nil)
        let h = Harness()
        let service = h.service(status: 503, json: Sample.error(code: "catalog_unavailable", message: "x", type: "api_error"))
        do {
            _ = try await service.fetchCover(for: found)
            Issue.record("Es hätte ein Fehler kommen müssen.")
        } catch let error as LibraryAPIError {
            guard case .catalogUnavailable = error else { Issue.record("Falscher Fehler: \(error)"); return }
        } catch {
            Issue.record("Falscher Fehler: \(error)")
        }
    }

    // MARK: Codes und Texte

    @Test func statusTextsFollowTheHandover() {
        let due = LibraryDateParsing.date(from: "2026-11-12")
        #expect(LibraryAvailabilityStatus(code: "available").displayText() == "Ausleihbar")
        #expect(LibraryAvailabilityStatus(code: "on_loan").displayText(dueDate: due) == "Ausgeliehen bis \(BibliothekFormat.shortDate(due!))")
        #expect(LibraryAvailabilityStatus(code: "on_loan").displayText() == "Ausgeliehen")
        #expect(LibraryAvailabilityStatus(code: "reference_only").displayText() == "Nur vor Ort")
        #expect(LibraryAvailabilityStatus(code: "online").displayText() == "Online lesen")
        #expect(LibraryAvailabilityStatus(code: "unknown").displayText() == "Status unbekannt")
        // Ein neuer Code der API bricht nichts, er gilt als unbekannt.
        #expect(LibraryAvailabilityStatus(code: "lost").displayText() == "Status unbekannt")
    }

    @Test func languageCodesBecomeNames() {
        #expect(LibraryLanguage.name(forCode: "ger") == "Deutsch")
        #expect(LibraryLanguage.name(forCode: "eng") == "Englisch")
        #expect(LibraryLanguage.name(forCode: "fre") == "Französisch")
        #expect(LibraryLanguage.name(forCode: "GER") == "Deutsch")
        #expect(LibraryLanguage.name(forCode: "qqq") == "QQQ")
    }

    @Test func unknownMediaTypeIsKept() async throws {
        let h = Harness()
        let item = Sample.catalogBook.replacingOccurrences(of: "\"ebook\"", with: "\"map\"")
        let response = try await h.service(json: Sample.list(data: [item], total: 1)).search(LibrarySearchQuery(text: "karte")).value
        #expect(response.items.first?.mediaType == .other("map"))
        #expect(response.items.first?.mediaType.displayName == "Medium")
    }

    @Test func datesWithAndWithoutTime() {
        #expect(LibraryDateParsing.date(from: "2026-10-29T00:06:54.519Z") != nil)
        #expect(LibraryDateParsing.date(from: "2026-10-26T00:00:00Z") != nil)
        #expect(LibraryDateParsing.date(from: "2026-11-05") != nil)
        #expect(LibraryDateParsing.date(from: "morgen") == nil)
    }
}
