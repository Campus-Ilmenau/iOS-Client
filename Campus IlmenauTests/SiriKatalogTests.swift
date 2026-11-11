import Testing
import Foundation
import AppIntents
@testable import Campus_Ilmenau

// Katalogsuche und Merkliste bei Siri: Sätze und Karten (reine Logik) und das Laden (mit Stub statt Netz).
// Nichts davon braucht eine Anmeldung.

// MARK: - Fixtures

private func treffer(_ nummer: Int, _ titel: String, status: SiriKatalogStatus? = nil) -> SiriKatalogTreffer {
    SiriKatalogTreffer(id: "med_\(nummer)", titel: titel, meta: "Jan Lunze · 2020 · Buch", status: status)
}

private let ausleihbar = SiriKatalogStatus(art: .ausleihbar, chipText: "Ausleihbar", rueckgabe: nil)

private func datum(_ tag: Int, monat: Int = 11) -> Date {
    EventKalender.kalender.date(from: DateComponents(year: 2026, month: monat, day: tag))!
}

// MARK: - Katalogsuche: Sätze und Karte

struct SiriKatalogSatzTests {
    @Test func trefferWieImMockup() throws {
        let a = SiriKatalog.antwort(SiriKatalogErgebnis(
            begriff: "Regelungstechnik", korrigiert: nil, gesamt: 128,
            treffer: [
                treffer(1, "Regelungstechnik für Ingenieure", status: ausleihbar),
                treffer(2, "Regelungstechnik 1", status: SiriKatalogStatus(art: .ausgeliehen, chipText: "Ausgeliehen bis 17. Nov.", rueckgabe: datum(17))),
                treffer(3, "Regelungstechnik", status: SiriKatalogStatus(art: .nurVorOrt, chipText: "Nur vor Ort", rueckgabe: nil))
            ]
        ))
        #expect(a.sagt == "Ich habe 128 Treffer für „Regelungstechnik“. Der erste, „Regelungstechnik für Ingenieure“, ist ausleihbar.")
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Katalog der UB")
        #expect(karte.titel == "128 Treffer")
        #expect(karte.untertitel == "für „Regelungstechnik“")
        #expect(karte.fuss == "Ohne Anmeldung")
        #expect(karte.treffer.map(\.status?.chipText) == ["Ausleihbar", "Ausgeliehen bis 17. Nov.", "Nur vor Ort"])
    }

