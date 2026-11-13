import Testing
import Foundation
@testable import Campus_Ilmenau

// MARK: - Fixtures

/// Donnerstag, 29. Oktober 2026 (Berlin). Stunden über 24 sind Zeiten nach Mitternacht.
private func zeit(_ stunden: Double, tag: String = "2026-10-29") -> Date {
    let teile = tag.split(separator: "-").compactMap { Int($0) }
    let basis = EventKalender.kalender.date(from: DateComponents(year: teile[0], month: teile[1], day: teile[2]))!
    let minuten = Int((stunden * 60).rounded())
    return HeuteUhr.datum(am: basis, minuten: 0).addingTimeInterval(TimeInterval(minuten * 60))
}

private func event(
    _ id: String, _ titel: String, von: Double, bis: Double? = nil, ort: String? = nil,
    veranstalter: String? = nil, abgesagt: Bool = false, tag: String = "2026-10-29"
) -> WidgetEvent {
    WidgetEvent(
        id: id, titel: titel, beginn: zeit(von, tag: tag), ende: bis.map { zeit($0, tag: tag) },
        ganztaegig: false, ort: ort, veranstalter: veranstalter, abgesagt: abgesagt
    )
}

/// Die Events aus `WidgetHeuteAbend.dc.html`.
private let spieleabend = event("spiel", "Spieleabend", von: 19, bis: 23, ort: "Studi-Club")
private let quiz = event("quiz", "Kneipenquiz", von: 20, bis: 23, ort: "Baracke5", abgesagt: true)
private let openStage = event("stage", "Open Stage", von: 21, bis: 25, ort: "BC-Club")
private let karaoke = event("karaoke", "Karaoke-Nacht", von: 22, bis: 26, ort: "Baracke5")

private let lola = event("lola", "Filmabend: Lola rennt", von: 20, bis: 22.5, ort: "Faraday-Hörsaal", veranstalter: "hsf", tag: "2026-10-30")
private let halloween = event("halloween", "Halloween-Party", von: 21, bis: 27, ort: "Studi-Club", tag: "2026-10-30")
private let elektro = event("elektro", "Elektro-Nacht", von: 22, bis: 28, ort: "BC-Club", tag: "2026-10-30")

private func anzeige(
    _ uhr: Double, _ events: [WidgetEvent], gemerkt: Set<String> = [], woche: Int? = nil
) -> AbendWidgetAnzeige {
    AbendWidgetPhasen.anzeige(
        events: events, gemerkteIDs: gemerkt, woche: woche.map { WidgetWoche(von: "2026-10-29", anzahl: $0) },
        jetzt: zeit(uhr)
    )
}

// MARK: - Zustände

struct AbendWidgetAnzeigeTests {
    @Test func abendVorBeginn() {
        let a = anzeige(18.5, [spieleabend, quiz, openStage, lola, halloween, elektro])
        #expect(a.titel == "Heute Abend")
        #expect(a.datum == "Do 29. Okt.")
        #expect(a.zeilen.map(\.zeit) == ["19:00", "20:00", "21:00"])
        #expect(a.zeilen.map(\.abgesagt) == [false, true, false])
        #expect(a.zeilen.map(\.laeuft) == [false, false, false])

        #expect(a.klein.kicker == "Heute Abend")
        #expect(a.klein.zeit == "19:00")
        #expect(a.klein.titel == "Spieleabend")
        #expect(a.klein.ort == "Studi-Club")
        // Abgesagte zählen nicht: Spieleabend und Open Stage, also eins weiter.
        #expect(a.klein.fuss == "+1 weitere heute")
        #expect(a.klein.link == DeepLink.event(id: "spiel").url)
    }

    @Test func einLaeuftEinesFaelltAus() {
        let a = anzeige(19 + 40.0 / 60, [spieleabend, openStage.mitAbsage(), karaoke, lola])
        #expect(a.zeilen.map(\.titel) == ["Spieleabend", "Open Stage", "Karaoke-Nacht"])
        #expect(a.zeilen[0].laeuft)
        #expect(a.zeilen[0].ort == "Studi-Club · bis 23:00")
        #expect(a.zeilen[1].abgesagt && !a.zeilen[1].laeuft)

        #expect(a.klein.kicker == "Läuft gerade")
        #expect(a.klein.laeuft)
        // Bei einer laufenden steht das Ende („bis 23:00“).
        #expect(a.klein.zeit == "23:00")
        #expect(a.klein.fuss == "+1 weitere heute")
    }

