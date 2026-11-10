import Foundation
import Testing
@testable import Campus_Ilmenau

struct MensaFilterTests {
    // MARK: - Beispielgerichte

    private func meal(
        _ id: String,
        badges: [String] = [],
        allergies: [String] = [],
        canteen: String = "Mensa Ehrenberg"
    ) -> MensaMeal {
        MensaMeal(
            id: id,
            category: "Mittagessen",
            name: id,
            description: nil,
            price: MensaMealPrice(student: 2.9, staff: 4.4, guest: 5.8, currency: "€"),
            allergies: allergies,
            badges: badges,
            additives: [],
            categories: [],
            co2GramPerPortion: nil,
            components: [],
            canteenName: canteen,
            date: .now
        )
    }

    private var meat: MensaMeal { meal("meat", allergies: ["Gluten"]) }
    private var vegetarian: MensaMeal { meal("vegetarian", badges: ["Vegetarisch"], allergies: ["Milch"]) }
    private var vegan: MensaMeal { meal("vegan", badges: ["Vegan", "Vegetarisch"]) }
    private var veganOnly: MensaMeal { meal("veganOnly", badges: ["Vegan"], allergies: ["Soja"]) }
    private var bioVegan: MensaMeal { meal("bioVegan", badges: ["Vegan", "Bio"], allergies: ["Gluten"]) }
    private var bioVegetarian: MensaMeal { meal("bioVegetarian", badges: ["Vegetarisch", "Bio"]) }

    private func ids(_ meals: [MensaMeal]) -> [String] { meals.map(\.id) }

    // MARK: - Ernährung

    @Test func defaultFilterIsInactiveAndKeepsEverything() {
        let filter = MensaFilter()
        let meals = [meat, vegetarian, vegan]
        #expect(!filter.isActive)
        #expect(filter.extraCount == 0)
        #expect(filter.summary == nil)
        #expect(ids(filter.apply(to: meals)) == ["meat", "vegetarian", "vegan"])
    }

    @Test func vegetarianAlsoShowsVeganMeals() {
        let filter = MensaFilter(diet: .vegetarisch)
        let result = filter.apply(to: [meat, vegetarian, vegan, veganOnly])
        // Auch ein Gericht, das nur „Vegan“ trägt, ist vegetarisch.
        #expect(ids(result) == ["vegetarian", "vegan", "veganOnly"])
    }

    @Test func veganShowsOnlyVeganMeals() {
        let filter = MensaFilter(diet: .vegan)
        #expect(ids(filter.apply(to: [meat, vegetarian, vegan, veganOnly])) == ["vegan", "veganOnly"])
    }

    // MARK: - Bio und Allergene

    @Test func bioAndAllergenAreCombinedWithAnd() {
        let filter = MensaFilter(diet: .alle, onlyBio: true, excludedAllergens: ["Gluten"])
        // Bio: bioVegan, bioVegetarian. Ohne Gluten schließt bioVegan aus.
        #expect(ids(filter.apply(to: [meat, vegan, bioVegan, bioVegetarian])) == ["bioVegetarian"])
        #expect(filter.extraCount == 2)
    }

    @Test func dietBioAndAllergenAllApplyTogether() {
        let filter = MensaFilter(diet: .vegan, onlyBio: true, excludedAllergens: ["Soja"])
        #expect(ids(filter.apply(to: [bioVegan, bioVegetarian, veganOnly])) == ["bioVegan"])
    }

    @Test func excludedAllergenRemovesMealsWithAnyOfThem() {
        let filter = MensaFilter(excludedAllergens: ["Milch", "Soja"])
        #expect(ids(filter.apply(to: [meat, vegetarian, veganOnly, vegan])) == ["meat", "vegan"])
    }

    // MARK: - Alles herausgefiltert

    @Test func filterCanRemoveEveryMeal() {
        let filter = MensaFilter(diet: .vegan, onlyBio: true)
        let meals = [meat, vegetarian, vegan]
        let result = filter.apply(to: meals)
        #expect(result.isEmpty)
        // Die Ausgangsliste bleibt unverändert, der leere Zustand unterscheidet sich von „kein Angebot“.
        #expect(!meals.isEmpty)
        #expect(filter.isActive)
    }

    @Test func filterAppliesPerVenueWithoutDroppingVenues() {
        let filter = MensaFilter(diet: .vegan, onlyBio: true)
        let meals = [
            meal("a", badges: ["Vegan", "Bio"], canteen: "Cafeteria NANOteria"),
            meal("b", badges: ["Vegetarisch"], canteen: "Mensa Ehrenberg")
        ]
        let filtered = filter.apply(to: meals)
        let byVenue = MensaVenue.allCases.map { venue in
            filtered.filter { venue.matches(canteenName: $0.canteenName) }.count
        }
        // Reihenfolge der Mensen: Mensa Ehrenberg, Cafeteria Ehrenberg, Nanoteria, Röntgenbau
        #expect(byVenue == [0, 0, 1, 0])
    }

