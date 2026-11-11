import Testing
import Foundation
@testable import Campus_Ilmenau

// MARK: - Fixtures

/// Ein Zeitpunkt am Berliner Tag `yyyy-MM-dd` zur Uhrzeit.
private func berlin(_ tag: String, _ uhr: String) -> Date {
    let datum = tag.split(separator: "-").compactMap { Int($0) }
    let zeit = uhr.split(separator: ":").compactMap { Int($0) }
    return EventKalender.kalender.date(from: DateComponents(
        year: datum[0], month: datum[1], day: datum[2], hour: zeit[0], minute: zeit[1]
    ))!
}

private func gericht(_ name: String, mensa: String, gruppe: String = "Mittag", badges: [String] = []) -> MensaMeal {
    MensaMeal(
        id: "\(mensa)-\(name)", category: gruppe, name: name, description: nil,
        price: MensaMealPrice(student: 2.9, staff: 3.9, guest: 4.9, currency: "EUR"),
        allergies: [], badges: badges, additives: [], categories: [], co2GramPerPortion: nil, components: [],
        canteenName: mensa, date: berlin("2026-10-30", "12:00")
    )
}

private func tempDatei() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("WidgetStore-\(UUID().uuidString).json")
}

/// Liefert pro Tag einen festen Speiseplan und merkt sich, welche Tage abgefragt wurden.
@MainActor
private final class MensaQuelleStub: HeuteMensaDatenquelle {
    var plaene: [String: [MensaMeal]] = [:]
    private(set) var abgefragt: [String] = []

    func speiseplan(am tag: Date) async throws -> [MensaMeal] {
        let schluessel = EventKalender.berlinDatum(tag)
        abgefragt.append(schluessel)
        return plaene[schluessel] ?? []
    }

    func mensen() async throws -> [Canteen] { [] }
}

@MainActor
private final class Neuladen {
    private(set) var aufrufe: [[String]] = []
    var kinds: Set<String> { Set(aufrufe.flatMap { $0 }) }
    func callAsFunction(_ kinds: [String]) { aufrufe.append(kinds) }
}

// MARK: - Deeplinks

struct DeepLinkTests {
    /// Jede Zeile der Tabelle in `Uebergabe.md` öffnet das richtige Ziel.
    @Test(arguments: [
        ("campusilmenau://mensa?mensa=nanoteria", DeepLink.mensa(id: "nanoteria")),
        ("campusilmenau://mensa", DeepLink.mensa(id: nil)),
        ("campusilmenau://mensa/gericht/meal_62e88be1", DeepLink.gericht(id: "meal_62e88be1", tag: nil)),
        ("campusilmenau://mensa/gericht/meal_1?tag=2026-11-09", DeepLink.gericht(id: "meal_1", tag: "2026-11-09")),
        ("campusilmenau://events", DeepLink.events),
        ("campusilmenau://events?filter=heute-abend", DeepLink.eventsHeuteAbend),
        ("campusilmenau://events/evt_dec1b86b", DeepLink.event(id: "evt_dec1b86b")),
        ("campusilmenau://thoska/auslesen", DeepLink.thoskaAuslesen),
        ("campusilmenau://katalog/suche", DeepLink.katalogSuche),
        ("campusilmenau://katalog/suche?q=Analysis", DeepLink.katalogSuchen(begriff: "Analysis")),
        ("campusilmenau://katalog/suche?q=lineare%20Algebra", DeepLink.katalogSuchen(begriff: "lineare Algebra")),
        ("campusilmenau://katalog/suche?q=", DeepLink.katalogSuche),
        ("campusilmenau://katalog/titel/ppn_123", DeepLink.katalogTitel(id: "ppn_123")),
        ("campusilmenau://mensa/zeiten", DeepLink.mensaZeiten),
        ("campusilmenau://bibliothek/merkliste", DeepLink.merkliste)
    ])
    func tabelle(_ text: String, _ erwartet: DeepLink) throws {
        let url = try #require(URL(string: text))
        #expect(DeepLink(url: url) == erwartet)
    }

