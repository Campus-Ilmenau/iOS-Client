import SwiftUI

/// Beispieldaten für die Previews: Namen und Gruppen wie in der Mensa-API.
private enum MensaPreviewData {
    static func meal(
        _ id: String,
        canteen: String,
        group: String = "Mittagessen",
        name: String,
        description: String? = nil,
        price: Double? = 2.9,
        allergies: [String] = [],
        badges: [String] = [],
        categories: [String] = []
    ) -> MensaMeal {
        MensaMeal(
            id: id,
            category: group,
            name: name,
            description: description,
            price: MensaMealPrice(student: price, staff: price.map { $0 + 1.6 }, guest: price.map { $0 + 2.9 }, currency: "€"),
            allergies: allergies,
            badges: badges,
            additives: [],
            categories: categories,
            co2GramPerPortion: nil,
            components: [],
            canteenName: canteen,
            date: .now
        )
    }

    static let meals: [MensaMeal] = [
        meal("e1", canteen: "Mensa Ehrenberg", name: "Linsen-Dal", description: "Basmatireis, Mango-Chutney",
             allergies: ["Sellerie", "Senf"], badges: ["Vegan", "Vegetarisch"], categories: ["Regional"]),
        meal("e2", canteen: "Mensa Ehrenberg", name: "Hähnchenschnitzel „Wiener Art“ mit Pommes frites und bunter Salatbeilage",
             description: "Pommes frites, Salat, Joghurt-Dressing, Zitronenspalte, Preiselbeeren und noch etwas mehr Beschreibung, damit sie umbrechen muss",
             price: 3.8, allergies: ["Gluten", "Ei", "Milch", "Senf", "Sellerie", "Sellerie"]),
        meal("e3", canteen: "Mensa Ehrenberg", name: "Pasta Arrabbiata", price: 2.6, badges: ["Vegan"]),
        meal("e4", canteen: "Mensa Ehrenberg", name: "Käsespätzle mit Röstzwiebeln", description: "Gurkensalat",
             price: 3.1, allergies: ["Gluten", "Ei", "Milch"], badges: ["Vegetarisch"]),
        meal("c1", canteen: "Cafeteria Mensa Ehrenberg", name: "Ofengemüse mit Feta", description: "Couscous, Kräuterdip",
             price: 3.0, allergies: ["Gluten", "Milch"], badges: ["Vegetarisch", "Bio"]),
        meal("c2", canteen: "Cafeteria Mensa Ehrenberg", name: "Thüringer Rostbratwurst", description: "Sauerkraut, Kartoffelpüree",
             price: 3.4, allergies: ["Milch", "Senf"], categories: ["Regional"]),
        meal("a1", canteen: "Cafeteria Mensa Ehrenberg", group: "Abendessen", name: "Flammkuchen mit Lauch und Speck",
             price: 3.2, allergies: ["Gluten", "Milch"]),
        meal("a2", canteen: "Cafeteria Mensa Ehrenberg", group: "Abendessen", name: "Gemüse-Bowl mit Erdnusssoße",
             description: "Reis, Edamame, Rotkohl", price: 3.0, allergies: ["Erdnüsse", "Soja"], badges: ["Vegan"]),
        meal("n1", canteen: "Cafeteria NANOteria", name: "Gemüse-Curry mit Kokos", description: "Jasminreis",
             price: 2.8, allergies: ["Soja"], badges: ["Vegan", "Bio"]),
        meal("n2", canteen: "Cafeteria NANOteria", name: "Chili sin Carne", description: "Baguette",
             price: 2.7, allergies: ["Gluten", "Sellerie"], badges: ["Vegan", "Vegetarisch"]),
        meal("r1", canteen: "Cafeteria Röntgenbau", name: "Seelachsfilet", description: "Dillkartoffeln, Gurkensalat",
             price: 4.2, allergies: ["Fisch", "Milch"]),
        meal("r2", canteen: "Cafeteria Röntgenbau", name: "Schweinebraten", description: "Rotkohl, Thüringer Klöße",
             price: 4.1, allergies: ["Gluten", "Sellerie"], categories: ["Regional"]),
        meal("r3", canteen: "Cafeteria Röntgenbau", name: "Gemüsepfanne", price: 2.9, badges: ["Vegan"])
    ]

    /// Gericht ohne Beschreibung und Allergene, sehr langer Name, fehlender Preis.
    static let edgeCases: [MensaMeal] = [
        meal("x1", canteen: "Mensa Ehrenberg", name: "Reis", price: 1.2),
        meal("x2", canteen: "Mensa Ehrenberg",
             name: "Gebratene Hähnchenbrust im Kräuter-Parmesan-Mantel auf mediterranem Ofengemüse mit Rosmarinkartoffeln und hausgemachter Zitronen-Knoblauch-Soße",
             description: "Hähnchenbrust, Ofengemüse, Rosmarinkartoffeln, Zitronen-Knoblauch-Soße, Parmesan, Kräuter, Olivenöl",
             price: 4.9, allergies: ["Milch", "Gluten", "Ei"], badges: ["Bio"], categories: ["Regional"]),
        meal("x3", canteen: "Mensa Ehrenberg", name: "Tagessuppe", description: "Brötchen", price: nil, allergies: ["Gluten"], badges: ["Vegetarisch"])
    ]

