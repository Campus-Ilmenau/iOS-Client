//
//  MensaService.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import Foundation
import Combine

/// Service für die Kommunikation mit der Campus-Ilmenau Mensa-API
@MainActor
class MensaService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var meals: [MensaMeal] = []
    @Published var canteens: [Canteen] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Properties
    private let baseURL: String
    private let session: URLSession
    /// Sprache der Anfragen. Wird bei jeder Anfrage neu gelesen, damit ein Wechsel sofort gilt.
    private let language: () -> AppLanguage
    
    // MARK: - Initialization
    init(
        baseURL: String = APIUmgebung.baseURL,
        session: URLSession = .shared,
        language: @escaping () -> AppLanguage = { .current }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.language = language
    }
    
    // MARK: - Public Methods
    
    /// Lädt den Speiseplan für heute
    func fetchTodaysMeals(canteenId: Int? = nil) async throws {
        try await fetchMeals(period: .today, canteenId: canteenId)
    }
    
    /// Lädt den Speiseplan für die aktuelle Woche
    func fetchWeekMeals(canteenId: Int? = nil) async throws {
        try await fetchMeals(period: .week, canteenId: canteenId)
    }
    
    /// Lädt den Speiseplan für ein bestimmtes Datum
    func fetchMeals(date: Date, canteenId: Int? = nil) async throws {
        try await fetchMeals(period: .date(date), canteenId: canteenId)
    }
    
    /// Lädt alle verfügbaren Mensen/Standorte
    func fetchCanteens() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let url = URL(string: "\(baseURL)/v1/mensa/canteens")!
            let response: ListResponse<APICanteen> = try await performRequest(url: url)
            
            self.canteens = response.data.map { apiCanteen in
                Canteen(
                    rscId: apiCanteen.rscId,
                    name: apiCanteen.name,
                    hasMenu: apiCanteen.hasMenu,
                    city: apiCanteen.city,
                    address: apiCanteen.address,
                    openingHours: apiCanteen.openingHours
                )
            }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchMeals(period: Period, canteenId: Int?) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let url = Self.mealsURL(baseURL: baseURL, period: period, canteenId: canteenId, language: language()) else {
                throw MensaAPIError.invalidURL
            }
            
            let response: ListResponse<APIMeal> = try await performRequest(url: url)
            
            self.meals = response.data.map(Self.meal(from:))
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MensaAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Versuche Error-Response zu dekodieren
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw MensaAPIError.apiError(code: errorResponse.error.code, message: errorResponse.error.message)
            }
            throw MensaAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MensaAPIError.decodingError(error)
        }
    }
    
    /// Die einzige Stelle, die `lang` anhängt: Jede URL unter `/v1/mensa` und `/v1/mensa/codes` trägt es, auch bei `de`.
    /// Es gibt kein `Accept-Language`. Die Historie (`/v1/mensa/dishes/...`), `canteens` und `like-request` kennen
    /// `lang` nicht. Eine Suche (`q`) braucht kein `lang`: Ohne es werden deutsche und englische Titel durchsucht, mit
    /// `lang=en&q=Pilz` ergibt es 0 Treffer (gegen Dev geprüft). Die App hat keine Mensa-Suche.
    nonisolated static func url(baseURL: String, path: String, queryItems: [URLQueryItem], language: AppLanguage) -> URL? {
        var items = queryItems
        if path == "/v1/mensa" || path == "/v1/mensa/codes" {
            items.removeAll { $0.name == "lang" }
            items.append(URLQueryItem(name: "lang", value: language.apiCode))
        }
        var components = URLComponents(string: baseURL + path)
        components?.queryItems = items.isEmpty ? nil : items
        return components?.url
    }

    nonisolated static func mealsURL(baseURL: String, period: Period, canteenId: Int?, language: AppLanguage) -> URL? {
        var queryItems: [URLQueryItem] = []

        // Datum/Period
        switch period {
        case .today:
            queryItems.append(URLQueryItem(name: "period", value: "today"))
        case .week:
            queryItems.append(URLQueryItem(name: "period", value: "week"))
        case .date(let date):
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd"
            queryItems.append(URLQueryItem(name: "date", value: dateFormatter.string(from: date)))
        }

        // Canteen-Filter
        if let canteenId = canteenId {
            queryItems.append(URLQueryItem(name: "canteen", value: String(canteenId)))
        }

        // Limit erhöhen (max 100)
        queryItems.append(URLQueryItem(name: "per_page", value: "100"))

        return url(baseURL: baseURL, path: "/v1/mensa", queryItems: queryItems, language: language)
    }

    /// Liest die Antwort von `GET /v1/mensa`. Fehlt `translated` (älterer API-Stand), gilt `false`.
    nonisolated static func meals(from data: Data) throws -> [MensaMeal] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ListResponse<APIMeal>.self, from: data).data.map(meal(from:))
    }

    /// Ein Gericht der API als Gericht der App. Titel, Gruppe, Komponenten und Namen der Codes stehen so, wie sie kommen
    /// (je Feld Deutsch oder Englisch); Allergene und Symbole tragen zusätzlich ihr sprachunabhängiges Kürzel.
    fileprivate nonisolated static func meal(from apiMeal: APIMeal) -> MensaMeal {
        MensaMeal(
            id: apiMeal.id,
            category: apiMeal.mealGroup ?? String(localized: "Gericht", table: "Shared"),
            name: apiMeal.title,
            description: Self.formatComponents(apiMeal.components),
            price: MensaMealPrice(
                student: apiMeal.price?.student,
                staff: apiMeal.price?.staff,
                guest: apiMeal.price?.guest,
                currency: apiMeal.price?.currency ?? "€"
            ),
            allergies: apiMeal.allergenCodes.compactMap { $0.name },
            badges: Self.determineBadges(from: apiMeal),
            additives: apiMeal.additiveCodes.compactMap { $0.name },
            categories: apiMeal.symbolCodes.compactMap { $0.name },
            co2GramPerPortion: apiMeal.co2GramPerPortion,
            components: apiMeal.components.map { component in
                MensaMealComponent(
                    name: component.name,
                    codes: component.codes.compactMap { $0.name },
                    codeRefs: component.codes.map { MensaCodeRef(code: $0.code, name: $0.name) }
                )
            },
            canteenName: apiMeal.canteen.name,
            date: apiMeal.date,
            translated: apiMeal.translated ?? false,
            allergenCodes: apiMeal.allergenCodes.map { MensaCodeRef(code: $0.code, name: $0.name) },
            additiveCodes: apiMeal.additiveCodes.map { MensaCodeRef(code: $0.code, name: $0.name) }
        )
    }

    private nonisolated static func formatComponents(_ components: [APIComponent]) -> String? {
        guard !components.isEmpty else { return nil }
        return components.map { $0.name }.joined(separator: ", ")
    }
    
    private nonisolated static func determineBadges(from meal: APIMeal) -> [String] {
        var badges: [String] = []
        
        if meal.flags.vegan {
            badges.append("Vegan")
        }
        if meal.flags.vegetarian {
            badges.append("Vegetarisch")
        }
        
        // Bio-Symbol prüfen
        if meal.symbolCodes.contains(where: { $0.code.lowercased().contains("bio") }) {
            badges.append("Bio")
        }
        
        return badges
    }
}