    @Test(arguments: [
        "https://campus-ilmenau.de/mensa",
        "campusilmenau://unbekannt",
        "campusilmenau://events?filter=anderes",
        "campusilmenau://thoska",
        "campusilmenau://mensa/gericht",
        "campusilmenau://katalog/suche/zuviel",
        "campusilmenau://katalog/titel",
        "campusilmenau://katalog/titel/a/b",
        "campusilmenau://mensa/zeiten/zuviel",
        "campusilmenau://bibliothek",
        "campusilmenau://bibliothek/ausleihen"
    ])
    func unbekanntes(_ text: String) throws {
        let url = try #require(URL(string: text))
        #expect(DeepLink(url: url) == nil)
    }

    @Test func urlUndZurueck() {
        let links: [DeepLink] = [
            .mensa(id: "roentgenbau"), .mensa(id: nil),
            .gericht(id: "meal_a/b c?d", tag: "2026-11-02"), .gericht(id: "x", tag: nil),
            .events, .eventsHeuteAbend, .event(id: "evt 1/2"), .thoskaAuslesen, .katalogSuche,
            .katalogSuchen(begriff: "C++ & Swift = 100% ä/ö"), .katalogTitel(id: "ppn 1/2"),
            .mensaZeiten, .merkliste
        ]
        for link in links {
            #expect(DeepLink(url: link.url) == link, "\(link.url)")
        }
    }
}

// MARK: - Einstellungen

struct AppGroupEinstellungenTests {
    private func defaults() throws -> UserDefaults {
        let name = "AppGroupTests-\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    @Test func uebernimmtBisherigeWerteEinmalig() throws {
        let alt = try defaults(), neu = try defaults()
        alt.set("roentgenbau", forKey: AppGroup.heuteMensaSchluessel)
        alt.set("gaeste", forKey: AppGroup.preisgruppeSchluessel)

        AppGroup.uebernimmEinstellungenEinmalig(von: alt, nach: neu)

        #expect(neu.string(forKey: AppGroup.heuteMensaSchluessel) == "roentgenbau")
        #expect(neu.string(forKey: AppGroup.preisgruppeSchluessel) == "gaeste")
        #expect(alt.object(forKey: AppGroup.heuteMensaSchluessel) == nil)
        #expect(alt.object(forKey: AppGroup.preisgruppeSchluessel) == nil)

        // Ein späterer Wert im Alten (z. B. von einer älteren App-Version) überschreibt nichts mehr.
        alt.set("nanoteria", forKey: AppGroup.heuteMensaSchluessel)
        AppGroup.uebernimmEinstellungenEinmalig(von: alt, nach: neu)
        #expect(neu.string(forKey: AppGroup.heuteMensaSchluessel) == "roentgenbau")
    }

    @Test func einWertInDerGruppeBleibt() throws {
        let alt = try defaults(), neu = try defaults()
        alt.set("nanoteria", forKey: AppGroup.heuteMensaSchluessel)
        neu.set("mensaEhrenberg", forKey: AppGroup.heuteMensaSchluessel)

        AppGroup.uebernimmEinstellungenEinmalig(von: alt, nach: neu)

        #expect(neu.string(forKey: AppGroup.heuteMensaSchluessel) == "mensaEhrenberg")
    }

    @Test func ohneAlteWerteBleibenDieVorgaben() throws {
        let alt = try defaults(), neu = try defaults()
        AppGroup.uebernimmEinstellungenEinmalig(von: alt, nach: neu)
        #expect(HeuteMensaSpeicher(defaults: neu).venue == .mensaEhrenberg)
    }

    @Test func schluesselSindDieDerApp() {
        #expect(HeuteMensaSpeicher.schluessel == AppGroup.heuteMensaSchluessel)
        #expect(MensaPriceGroup.storageKey == AppGroup.preisgruppeSchluessel)
    }
}

// MARK: - Speicher

struct WidgetStoreTests {
    @Test func schreibenUndLesen() {
        let store = WidgetStore(dateiURL: tempDatei())
        #expect(store.lesen() == WidgetSnapshot())

        let geaendert = store.aendern { $0.gemerkteEventIDs = ["a", "b"] }
        #expect(geaendert)
        #expect(store.lesen().gemerkteEventIDs == ["a", "b"])
        #expect(store.lesen().stand != nil)
    }

    @Test func gleicheDatenSindKeineAenderung() {
        let store = WidgetStore(dateiURL: tempDatei())
        store.aendern { $0.gemerkteEventIDs = ["a"] }
        #expect(!store.aendern { $0.gemerkteEventIDs = ["a"] })
    }

