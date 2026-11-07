import UIKit

/// Hinweise zur Antwort, die nicht zu den Daten gehören.
struct LibraryResponseInfo: Equatable {
    /// `X-Cache-Status: stale`: Der Katalog antwortet langsam, die Daten stammen aus dem Zwischenspeicher
    /// und können veraltet sein (Hinweis „Verfügbarkeit kann sich geändert haben“).
    /// Einen `Age`-Header setzt die API nicht. Für „Stand von …“ dient `fetchedAt` am Titel
    /// (bei Listen `LibrarySearchResponse.oldestFetchedAt`).
    let isStale: Bool
    /// Wert von `X-Cache-Status` (`hit`, `miss`, `stale`), nur zur Diagnose.
    let cacheStatus: String?
    /// `X-Request-Id`, bei Problemen mitschicken.
    let requestId: String?
}

/// Daten plus Hinweise zur Antwort.
struct LibraryResult<Value> {
    let value: Value
    let info: LibraryResponseInfo
}

extension LibraryResult: Equatable where Value: Equatable {}

/// Ergebnis eines Cover-Abrufs.
enum LibraryCoverResult: Equatable {
    case image(Data, mimeType: String?)
    /// Das Cover wird noch geholt; nach `retryAfter` Sekunden erneut versuchen.
    case pending(retryAfter: TimeInterval?)
    /// Es gibt kein Cover.
    case missing
}

/// Service für die Katalog-API `/v1/library/*` des Hintergrundsystems. Ohne Anmeldung, nur lesend.
/// Aufbau wie `MensaService`: Basis-URL und `URLSession` von außen, ein generisches `perform`, eigener Fehlertyp.
/// Der Service hält keinen Zustand und speichert nichts; Inhaltsverzeichnis und Klappentext bleiben im Speicher des Aufrufers.
@MainActor
final class LibraryCatalogService {

    // MARK: - Properties
    private let baseURL: String
    private let session: URLSession

    /// Höchstens so viele IDs pro Verfügbarkeitsabfrage.
    static let maxAvailabilityIDs = 20

    // MARK: - Initialization
    init(
        baseURL: String = "https://dev-api.campus-ilmenau.de/develop",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Public Methods

    /// Sucht im Katalog. Die Eingabe wird vorher geprüft (`LibraryAPIError.invalidQuery`).
    func search(_ query: LibrarySearchQuery) async throws -> LibraryResult<LibrarySearchResponse> {
        let issues = query.validate()
        guard issues.isEmpty else { throw LibraryAPIError.invalidQuery(issues) }
        return try await perform(path: "/v1/library/search", queryItems: query.queryItems)
    }

    /// Verfügbarkeit für bis zu 20 Titel. Unbekannte IDs kommen mit Status `unknown` zurück.
    func availability(ids: [String]) async throws -> LibraryResult<[String: LibraryAvailability]> {
        var seen = Set<String>()
        let unique = ids.filter { seen.insert($0).inserted }
        guard !unique.isEmpty else {
            return LibraryResult(value: [:], info: LibraryResponseInfo(isStale: false, cacheStatus: nil, requestId: nil))
        }
        guard unique.count <= Self.maxAvailabilityIDs else {
            throw LibraryAPIError.tooManyIDs(unique.count)
        }
        let result: LibraryResult<LibraryAvailabilityList> = try await perform(
            path: "/v1/library/availability",
            queryItems: [URLQueryItem(name: "ids", value: unique.joined(separator: ","))]
        )
        return LibraryResult(value: result.value.byID, info: result.info)
    }

    /// Titel mit Exemplaren, Gesamtstatus und Inhalten.
    /// - Parameters:
    ///   - searchId: `search_id` der Suche, aus der man kam.
    ///   - track: `false` beim Neuladen einer offenen Seite, damit der Aufruf nicht noch einmal gezählt wird.
    func media(id: String, searchId: String? = nil, track: Bool = true) async throws -> LibraryResult<LibraryMediaDetail> {
        var items: [URLQueryItem] = []
        if let searchId, !searchId.isEmpty { items.append(URLQueryItem(name: "search_id", value: searchId)) }
        if !track { items.append(URLQueryItem(name: "track", value: "false")) }
        return try await perform(path: "/v1/library/media/\(id.pathComponentEncoded)", queryItems: items)
    }

    /// Was die API gerade anbietet. Nicht speichern, bei Bedarf neu abfragen.
    func features() async throws -> LibraryResult<LibraryFeatures> {
        try await perform(path: "/v1/library/features", queryItems: [])
    }

    /// Absolute Adresse des Covers, oder `nil`, wenn der Titel keines hat.
    func coverURL(for cover: LibraryCover) -> URL? {
        guard cover.status == .found || cover.status == .pending, let path = cover.url, !path.isEmpty else { return nil }
        if let absolute = URL(string: path), absolute.scheme != nil { return absolute }
        return URL(string: baseURL + path)
    }

    /// Lädt das Cover. Die API antwortet nie mit 202: „wird noch geholt“ ist 404 mit `code: cover_pending`
    /// (dazu `Retry-After: 30`), „kein Cover“ ist 404 mit `cover_missing`.
    /// Ob es überhaupt eines gibt, zeigt vorher `cover.status`: bei `none` und `disabled` fragt der Service gar nicht erst.
    func fetchCover(for cover: LibraryCover) async throws -> LibraryCoverResult {
        switch cover.status {
        case .absent, .disabled: return .missing
        case .found, .pending, .other: break
        }
        guard let url = coverURL(for: cover) else { return .missing }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await send(request)

        if (200...299).contains(response.statusCode) {
            return .image(data, mimeType: response.value(forHTTPHeaderField: "Content-Type"))
        }

        let error = Self.error(from: data, response: response)
        if response.statusCode == 404, case .apiError(_, let code, _, _) = error {
            switch code {
            case "cover_pending": return .pending(retryAfter: Self.retryAfter(from: response) ?? Self.defaultCoverRetry)
            case "cover_missing": return .missing
            default: break
            }
        }
        if response.statusCode == 404, case .notFound = error { return .missing }
        throw error
    }

    /// Wartezeit, wenn `cover_pending` ohne `Retry-After` kommt (die API nennt 30 Sekunden).
    static let defaultCoverRetry: TimeInterval = 30

    // MARK: - Private Methods

    private func perform<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> LibraryResult<T> {
        guard let url = Self.buildURL(baseURL: baseURL, path: path, queryItems: queryItems) else {
            throw LibraryAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await send(request)

        guard (200...299).contains(response.statusCode) else {
            throw Self.error(from: data, response: response)
        }

        do {
            let value = try Self.decoder.decode(T.self, from: data)
            return LibraryResult(value: value, info: Self.info(from: response))
        } catch {
            throw LibraryAPIError.decodingError(error)
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LibraryAPIError.invalidResponse
            }
            return (data, http)
        } catch let error as LibraryAPIError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw LibraryAPIError.networkError(error)
        }
    }

