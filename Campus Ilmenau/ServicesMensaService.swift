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
    
    // MARK: - Initialization
    init(
        baseURL: String = "https://dev-api.campus-ilmenau.de/develop",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
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
            guard let url = buildMealsURL(period: period, canteenId: canteenId) else {
                throw MensaAPIError.invalidURL
            }
            
            let response: ListResponse<APIMeal> = try await performRequest(url: url)
            
            self.meals = response.data.map { apiMeal in
                MensaMeal(
                    id: apiMeal.id,
                    category: apiMeal.mealGroup ?? "Gericht",
                    name: apiMeal.title,
                    description: formatComponents(apiMeal.components),
                    price: MensaMealPrice(
                        student: apiMeal.price?.student,
                        staff: apiMeal.price?.staff,
                        guest: apiMeal.price?.guest,
                        currency: apiMeal.price?.currency ?? "€"
                    ),
                    allergies: apiMeal.allergenCodes.compactMap { $0.name },
                    badges: determineBadges(from: apiMeal),
                    additives: apiMeal.additiveCodes.compactMap { $0.name },
                    categories: apiMeal.symbolCodes.compactMap { $0.name },
                    co2GramPerPortion: apiMeal.co2GramPerPortion,
                    components: apiMeal.components.map { component in
                        MensaMealComponent(name: component.name, codes: component.codes.compactMap { $0.name })
                    },
                    canteenName: apiMeal.canteen.name,
                    date: apiMeal.date
                )
            }
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
    
    private func buildMealsURL(period: Period, canteenId: Int?) -> URL? {
        var components = URLComponents(string: "\(baseURL)/v1/mensa")
        var queryItems: [URLQueryItem] = []
        
        // Datum/Period
        switch period {
        case .today:
            queryItems.append(URLQueryItem(name: "period", value: "today"))
        case .week:
            queryItems.append(URLQueryItem(name: "period", value: "week"))
        case .date(let date):
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            queryItems.append(URLQueryItem(name: "date", value: dateFormatter.string(from: date)))
        }
        
        // Canteen-Filter
        if let canteenId = canteenId {
            queryItems.append(URLQueryItem(name: "canteen", value: String(canteenId)))
        }
        
        // Limit erhöhen (max 100)
        queryItems.append(URLQueryItem(name: "per_page", value: "100"))
        
        components?.queryItems = queryItems
        return components?.url
    }
    
    private func formatComponents(_ components: [APIComponent]) -> String? {
        guard !components.isEmpty else { return nil }
        return components.map { $0.name }.joined(separator: ", ")
    }
    
    private func determineBadges(from meal: APIMeal) -> [String] {
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
    enum Period {
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
            return "Ungültige API-URL"
        case .invalidResponse:
            return "Ungültige Server-Antwort"
        case .httpError(let statusCode):
            return "HTTP-Fehler: \(statusCode)"
        case .apiError(let code, let message):
            return "API-Fehler (\(code)): \(message)"
        case .decodingError(let error):
            return "Fehler beim Dekodieren: \(error.localizedDescription)"
        case .networkError(let error):
            return "Netzwerk-Fehler: \(error.localizedDescription)"
        }
    }
}