    @Test func ohneDateiOrtPassiertNichts() {
        let store = WidgetStore(dateiURL: nil)
        #expect(!store.aendern { $0.gemerkteEventIDs = ["a"] })
        #expect(store.lesen() == WidgetSnapshot())
    }

    /// Der Speicher enthält genau die erlaubten Teile und keine Kontodaten.
    @Test func nurErlaubteFelder() throws {
        let datei = tempDatei()
        let store = WidgetStore(dateiURL: datei)
        store.aendern { snapshot in
            snapshot.mensen = [WidgetMensa(id: "mensaEhrenberg", name: "Mensa Ehrenberg", kurzname: "Ehrenberg")]
            snapshot.gemerkteEventIDs = ["a"]
        }
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: datei)) as? [String: Any])
        #expect(Set(json.keys) == ["mensen", "events", "gemerkteEventIDs", "stand"])
        let mensa = try #require((json["mensen"] as? [[String: Any]])?.first)
        #expect(Set(mensa.keys) == ["id", "name", "kurzname", "oeffnungszeiten"])
    }
}

// MARK: - Schreiben aus der App

@MainActor
struct WidgetSyncTests {
    private let freitag = "2026-10-30"
    private let montag = "2026-11-02"

    private func aufbau() -> (sync: WidgetSync, store: WidgetStore, neuladen: Neuladen) {
        let store = WidgetStore(dateiURL: tempDatei())
        let neuladen = Neuladen()
        return (WidgetSync(store: store, neuLaden: { neuladen($0) }), store, neuladen)
    }

    private func mensen() -> [Canteen] {
        MensaVenue.allCases.map { venue in
            Canteen(
                rscId: nil, name: venue.apiName, hasMenu: true, city: nil, address: nil,
                openingHours: [OpeningHour(weekday: "MON", opensAt: "11:00", closesAt: "14:00")]
            )
        }
    }

    @Test func schreibtHeuteOeffnungszeitenUndNaechstenTag() async {
        let (sync, store, neuladen) = aufbau()
        let quelle = MensaQuelleStub()
        let heute = [
            gericht("Linsen-Dal", mensa: "Mensa Ehrenberg", badges: ["Vegan"]),
            gericht("Flammkuchen", mensa: "Cafeteria Mensa Ehrenberg", gruppe: "Abendessen")
        ]
        let morgen = [gericht("Reispfanne", mensa: "Cafeteria NANOteria")]

        await sync.speichereMensa(
            mensen: mensen(), heute: heute, morgen: morgen, quelle: quelle, jetzt: berlin(freitag, "12:00")
        )

        let snapshot = store.lesen()
        #expect(snapshot.mensen.map(\.id) == MensaVenue.allCases.map(\.rawValue))
        let ehrenberg = snapshot.mensa(id: "mensaEhrenberg")
        #expect(ehrenberg?.heute?.tag == freitag)
        #expect(ehrenberg?.heute?.gerichte.map(\.name) == ["Linsen-Dal"])
        #expect(ehrenberg?.heute?.gerichte.first?.chips == [WidgetChip(titel: "Vegan", art: .gruen)])
        #expect(ehrenberg?.oeffnungszeiten == [WidgetOeffnung(wochentag: "mon", oeffnet: "11:00", schliesst: "14:00")])
        let cafeteria = snapshot.mensa(id: "cafeteriaEhrenberg")?.heute?.gerichte.first
        #expect(cafeteria?.abendessen == true)
        #expect(cafeteria?.preisStudierende == 2.9)
        #expect(cafeteria?.preisGaeste == 4.9)
        // Nur Nanoteria hat morgen einen Plan; die übrigen suchen weiter und finden nichts.
        #expect(snapshot.mensa(id: "nanoteria")?.naechsterOeffnungstag?.gerichte.map(\.name) == ["Reispfanne"])
        #expect(neuladen.kinds == [WidgetKinds.mensa])
    }