    @Test func tippenFuehrtZumTitelUndZurSuche() throws {
        let karte = try #require(SiriKatalog.antwort(SiriKatalogErgebnis(
            begriff: "C++ & Swift", korrigiert: nil, gesamt: 2, treffer: [treffer(1, "A"), treffer(2, "B")]
        )).karte)
        #expect(karte.treffer.map(\.link) == [DeepLink.katalogTitel(id: "med_1").url, DeepLink.katalogTitel(id: "med_2").url])
        #expect(karte.alleLink == DeepLink.katalogSuchen(begriff: "C++ & Swift").url)
        #expect(DeepLink(url: karte.alleLink) == .katalogSuchen(begriff: "C++ & Swift"))
    }

    // Zu langsam: Die Treffer kommen ohne Chip.
    @Test func ohneStatusKeinChipUndKeinStatusImSatz() throws {
        let a = SiriKatalog.antwort(SiriKatalogErgebnis(
            begriff: "Regelungstechnik", korrigiert: nil, gesamt: 128,
            treffer: [treffer(1, "Regelungstechnik für Ingenieure"), treffer(2, "Regelungstechnik 1")]
        ))
        #expect(a.sagt == "Ich habe 128 Treffer für „Regelungstechnik“. Der erste ist „Regelungstechnik für Ingenieure“.")
        #expect(a.karte?.treffer.allSatisfy { $0.status == nil } == true)
    }

    @Test func nullTreffer() throws {
        let a = SiriKatalog.antwort(SiriKatalogErgebnis(begriff: "Qxzvw", korrigiert: nil, gesamt: 0, treffer: []))
        #expect(a.sagt == "Für „Qxzvw“ habe ich nichts gefunden.")
        let karte = try #require(a.karte)
        #expect(karte.titel == "Keine Treffer")
        #expect(karte.treffer.isEmpty)
        #expect(karte.alleLink == DeepLink.katalogSuchen(begriff: "Qxzvw").url)
    }

    // Hat die Suche korrigiert, sagt Siri, wonach sie gesucht hat.
    @Test func korrigierteSuche() throws {
        let a = SiriKatalog.antwort(SiriKatalogErgebnis(
            begriff: "Regelungstechnk", korrigiert: "Regelungstechnik", gesamt: 128,
            treffer: [treffer(1, "Regelungstechnik für Ingenieure", status: ausleihbar)]
        ))
        #expect(a.sagt == "Ich habe nach „Regelungstechnik“ gesucht. Das sind 128 Treffer. Der erste, „Regelungstechnik für Ingenieure“, ist ausleihbar.")
        #expect(a.karte?.untertitel == "für „Regelungstechnik“ statt „Regelungstechnk“")
        // „Alle Treffer“ sucht mit dem, was gesagt wurde; die App korrigiert selbst.
        #expect(a.karte?.alleLink == DeepLink.katalogSuchen(begriff: "Regelungstechnk").url)
    }

    @Test func korrigiertUndTrotzdemNichts() {
        let a = SiriKatalog.antwort(SiriKatalogErgebnis(begriff: "Qxzvw", korrigiert: "Qxzv", gesamt: 0, treffer: []))
        #expect(a.sagt == "Ich habe nach „Qxzv“ gesucht. Für „Qxzvw“ habe ich nichts gefunden.")
    }

    @Test func einEinzelnerTreffer() {
        let a = SiriKatalog.antwort(SiriKatalogErgebnis(
            begriff: "Quantenfeldtheorie", korrigiert: nil, gesamt: 1,
            treffer: [treffer(1, "Quantenfeldtheorie", status: SiriKatalogStatus(art: .ausgeliehen, chipText: "Ausgeliehen bis 17. Nov.", rueckgabe: datum(17)))]
        ))
        #expect(a.sagt == "Ich habe einen Treffer für „Quantenfeldtheorie“: „Quantenfeldtheorie“. Er ist ausgeliehen bis zum 17. November.")
        #expect(a.karte?.titel == "1 Treffer")

        let korrigiert = SiriKatalog.antwort(SiriKatalogErgebnis(
            begriff: "Quantenfeldtheori", korrigiert: "Quantenfeldtheorie", gesamt: 1, treffer: [treffer(1, "Quantenfeldtheorie")]
        ))
        #expect(korrigiert.sagt == "Ich habe nach „Quantenfeldtheorie“ gesucht. Das ist ein Treffer: „Quantenfeldtheorie“.")
    }

    @Test func hoechstensDreiTrefferAufDerKarte() {
        let fuenf = (1...5).map { treffer($0, "Titel \($0)") }
        let a = SiriKatalog.antwort(SiriKatalogErgebnis(begriff: "x", korrigiert: nil, gesamt: 1280, treffer: fuenf))
        #expect(a.karte?.treffer.count == 3)
        #expect(a.karte?.titel == "1.280 Treffer")
    }

    @Test func dieStatusWoerter() {
        #expect(SiriKatalogStatus(art: .nurVorOrt, chipText: "", rueckgabe: nil).sagt == "nur vor Ort nutzbar")
        #expect(SiriKatalogStatus(art: .online, chipText: "", rueckgabe: nil).sagt == "online lesbar")
        #expect(SiriKatalogStatus(art: .ausgeliehen, chipText: "", rueckgabe: nil).sagt == "ausgeliehen")
    }
}

// MARK: - Katalogsuche: Laden

/// Der Status antwortet erst nach 2 Sekunden, die Suche sofort.
private final class LangsamerStatusStub: URLProtocol {
    private var arbeit: DispatchWorkItem?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let istStatus = url.path.hasSuffix("/availability")
        let json = istStatus
            ? #"{"object":"list","data":[{"id":"med_1","availabilityStatus":"available","items":[]}]}"#
            : SiriKatalogStubs.suche(medien: [SiriKatalogStubs.buch(1, "Regelungstechnik 1")], gesamt: 1)
        let arbeit = DispatchWorkItem { [self] in
            let antwort = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: antwort, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(json.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        self.arbeit = arbeit
        DispatchQueue.global().asyncAfter(deadline: .now() + (istStatus ? 2 : 0), execute: arbeit)
    }

    override func stopLoading() { arbeit?.cancel() }
}

private enum SiriKatalogStubs {
    static func buch(_ nummer: Int, _ titel: String) -> String {
        """
        {"id":"med_\(nummer)","object":"media","ppn":"\(nummer)","mediaType":"print_book","title":"\(titel)",
         "authors":["Lunze, Jan"],"year":"2020","isbns":[],"subjects":[],"rvk":[],"links":[],"onlineUrl":null,"catalogUrl":null,
         "cover":{"status":"none","url":null,"width":null,"height":null}}
        """
    }