    // MARK: - Helfer (static, damit sie ohne Instanz testbar sind)

    /// Baut die URL und kodiert die Werte selbst: `URLComponents` lässt ein `+` stehen, die API läse es als Leerzeichen
    /// („C++“ würde zu „C  “).
    static func buildURL(baseURL: String, path: String, queryItems: [URLQueryItem]) -> URL? {
        var string = baseURL + path
        if !queryItems.isEmpty {
            let query = queryItems.map { item in
                "\(item.name.queryEncoded)=\((item.value ?? "").queryEncoded)"
            }.joined(separator: "&")
            string += "?" + query
        }
        return URL(string: string)
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let date = LibraryDateParsing.date(from: string) { return date }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Ungültiges Datum: \(string)")
            )
        }
        return decoder
    }

    static func info(from response: HTTPURLResponse) -> LibraryResponseInfo {
        let cache = response.value(forHTTPHeaderField: "X-Cache-Status")
        return LibraryResponseInfo(
            isStale: cache?.lowercased() == "stale",
            cacheStatus: cache,
            requestId: response.value(forHTTPHeaderField: "X-Request-Id")
        )
    }

    /// `Retry-After` als Sekunden. Kommt der Wert als Datum, wird die Wartezeit bis dahin berechnet.
    static func retryAfter(from response: HTTPURLResponse, now: Date = .now) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces),
              !value.isEmpty else { return nil }
        if let seconds = TimeInterval(value) { return max(0, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value).map { max(0, $0.timeIntervalSince(now)) }
    }

    /// Wandelt eine Fehlerantwort in einen `LibraryAPIError`.
    static func error(from data: Data, response: HTTPURLResponse) -> LibraryAPIError {
        let body = try? decoder.decode(LibraryErrorResponse.self, from: data)
        let detail = body?.error
        let status = response.statusCode

        switch status {
        case 400:
            return .badRequest(param: detail?.param, message: detail?.message ?? "Ungültige Anfrage.")
        case 404:
            // Cover-Antworten tragen eigene Codes und werden vom Cover-Abruf ausgewertet.
            if let detail, detail.code.hasPrefix("cover_") {
                return .apiError(statusCode: status, code: detail.code, message: detail.message, param: detail.param)
            }
            return .notFound(message: detail?.message)
        case 503:
            // Auch ohne lesbaren Body: 503 heißt, der Katalog ist nicht erreichbar.
            if detail == nil || detail?.code == "catalog_unavailable" {
                return .catalogUnavailable(retryAfter: retryAfter(from: response))
            }
        default:
            break
        }
        if let detail {
            return .apiError(statusCode: status, code: detail.code, message: detail.message, param: detail.param)
        }
        return .httpError(statusCode: status)
    }
}