    @Test func laufendeZuerstAuchWennSpaeterBegonnen() {
        let frueh = event("frueh", "Früh", von: 18, bis: 19.5, ort: "A")
        let lang = event("lang", "Lang", von: 17.5, bis: 23, ort: "B")
        let a = anzeige(18.5, [frueh, lang])
        // Beide laufen; unter Gleichen entscheidet der Beginn.
        #expect(a.zeilen.map(\.id) == ["lang", "frueh"])
        let spaeter = event("spaet", "Spät", von: 20, bis: 22)
        let b = anzeige(18.5, [spaeter, frueh])
        #expect(b.zeilen.map(\.id) == ["frueh", "spaet"])
    }

    @Test func nachDemLetztenEndeDerNaechsteAbend() {
        // Alles von heute ist um 23:50 vorbei.
        let vorbei = [event("a", "A", von: 19, bis: 23), event("b", "B", von: 20, bis: 23.5)]
        let a = anzeige(23 + 50.0 / 60, vorbei + [lola, halloween, elektro])
        #expect(a.titel == "Morgen Abend")
        #expect(a.datum == "Fr 30. Okt.")
        #expect(a.zeigtMorgen)
        #expect(a.zeilen.map(\.titel) == ["Filmabend: Lola rennt", "Halloween-Party", "Elektro-Nacht"])
        #expect(a.zeilen[0].ort == "Faraday-Hörsaal · hsf")
        // Klein zeigt dann den leeren Zustand mit dem Morgen.
        #expect(!a.klein.hatEvent)
        #expect(a.klein.leerText == "Morgen · 20:00 Filmabend: Lola rennt")
        #expect(a.klein.link == DeepLink.events.url)
    }

    @Test func nichtsEingetragenHeute() {
        let a = anzeige(19.5, [lola, halloween])
        #expect(a.leer)
        #expect(a.titel == "Heute Abend")
        #expect(a.zeilen.isEmpty)
        #expect(a.leerHinweis == "Morgen · 20:00 Filmabend: Lola rennt, Faraday-Hörsaal")
        #expect(a.morgenZeilen.map(\.id) == ["lola", "halloween"])
        #expect(a.klein.leerText == "Morgen · 20:00 Filmabend: Lola rennt")
    }

    @Test func nichtsHeuteUndNichtsMorgen() {
        let a = anzeige(19.5, [])
        #expect(a.leer)
        #expect(a.zeilen.isEmpty && a.morgenZeilen.isEmpty)
        #expect(!a.leerHinweis.isEmpty)
        #expect(a.klein.link == DeepLink.events.url)
    }

    @Test func nachMitternachtGehoertNochZumVortag() {
        // 01:30 am Freitag: Der Abend vom Donnerstag läuft noch (Karaoke bis 02:00), Open Stage ist seit 01:00 vorbei.
        let a = anzeige(25.5, [spieleabend, openStage, karaoke, lola])
        #expect(a.titel == "Heute Abend")
        #expect(a.datum == "Do 29. Okt.")
        #expect(a.zeilen.map(\.id) == ["karaoke"])
        #expect(a.klein.zeit == "02:00")
    }

    @Test func ohneEndeLaeuftEsBisZumMorgen() {
        let offen = event("offen", "Offen", von: 20)
        let a = anzeige(23.5, [offen])
        #expect(a.zeilen.map(\.id) == ["offen"])
        #expect(a.zeilen[0].laeuft)
        // Ohne Ende kein „bis“.
        #expect(a.zeilen[0].ort == "")
        #expect(a.klein.zeit == "20:00")
    }

    @Test func ganztaegigeFehlen() {
        var ganztags = event("ganz", "Ganztags", von: 0)
        ganztags.ganztaegig = true
        let a = anzeige(18, [ganztags, spieleabend])
        #expect(a.zeilen.map(\.id) == ["spiel"])
    }