// MARK: - Period Enum
extension MensaService {
    nonisolated enum Period {
        case today
        case week
        case date(Date)
    }
}

// MARK: - API Response Models

/// List-Envelope für API-Responses
private struct ListResponse<T: Decodable>: Decodable {
    let object: String
    let url: String
    let hasMore: Bool
    let totalCount: Int
    let data: [T]
}

/// API-Model für ein Meal
private struct APIMeal: Decodable {
    let id: String
    let object: String
    let canteen: APICanteenInfo
    let date: Date
    let mealGroup: String?
    let title: String
    let dishId: String?
    /// Fehlt bei älteren API-Ständen: dann `false`.
    let translated: Bool?
    let isActive: Bool
    let lastSeenAt: Date
    let additiveCodes: [APICode]
    let allergenCodes: [APICode]
    let symbolCodes: [APICode]
    let flags: APIFlags
    let co2GramPerPortion: Double?
    let likeCount: Int?
    let feedbackUrl: String?
    let sourceMealKey: String?
    let productionDate: Date?
    let price: APIPrice?
    let components: [APIComponent]
    let createdAt: Date
    let updatedAt: Date
}

/// Canteen-Info im Meal
private struct APICanteenInfo: Decodable {
    let rscId: Int?
    let name: String
    let city: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
}

/// Preis-Struktur
private struct APIPrice: Decodable {
    let student: Double?
    let staff: Double?
    let guest: Double?
    let currency: String
}

/// Code (Zusatzstoff/Allergen/Symbol)
private struct APICode: Decodable {
    let code: String
    let name: String?
    let description: String?
}

/// Flags (Ernährungsform, etc.)
private struct APIFlags: Decodable {
    let vegetarian: Bool
    let vegan: Bool
    let pork: Bool
    let beef: Bool
    let poultry: Bool
    let fish: Bool
    let garlic: Bool
    let alcohol: Bool
}

/// Komponente eines Gerichts
private struct APIComponent: Decodable {
    let name: String
    let codes: [APICode]
}

/// Canteen/Standort
private struct APICanteen: Decodable {
    let object: String
    let rscId: Int?
    let name: String
    let hasMenu: Bool
    let city: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let seatingCapacity: Int?
    let infoPageUrl: String?
    let openingHours: [OpeningHour]
    let notice: Notice?
}

/// Öffnungszeiten
struct OpeningHour: Codable {
    let weekday: String
    let opensAt: String
    let closesAt: String
}

/// Hinweis
private struct Notice: Decodable {
    let rawText: String
    let noticeType: String
    let parsedFrom: Date?
    let parsedUntil: Date?
}

/// Error-Response
private struct APIErrorResponse: Decodable {
    let error: APIError
    
    struct APIError: Decodable {
        let type: String
        let code: String
        let message: String
        let param: String?
        let requestId: String?
    }
}

// MARK: - App Models (Public)

/// Canteen-Model für die App
struct Canteen: Identifiable {
    let id: Int?
    let rscId: Int?
    let name: String
    let hasMenu: Bool
    let city: String?
    let address: String?
    let openingHours: [OpeningHour]
    
    init(rscId: Int?, name: String, hasMenu: Bool, city: String?, address: String?, openingHours: [OpeningHour]) {
        self.id = rscId
        self.rscId = rscId
        self.name = name
        self.hasMenu = hasMenu
        self.city = city
        self.address = address
        self.openingHours = openingHours
    }
}

// MARK: - Error Handling

enum MensaAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(code: String, message: String)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Ungültige API-URL", table: "Shared")
        case .invalidResponse:
            return String(localized: "Ungültige Server-Antwort", table: "Shared")
        case .httpError(let statusCode):
            return String(localized: "HTTP-Fehler: \(statusCode)", table: "Shared")
        case .apiError(let code, let message):
            return String(localized: "API-Fehler (\(code)): \(message)", table: "Shared")
        case .decodingError(let error):
            return String(localized: "Fehler beim Dekodieren: \(error.localizedDescription)", table: "Shared")
        case .networkError(let error):
            return String(localized: "Netzwerk-Fehler: \(error.localizedDescription)", table: "Shared")
        }
    }
}