    // MARK: - Texte

    @Test func summaryListsBioAndSortedAllergens() {
        let filter = MensaFilter(diet: .vegetarisch, onlyBio: true, excludedAllergens: ["Gluten", "Ei"])
        #expect(filter.summary == "Nur Bio · ohne Ei, Gluten")
        #expect(filter.activeDescription == "Vegetarisch · Nur Bio · ohne Ei, Gluten")
    }

    @Test func availableAllergensAlwaysContainAllTwentySixKnownOnes() {
        let list = MensaFilter.availableAllergens(in: [], keeping: [])
        #expect(MensaFilter.knownAllergens.count == 26)
        #expect(Set(MensaFilter.knownAllergens).count == 26)
        #expect(list.count == 26)
        // Auch Allergene, die selten im Speiseplan stehen.
        #expect(list.contains("Walnüsse"))
        #expect(list.contains("Hühnerei"))
        #expect(list.contains("Milch und Milchzucker"))
        #expect(list.contains("Weichtiere"))
    }

    @Test func availableAllergensAreSortedAndWithoutDuplicates() {
        let meals = [meal("x", allergies: ["Sellerie", "Sellerie", "Hühnerei"])]
        let list = MensaFilter.availableAllergens(in: meals, keeping: [])
        #expect(list.count == 26)
        #expect(list == list.sorted { $0.localizedCompare($1) == .orderedAscending })
    }

    @Test func availableAllergensAddUnknownOnesFromMealsAndExcluded() {
        let meals = [meal("x", allergies: ["Sellerie", "Lupinenkaffee"])]
        let list = MensaFilter.availableAllergens(in: meals, keeping: ["Alt-Allergen"])
        // Neue Allergene der API und alte, bereits ausgeschlossene bleiben sichtbar.
        #expect(list.contains("Lupinenkaffee"))
        #expect(list.contains("Alt-Allergen"))
        #expect(list.count == 28)
    }

    // MARK: - Migration

    @Test func migrationMapsOldStates() {
        let legacy = [
            "Vegan": "include",
            "Bio": "include",
            "Gluten": "exclude",
            "Ei": "exclude",
            "Milch": "include",       // Allergen einschließen → egal
            "Vegetarisch": "exclude"  // Badge ausschließen → egal
        ]
        let filter = MensaFilterStore.migrate(legacy: legacy)
        #expect(filter.diet == .vegan)
        #expect(filter.onlyBio)
        #expect(filter.excludedAllergens == ["Gluten", "Ei"])
    }

    @Test func migrationVegetarianIncludeBecomesVegetarianStep() {
        #expect(MensaFilterStore.migrate(legacy: ["Vegetarisch": "include"]).diet == .vegetarisch)
        // Vegan und Vegetarisch eingeschlossen: die strengere Stufe gilt.
        #expect(MensaFilterStore.migrate(legacy: ["Vegan": "include", "Vegetarisch": "include"]).diet == .vegan)
    }

    @Test func migrationOfOnlyNeutralStatesGivesInactiveFilter() {
        let filter = MensaFilterStore.migrate(legacy: ["Vegan": "any", "Gluten": "any", "Bio": "exclude"])
        #expect(filter == MensaFilter())
    }

    // MARK: - Speicher

    private func makeDefaults() -> UserDefaults {
        let suite = "MensaFilterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func loadMigratesLegacyKeyStoresNewKeyAndRemovesOldOne() throws {
        let defaults = makeDefaults()
        let legacy = ["Vegan": "include", "Gluten": "exclude", "Bio": "include"]
        defaults.set(try JSONEncoder().encode(legacy), forKey: MensaFilterStore.legacyKey)

        let loaded = MensaFilterStore.load(defaults: defaults)

        #expect(loaded == MensaFilter(diet: .vegan, onlyBio: true, excludedAllergens: ["Gluten"]))
        #expect(defaults.data(forKey: MensaFilterStore.legacyKey) == nil)
        #expect(defaults.data(forKey: MensaFilterStore.key) != nil)
        // Beim nächsten Start kommt derselbe Filter aus dem neuen Schlüssel.
        #expect(MensaFilterStore.load(defaults: defaults) == loaded)
    }

    @Test func loadWithoutAnyDataGivesInactiveFilter() {
        #expect(MensaFilterStore.load(defaults: makeDefaults()) == MensaFilter())
    }

    @Test func saveAndLoadRoundTrip() {
        let defaults = makeDefaults()
        let filter = MensaFilter(diet: .vegetarisch, onlyBio: true, excludedAllergens: ["Ei", "Soja"])
        MensaFilterStore.save(filter, defaults: defaults)
        #expect(MensaFilterStore.load(defaults: defaults) == filter)
    }