    static func suche(medien: [String], gesamt: Int, korrigiert: String? = nil) -> String {
        Sample.list(data: medien, total: gesamt, corrected: korrigiert)
    }

    static func status(_ eintraege: [(id: String, status: String, standort: String?, signatur: String, faellig: String?)]) -> String {
        let daten = eintraege.map { e in
            let ort = e.standort.map { #"{"id":"x","code":"1","name":"\#($0)","floorPlanUrl":null}"# } ?? "null"
            let faellig = e.faellig.map { "\"\($0)\"" } ?? "null"
            return #"{"id":"\#(e.id)","availabilityStatus":"\#(e.status)","items":[{"label":"\#(e.signatur)","location":\#(ort),"status":"\#(e.status)","dueDate":\#(faellig),"reserveUrl":null,"queue":null}]}"#
        }
        return #"{"object":"list","data":[\#(daten.joined(separator: ","))]}"#
    }

    @MainActor
    static func langsamerService() -> LibraryCatalogService {
        let konfiguration = URLSessionConfiguration.ephemeral
        konfiguration.protocolClasses = [LangsamerStatusStub.self]
        return LibraryCatalogService(baseURL: "https://langsam.test/develop", session: URLSession(configuration: konfiguration))
    }
}

@MainActor
struct SiriKatalogDatenTests {
    private let h = Harness()
    private let statusPfad = "/develop/v1/library/availability"

