import Foundation

/// Fehler der Events-API.
enum EventsAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    /// 404: Die Veranstaltung gibt es nicht (mehr).
    case notFound
    case apiError(statusCode: Int, code: String, message: String, param: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Ungültige API-URL"
        case .invalidResponse: "Ungültige Server-Antwort"
        case .httpError(let statusCode): "HTTP-Fehler: \(statusCode)"
        case .notFound: "Veranstaltung nicht gefunden"
        case .apiError(_, let code, let message, _): "API-Fehler (\(code)): \(message)"
        case .decodingError(let error): "Fehler beim Dekodieren: \(error.localizedDescription)"
        case .networkError(let error): "Netzwerk-Fehler: \(error.localizedDescription)"
        }
    }
}

/// Service für die Events-API des Hintergrundsystems. Lesend, ohne Anmeldung. Aufbau wie `LibraryCatalogService`:
/// Basis-URL und `URLSession` von außen, ein generisches `perform`, eigener Fehlertyp. Er hält keinen Zustand.
///
/// Endpunkte:
/// - `GET /v1/events` mit `from`, `to`, `date`, `evening`, `organizer`, `category`, `include_cancelled`, `page`, `per_page`
/// - `GET /v1/events/{id}`
/// - `GET /v1/events/organizers`
@MainActor
final class EventsService {
    static let seitenGroesse = 100

    private let baseURL: String
    private let session: URLSession

    init(
        baseURL: String = "https://dev-api.campus-ilmenau.de/develop",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Öffentlich

    /// Eine Seite der Liste, nach Beginn aufsteigend, bis zu 100 Veranstaltungen.
    ///
    /// Bei „ab Tag X“ (Zeitraum oder Standard) holt die erste Seite zusätzlich mehrtägige Veranstaltungen, die vor
    /// diesem Tag begonnen haben und noch laufen. Die API findet sie über `from` nicht.
    func liste(filter: EventFilter, seite: Int = 1, jetzt: Date = .now) async throws -> EventSeite {
        let anfrage = filter.anfrage(jetzt: jetzt)
        let items = anfrage.items + [
            URLQueryItem(name: "page", value: String(max(1, seite))),
            URLQueryItem(name: "per_page", value: String(Self.seitenGroesse))
        ]
        let antwort: EventListResponse = try await perform(path: "/v1/events", queryItems: items)

        // Das Fenster der API ist in UTC-Tagen verbreitert; hier auf Berliner Tage zuschneiden.
        var events = antwort.data.filter { event in
            if let von = anfrage.vonGrenze, event.beginn < von { return false }
            if let bis = anfrage.bisGrenze, event.beginn >= bis { return false }
            return true
        }

        if seite == 1, let tag = anfrage.laufendeAm {
            let laufende = await laufendeVeranstaltungen(am: tag, anfrage: anfrage)
            let vorhanden = Set(events.map(\.id))
            events += laufende.filter { !vorhanden.contains($0.id) }
            events.sort { $0.beginn < $1.beginn }
        }

        return EventSeite(events: events, seite: antwort.page, hatWeitere: antwort.hasMore, gesamt: antwort.totalCount)
    }

    /// Eine einzelne Veranstaltung. Gibt es sie nicht (mehr), wirft der Service `EventsAPIError.notFound`.
    func detail(id: String) async throws -> CampusEvent {
        try await perform(path: "/v1/events/\(id.pfadKodiert)", queryItems: [])
    }

    /// Veranstalter mit kommenden Veranstaltungen, alphabetisch.
    func veranstalter() async throws -> [Veranstalter] {
        let antwort: OrganizerListResponse = try await perform(path: "/v1/events/organizers", queryItems: [])
        return antwort.data
            .filter { $0.anzahlKommende > 0 }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Intern

    /// Mehrtägige Veranstaltungen, die vor `tag` begonnen haben und an `tag` noch laufen. Schlägt die Abfrage fehl,
    /// bleibt die Liste ohne sie, statt ganz zu scheitern.
    private func laufendeVeranstaltungen(am tag: Date, anfrage: EventFilter.Anfrage) async -> [CampusEvent] {
        let items = [URLQueryItem(name: "date", value: EventKalender.berlinDatum(tag))]
            + anfrage.gemeinsam
            + [URLQueryItem(name: "per_page", value: String(Self.seitenGroesse))]
        guard let antwort: EventListResponse = try? await perform(path: "/v1/events", queryItems: items) else { return [] }
        return antwort.data.filter { $0.beginn < tag && $0.laeuftAm(tag) }
    }

    private func perform<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        guard let url = APIHilfen.buildURL(baseURL: baseURL, path: path, queryItems: queryItems) else {
            throw EventsAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let http: HTTPURLResponse
        do {
            let (body, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw EventsAPIError.invalidResponse }
            data = body
            http = httpResponse
        } catch let error as EventsAPIError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw EventsAPIError.networkError(error)
        }

        guard (200...299).contains(http.statusCode) else {
            throw Self.fehler(aus: data, status: http.statusCode)
        }
        do {
            return try APIHilfen.decoder.decode(T.self, from: data)
        } catch {
            throw EventsAPIError.decodingError(error)
        }
    }

    static func fehler(aus data: Data, status: Int) -> EventsAPIError {
        let detail = (try? APIHilfen.decoder.decode(LibraryErrorResponse.self, from: data))?.error
        if status == 404 { return .notFound }
        if let detail {
            return .apiError(statusCode: status, code: detail.code, message: detail.message, param: detail.param)
        }
        return .httpError(statusCode: status)
    }
}

// MARK: - Antworten

private struct EventListResponse: Decodable {
    let data: [CampusEvent]
    let hasMore: Bool
    let totalCount: Int
    let page: Int

    private enum CodingKeys: String, CodingKey { case data, hasMore, totalCount, page }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode([CampusEvent].self, forKey: .data)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? data.count
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
    }
}

private struct OrganizerListResponse: Decodable {
    let data: [Veranstalter]
}

private extension String {
    var pfadKodiert: String {
        addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? self
    }
}