    @Test func newKeyWinsAndLeftoverLegacyKeyIsRemoved() throws {
        let defaults = makeDefaults()
        MensaFilterStore.save(MensaFilter(diet: .vegan), defaults: defaults)
        defaults.set(try JSONEncoder().encode(["Bio": "include"]), forKey: MensaFilterStore.legacyKey)

        #expect(MensaFilterStore.load(defaults: defaults) == MensaFilter(diet: .vegan))
        #expect(defaults.data(forKey: MensaFilterStore.legacyKey) == nil)
    }

    // MARK: - Gemeinsame Logik für Widget und App

    @Test func widgetUndMensaAnsichtFilternGleich() {
        let meals = [meat, vegetarian, vegan, veganOnly, bioVegan, bioVegetarian]
        let filters = [
            MensaFilter(), MensaFilter(diet: .vegetarisch), MensaFilter(diet: .vegan), MensaFilter(onlyBio: true),
            MensaFilter(diet: .vegan, onlyBio: true), MensaFilter(excludedAllergens: ["Gluten", "Soja"]),
            MensaFilter(diet: .vegetarisch, excludedAllergens: ["Milch"])
        ]
        for filter in filters {
            let gerichte = meals.map { meal in
                WidgetGericht(
                    id: meal.id, name: meal.name, gruppe: "Mittag", abendessen: false, preisStudierende: nil,
                    preisBedienstete: nil, preisGaeste: nil, waehrung: "EUR", chips: meal.widgetChips,
                    allergene: meal.allergies
                )
            }
            #expect(filter.apply(to: gerichte).map(\.id) == ids(filter.apply(to: meals)), "Filter: \(filter.activeDescription)")
        }
    }

    @Test func gerichtOhneAllergeneAusAelterenDateienLaesstSichLesen() throws {
        let json = #"{"id":"1","name":"Suppe","gruppe":"Mittag","abendessen":false,"waehrung":"EUR","chips":[]}"#
        let gericht = try JSONDecoder().decode(WidgetGericht.self, from: Data(json.utf8))
        #expect(gericht.allergene.isEmpty)
        let rund = try JSONDecoder().decode(WidgetGericht.self, from: JSONEncoder().encode(WidgetGericht(
            id: "2", name: "Pasta", gruppe: "Mittag", abendessen: false, preisStudierende: nil, preisBedienstete: nil,
            preisGaeste: nil, waehrung: "EUR", chips: [], allergene: ["Weizen"]
        )))
        #expect(rund.allergene == ["Weizen"])
    }

    // MARK: - Übernahme in die App Group

    @Test func filterWirdEinmaligInDieGruppeUebernommen() throws {
        let alt = makeDefaults(), neu = makeDefaults()
        MensaFilterStore.save(MensaFilter(diet: .vegan, onlyBio: true), defaults: alt)

        AppGroup.uebernimmEinstellungenEinmalig(von: alt, nach: neu)

        #expect(MensaFilterStore.load(defaults: neu) == MensaFilter(diet: .vegan, onlyBio: true))
        #expect(alt.data(forKey: MensaFilterStore.key) == nil)
    }

    @Test func filterWirdAuchNachDerErstenUebernahmeNachgeholt() throws {
        let alt = makeDefaults(), neu = makeDefaults()
        neu.set(true, forKey: "appGroupEinstellungenUebernommen")
        MensaFilterStore.save(MensaFilter(diet: .vegetarisch), defaults: alt)

        AppGroup.uebernimmEinstellungenEinmalig(von: alt, nach: neu)

        #expect(MensaFilterStore.load(defaults: neu) == MensaFilter(diet: .vegetarisch))
    }

    @Test func alterDreiZustandeFilterWirdInDerGruppeUmgerechnet() throws {
        let alt = makeDefaults(), neu = makeDefaults()
        alt.set(try JSONEncoder().encode(["Vegan": "include", "Gluten": "exclude"]), forKey: MensaFilterStore.legacyKey)

        AppGroup.uebernimmEinstellungenEinmalig(von: alt, nach: neu)

        #expect(MensaFilterStore.load(defaults: neu) == MensaFilter(diet: .vegan, excludedAllergens: ["Gluten"]))
    }

    @Test func filterInDerGruppeBleibt() throws {
        let alt = makeDefaults(), neu = makeDefaults()
        MensaFilterStore.save(MensaFilter(diet: .vegan), defaults: alt)
        MensaFilterStore.save(MensaFilter(onlyBio: true), defaults: neu)

        AppGroup.uebernimmEinstellungenEinmalig(von: alt, nach: neu)

        #expect(MensaFilterStore.load(defaults: neu) == MensaFilter(onlyBio: true))
    }
}