    @Test func sucheNurImBestandOhneGesamtkatalogUndStatusNurFuerDieErstenDrei() async throws {
        let medien = (1...5).map { SiriKatalogStubs.buch($0, "Regelungstechnik \($0)") }
        let service = h.service(json: SiriKatalogStubs.suche(medien: medien, gesamt: 128))
        h.route(statusPfad, json: SiriKatalogStubs.status([
            ("med_1", "available", "60 ELT", "ELT 1", nil), ("med_2", "on_loan", nil, "ELT 2", "2026-11-17"), ("med_3", "reference_only", nil, "ELT 3", nil)
        ]))

        let a = await SiriKatalogDaten.suche("  Regelungstechnik ", service: service)

        // Eine Suchanfrage im Bestand (`in=local`, „Gedruckt“), keine zum Gesamtkatalog.
        let suchen = h.requestURLs.filter { $0.path.hasSuffix("/search") }
        #expect(suchen.count == 1)
        let items = URLComponents(url: try #require(suchen.first), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "q" }?.value == "Regelungstechnik")
        #expect(items.first { $0.name == "in" }?.value == "local")
        #expect(items.first { $0.name == "type" }?.value == "print_book")
        // Der Status wird für genau 3 IDs geholt.
        let status = h.requestURLs.filter { $0.path.hasSuffix("/availability") }
        #expect(status.count == 1)
        #expect(URLComponents(url: status[0], resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "ids" }?.value == "med_1,med_2,med_3")

        #expect(a.sagt == "Ich habe 128 Treffer für „Regelungstechnik“. Der erste, „Regelungstechnik 1“, ist ausleihbar.")
        let karte = try #require(a.karte)
        #expect(karte.treffer.map(\.titel) == ["Regelungstechnik 1", "Regelungstechnik 2", "Regelungstechnik 3"])
        #expect(karte.treffer.map(\.status?.chipText) == ["Ausleihbar", "Ausgeliehen bis 17. Nov.", "Nur vor Ort"])
        #expect(karte.treffer.first?.meta == "Jan Lunze · 2020 · Buch")
    }

    @Test func korrigierteSucheKommtAusDerAntwort() async {
        let service = h.service(json: SiriKatalogStubs.suche(medien: [SiriKatalogStubs.buch(1, "Regelungstechnik 1")], gesamt: 7, korrigiert: "Regelungstechnik"))
        h.route(statusPfad, json: SiriKatalogStubs.status([("med_1", "available", nil, "ELT 1", nil)]))
        let a = await SiriKatalogDaten.suche("Regelungstechnk", service: service)
        #expect(a.sagt.hasPrefix("Ich habe nach „Regelungstechnik“ gesucht. Das sind 7 Treffer."))
    }

    @Test func nullTrefferFragtKeinenStatusAb() async {
        let service = h.service(json: SiriKatalogStubs.suche(medien: [], gesamt: 0))
        let a = await SiriKatalogDaten.suche("Qxzvw", service: service)
        #expect(a.sagt == "Für „Qxzvw“ habe ich nichts gefunden.")
        #expect(h.requestURLs.contains { $0.path.hasSuffix("/availability") } == false)
    }

    @Test func fehlerBeimStatusLaesstDieTrefferOhneChip() async {
        let service = h.service(json: SiriKatalogStubs.suche(medien: [SiriKatalogStubs.buch(1, "Regelungstechnik 1")], gesamt: 1))
        h.route(statusPfad, status: 503, json: Sample.error(code: "unavailable", message: "Katalog nicht erreichbar"))
        let a = await SiriKatalogDaten.suche("Regelungstechnik", service: service)
        #expect(a.sagt == "Ich habe einen Treffer für „Regelungstechnik“: „Regelungstechnik 1“.")
        #expect(a.karte?.treffer.first?.status == nil)
    }

    @Test func unbekannterStatusZeigtKeinenChip() async {
        let service = h.service(json: SiriKatalogStubs.suche(medien: [SiriKatalogStubs.buch(1, "Regelungstechnik 1")], gesamt: 1))
        h.route(statusPfad, json: SiriKatalogStubs.status([("med_1", "unknown", nil, "x", nil)]))
        let a = await SiriKatalogDaten.suche("Regelungstechnik", service: service)
        #expect(a.karte?.treffer.first?.status == nil)
    }

    /// Ist der Status zu langsam, kommen die Treffer sofort ohne Chip. Siri wartet nicht auf die 2 Sekunden des Stubs.
    @Test func zuLangsamerStatusErgibtTrefferOhneChip() async {
        let start = ContinuousClock.now
        let a = await SiriKatalogDaten.suche("Regelungstechnik", service: SiriKatalogStubs.langsamerService(), statuslimit: .milliseconds(150))
        #expect(ContinuousClock.now - start < .seconds(1.5))
        #expect(a.sagt == "Ich habe einen Treffer für „Regelungstechnik“: „Regelungstechnik 1“.")
        #expect(a.karte?.treffer.first?.status == nil)
    }

    /// Suche und Status zusammen bleiben unter dem Gesamtlimit: Was die Suche übrig lässt, gilt für den Status.
    @Test func derStatusBekommtNurDieRestzeitDesGesamtlimits() async {
        let start = ContinuousClock.now
        // Der Status ließe 3 s zu, aber insgesamt sind es nur 400 ms: Der Stub antwortet erst nach 2 s.
        let a = await SiriKatalogDaten.suche(
            "Regelungstechnik", service: SiriKatalogStubs.langsamerService(), statuslimit: .seconds(3),
            gesamtlimit: .milliseconds(400), mindestZeitFuerStatus: .milliseconds(50)
        )
        #expect(ContinuousClock.now - start < .seconds(1.2))
        #expect(a.karte?.treffer.first?.status == nil)
    }

    @Test func istDieZeitSchonAufkommtDerStatusGarNichtErstGefragt() async {
        let service = h.service(json: SiriKatalogStubs.suche(medien: [SiriKatalogStubs.buch(1, "Regelungstechnik 1")], gesamt: 1))
        h.route(statusPfad, json: SiriKatalogStubs.status([("med_1", "available", nil, "ELT 1", nil)]))
        // Das Gesamtlimit ist kleiner als die Mindestzeit für den Status.
        let a = await SiriKatalogDaten.suche(
            "Regelungstechnik", service: service, gesamtlimit: .seconds(8), mindestZeitFuerStatus: .seconds(10)
        )
        #expect(h.requestURLs.contains { $0.path.hasSuffix("/availability") } == false)
        #expect(a.sagt == "Ich habe einen Treffer für „Regelungstechnik“: „Regelungstechnik 1“.")
    }

    @Test func dieVorgabenLiegenUnterAchtSekunden() {
        // Suche (6 s) und Status (3 s) hätten zusammen 9 s; das Gesamtlimit hält sie unter etwa 8 s.
        #expect(SiriKatalogDaten.suchlimit + SiriKatalogDaten.statuslimit > SiriKatalogDaten.gesamtlimit)
        #expect(SiriKatalogDaten.gesamtlimit == .seconds(8))
    }

    @Test func scheitertDieSucheKommtDieFehlermeldung() async {
        let service = h.service(status: 503, json: Sample.error(code: "unavailable", message: "Katalog nicht erreichbar"))
        let a = await SiriKatalogDaten.suche("Regelungstechnik", service: service)
        #expect(a == SiriKatalog.nichtErreichbar)
        #expect(a.sagt == "Ich komme gerade nicht an den Katalog. Versuch es gleich noch mal.")
    }

    @Test func leererOderZuLangerBegriffWirdNichtGesendet() async {
        let service = h.service(json: SiriKatalogStubs.suche(medien: [], gesamt: 0))
        let leer = await SiriKatalogDaten.suche("   ", service: service)
        let lang = await SiriKatalogDaten.suche(String(repeating: "a", count: 201), service: service)
        #expect(leer == SiriKatalog.ungueltig)
        #expect(lang == SiriKatalog.ungueltig)
        #expect(h.requestURLs.isEmpty)
    }

    @Test func statusWieInDerSuche() {
        func verfuegbarkeit(_ status: String, faellig: String? = nil) -> LibraryAvailability {
            let json = SiriKatalogStubs.status([("med_1", status, nil, "X", faellig)])
            let liste = try! LibraryCatalogService.decoder.decode(LibraryAvailabilityList.self, from: Data(json.utf8))
            return liste.data[0]
        }
        #expect(SiriKatalogDaten.status(nil) == nil)
        #expect(SiriKatalogDaten.status(verfuegbarkeit("unknown")) == nil)
        #expect(SiriKatalogDaten.status(verfuegbarkeit("available"))?.chipText == "Ausleihbar")
        #expect(SiriKatalogDaten.status(verfuegbarkeit("online"))?.art == .online)
        #expect(SiriKatalogDaten.status(verfuegbarkeit("reference_only"))?.chipText == "Nur vor Ort")
        let ausgeliehen = SiriKatalogDaten.status(verfuegbarkeit("on_loan", faellig: "2026-11-17"))
        #expect(ausgeliehen?.chipText == "Ausgeliehen bis 17. Nov.")
        #expect(ausgeliehen?.rueckgabe != nil)
        #expect(ausgeliehen?.sagt == "ausgeliehen bis zum 17. November")
        // Nur ein ausgeliehener Titel trägt ein Rückgabedatum.
        #expect(SiriKatalogDaten.status(verfuegbarkeit("available", faellig: "2026-11-17"))?.rueckgabe == nil)
    }

    @Test func derIntentLaeuftOhneDieAppUndDerSteuerelementIntentBleibt() {
        #expect(!KatalogFragenIntent.openAppWhenRun)
        #expect(!MerklisteIntent.openAppWhenRun)
        // Der vorhandene Intent des Steuerelements ist unverändert: öffnet die App und die leere Suche.
        #expect(KatalogSuchenIntent.openAppWhenRun)
    }
}

// MARK: - Merkliste: Sätze und Karte

private func eintrag(_ nummer: Int, _ titel: String, _ stand: SiriMerklisteStand) -> SiriMerklisteEintrag {
    SiriMerklisteEintrag(id: "med_\(nummer)", titel: titel, stand: stand)
}

private func regal(_ standort: String, _ signatur: String? = nil) -> SiriMerklisteStand {
    .imRegal(standort: standort, signatur: signatur)
}

struct SiriMerklisteSatzTests {
    @Test func wieImMockup() throws {
        let a = SiriMerkliste.antwort([
            eintrag(1, "Regelungstechnik für Ingenieure", regal("60 ELT", "ELT ZQ 5200 R447(10)")),
            eintrag(2, "Elektrische Maschinen", regal("60 ELT", "ELT ZN 4000 F542(4)")),
            eintrag(3, "Technische Mechanik 1: Statik", regal("70 MB", "MB UF 1000 G878(14)")),
            eintrag(4, "Analysis 1", .ausgeliehen)
        ])
        #expect(a.sagt == "Drei Titel stehen im Regal: zwei im Bereich 60 ELT, einer in 70 MB. Einer ist ausgeliehen.")
        // Gesprochen werden keine Signaturen.
        #expect(!a.sagt.contains("ELT ZQ"))
        #expect(!a.sagt.contains("MB UF"))

        let karte = try #require(a.karte)
        #expect(karte.titel == "3 Titel im Regal")
        #expect(karte.untertitel == "Nach Standort, so läufst du einmal durch.")
        #expect(karte.standorte.map(\.name) == ["60 ELT", "70 MB"])
        #expect(karte.standorte.map(\.anzahl) == [2, 1])
        // Die Karte zeigt die Signatur je Titel.
        #expect(karte.standorte[0].titel.map(\.signatur) == ["ELT ZQ 5200 R447(10)", "ELT ZN 4000 F542(4)"])
        #expect(karte.fuss == "Nicht im Regal: 1")
        #expect(karte.link == DeepLink.merkliste.url)
    }

