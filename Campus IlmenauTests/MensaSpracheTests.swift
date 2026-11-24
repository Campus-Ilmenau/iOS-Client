import Foundation
import Testing
@testable import Campus_Ilmenau

/// Mensa in zwei Sprachen: `lang` an der URL, `translated` im Modell, Filter über Kürzel, Speicher je Sprache.
struct MensaSpracheTests {
    private let base = "https://dev-api.campus-ilmenau.de/develop"

    private func query(_ url: URL?) -> [String: String] {
        let items = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - URL

    @Test func mealsURLCarriesLangForBothLanguages() {
        for language in AppLanguage.allCases {
            let url = MensaService.mealsURL(baseURL: base, period: .today, canteenId: nil, language: language)
            #expect(query(url)["lang"] == language.apiCode)
            #expect(url?.path == "/develop/v1/mensa")
        }
    }

    @Test func mealsURLKeepsOtherParameters() {
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))!
        let url = MensaService.mealsURL(baseURL: base, period: .date(day), canteenId: 46, language: .en)
        let items = query(url)
        #expect(items["date"] == "2026-11-24")
        #expect(items["canteen"] == "46")
        #expect(items["per_page"] == "100")
        #expect(items["lang"] == "en")
    }

    @Test func langIsAddedToCodesButNotToOtherPaths() {
        let codes = MensaService.url(baseURL: base, path: "/v1/mensa/codes", queryItems: [], language: .en)
        #expect(query(codes)["lang"] == "en")
        let dishes = MensaService.url(baseURL: base, path: "/v1/mensa/dishes/dish_1", queryItems: [], language: .en)
        #expect(query(dishes)["lang"] == nil)
        let canteens = MensaService.url(baseURL: base, path: "/v1/mensa/canteens", queryItems: [], language: .en)
        #expect(query(canteens)["lang"] == nil)
    }

    @Test func callerCannotOverrideLang() {
        let url = MensaService.url(
            baseURL: base, path: "/v1/mensa", queryItems: [URLQueryItem(name: "lang", value: "fr")], language: .de
        )
        #expect(url?.query?.components(separatedBy: "lang=").count == 2)
        #expect(query(url)["lang"] == "de")
    }

    // MARK: - Dekodierung

    private func json(translated: String, group: String = "Lunch", allergens: String = #"[{"code":"Wz","name":"Wheat","description":"contains wheat"}]"#) -> Data {
        Data("""
        {"object":"list","url":"/v1/mensa","has_more":false,"total_count":1,"data":[{
          "id":"meal_1","object":"meal",
          "canteen":{"rscId":46,"name":"Mensa Ehrenberg"},
          "date":"2026-11-24T00:00:00.000Z","mealGroup":"\(group)","title":"Mushroom stir-fry",
          \(translated)
          "isActive":true,"lastSeenAt":"2026-11-24T09:00:09.000Z",
          "additiveCodes":[{"code":"7","name":"Waxed","description":"waxed"}],
          "allergenCodes":\(allergens),
          "symbolCodes":[{"code":"V","name":"Vegetarian","description":"Vegetarian dishes"}],
          "flags":{"vegetarian":true,"vegan":false,"pork":false,"beef":false,"poultry":false,"fish":false,"garlic":false,"alcohol":false},
          "price":{"student":2.8,"staff":5.1,"guest":6.5,"currency":"€"},
          "components":[{"name":"Potato rösti","codes":[
            {"code":"Wz","name":"Wheat","description":"contains wheat"},
            {"code":"7","name":"Waxed","description":"waxed"},
            {"code":"V","name":"Vegetarian","description":"Vegetarian dishes"}]}],
          "createdAt":"2026-11-09T06:30:14.069Z","updatedAt":"2026-11-24T09:00:09.000Z"}]}
        """.utf8)
    }

    @Test func decodesTranslatedTrue() throws {
        let meal = try #require(try MensaService.meals(from: json(translated: #""translated":true,"#)).first)
        #expect(meal.translated)
        #expect(meal.category == "Lunch")
    }

    @Test func decodesTranslatedFalse() throws {
        let meal = try #require(try MensaService.meals(from: json(translated: #""translated":false,"#, group: "Mittagessen")).first)
        #expect(!meal.translated)
    }

    @Test func missingTranslatedDefaultsToFalse() throws {
        let meal = try #require(try MensaService.meals(from: json(translated: "")).first)
        #expect(!meal.translated)
    }

    @Test func codesCarryLanguageIndependentKeys() throws {
        let meal = try #require(try MensaService.meals(from: json(translated: #""translated":true,"#)).first)
        #expect(meal.allergenCodes == [MensaCodeRef(code: "Wz", name: "Wheat")])
        #expect(meal.allergies == ["Wheat"])
        #expect(meal.additiveCodes.map(\.code) == ["7"])
        #expect(meal.badges == ["Vegetarisch"])
    }

    @Test func componentInfoSplitsByCodeNotByName() throws {
        let meal = try #require(try MensaService.meals(from: json(translated: #""translated":true,"#)).first)
        let info = try #require(meal.componentInfos.first)
        #expect(info.allergens == ["Wheat"])
        #expect(info.additives == ["Waxed"])
    }

    // MARK: - Filter über Kürzel

    @Test func allergenFilterWorksOnEnglishMeal() throws {
        let meal = try #require(try MensaService.meals(from: json(translated: #""translated":true,"#)).first)
        let filter = MensaFilter(diet: .alle, onlyBio: false, excludedAllergens: ["Wz"])
        #expect(!filter.matches(meal))
        #expect(MensaFilter(excludedAllergens: ["Mi"]).matches(meal))
    }

    @Test func allergenFilterSameResultInBothLanguages() throws {
        let en = try #require(try MensaService.meals(from: json(translated: #""translated":true,"#)).first)
        let de = try #require(try MensaService.meals(from: json(
            translated: #""translated":false,"#, group: "Mittagessen",
            allergens: #"[{"code":"Wz","name":"Weizen","description":"enthält Weizen"}]"#
        )).first)
        let filter = MensaFilter(excludedAllergens: ["Wz"])
        #expect(filter.matches(en) == filter.matches(de))
    }

    @Test func legacyFilterWithGermanNamesIsMigrated() throws {
        let old = Data(#"{"diet":"vegetarisch","onlyBio":true,"excludedAllergens":["Weizen","Milch und Milchzucker","Ei"]}"#.utf8)
        let filter = try JSONDecoder().decode(MensaFilter.self, from: old)
        #expect(filter.excludedAllergens == ["Wz", "Mi", "Ei"])
        #expect(filter.diet == .vegetarisch)
        #expect(filter.onlyBio)
    }

    @Test func filterRoundTripKeepsCodes() throws {
        let filter = MensaFilter(diet: .vegan, onlyBio: false, excludedAllergens: ["Sel", "Sen"])
        let decoded = try JSONDecoder().decode(MensaFilter.self, from: JSONEncoder().encode(filter))
        #expect(decoded == filter)
    }

    @Test func legacyThreeStateFilterMigratesToCodes() {
        let filter = MensaFilterStore.migrate(legacy: ["Weizen": "exclude", "Vegan": "include"])
        #expect(filter.excludedAllergens == ["Wz"])
        #expect(filter.diet == .vegan)
    }

    @Test func allAllergensHaveANameAndAreUnique() {
        #expect(Set(MensaAllergen.knownCodes).count == 26)
        for code in MensaAllergen.knownCodes {
            #expect(MensaAllergen.displayName(code: code) != code, "\(code)")
        }
    }

    // MARK: - Mahlzeit

    private func meal(group: String) -> MensaMeal {
        MensaMeal(
            id: "m", category: group, name: "x", description: nil,
            price: MensaMealPrice(student: 1, staff: 2, guest: 3, currency: "€"),
            allergies: [], badges: [], additives: [], categories: [], co2GramPerPortion: nil, components: [],
            canteenName: "Cafeteria Ehrenberg", date: .now
        )
    }

    @Test func dinnerIsRecognisedInBothLanguages() {
        #expect(MensaMealtime.isDinner(meal(group: "Abendessen")))
        #expect(MensaMealtime.isDinner(meal(group: "Dinner")))
        #expect(!MensaMealtime.isDinner(meal(group: "Mittagessen")))
        #expect(!MensaMealtime.isDinner(meal(group: "Lunch")))
    }

    // MARK: - Speicher je Sprache

    @Test func widgetStoreDropsMealsFromOtherLanguage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WidgetStore-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let gericht = WidgetGericht(
            id: "1", name: "Pilzpfanne", gruppe: "Mittagessen", abendessen: false, waehrung: "EUR", chips: [],
            allergene: ["Weizen"], allergenCodes: ["Wz"]
        )
        let mensa = WidgetMensa(
            id: "mensaEhrenberg", name: "Mensa Ehrenberg", kurzname: "Ehrenberg",
            heute: WidgetSpeiseplan(tag: "2026-11-24", gerichte: [gericht])
        )

        let deutsch = WidgetStore(dateiURL: url, sprache: { .de })
        deutsch.aendern { $0.mensen = [mensa] }
        #expect(deutsch.lesen().mensen.first?.heute?.gerichte.count == 1)

        // Gleiche Datei, englische Oberfläche: keine deutschen Gerichte als englisch anzeigen.
        let englisch = WidgetStore(dateiURL: url, sprache: { .en })
        #expect(englisch.lesen().mensen.first?.heute == nil)
        #expect(englisch.lesen().mensen.first?.name == "Mensa Ehrenberg")

        // Zurück auf Deutsch: Der Stand auf der Platte ist unverändert deutsch.
        #expect(deutsch.lesen().mensen.first?.heute?.gerichte.count == 1)
    }

    @Test func widgetStoreRejectsOldFileWithoutLanguage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WidgetStore-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var alt = WidgetSnapshot()
        alt.mensen = [WidgetMensa(id: "mensaEhrenberg", name: "Mensa Ehrenberg", kurzname: "Ehrenberg",
                                  heute: WidgetSpeiseplan(tag: "2026-11-24", gerichte: []))]
        try JSONEncoder().encode(alt).write(to: url)
        #expect(WidgetStore(dateiURL: url, sprache: { .de }).lesen().mensen.first?.heute == nil)
    }

    @Test func widgetFilterUsesCodesNotNames() {
        let gericht = WidgetGericht(
            id: "1", name: "Mushroom", gruppe: "Lunch", abendessen: false, waehrung: "EUR", chips: [],
            allergene: ["Wheat"], allergenCodes: ["Wz"]
        )
        #expect(!MensaFilter(excludedAllergens: ["Wz"]).matches(gericht))
    }
}