    @Test func gemerkteTragenEinenStern() {
        let a = anzeige(18.5, [spieleabend, openStage], gemerkt: ["stage"])
        #expect(a.zeilen.map(\.gemerkt) == [false, true])
    }

    @Test func ortUndVeranstalterOhneLeeres() {
        let e = event("x", "X", von: 19, bis: 20, ort: "  ", veranstalter: "StuRa")
        #expect(anzeige(18, [e]).zeilen.first?.ort == "StuRa")
    }
}

private extension WidgetEvent {
    func mitAbsage() -> WidgetEvent {
        var kopie = self
        kopie.abgesagt = true
        return kopie
    }
}

// MARK: - Größen

struct AbendWidgetGroessenTests {
    @Test func mittelHatDreiZeilenUndEineMorgenZeile() {
        let wenige = anzeige(18, [spieleabend, openStage, lola])
        let mittel = wenige.mittel(maxZeilen: 3)
        #expect(mittel.zeilen.count == 2)
        #expect(mittel.tail == "Morgen · 20:00 Filmabend: Lola rennt")

        let viele = anzeige(18, [spieleabend, quiz, openStage, karaoke, lola])
        #expect(viele.mittel(maxZeilen: 3).zeilen.count == 3)
        #expect(viele.mittel(maxZeilen: 3).tail == nil)
    }

    @Test func beiGrosserSchriftEineZeileWeniger() {
        let a = anzeige(18, [spieleabend, openStage, lola])
        // Zwei Zeilen passen auch bei großer Schrift, die Morgen-Zeile aber nicht mehr.
        #expect(a.mittel(maxZeilen: 2).zeilen.count == 2)
        #expect(a.mittel(maxZeilen: 2).tail == nil)
        let drei = anzeige(18, [spieleabend, quiz, openStage, lola])
        #expect(drei.mittel(maxZeilen: 2).zeilen.count == 2)
    }

    @Test func grossVerteiltFuenfZeilen() {
        let fuenfHeute = [
            event("a", "A", von: 18, bis: 19), event("b", "B", von: 19, bis: 20), event("c", "C", von: 20, bis: 21),
            event("d", "D", von: 21, bis: 22), event("e", "E", von: 22, bis: 23)
        ]
        let a = anzeige(17.5, fuenfHeute + [lola, halloween, elektro], woche: 14)
        let gross = a.gross(maxHeute: 4, gesamt: 5)
        #expect(gross.zeilen.map(\.id) == ["a", "b", "c", "d"])
        // Morgen bekommt mindestens eine Zeile.
        #expect(gross.morgenZeilen.map(\.id) == ["lola"])
        #expect(gross.fuss == "+1 weitere heute")

        // Bei großer Schrift: heute 3, zusammen 4.
        let gross2 = a.gross(maxHeute: 3, gesamt: 4)
        #expect(gross2.zeilen.count == 3)
        #expect(gross2.morgenZeilen.count == 1)
        #expect(gross2.fuss == "+2 weitere heute")
    }

    @Test func grossMitWenigenFuelltMitMorgenAuf() {
        let a = anzeige(18, [spieleabend, openStage, lola, halloween, elektro], woche: 14)
        let gross = a.gross(maxHeute: 4, gesamt: 5)
        #expect(gross.zeilen.count == 2)
        #expect(gross.morgenZeilen.count == 3)
        #expect(gross.fuss == "Diese Woche: 14 Veranstaltungen")
    }

    @Test func grossOhneWochenzahlHatKeinenFusstext() {
        #expect(anzeige(18, [spieleabend]).gross(maxHeute: 4, gesamt: 5).fuss == "")
    }

    @Test func grossWennHeuteNichtsIst() {
        let a = anzeige(18, [lola, halloween, elektro])
        let gross = a.gross(maxHeute: 4, gesamt: 5)
        #expect(a.leer)
        #expect(gross.zeilen.isEmpty)
        #expect(gross.morgenZeilen.count == 3)
    }