    @Test func leereMerkliste() {
        let a = SiriMerkliste.antwort([])
        #expect(a.sagt == "Deine Merkliste ist leer. Titel merkst du dir im Katalog.")
        #expect(a.karte == nil)
        #expect(a == SiriMerkliste.leer)
    }

    @Test func standorteNatuerlichSortiert() throws {
        let a = SiriMerkliste.antwort([
            eintrag(1, "A", regal("60 ELT")), eintrag(2, "B", regal("52/53 INF")), eintrag(3, "C", regal("9 X"))
        ])
        #expect(try #require(a.karte).standorte.map(\.name) == ["9 X", "52/53 INF", "60 ELT"])
        #expect(a.sagt == "Drei Titel stehen im Regal: einer im Bereich 9 X, einer in 52/53 INF und einer in 60 ELT.")
    }

    @Test func einStandortUndEinzelnerTitel() {
        #expect(SiriMerkliste.antwort([eintrag(1, "A", regal("60 ELT"))]).sagt == "Ein Titel steht im Regal, im Bereich 60 ELT.")
        #expect(SiriMerkliste.antwort([eintrag(1, "A", regal("60 ELT")), eintrag(2, "B", regal("60 ELT"))]).sagt
            == "Zwei Titel stehen im Regal, alle im Bereich 60 ELT.")
    }

