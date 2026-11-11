import Testing
import Foundation
import AppIntents
@testable import Campus_Ilmenau

// Die gesprochenen Sätze und die Karte von „Was ist heute Abend los?“. Die Events sind die aus dem Mockup
// (`WidgetHeuteAbend.dc.html`): Donnerstag, 29. Oktober 2026 (Berlin). Stunden über 24 sind Zeiten nach Mitternacht.

// MARK: - Fixtures

private func zeit(_ stunden: Double, tag: String = "2026-10-29") -> Date {
    let teile = tag.split(separator: "-").compactMap { Int($0) }
    let basis = EventKalender.kalender.date(from: DateComponents(year: teile[0], month: teile[1], day: teile[2]))!
    return HeuteUhr.datum(am: basis, minuten: 0).addingTimeInterval(TimeInterval(Int((stunden * 60).rounded()) * 60))
}

private func event(
    _ id: String, _ titel: String, von: Double, bis: Double? = nil, ort: String? = nil, abgesagt: Bool = false,
    tag: String = "2026-10-29"
) -> WidgetEvent {
    WidgetEvent(
        id: id, titel: titel, beginn: zeit(von, tag: tag), ende: bis.map { zeit($0, tag: tag) },
        ganztaegig: false, ort: ort, veranstalter: nil, abgesagt: abgesagt
    )
}

private let spieleabend = event("spiel", "Spieleabend", von: 19, bis: 23, ort: "Studi-Club")
private let quiz = event("quiz", "Kneipenquiz", von: 20, bis: 23, ort: "Baracke5", abgesagt: true)
private let openStage = event("stage", "Open Stage", von: 21, bis: 25, ort: "BC-Club")
private let karaoke = event("karaoke", "Karaoke-Nacht", von: 22, bis: 26, ort: "Baracke5")

private let lola = event("lola", "Filmabend: Lola rennt", von: 20, bis: 22.5, ort: "Faraday-Hörsaal", tag: "2026-10-30")
private let halloween = event("halloween", "Halloween-Party", von: 21, bis: 27, ort: "Studi-Club", tag: "2026-10-30")
private let elektro = event("elektro", "Elektro-Nacht", von: 22, bis: 28, ort: "BC-Club", tag: "2026-10-30")

/// Ein Speicher, der schon einmal geschrieben wurde (`stand`): Er enthält, was die Events-API geliefert hat.
private func daten(_ events: [WidgetEvent], gemerkt: [String] = []) -> WidgetSnapshot {
    WidgetSnapshot(events: events, gemerkteEventIDs: gemerkt, stand: zeit(12))
}

private func antwort(_ uhr: Double, _ events: [WidgetEvent], gemerkt: [String] = []) -> SiriAbendAntwort {
    SiriAbend.antwort(snapshot: daten(events, gemerkt: gemerkt), jetzt: zeit(uhr))
}

// MARK: - Gesprochen

struct SiriAbendSatzTests {
    /// Wie im Mockup: Laufendes zuerst, danach die nächsten, die Absage nur am Ende.
    @Test func einEventLaeuftGerade() {
        let a = antwort(19 + 40.0 / 60, [spieleabend, quiz, openStage, karaoke, lola])
        #expect(a.sagt == "Gerade läuft Spieleabend im Studi-Club. Um 21 Uhr ist Open Stage im BC-Club, um 22 Uhr Karaoke-Nacht in der Baracke5. Kneipenquiz fällt aus.")
    }

    @Test func nochNichtsLaeuftDannDieNaechstenDreiMitAbsageAmEnde() {
        let a = antwort(18.5, [spieleabend, quiz, openStage, karaoke, lola])
        #expect(a.sagt == "Heute Abend ist um 19 Uhr Spieleabend im Studi-Club, um 21 Uhr Open Stage im BC-Club und um 22 Uhr Karaoke-Nacht in der Baracke5. Kneipenquiz fällt aus.")
    }

    @Test func eineAbsageOhneLaufendesStehtNurAmEnde() {
        let a = antwort(18.5, [quiz, openStage])
        #expect(a.sagt == "Heute Abend ist um 21 Uhr Open Stage im BC-Club. Kneipenquiz fällt aus.")
    }