    @Test func grossWennHeuteVorbeiIst() {
        let vorbei = [event("a", "A", von: 19, bis: 20)]
        let a = anzeige(22, vorbei + [lola, halloween, elektro, event("x", "X", von: 23, bis: 24, tag: "2026-10-30"),
                                       event("y", "Y", von: 23.5, bis: 25, tag: "2026-10-30")])
        let gross = a.gross(maxHeute: 4, gesamt: 5)
        #expect(a.titel == "Morgen Abend")
        #expect(gross.zeilen.count == 4)
        // Der nächste Abend steht schon oben, darunter kommt nichts mehr.
        #expect(gross.morgenZeilen.isEmpty)
        #expect(gross.fuss == "+1 weitere morgen")
    }
}

// MARK: - Links und Zeitleiste

struct AbendWidgetLinkTests {
    @Test func kopfZeileUndListe() throws {
        let a = anzeige(18.5, [spieleabend])
        #expect(a.kopfLink == DeepLink.eventsHeuteAbend.url)
        #expect(a.listeLink == DeepLink.events.url)
        #expect(DeepLink(url: a.kopfLink) == .eventsHeuteAbend)
        #expect(DeepLink(url: a.listeLink) == .events)
        #expect(DeepLink(url: try #require(a.zeilen.first?.link)) == .event(id: "spiel"))
    }
}

struct AbendWidgetZeitleisteTests {
    @Test func einEintragProBeginnUndEnde() {
        let wechsel = AbendWidgetPhasen.wechsel(events: [spieleabend, openStage, lola], nach: zeit(18.5))
        #expect(wechsel.contains(zeit(19)))
        #expect(wechsel.contains(zeit(21)))
        #expect(wechsel.contains(zeit(23)))
        #expect(wechsel.contains(zeit(25)))
        #expect(wechsel.contains(zeit(20, tag: "2026-10-30")))
        // Der Tageswechsel um 6 Uhr am nächsten Morgen.
        #expect(wechsel.contains(zeit(6, tag: "2026-10-30")))
        #expect(wechsel == wechsel.sorted())
        #expect(wechsel.allSatisfy { $0 > zeit(18.5) })
    }

    @Test func vergangenesFaelltWeg() {
        let wechsel = AbendWidgetPhasen.wechsel(events: [spieleabend], nach: zeit(23.5))
        #expect(!wechsel.contains(zeit(19)))
        #expect(!wechsel.contains(zeit(23)))
    }

    @Test func neuladenEineStundeSpaeter() {
        let jetzt = zeit(19.25)
        #expect(AbendWidgetPhasen.zeitleistenEnde(nach: jetzt) == zeit(20.25))
    }
}

// MARK: - Speicher

@MainActor
struct WidgetEventPflegeTests {
    private func campusEvent(_ id: String, von: Double, status: EventStatus = .findetStatt) -> CampusEvent {
        CampusEvent(id: id, titel: id, beginn: zeit(von), ende: zeit(von + 2), status: status, ort: "Ort")
    }

    @Test func abgesagteBleibenAnderesMarkiert() {
        var daten = WidgetSnapshot()
        let jetzt = zeit(12)
        WidgetEventPflege.uebernehme(
            [(EventKalender.tagesbeginn(jetzt), [campusEvent("a", von: 19), campusEvent("b", von: 20, status: .abgesagt)])],
            jetzt: jetzt, abgesagteMitgeliefert: true, in: &daten
        )
        #expect(daten.events.map(\.abgesagt) == [false, true])
    }

    @Test func eineListeOhneAbgesagteLaesstSieNichtVerschwinden() {
        var daten = WidgetSnapshot()
        let jetzt = zeit(12)
        let tag = EventKalender.tagesbeginn(jetzt)
        WidgetEventPflege.uebernehme(
            [(tag, [campusEvent("a", von: 19), campusEvent("b", von: 20, status: .abgesagt)])],
            jetzt: jetzt, abgesagteMitgeliefert: true, in: &daten
        )
        // Die Heute-Seite lädt ohne Abgesagte: „b“ bleibt, „a“ wird ersetzt.
        WidgetEventPflege.uebernehme([(tag, [campusEvent("a", von: 19.5)])], jetzt: jetzt, abgesagteMitgeliefert: false, in: &daten)
        #expect(daten.events.map(\.id) == ["a", "b"])
        #expect(daten.events.first?.beginn == zeit(19.5))
        #expect(daten.events.last?.abgesagt == true)
    }

