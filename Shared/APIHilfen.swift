import Foundation

/// Gemeinsame Hilfen für die öffentlichen APIs (Bibliothekskatalog, Events): URL bauen, Antworten lesen.
/// Die Datei gehört zu App und Widget-Extension.
nonisolated enum APIHilfen {
    /// Baut die URL und kodiert die Werte selbst: `URLComponents` lässt ein `+` stehen, die API läse es als Leerzeichen
    /// („C++“ würde zu „C  “).
    static func buildURL(baseURL: String, path: String, queryItems: [URLQueryItem]) -> URL? {
        var string = baseURL + path
        if !queryItems.isEmpty {
            let query = queryItems.map { item in
                "\(kodiert(item.name))=\(kodiert(item.value ?? ""))"
            }.joined(separator: "&")
            string += "?" + query
        }
        return URL(string: string)
    }

    /// Nur unreservierte Zeichen bleiben stehen.
    static func kodiert(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserviert) ?? text
    }

    private static let unreserviert = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

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
}

// MARK: - Datum

/// Die API liefert ISO-8601 mit Millisekunden (`2026-10-29T00:06:54.519Z`) und reine Daten (`2026-11-05`).
nonisolated enum LibraryDateParsing {
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

// MARK: - Fehlerantwort

nonisolated struct LibraryErrorResponse: Decodable {
    struct Detail: Decodable {
        let type: String?
        let code: String
        let message: String
        let param: String?
        let requestId: String?
    }

    let error: Detail
}

// MARK: - Dekodieren

extension KeyedDecodingContainer {
    /// Liest eine URL und ergibt `nil`, wenn sie fehlt oder nicht lesbar ist, statt die ganze Antwort zu verwerfen.
    func lenientURL(forKey key: Key) -> URL? {
        guard let string = (try? decodeIfPresent(String.self, forKey: key)) ?? nil, !string.isEmpty else { return nil }
        return URL(string: string)
    }
}