    @Test func vieleStandorteWerdenZusammengefasst() {
        let namen = ["A 1", "B 2", "C 3", "D 4", "E 5", "F 6"]
        let a = SiriMerkliste.antwort(namen.enumerated().map { eintrag($0.offset, "T", regal($0.element)) })
        #expect(a.sagt == "6 Titel stehen im Regal: einer im Bereich A 1, einer in B 2, einer in C 3, einer in D 4 und zwei an weiteren Standorten.")
    }

    @Test func nichtImRegalWirdBenannt() {
        let a = SiriMerkliste.antwort([
            eintrag(1, "A", regal("60 ELT")), eintrag(2, "B", .ausgeliehen), eintrag(3, "C", .ausgeliehen),
            eintrag(4, "D", .online), eintrag(5, "E", .unbekannt)
        ])
        #expect(a.sagt == "Ein Titel steht im Regal, im Bereich 60 ELT. Zwei sind ausgeliehen. Einer ist online verfügbar. Bei einem Titel kenne ich den Standort nicht.")
        #expect(a.karte?.fuss == "Nicht im Regal: 4")
    }

    @Test func nichtsImRegal() {
        let a = SiriMerkliste.antwort([eintrag(1, "A", .ausgeliehen), eintrag(2, "B", .ausgeliehen)])
        #expect(a.sagt == "Gerade steht keiner deiner 2 Titel im Regal. Zwei sind ausgeliehen.")
        #expect(a.karte?.titel == "Nichts im Regal")
        #expect(a.karte?.standorte.isEmpty == true)
    }