    @Test func vergangeneAbendeFallenWegDieNachtNochNicht() {
        var daten = WidgetSnapshot()
        let gestern = zeit(21, tag: "2026-10-28")
        daten.events = [
            WidgetEvent(id: "alt", titel: "Alt", beginn: gestern, ende: gestern.addingTimeInterval(3600), ganztaegig: false),
            WidgetEvent(id: "nacht", titel: "Nacht", beginn: zeit(22), ende: zeit(26), ganztaegig: false)
        ]
        // 01:00 am Freitag: Der Abend vom Donnerstag gilt noch, der von Mittwoch nicht.
        WidgetEventPflege.uebernehme([], jetzt: zeit(25), abgesagteMitgeliefert: true, in: &daten)
        #expect(daten.events.map(\.id) == ["nacht"])
    }

    @Test func aeltereDateienOhneAbgesagtLassenSichLesen() throws {
        let json = """
        {"id":"x","titel":"X","beginn":0,"ganztaegig":false}
        """
        let event = try JSONDecoder().decode(WidgetEvent.self, from: Data(json.utf8))
        #expect(!event.abgesagt)
    }

    @Test func wocheWirdGespeichert() {
        var daten = WidgetSnapshot()
        WidgetEventPflege.uebernehmeWoche(von: zeit(12), anzahl: 14, in: &daten)
        #expect(daten.woche == WidgetWoche(von: "2026-10-29", anzahl: 14))
    }
}

/// Liefert fest eingebaute Seiten und zählt die Aufrufe.
@MainActor
private final class EventsQuelleStub: EventsDatenquelle {
    var abend: [CampusEvent] = []
    var gesamt = 14
    var scheitert = false
    private(set) var filter: [EventFilter] = []

    func liste(filter: EventFilter, seite: Int, jetzt: Date) async throws -> EventSeite {
        self.filter.append(filter)
        if scheitert { throw URLError(.notConnectedToInternet) }
        return EventSeite(events: filter.heuteAbend ? abend : [], seite: 1, hatWeitere: false, gesamt: gesamt)
    }

    func veranstalter() async throws -> [Veranstalter] { [] }
    func detail(id: String) async throws -> CampusEvent { throw URLError(.badURL) }
}

@MainActor
struct WidgetEventsAktualisierungTests {
    private func store() -> WidgetStore {
        WidgetStore(dateiURL: FileManager.default.temporaryDirectory.appendingPathComponent("a-\(UUID().uuidString).json"))
    }

    @Test func holtDieEventsSelbstMitAbgesagtenUndDerWoche() async {
        let speicher = store()
        let quelle = EventsQuelleStub()
        quelle.abend = [
            CampusEvent(id: "a", titel: "A", beginn: zeit(19), ende: zeit(21), ort: "Club"),
            CampusEvent(id: "b", titel: "B", beginn: zeit(20), ende: zeit(22), status: .abgesagt)
        ]

        let geaendert = await WidgetEventsAktualisierung(store: speicher)
            .ladeUndSpeichere(quelle: quelle, jetzt: zeit(17), zeitlimit: .seconds(5), clock: ManualClock())

        #expect(geaendert)
        let daten = speicher.lesen()
        // Die Anfrage für heute und morgen nennt „Abend“ und blendet Abgesagte nicht aus.
        let abendFilter = quelle.filter.filter(\.heuteAbend)
        #expect(abendFilter.count == 2)
        #expect(abendFilter.allSatisfy { !$0.abgesagteAusblenden })
        #expect(daten.events.filter { $0.id == "b" }.first?.abgesagt == true)
        #expect(daten.woche?.anzahl == 14)
    }