    @Test func mehrereAbsagenInEinemSatz() {
        let a = antwort(18.5, [spieleabend, quiz, openStage.mitAbsage()])
        #expect(a.sagt == "Heute Abend ist um 19 Uhr Spieleabend im Studi-Club. Kneipenquiz und Open Stage fallen aus.")
    }

    @Test func hoechstensDreiVeranstaltungenAbgesagteZaehlenNicht() {
        let mehr = [
            spieleabend, quiz, openStage, karaoke,
            event("film", "Filmabend", von: 22.5, bis: 24, ort: "Aula"),
            event("disco", "Disco", von: 23, bis: 26, ort: "Café Sonne")
        ]
        let a = antwort(18.5, mehr)
        #expect(a.sagt == "Heute Abend ist um 19 Uhr Spieleabend im Studi-Club, um 21 Uhr Open Stage im BC-Club und um 22 Uhr Karaoke-Nacht in der Baracke5. Kneipenquiz fällt aus.")
        #expect(!a.sagt.contains("Filmabend"))
        // Die Karte zeigt 3 Zeilen (mit der Absage) und zählt den Rest.
        #expect(a.karte?.zeilen.map(\.titel) == ["Spieleabend", "Kneipenquiz", "Open Stage"])
        #expect(a.karte?.fuss == "+3 weitere heute")
    }

    /// Das Geschlecht eines Ortes sieht man nur am Wortende; sonst steht er ohne Verhältniswort.
    @Test func orteMitUndOhneVerhaeltniswort() {
        #expect(SiriSprache.ortsangabe("Studi-Club") == " im Studi-Club")
        #expect(SiriSprache.ortsangabe("Faraday-Hörsaal") == " im Faraday-Hörsaal")
        #expect(SiriSprache.ortsangabe("Baracke5") == " in der Baracke5")
        #expect(SiriSprache.ortsangabe("Mensa") == " in der Mensa")
        #expect(SiriSprache.ortsangabe("Kasseturm") == " – Kasseturm")
        #expect(SiriSprache.ortsangabe(nil) == "")
        #expect(SiriSprache.ortsangabe("  ") == "")

        let ohneOrt = antwort(18.5, [event("x", "Spieleabend", von: 19)])
        #expect(ohneOrt.sagt == "Heute Abend ist um 19 Uhr Spieleabend.")
        let unbekannt = antwort(18.5, [event("x", "Open Stage", von: 20.5, ort: "Kasseturm")])
        #expect(unbekannt.sagt == "Heute Abend ist um 20:30 Uhr Open Stage – Kasseturm.")
    }

    // Leer: der Satz mit dem nächsten Abend.
    @Test func nichtsEingetragenMitMorgen() {
        let a = antwort(18, [halloween])
        #expect(a.sagt == "Heute Abend ist nichts eingetragen. Morgen um 21 Uhr: Halloween-Party im Studi-Club.")
    }

    @Test func nichtsEingetragenUndMorgenAuchNicht() {
        let a = antwort(18, [])
        #expect(a.sagt == "Heute Abend ist nichts eingetragen.")
    }

    @Test func morgenNurAbgesagtesZaehltNichtAlsNaechstes() {
        let a = antwort(18, [halloween.mitAbsage()])
        #expect(a.sagt == "Heute Abend ist nichts eingetragen.")
    }

    @Test func nurNochAbgesagtesHeute() {
        let a = antwort(18.5, [quiz, halloween])
        #expect(a.sagt == "Heute Abend ist nichts los. Kneipenquiz fällt aus. Morgen um 21 Uhr: Halloween-Party im Studi-Club.")
    }

    // Alles vorbei: es geht um den nächsten Abend.
    @Test func alleVorbeiDannMorgenAbend() {
        let a = antwort(23.5, [spieleabend, lola, halloween, elektro])
        #expect(a.sagt == "Heute Abend ist alles vorbei. Morgen Abend ist um 20 Uhr Filmabend: Lola rennt im Faraday-Hörsaal, um 21 Uhr Halloween-Party im Studi-Club und um 22 Uhr Elektro-Nacht im BC-Club.")
    }

    @Test func alleVorbeiUndMorgenNichtsDa() {
        let a = antwort(23.5, [spieleabend])
        #expect(a.sagt == "Heute Abend ist alles vorbei. Für morgen Abend ist nichts eingetragen.")
        #expect(a.karte?.zeilen.isEmpty == true)
    }