    @Test func dieKarteHatDreiZeilenUndZaehltDenRest() throws {
        let titel = (1...5).map { eintrag($0, "Titel \($0)", regal($0 <= 3 ? "60 ELT" : "70 MB", "S\($0)")) } + [eintrag(6, "Weg", .ausgeliehen)]
        let karte = try #require(SiriMerkliste.antwort(titel).karte)
        #expect(karte.standorte.flatMap(\.titel).count == 3)
        // Die Überschrift nennt die ganze Zahl, auch wenn nicht alle Titel zu sehen sind.
        #expect(karte.standorte.map(\.anzahl) == [3])
        #expect(karte.fuss == "+2 weitere · Nicht im Regal: 1")
        #expect(karte.titel == "5 Titel im Regal")
    }

    // „Gefunden“ gibt es in der Merkliste der App noch nicht. Der Fuß ist darauf vorbereitet und zeigt es von selbst.
    @Test func gefundeneErscheinenImFussSobaldEsSieGibt() throws {
        let a = SiriMerkliste.antwort([
            eintrag(1, "A", regal("60 ELT", "S1")), eintrag(2, "B", regal("60 ELT", "S2")), eintrag(3, "C", regal("70 MB", "S3")),
            eintrag(4, "D", .ausgeliehen), SiriMerklisteEintrag(id: "med_5", titel: "E", stand: regal("60 ELT"), gefunden: true)
        ])
        let karte = try #require(a.karte)
        #expect(karte.titel == "3 Titel im Regal")
        #expect(karte.fuss == "Nicht im Regal: 1 · Gefunden: 1")
        #expect(a.sagt == "Drei Titel stehen im Regal: zwei im Bereich 60 ELT, einer in 70 MB. Einer ist ausgeliehen. Einer ist schon gefunden.")
    }

    @Test func gefundeneZaehlenWederImRegalNochAlsAusgeliehen() {
        let a = SiriMerkliste.antwort([
            SiriMerklisteEintrag(id: "med_1", titel: "A", stand: .ausgeliehen, gefunden: true),
            eintrag(2, "B", regal("60 ELT"))
        ])
        #expect(a.sagt == "Ein Titel steht im Regal, im Bereich 60 ELT. Einer ist schon gefunden.")
        #expect(a.karte?.fuss == "Gefunden: 1")
    }

    @Test func nurGefundeneUndNichtsSonst() {
        let a = SiriMerkliste.antwort([SiriMerklisteEintrag(id: "med_1", titel: "A", stand: regal("60 ELT"), gefunden: true)])
        #expect(a.sagt == "Dein Titel ist schon gefunden.")
        #expect(a.karte == nil)
        #expect(SiriMerkliste.antwort([
            SiriMerklisteEintrag(id: "med_1", titel: "A", stand: .online, gefunden: true),
            SiriMerklisteEintrag(id: "med_2", titel: "B", stand: .online, gefunden: true)
        ]).sagt == "Alle 2 Titel sind schon gefunden.")
    }

    @Test func ohneGefundeneKeinGefundenImFuss() throws {
        let a = SiriMerkliste.antwort([eintrag(1, "A", regal("60 ELT")), eintrag(2, "B", .ausgeliehen)])
        #expect(!(a.karte?.fuss.contains("Gefunden") ?? true))
    }

    @Test func ohneIrgendeinenStandKommtKeineFalscheAuskunft() {
        let a = SiriMerkliste.antwort([eintrag(1, "A", .unbekannt), eintrag(2, "B", .unbekannt), eintrag(3, "C", .unbekannt)])
        #expect(a.sagt == "Auf deiner Merkliste stehen 3 Titel. Den Stand im Regal kenne ich gerade nicht.")
        #expect(a.karte == nil)
        #expect(SiriMerkliste.antwort([eintrag(1, "A", .unbekannt)]).sagt
            == "Auf deiner Merkliste steht ein Titel. Den Stand im Regal kenne ich gerade nicht.")
    }
}

// MARK: - Merkliste: Laden

@MainActor
struct SiriMerklisteDatenTests {
    private let h = Harness()
    private let statusPfad = "/develop/v1/library/availability"

    private func merkliste(_ titel: [(Int, String)]) -> [GemerkterTitel] {
        titel.map { GemerkterTitel(id: "med_\($0.0)", titel: $0.1) }
    }