    @Test func scheitertDasLadenBleibtDerSpeicher() async {
        let speicher = store()
        speicher.aendern { $0.events = [WidgetEvent(id: "alt", titel: "Alt", beginn: zeit(19), ende: zeit(21), ganztaegig: false)] }
        let quelle = EventsQuelleStub()
        quelle.scheitert = true

        await WidgetEventsAktualisierung(store: speicher)
            .ladeUndSpeichere(quelle: quelle, jetzt: zeit(17), zeitlimit: .seconds(5), clock: ManualClock())

        #expect(speicher.lesen().events.map(\.id) == ["alt"])
    }
}

// MARK: - Sperrbildschirm

/// Die drei Zustände aus `WidgetSperrbildschirm.dc.html`.
struct AbendWidgetSperrbildschirmTests {
    private let nachtEvents = [spieleabend, quiz, openStage, karaoke, halloween]

    @Test func abendVorBeginnUeberspringtDasAbgesagte() {
        let sperre = anzeige(18.5, nachtEvents).sperre
        #expect(sperre.zeile == "19:00 Spieleabend · Studi-Club")
        #expect(sperre.rechteck.kicker == "Heute Abend")
        #expect(sperre.rechteck.titel == "19:00 Spieleabend")
        // „dann“ überspringt das Kneipenquiz.
        #expect(sperre.rechteck.unterzeile == "Studi-Club · dann Open Stage")
        #expect(sperre.kreis.gross == "19:00" && sperre.kreis.klein == "+2")
        #expect(sperre.link == DeepLink.event(id: "spiel").url)
        #expect(sperre.kreisLink == DeepLink.eventsHeuteAbend.url)
        #expect(!sperre.leer)
    }

    @Test func eineLaeuft() {
        let sperre = anzeige(19 + 40.0 / 60, nachtEvents).sperre
        #expect(sperre.zeile == "Läuft · Spieleabend · Studi-Club")
        #expect(sperre.rechteck.kicker == "Läuft gerade")
        #expect(sperre.rechteck.titel == "Spieleabend")
        #expect(sperre.rechteck.unterzeile == "Studi-Club · bis 23:00")
        #expect(sperre.kreis.gross == "21:00" && sperre.kreis.klein == "danach")
    }

    @Test func laeuftDieLetzteZeigtDasEnde() {
        let sperre = anzeige(22, [spieleabend]).sperre
        #expect(sperre.kreis.gross == "23:00" && sperre.kreis.klein == "bis")
    }

    @Test func nachDemLetztenDerNaechsteAbend() {
        let sperre = anzeige(23 + 50.0 / 60, [spieleabend, quiz, halloween]).sperre
        #expect(sperre.zeile == "Morgen 21:00 Halloween-Party")
        #expect(sperre.rechteck.kicker == "Morgen Abend")
        #expect(sperre.rechteck.titel == "21:00 Halloween-Party")
        #expect(sperre.rechteck.unterzeile == "Studi-Club")
        #expect(sperre.kreis.gross == "Fr" && sperre.kreis.klein == "21:00")
        #expect(sperre.link == DeepLink.event(id: "halloween").url)
    }

    @Test func nichtsDaZeigtDenMondAllein() {
        let sperre = anzeige(19, []).sperre
        #expect(sperre.leer)
        #expect(sperre.zeile == "Heute Abend nichts eingetragen")
        #expect(sperre.kreis.gross.isEmpty && sperre.kreis.klein.isEmpty)
        #expect(sperre.link == DeepLink.events.url)
        #expect(sperre.kreisLink == DeepLink.events.url)
    }

    @Test func nurNochAbgesagtesFaelltAus() {
        let sperre = anzeige(19, [quiz]).sperre
        #expect(sperre.rechteck.abgesagt)
        #expect(sperre.rechteck.titel == "20:00 Kneipenquiz")
        #expect(sperre.rechteck.unterzeile == "Baracke5 · fällt aus")
        // Die Zeile überspringt Abgesagte.
        #expect(sperre.zeile == "Heute Abend nichts eingetragen")
        #expect(sperre.link == DeepLink.event(id: "quiz").url)
    }

    @Test func gemerkteTragenImRechteckEinenStern() {
        #expect(anzeige(18.5, nachtEvents, gemerkt: ["spiel"]).sperre.rechteck.gemerkt)
        #expect(!anzeige(18.5, nachtEvents).sperre.rechteck.gemerkt)
    }
}