    static let canteens: [Canteen] = [
        canteen(46, "Mensa Ehrenberg", "11:00", "14:00"),
        canteen(53, "Cafeteria Mensa Ehrenberg", "08:00", "20:00"),
        canteen(55, "Cafeteria NANOteria", "11:00", "14:00"),
        canteen(57, "Cafeteria Röntgenbau", "10:30", "14:00")
    ]

    private static func canteen(_ id: Int, _ name: String, _ opens: String, _ closes: String) -> Canteen {
        Canteen(
            rscId: id, name: name, hasMenu: true, city: "Ilmenau", address: nil,
            openingHours: ["mon", "tue", "wed", "thu", "fri"].map { OpeningHour(weekday: $0, opensAt: opens, closesAt: closes) }
        )
    }

    /// Heute 12:15, damit die Status-Chips in jeder Preview gleich aussehen.
    static var now: Date {
        Calendar.current.date(bySettingHour: 12, minute: 15, second: 0, of: .now) ?? .now
    }
}

private struct MensaPreviewHost: View {
    @State var venue: MensaVenue = .mensaEhrenberg
    @State var mealtime: MensaMealtime = .lunch
    @State var dayIndex = 0
    var loadState: MensaLoadState = .loaded
    var meals: [MensaMeal] = MensaPreviewData.meals
    @State var filter = MensaFilter()

    var body: some View {
        NavigationStack {
            MensaScreen(
                days: MensaFormatting.workdays(from: MensaPreviewData.now),
                selectedDayIndex: $dayIndex,
                selectedVenue: $venue,
                mealtime: $mealtime,
                loadState: loadState,
                allMeals: meals,
                filter: $filter,
                canteens: MensaPreviewData.canteens,
                now: MensaPreviewData.now,
                onRetry: {},
                onOpenFilter: {}
            )
        }
    }
}

#Preview("Ehrenberg Mittag – Light") {
    MensaPreviewHost().preferredColorScheme(.light)
}

#Preview("Ehrenberg Mittag – Dark") {
    MensaPreviewHost().preferredColorScheme(.dark)
}

#Preview("Cafeteria Mittag – Light") {
    MensaPreviewHost(venue: .cafeteriaEhrenberg).preferredColorScheme(.light)
}

#Preview("Cafeteria Abendessen – Light") {
    MensaPreviewHost(venue: .cafeteriaEhrenberg, mealtime: .dinner).preferredColorScheme(.light)
}

#Preview("Cafeteria Abendessen – Dark") {
    MensaPreviewHost(venue: .cafeteriaEhrenberg, mealtime: .dinner).preferredColorScheme(.dark)
}

#Preview("Röntgenbau – Light") {
    MensaPreviewHost(venue: .roentgenbau).preferredColorScheme(.light)
}

#Preview("Anderer Tag – Light") {
    MensaPreviewHost(dayIndex: 4).preferredColorScheme(.light)
}

#Preview("Sonderfälle – Light") {
    MensaPreviewHost(meals: MensaPreviewData.edgeCases).preferredColorScheme(.light)
}

#Preview("Sonderfälle – Dark") {
    MensaPreviewHost(meals: MensaPreviewData.edgeCases).preferredColorScheme(.dark)
}

#Preview("Ladefehler") {
    MensaPreviewHost(loadState: .failed)
}

#Preview("Lädt") {
    MensaPreviewHost(loadState: .loading)
}

#Preview("Leer") {
    MensaPreviewHost(meals: [])
}

#Preview("Filter aktiv – Light") {
    MensaPreviewHost(filter: MensaFilter(diet: .vegetarisch, onlyBio: false, excludedAllergens: ["Gluten", "Ei"]))
        .preferredColorScheme(.light)
}

#Preview("Filter aktiv – Dark") {
    MensaPreviewHost(filter: MensaFilter(diet: .vegetarisch, onlyBio: true, excludedAllergens: ["Gluten"]))
        .preferredColorScheme(.dark)
}

#Preview("Filter blendet alles aus") {
    MensaPreviewHost(
        meals: MensaPreviewData.meals.filter { $0.canteenName == "Mensa Ehrenberg" },
        filter: MensaFilter(diet: .vegan, onlyBio: true)
    )
}

#Preview("Große Schrift") {
    MensaPreviewHost()
        .dynamicTypeSize(.xxxLarge)
}
