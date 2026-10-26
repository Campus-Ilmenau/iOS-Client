//
//  MockMensaService.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import Foundation
import Combine

/// Mock-Service für Tests und Preview ohne echte API
@MainActor
class MockMensaService: MensaService {
    
    private let useMockData: Bool
    
    init(useMockData: Bool = true) {
        self.useMockData = useMockData
        super.init(baseURL: "https://mock.api.example.com")
    }
    
    override func fetchTodaysMeals(canteenId: Int? = nil) async throws {
        isLoading = true
        
        // Simuliere Netzwerk-Delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 Sekunde
        
        if useMockData {
            self.meals = generateMockMeals()
            isLoading = false
        } else {
            // Simuliere Fehler
            isLoading = false
            errorMessage = "Mock-Fehler: API nicht erreichbar"
            throw MensaAPIError.networkError(NSError(domain: "Mock", code: -1))
        }
    }
    
    override func fetchWeekMeals(canteenId: Int? = nil) async throws {
        try await fetchTodaysMeals(canteenId: canteenId)
    }
    
    override func fetchMeals(date: Date, canteenId: Int? = nil) async throws {
        try await fetchTodaysMeals(canteenId: canteenId)
    }
    
    private func generateMockMeals() -> [MensaMeal] {
        let today = Date()
        return [
            MensaMeal(
                id: "meal_mock_1",
                category: "Hauptgericht 1",
                name: "Hähnchenschnitzel",
                description: "mit Pommes Frites und Salat",
                price: MensaMealPrice(student: 3.50, staff: 4.70, guest: 5.90, currency: "€"),
                allergies: ["Gluten", "Ei"],
                badges: [],
                canteenName: "Mensa Ehrenberg",
                date: today
            ),
            MensaMeal(
                id: "meal_mock_2",
                category: "Hauptgericht 2",
                name: "Gemüselasagne",
                description: "mit Tomatensauce und Mozzarella",
                price: MensaMealPrice(student: 3.20, staff: 4.40, guest: 5.60, currency: "€"),
                allergies: ["Gluten", "Milch"],
                badges: ["Vegetarisch"],
                canteenName: "Mensa Ehrenberg",
                date: today
            ),
            MensaMeal(
                id: "meal_mock_3",
                category: "Hauptgericht 3",
                name: "Curry-Linsen-Eintopf",
                description: "mit Kokosmilch und Basmatireis",
                price: MensaMealPrice(student: 2.80, staff: 4.00, guest: 5.20, currency: "€"),
                allergies: [],
                badges: ["Vegan", "Bio"],
                canteenName: "Mensa Ehrenberg",
                date: today
            ),
            MensaMeal(
                id: "meal_mock_4",
                category: "Beilage",
                name: "Kartoffelpüree",
                description: nil,
                price: MensaMealPrice(student: 0.80, staff: 1.00, guest: 1.20, currency: "€"),
                allergies: ["Milch"],
                badges: ["Vegetarisch"],
                canteenName: "Mensa Ehrenberg",
                date: today
            ),
            MensaMeal(
                id: "meal_mock_5",
                category: "Beilage",
                name: "Gemischter Salat",
                description: "mit Balsamico-Dressing",
                price: MensaMealPrice(student: 1.20, staff: 1.50, guest: 1.80, currency: "€"),
                allergies: [],
                badges: ["Vegan"],
                canteenName: "Mensa Ehrenberg",
                date: today
            ),
            MensaMeal(
                id: "meal_mock_6",
                category: "Dessert",
                name: "Apfelstrudel",
                description: "mit Vanillesauce",
                price: MensaMealPrice(student: 1.50, staff: 1.90, guest: 2.30, currency: "€"),
                allergies: ["Gluten", "Ei", "Milch"],
                badges: ["Vegetarisch"],
                canteenName: "Mensa Ehrenberg",
                date: today
            )
        ]
    }
}
