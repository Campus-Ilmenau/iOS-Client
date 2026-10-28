//
//  ServicesPAIAService.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 27.10.26.
//

import Foundation
import Combine

/// Service für die Kommunikation mit dem PAIA-Server der Universitätsbibliothek
/// Ilmenau (https://gbv.github.io/paia/paia.html). Übernimmt Login (auth/login)
/// und das Laden der ausgeliehenen/vorgemerkten Medien (core/{patron}/items).
@MainActor
final class PAIAService: ObservableObject {

    /// Geteilte Instanz, damit die Session (Access-Token) über Navigations-
    /// wechsel hinweg bestehen bleibt — ein `@StateObject` pro View würde beim
    /// Verlassen und erneuten Öffnen der Bibliotheksseite neu angelegt.
    static let shared = PAIAService()

    // MARK: - Published Properties
    @Published private(set) var isAuthenticated = false
    @Published private(set) var items: [PAIALoanItem] = []
    @Published private(set) var notifications: [PAIANotification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Properties
    private let baseURL: String
    private let session: URLSession

    private var accessToken: String?
    private var patronId: String?
    private var tokenExpiryDate: Date?

    // MARK: - Initialization
    init(
        baseURL: String = "https://paia.gbv.de/DE-Ilm1",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Public Methods

    /// Meldet den Nutzer per Resource-Owner-Password-Grant an (PAIA auth/login).
    func login(username: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw PAIAError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "password"),
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "scope", value: "read_patron read_fees read_items write_items read_notifications")
        ]
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PAIAError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorResponse = try? JSONDecoder().decode(PAIAErrorResponse.self, from: data) {
                    throw PAIAError.authenticationFailed(errorResponse.errorDescription ?? errorResponse.error)
                }
                throw PAIAError.httpError(statusCode: httpResponse.statusCode)
            }

            let authResponse = try JSONDecoder().decode(PAIAAuthResponse.self, from: data)
            self.accessToken = authResponse.accessToken
            self.patronId = authResponse.patron
            self.tokenExpiryDate = authResponse.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
            self.isAuthenticated = true
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            throw error
        }
    }

    /// Lädt die ausgeliehenen, vorgemerkten und bestellten Medien des angemeldeten Nutzers.
    func fetchItems() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: PAIAItemsResponse = try await performAuthorizedGET(path: "items")
            self.items = response.doc
        } catch let error as PAIAError {
            if case .sessionExpired = error { throw error }
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Lädt die Benachrichtigungen des angemeldeten Nutzers. Der Endpunkt ist laut
    /// PAIA-Spezifikation optional — Server, die ihn nicht anbieten, antworten mit
    /// 404. Das ist kein Fehler, den wir anzeigen wollen, sonst überschreibt er die
    /// Fehlermeldung der Ausleihen-Liste.
    func fetchNotifications() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: PAIANotificationsResponse = try await performAuthorizedGET(path: "notifications")
            self.notifications = response.notification
        } catch PAIAError.httpError(404) {
            self.notifications = []
        } catch let error as PAIAError {
            if case .sessionExpired = error { throw error }
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Verlängert die Leihfrist eines Mediums (PAIA core/{patron}/renew).
    func renew(_ item: PAIALoanItem) async throws {
        guard let itemURI = item.item else {
            throw PAIAError.missingItemIdentifier
        }

        if let tokenExpiryDate, Date() >= tokenExpiryDate {
            logout()
            throw PAIAError.sessionExpired
        }

        do {
            let body = try JSONEncoder().encode(PAIARenewRequest(doc: [PAIARenewRequestDoc(item: itemURI)]))
            let request = try authorizedRequest(path: "renew", method: "POST", body: body)
            let renewResponse: PAIARenewResponse = try await send(request)

            guard let result = renewResponse.doc.first(where: { $0.item == itemURI }) ?? renewResponse.doc.first else {
                throw PAIAError.invalidResponse
            }

            if let error = result.error {
                throw PAIAError.renewalFailed(error)
            }

            if let index = items.firstIndex(where: { $0.item == itemURI }) {
                items[index] = items[index].renewed(newEndtime: result.endtime, newStatus: result.status)
            }
        } catch let error as PAIAError {
            if case .sessionExpired = error { throw error }
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Beendet die Session lokal. Wird auch automatisch aufgerufen, wenn der
    /// Server eine abgelaufene/ungültige Session meldet (HTTP 401/403).
    func logout() {
        accessToken = nil
        patronId = nil
        tokenExpiryDate = nil
        isAuthenticated = false
        items = []
        notifications = []
    }

    // MARK: - Private Methods

    /// Führt ein authentifiziertes GET gegen `core/{patron}/{path}` aus und
    /// dekodiert die Antwort. Wirft `.sessionExpired`, wenn der Server die
    /// Session ablehnt oder das Token bereits lokal abgelaufen ist.
    private func performAuthorizedGET<T: Decodable>(path: String) async throws -> T {
        if let tokenExpiryDate, Date() >= tokenExpiryDate {
            logout()
            throw PAIAError.sessionExpired
        }

        let request = try authorizedRequest(path: path, method: "GET")
        return try await send(request)
    }

    /// Baut ein authentifiziertes Request gegen `core/{patron}/{path}`.
    private func authorizedRequest(path: String, method: String, body: Data? = nil) throws -> URLRequest {
        guard isAuthenticated, let accessToken, let patronId else {
            throw PAIAError.notAuthenticated
        }

        guard let encodedPatron = patronId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/core/\(encodedPatron)/\(path)") else {
            throw PAIAError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    /// Schickt das Request ab und dekodiert die Antwort. Wandelt 401/403 in
    /// `.sessionExpired` und beendet dabei die lokale Session.
    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PAIAError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            logout()
            throw PAIAError.sessionExpired
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PAIAError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .paia
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - API Response Models

private struct PAIAAuthResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let patron: String?
    let scope: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case patron, scope
        case expiresIn = "expires_in"
    }
}

private struct PAIAErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private struct PAIARenewRequest: Encodable {
    let doc: [PAIARenewRequestDoc]
}

private struct PAIARenewRequestDoc: Encodable {
    let item: String
}

private struct PAIARenewResponse: Decodable {
    let doc: [PAIARenewResult]
}

private struct PAIARenewResult: Decodable {
    let item: String?
    let endtime: Date?
    let status: PAIAItemStatus?
    let error: String?
}

// MARK: - Date Decoding

private extension JSONDecoder.DateDecodingStrategy {
    /// PAIA-Server liefern Datumsangaben wahlweise als vollständiges ISO8601-Datetime
    /// oder als reines Datum (z. B. Fälligkeitsdatum ohne Uhrzeit).
    static var paia: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = ISO8601DateFormatter().date(from: string) {
                return date
            }

            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
            if let date = dateOnlyFormatter.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
    }
}

// MARK: - Error Handling

enum PAIAError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case authenticationFailed(String)
    case notAuthenticated
    case sessionExpired
    case renewalFailed(String)
    case missingItemIdentifier

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige PAIA-Server-URL"
        case .invalidResponse:
            return "Ungültige Server-Antwort"
        case .httpError(let statusCode):
            return "HTTP-Fehler: \(statusCode)"
        case .authenticationFailed(let message):
            return message
        case .notAuthenticated:
            return "Nicht angemeldet"
        case .sessionExpired:
            return "Sitzung abgelaufen, bitte erneut anmelden"
        case .renewalFailed(let message):
            return "Verlängerung fehlgeschlagen: \(message)"
        case .missingItemIdentifier:
            return "Dieses Medium kann nicht verlängert werden"
        }
    }
}
