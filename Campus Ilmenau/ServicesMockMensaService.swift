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
                price: "3,50 €",
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
                price: "3,20 €",
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
                price: "2,80 €",
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
                price: "0,80 €",
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
                price: "1,20 €",
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
                price: "1,50 €",
                allergies: ["Gluten", "Ei", "Milch"],
                badges: ["Vegetarisch"],
                canteenName: "Mensa Ehrenberg",
                date: today
            )
        ]
    }
}