    @Test func alleVorbeiMorgenMitAbsage() {
        let a = antwort(23.5, [spieleabend, lola, halloween.mitAbsage()])
        #expect(a.sagt == "Heute Abend ist alles vorbei. Morgen Abend ist um 20 Uhr Filmabend: Lola rennt im Faraday-Hörsaal. Halloween-Party fällt aus.")
    }

    @Test func nachMitternachtGehoertDerAbendNochZumVortag() {
        // 0:30 am Freitag: Open Stage (bis 1:00) läuft noch.
        let a = antwort(24.5, [spieleabend, openStage])
        #expect(a.sagt == "Gerade läuft Open Stage im BC-Club.")
    }

    @Test func ohneSpeicherUndOhneDatenKeineAntwort() {
        let a = SiriAbend.antwort(snapshot: WidgetSnapshot(), jetzt: zeit(18))
        #expect(a.sagt == "Ich komme gerade nicht an die Veranstaltungen. Versuch es gleich noch mal.")
        #expect(a.karte == nil)
    }
}

// MARK: - Karte

struct SiriAbendKarteTests {
    @Test func laufendesZuerstDannDieNaechstenMitAbsageInderReihe() throws {
        let a = antwort(19 + 40.0 / 60, [spieleabend, quiz, openStage, karaoke], gemerkt: ["stage"])
        let karte = try #require(a.karte)
        #expect(karte.titel == "Heute Abend")
        #expect(karte.datum == "Do 29. Okt.")
        #expect(karte.zeilen.map(\.titel) == ["Spieleabend", "Kneipenquiz", "Open Stage"])
        #expect(karte.zeilen.map(\.laeuft) == [true, false, false])
        #expect(karte.zeilen.map(\.abgesagt) == [false, true, false])
        #expect(karte.zeilen.map(\.gemerkt) == [false, false, true])
        #expect(karte.zeilen.map(\.zeit) == ["19:00", "20:00", "21:00"])
        #expect(karte.fuss == "+1 weitere heute")
        #expect(karte.leerText == nil)
    }

    @Test func zeileFuehrtZumEventKopfUndFussZuHeuteAbend() throws {
        let karte = try #require(antwort(18.5, [spieleabend, openStage]).karte)
        #expect(karte.zeilen.map(\.link) == [DeepLink.event(id: "spiel").url, DeepLink.event(id: "stage").url])
        #expect(karte.kopfLink == DeepLink.eventsHeuteAbend.url)
    }

    @Test func ohneWeitereKeinFussText() throws {
        let karte = try #require(antwort(18.5, [spieleabend, openStage]).karte)
        #expect(karte.fuss == "")
    }

    @Test func nachDemLetztenEndeZeigtDieKarteMorgenAbend() throws {
        let karte = try #require(antwort(23.5, [spieleabend, lola, halloween, elektro]).karte)
        #expect(karte.titel == "Morgen Abend")
        #expect(karte.datum == "Fr 30. Okt.")
        #expect(karte.zeilen.map(\.titel) == ["Filmabend: Lola rennt", "Halloween-Party", "Elektro-Nacht"])
        #expect(karte.zeilen.allSatisfy { !$0.laeuft })
    }

    @Test func leerZeigtDenHinweisAufMorgen() throws {
        let karte = try #require(antwort(18, [halloween]).karte)
        #expect(karte.titel == "Heute Abend")
        #expect(karte.zeilen.isEmpty)
        #expect(karte.leerText == "Morgen · 21:00 Halloween-Party, Studi-Club")
    }

    @Test func leerOhneIrgendwasZeigtEinenNeutralenHinweis() throws {
        let karte = try #require(antwort(18, []).karte)
        #expect(karte.zeilen.isEmpty)
        #expect(karte.leerText == "Schau, was in den nächsten Tagen los ist.")
    }
}

struct SiriAbendIntentTests {
    @Test func derIntentLaeuftOhneDieAppZuOeffnen() {
        #expect(!HeuteAbendIntent.openAppWhenRun)
    }
}

private extension WidgetEvent {
    func mitAbsage() -> WidgetEvent {
        var kopie = self
        kopie.abgesagt = true
        return kopie
    }
}