    @Test func frischesAvailabilityGruppiertNachStandort() async {
        let service = h.service(json: "{}")
        h.route(statusPfad, json: SiriKatalogStubs.status([
            ("med_1", "available", "60 ELT", "ELT ZQ 5200", nil), ("med_2", "reference_only", "60 ELT", "ELT ZN 4000", nil),
            ("med_3", "available", "70 MB", "MB UF 1000", nil), ("med_4", "on_loan", nil, "X", "2026-11-17")
        ]))
        let a = await SiriKatalogDaten.merkliste(merkliste([(1, "A"), (2, "B"), (3, "C"), (4, "D")]), service: service)

        #expect(h.requestURLs.filter { $0.path.hasSuffix("/availability") }.count == 1)
        #expect(a.sagt == "Drei Titel stehen im Regal: zwei im Bereich 60 ELT, einer in 70 MB. Einer ist ausgeliehen.")
        #expect(a.karte?.standorte.flatMap(\.titel).map(\.signatur) == ["ELT ZQ 5200", "ELT ZN 4000", "MB UF 1000"])
    }

    @Test func leereMerklisteFragtNichtsAb() async {
        let service = h.service(json: "{}")
        let a = await SiriKatalogDaten.merkliste([], service: service)
        #expect(a == SiriMerkliste.leer)
        #expect(h.requestURLs.isEmpty)
    }

    @Test func fehlerBeiAvailabilityErgibtUnbekannt() async {
        let service = h.service(status: 503, json: Sample.error(code: "unavailable", message: "Katalog nicht erreichbar"))
        let a = await SiriKatalogDaten.merkliste(merkliste([(1, "A"), (2, "B")]), service: service)
        #expect(a.sagt == "Auf deiner Merkliste stehen 2 Titel. Den Stand im Regal kenne ich gerade nicht.")
    }

    @Test func zuLangsamErgibtUnbekannt() async {
        let start = ContinuousClock.now
        let a = await SiriKatalogDaten.merkliste(merkliste([(1, "A")]), service: SiriKatalogStubs.langsamerService(), limit: .milliseconds(150))
        #expect(ContinuousClock.now - start < .seconds(1.5))
        #expect(a.sagt == "Auf deiner Merkliste steht ein Titel. Den Stand im Regal kenne ich gerade nicht.")
    }

    @Test func titelOhneDatenZeigenIhreNummer() async {
        let service = h.service(json: "{}")
        h.route(statusPfad, json: SiriKatalogStubs.status([("med_9", "available", "60 ELT", "S", nil)]))
        let unvollstaendig = GemerkterTitel(id: "med_9", titel: "")
        let a = await SiriKatalogDaten.merkliste([unvollstaendig], service: service)
        #expect(a.karte?.standorte.first?.titel.first?.titel == "Titel 9")
    }

    @Test func standNurMitStandortImRegal() {
        let exemplar = BibMerklisteExemplar(signatur: "S 1", standort: "60 ELT")
        #expect(SiriKatalogDaten.merklisteStand(status: .available, exemplar: exemplar) == .imRegal(standort: "60 ELT", signatur: "S 1"))
        #expect(SiriKatalogDaten.merklisteStand(status: .referenceOnly, exemplar: exemplar) == .imRegal(standort: "60 ELT", signatur: "S 1"))
        // Ohne Standort ist es nicht „im Regal“, auch wenn es ausleihbar ist.
        #expect(SiriKatalogDaten.merklisteStand(status: .available, exemplar: BibMerklisteExemplar(signatur: "S", standort: nil)) == .unbekannt)
        #expect(SiriKatalogDaten.merklisteStand(status: .available, exemplar: nil) == .unbekannt)
        #expect(SiriKatalogDaten.merklisteStand(status: .onLoan, exemplar: exemplar) == .ausgeliehen)
        #expect(SiriKatalogDaten.merklisteStand(status: .online, exemplar: nil) == .online)
        #expect(SiriKatalogDaten.merklisteStand(status: .unknown, exemplar: exemplar) == .unbekannt)
        #expect(SiriKatalogDaten.merklisteStand(status: nil, exemplar: nil) == .unbekannt)
    }
}