    @Test func suchtAmWochenendeDenNaechstenOeffnungstag() async {
        let (sync, store, _) = aufbau()
        let quelle = MensaQuelleStub()
        quelle.plaene[montag] = MensaVenue.allCases.map { gericht("Montagsessen", mensa: $0.apiName) }

        // Freitag: Samstag („morgen“) ist leer, Sonntag auch, Montag hat Gerichte.
        await sync.speichereMensa(
            mensen: mensen(), heute: [], morgen: [], quelle: quelle, jetzt: berlin(freitag, "12:00")
        )

        #expect(quelle.abgefragt == ["2026-11-01", montag])
        for venue in MensaVenue.allCases {
            let naechster = store.lesen().mensa(id: venue.rawValue)?.naechsterOeffnungstag
            #expect(naechster?.tag == montag, "\(venue)")
            #expect(naechster?.gerichte.first?.name == "Montagsessen")
        }
    }

    @Test func fehlendeDatenLassenDenAltenStandStehen() async {
        let (sync, store, _) = aufbau()
        let quelle = MensaQuelleStub()
        await sync.speichereMensa(
            mensen: mensen(), heute: [gericht("Alt", mensa: "Mensa Ehrenberg")], morgen: nil,
            quelle: quelle, jetzt: berlin(freitag, "12:00")
        )

        // Zweiter Versuch ohne Daten (Netzfehler): nichts wird gelöscht.
        await sync.speichereMensa(mensen: nil, heute: nil, morgen: nil, quelle: quelle, jetzt: berlin(freitag, "13:00"))

        let ehrenberg = store.lesen().mensa(id: "mensaEhrenberg")
        #expect(ehrenberg?.heute?.gerichte.map(\.name) == ["Alt"])
        #expect(ehrenberg?.oeffnungszeiten.count == 1)
    }

    @Test func eventsNurDerAbendMitAbgesagtenOhneGanztaegige() {
        let (sync, store, neuladen) = aufbau()
        func event(_ id: String, _ von: String, bis: String? = nil, status: EventStatus = .findetStatt, ganztaegig: Bool = false) -> CampusEvent {
            CampusEvent(
                id: id, titel: id, beginn: berlin(freitag, von), ende: bis.map { berlin(freitag, $0) },
                ganztaegig: ganztaegig, status: status
            )
        }
        let liste = [
            event("frueh", "10:00", bis: "12:00"),
            event("laeuftInDenAbend", "15:00", bis: "18:30"),
            event("abend", "19:00", bis: "23:00"),
            event("abgesagt", "20:00", status: .abgesagt),
            event("ganztags", "00:00", ganztaegig: true)
        ]

        sync.speichereEvents(heute: liste, morgen: [], abgesagteMitgeliefert: true, jetzt: berlin(freitag, "09:00"))

        // Abgesagte bleiben drin (das Widget zeigt „Fällt aus“), Ganztägige und Frühe nicht.
        #expect(store.lesen().events.map(\.id) == ["laeuftInDenAbend", "abend", "abgesagt"])
        #expect(store.lesen().events.map(\.abgesagt) == [false, false, true])
        #expect(neuladen.kinds == [WidgetKinds.heuteAbend])
    }

    @Test func nichtGeladenerTagBleibtErhalten() {
        let (sync, store, _) = aufbau()
        let heute = CampusEvent(id: "heute", titel: "Heute", beginn: berlin(freitag, "20:00"))
        let morgen = CampusEvent(id: "morgen", titel: "Morgen", beginn: berlin("2026-10-31", "20:00"))
        sync.speichereEvents(heute: [heute], morgen: [morgen], abgesagteMitgeliefert: true, jetzt: berlin(freitag, "09:00"))

        // Nur „morgen“ ist neu geladen; „heute“ bleibt, wie es war.
        sync.speichereEvents(heute: nil, morgen: [], abgesagteMitgeliefert: true, jetzt: berlin(freitag, "09:30"))

        #expect(store.lesen().events.map(\.id) == ["heute"])
    }

    @Test func merklisteUndEinstellungenMelden() {
        let (sync, store, neuladen) = aufbau()

        sync.speichereMerkliste(["b", "a"])
        #expect(store.lesen().gemerkteEventIDs == ["a", "b"])
        #expect(neuladen.kinds == [WidgetKinds.heuteAbend])

        // Gleiche Merkliste: kein Neuladen.
        let anzahl = neuladen.aufrufe.count
        sync.speichereMerkliste(["a", "b"])
        #expect(neuladen.aufrufe.count == anzahl)

        sync.einstellungenGeaendert()
        #expect(neuladen.aufrufe.last == [WidgetKinds.mensa])
    }
}