// MARK: - Datum

/// Die API liefert ISO-8601 mit Millisekunden (`2026-10-29T00:06:54.519Z`) und reine Daten (`2026-11-05`).
enum LibraryDateParsing {
    static func date(from string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: string) { return date }

        // Reines Datum: Mittag UTC, damit der Tag in jeder Zeitzone der gleiche bleibt.
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, string.count == 10 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}

// MARK: - Fehler

struct LibraryErrorResponse: Decodable {
    struct Detail: Decodable {
        let type: String?
        let code: String
        let message: String
        let param: String?
        let requestId: String?
    }

    let error: Detail
}

enum LibraryAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    /// Die Eingabe wurde schon in der App abgewiesen.
    case invalidQuery([LibraryQueryIssue])
    case tooManyIDs(Int)
    /// 400: falsche Eingabe. `param` nennt den Parameter, der Anlass war. Sollte durch die Prüfung in der App nicht vorkommen.
    case badRequest(param: String?, message: String)
    /// 404: Titel nicht gefunden.
    case notFound(message: String?)
    /// 503 `catalog_unavailable`: Der Katalog ist nicht erreichbar und die Datenbank hat keinen Stand.
    /// Die API schickt dazu kein `Retry-After`; `retryAfter` bleibt in der Regel `nil`.
    case catalogUnavailable(retryAfter: TimeInterval?)
    case apiError(statusCode: Int, code: String, message: String, param: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige API-URL"
        case .invalidResponse:
            return "Ungültige Server-Antwort"
        case .httpError(let statusCode):
            return "HTTP-Fehler: \(statusCode)"
        case .invalidQuery(let issues):
            return issues.first?.message ?? "Ungültige Suche."
        case .tooManyIDs(let count):
            return "Zu viele Titel für eine Abfrage: \(count) (höchstens \(LibraryCatalogService.maxAvailabilityIDs))."
        case .badRequest(_, let message):
            return message
        case .notFound:
            return "Titel nicht gefunden"
        case .catalogUnavailable:
            return "Katalog gerade nicht erreichbar"
        case .apiError(_, let code, let message, _):
            return "API-Fehler (\(code)): \(message)"
        case .decodingError(let error):
            return "Fehler beim Dekodieren: \(error.localizedDescription)"
        case .networkError(let error):
            return "Netzwerk-Fehler: \(error.localizedDescription)"
        }
    }

    /// „Erneut versuchen“ ist sinnvoll.
    var isRetryable: Bool {
        switch self {
        case .catalogUnavailable, .networkError: true
        default: false
        }
    }
}

// MARK: - URL-Kodierung

private extension String {
    /// Für Werte und Namen im Query: nur unreservierte Zeichen bleiben stehen.
    var queryEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .libraryUnreserved) ?? self
    }

    var pathComponentEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .libraryUnreserved) ?? self
    }
}

private extension CharacterSet {
    static let libraryUnreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

// MARK: - Cover laden

/// Holt Cover und merkt sich die Bilder für die Dauer der Sitzung. Bei „wird noch geholt“ wartet er die genannte Zeit
/// und versucht es bis zu zweimal erneut.
@MainActor
final class LibraryCoverLoader {
    private let service: LibraryCatalogService
    private let cache = NSCache<NSString, UIImage>()

    init(service: LibraryCatalogService) {
        self.service = service
    }

    func image(for media: LibraryMedia) async -> UIImage? {
        guard media.cover.status == .found || media.cover.status == .pending else { return nil }
        if let cached = cache.object(forKey: media.id as NSString) { return cached }
        var attempts = 0
        while attempts < 3, !Task.isCancelled {
            guard let result = try? await service.fetchCover(for: media.cover) else { return nil }
            switch result {
            case .image(let data, _):
                guard let image = UIImage(data: data) else { return nil }
                cache.setObject(image, forKey: media.id as NSString)
                return image
            case .missing:
                return nil
            case .pending(let retryAfter):
                attempts += 1
                try? await Task.sleep(for: .seconds(min(retryAfter ?? LibraryCatalogService.defaultCoverRetry, 30)))
            }
        }
        return nil
    }
}
