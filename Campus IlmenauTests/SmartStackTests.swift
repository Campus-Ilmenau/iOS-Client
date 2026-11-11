import Testing
import Foundation
@testable import Campus_Ilmenau

// Relevanz im Smart Stack (Widgets „Mensa heute“ und „Heute Abend“) und die Meldungen an Siri.
// Donnerstag, 29. Oktober 2026 (Berlin), Freitag der 30., Samstag der 31.

// MARK: - Fixtures

private func zeit(_ tag: String, _ uhr: String) -> Date {
    let datum = tag.split(separator: "-").compactMap { Int($0) }
    let teile = uhr.split(separator: ":").compactMap { Int($0) }
    return EventKalender.kalender.date(from: DateComponents(
        year: datum[0], month: datum[1], day: datum[2], hour: teile[0], minute: teile[1]
    ))!
}

private func gericht(_ name: String, abend: Bool = false) -> WidgetGericht {
    WidgetGericht(
        id: "id-\(name)", name: name, gruppe: abend ? "Abendessen" : "Mittag", abendessen: abend,
        preisStudierende: 2.9, preisBedienstete: 3.9, preisGaeste: nil, waehrung: "EUR", chips: []
    )
}

private func mensa(_ venue: MensaVenue, von: String, bis: String, heute: String, plan: [WidgetGericht], naechster: String) -> WidgetMensa {
    WidgetMensa(
        id: venue.rawValue, name: venue.displayName, kurzname: venue.shortName,
        oeffnungszeiten: ["mon", "tue", "wed", "thu", "fri"].map { WidgetOeffnung(wochentag: $0, oeffnet: von, schliesst: bis) },
        heute: WidgetSpeiseplan(tag: heute, gerichte: plan),
        naechsterOeffnungstag: WidgetSpeiseplan(tag: naechster, gerichte: [gericht("Suppe")])
    )
}

/// Mittag 11–14 Uhr in Ehrenberg, Abendessen in der Cafeteria Ehrenberg.
private func mensaDaten(heute: String = "2026-10-29", naechster: String = "2026-10-30", leer: Bool = false) -> WidgetSnapshot {
    WidgetSnapshot(mensen: [
        mensa(.mensaEhrenberg, von: "11:00", bis: "14:00", heute: heute, plan: leer ? [] : [gericht("Linsen-Dal")], naechster: naechster),
        mensa(.cafeteriaEhrenberg, von: "11:00", bis: "14:00", heute: heute, plan: leer ? [] : [gericht("Flammkuchen", abend: true)], naechster: naechster),
        mensa(.nanoteria, von: "08:00", bis: "15:00", heute: heute, plan: leer ? [] : [gericht("Curry")], naechster: naechster),
        mensa(.roentgenbau, von: "10:30", bis: "14:00", heute: heute, plan: leer ? [] : [gericht("Couscous")], naechster: naechster)
    ])
}

private func mensaAnzeige(_ uhr: String, tag: String = "2026-10-29", daten: WidgetSnapshot? = nil) -> MensaWidgetAnzeige {
    MensaWidgetPhasen.anzeige(
        snapshot: daten ?? mensaDaten(), mensaID: "mensaEhrenberg", preisgruppe: .studierende, jetzt: zeit(tag, uhr)
    )
}

// MARK: - Mensa heute: je Phase

struct SmartStackMensaTests {
    @Test func werteDerUebergabe() {
        #expect(SmartStack.hoch == 80)
        #expect(SmartStack.mittel == 40)
        #expect(SmartStack.niedrig == 0)
    }

    @Test(arguments: [
        (MensaWidgetAnzeige.Phase.morgen, Float(40)),
        (.mittag, 80),
        (.nachmittag, 40),
        (.abend, 80),
        (.nacht, 0),
        (.geschlossen, 0)
    ])
    func jedePhaseHatIhrenWert(phase: MensaWidgetAnzeige.Phase, erwartet: Float) {
        #expect(MensaWidgetPhasen.relevanz(phase) == erwartet)
    }

    /// Hoch ab 10:30 bis zur Schließzeit und während des Abendessens, mittel bis 10:30 und zwischen Mittag und
    /// Abendessen, niedrig danach.
    @Test(arguments: [
        ("08:15", Float(40)),   // Vorschau
        ("10:29", 40),
        ("10:30", 80),          // ab 10:30
        ("11:45", 80),
        ("13:59", 80),
        ("14:00", 40),          // nach der Schließzeit bis zum Abendessen
        ("16:29", 40),
        ("16:30", 80),          // Abendessen
        ("19:29", 80),
        ("19:30", 0),           // danach
        ("23:30", 0)
    ])
    func dieUhrzeitenDerUebergabe(uhr: String, erwartet: Float) {
        #expect(MensaWidgetPhasen.relevanz(mensaAnzeige(uhr).phase) == erwartet, "\(uhr)")
    }

    @Test func amWochenendeNiedrig() {
        let daten = mensaDaten(heute: "2026-10-31", naechster: "2026-11-02", leer: true)
        for uhr in ["09:00", "11:45", "17:00"] {
            let anzeige = mensaAnzeige(uhr, tag: "2026-10-31", daten: daten)
            #expect(anzeige.phase == .geschlossen)
            #expect(MensaWidgetPhasen.relevanz(anzeige.phase) == 0, "\(uhr)")
        }
    }

    /// Die Zeitleiste: Ein Eintrag je Phasenwechsel, jeder gilt bis zum nächsten, der letzte bis zum Neuladen um 6 Uhr.
    @Test func zeitleisteHatWertUndDauerJeEintrag() {
        let jetzt = zeit("2026-10-29", "08:15")
        let zeitpunkte = [jetzt] + MensaWidgetPhasen.wechsel(snapshot: mensaDaten(), mensaID: "mensaEhrenberg", nach: jetzt)
        let anzeigen = zeitpunkte.map {
            MensaWidgetPhasen.anzeige(snapshot: mensaDaten(), mensaID: "mensaEhrenberg", preisgruppe: .studierende, jetzt: $0)
        }
        let ende = MensaWidgetPhasen.naechsteNeuladung(nach: jetzt)
        let relevanzen = MensaWidgetPhasen.relevanzen(anzeigen: anzeigen, zeitpunkte: zeitpunkte, ende: ende)

        // 08:15 · 10:30 · 14:00 · 16:30 · 19:30 · Mitternacht (der neue Tag beginnt wieder mit der Vorschau)
        #expect(relevanzen.map(\.score) == [40, 80, 40, 80, 0, 40])
        let stunde: TimeInterval = 3600
        #expect(relevanzen.map(\.dauer) == [2.25 * stunde, 3.5 * stunde, 2.5 * stunde, 3 * stunde, 4.5 * stunde, 6 * stunde])
        #expect(relevanzen.reduce(0) { $0 + $1.dauer } == ende.timeIntervalSince(jetzt))
    }
}

// MARK: - Heute Abend

private func zeit(_ stunden: Double, tag: String = "2026-10-29") -> Date {
    let teile = tag.split(separator: "-").compactMap { Int($0) }
    let basis = EventKalender.kalender.date(from: DateComponents(year: teile[0], month: teile[1], day: teile[2]))!
    return HeuteUhr.datum(am: basis, minuten: 0).addingTimeInterval(TimeInterval(Int((stunden * 60).rounded()) * 60))
}

private func event(
    _ id: String, von: Double, bis: Double? = nil, abgesagt: Bool = false, ganztaegig: Bool = false, tag: String = "2026-10-29"
) -> WidgetEvent {
    WidgetEvent(
        id: id, titel: id, beginn: zeit(von, tag: tag), ende: bis.map { zeit($0, tag: tag) },
        ganztaegig: ganztaegig, ort: "Ort", veranstalter: nil, abgesagt: abgesagt
    )
}

private func abend(_ uhr: Double, _ events: [WidgetEvent]) -> Float {
    AbendWidgetPhasen.relevanz(events: events, jetzt: zeit(uhr))
}

struct SmartStackAbendTests {
    private let spieleabend = event("spiel", von: 21, bis: 23)

    @Test func tagsueberNiedrig() {
        #expect(abend(9, [spieleabend]) == 0)
        #expect(abend(14, [spieleabend]) == 0)
        #expect(abend(16.9, [spieleabend]) == 0)
    }

    @Test func abSiebzehnUhrMittel() {
        #expect(abend(17, [spieleabend]) == 40)
        #expect(abend(19, [spieleabend]) == 40)
        #expect(abend(20.49, [spieleabend]) == 40)
    }

    @Test func abDreissigMinutenVorBeginnHoch() {
        #expect(abend(20.5, [spieleabend]) == 80)   // genau 30 Minuten vorher
        #expect(abend(20.9, [spieleabend]) == 80)
    }

    @Test func solangeEtwasLaeuftHoch() {
        #expect(abend(21, [spieleabend]) == 80)
        #expect(abend(22.9, [spieleabend]) == 80)
    }

    /// Ein Event, das kurz nach 17 Uhr beginnt, ist schon vorher hoch: Es zählt der Beginn, nicht 17 Uhr.
    @Test func vorSiebzehnUhrWennBaldEtwasBeginnt() {
        let frueh = event("frueh", von: 17.25, bis: 19)
        #expect(abend(16.5, [frueh]) == 0)
        #expect(abend(16.75, [frueh]) == 80)
    }

    @Test func nachMitternachtGehoertNochZumVortag() {
        let lang = event("lang", von: 21, bis: 26)   // bis 2 Uhr
        #expect(abend(24.5, [lang]) == 80)
        #expect(abend(25.9, [lang]) == 80)
        #expect(abend(26.1, [lang]) == 0)
    }

    @Test func nichtsEingetragenNiedrig() {
        #expect(abend(18, []) == 0)
        #expect(abend(21, []) == 0)
    }

    @Test func alleVorbeiNiedrigAuchWennMorgenWasIst() {
        let morgen = event("morgen", von: 20, bis: 22, tag: "2026-10-30")
        #expect(abend(23.5, [spieleabend, morgen]) == 0)
    }

    @Test func abgesagteZaehlenNicht() {
        let abgesagt = event("quiz", von: 20, bis: 23, abgesagt: true)
        #expect(abend(19.9, [abgesagt]) == 0)
        #expect(abend(21, [abgesagt]) == 0)
        // Neben einem Abgesagten zählt das andere Event.
        #expect(abend(19, [abgesagt, spieleabend]) == 40)
    }

    @Test func ganztaegigeZaehlenNicht() {
        let ganztags = event("tag", von: 0, ganztaegig: true)
        #expect(abend(18, [ganztags]) == 0)
    }

    @Test func nurDerHeutigeAbendZaehlt() {
        let morgen = event("morgen", von: 20, bis: 22, tag: "2026-10-30")
        #expect(abend(19.6, [morgen]) == 0)
    }

    // MARK: Zeitleiste

    @Test func dieZeitleisteHatEinenEintragAnJederStelleDerRelevanz() {
        let events = [spieleabend]
        let jetzt = zeit(14)
        let wechsel = AbendWidgetPhasen.wechsel(events: events, nach: jetzt)
        // 17 Uhr (mittel), 30 Minuten vor Beginn (hoch), Beginn, Ende, 6 Uhr, 17 Uhr am nächsten Tag.
        #expect(wechsel.contains(zeit(17)))
        #expect(wechsel.contains(zeit(20.5)))
        #expect(wechsel.contains(zeit(21)))
        #expect(wechsel.contains(zeit(23)))
        #expect(wechsel.contains(zeit(6, tag: "2026-10-30")))
        #expect(wechsel.contains(zeit(17, tag: "2026-10-30")))
        #expect(wechsel == wechsel.sorted())

        let zeitpunkte = [jetzt] + wechsel
        let relevanzen = AbendWidgetPhasen.relevanzen(events: events, zeitpunkte: zeitpunkte)
        let werte = Dictionary(uniqueKeysWithValues: zip(zeitpunkte, relevanzen.map(\.score)))
        #expect(werte[jetzt] == 0)
        #expect(werte[zeit(17)] == 40)
        #expect(werte[zeit(20.5)] == 80)
        #expect(werte[zeit(21)] == 80)
        #expect(werte[zeit(23)] == 0)
        #expect(werte[zeit(6, tag: "2026-10-30")] == 0)
        #expect(werte[zeit(17, tag: "2026-10-30")] == 0)
    }

    @Test func jederEintragGiltBisZumNaechsten() {
        let jetzt = zeit(14)
        let zeitpunkte = [jetzt] + AbendWidgetPhasen.wechsel(events: [spieleabend], nach: jetzt)
        let relevanzen = AbendWidgetPhasen.relevanzen(events: [spieleabend], zeitpunkte: zeitpunkte)
        #expect(relevanzen.count == zeitpunkte.count)
        #expect(relevanzen[0].dauer == 3 * 3600)   // 14 bis 17 Uhr
        for index in 0..<(zeitpunkte.count - 1) {
            #expect(relevanzen[index].dauer == zeitpunkte[index + 1].timeIntervalSince(zeitpunkte[index]))
        }
        // Der letzte gilt bis zum Ende des Zeithorizonts.
        #expect(relevanzen.last?.dauer == jetzt.addingTimeInterval(AbendWidgetPhasen.zeitleistenHorizont)
            .timeIntervalSince(zeitpunkte.last ?? jetzt))
    }

    @Test func abgesagteErzeugenKeinenVorlaufEintrag() {
        let punkte = AbendWidgetPhasen.relevanzWechsel(events: [event("quiz", von: 20, abgesagt: true)], heute: zeit(0))
        #expect(!punkte.contains(zeit(19.5)))
        #expect(punkte.contains(zeit(17)))
    }
}

struct SmartStackZeitleisteTests {
    @Test func dauerEndetAmEndeUndWirdNieNegativ() {
        let a = zeit(10), b = zeit(12)
        let relevanzen = SmartStack.relevanzen(scores: [40, 80], zeitpunkte: [a, b], ende: zeit(11))
        #expect(relevanzen == [.init(score: 40, dauer: 7200), .init(score: 80, dauer: 0)])
    }

    @Test func leereZeitleiste() {
        #expect(SmartStack.relevanzen(scores: [], zeitpunkte: [], ende: zeit(11)).isEmpty)
    }
}

// MARK: - Router: von außen

struct RouterAussenTests {
    @MainActor
    @Test func einLinkVonAussenMarkiertDieAktionFuerKurzeZeit() {
        let router = AppRouter()
        let jetzt = Date()
        #expect(!router.kamGeradeVonAussen(jetzt: jetzt))

        router.oeffne(.mensa(id: nil), jetzt: jetzt)
        #expect(router.kamGeradeVonAussen(jetzt: jetzt))
        #expect(router.kamGeradeVonAussen(jetzt: jetzt.addingTimeInterval(AppRouter.aussenFenster - 0.1)))
        #expect(!router.kamGeradeVonAussen(jetzt: jetzt.addingTimeInterval(AppRouter.aussenFenster + 0.1)))
    }

    @MainActor
    @Test func eineHandlungInDerAppIstNichtVonAussen() {
        let router = AppRouter()
        router.zeigeMensa(.nanoteria)
        router.zeigeEventsHeuteAbend()
        #expect(!router.kamGeradeVonAussen())
    }

    @MainActor
    @Test func auchEinWartendesZielZaehltSobaldEsOeffnet() {
        let router = AppRouter(wartetAufStart: true)
        router.eingang(.thoskaAuslesen)
        #expect(!router.kamGeradeVonAussen())
        router.startBeendet()
        #expect(router.kamGeradeVonAussen())
    }
}

// MARK: - Meldungen an Siri

@MainActor
private final class Gemeldet {
    var liste: [SiriMeldung] = []
}

@MainActor
struct SiriMelderTests {
    private let gemeldet = Gemeldet()

    private func melder() -> SiriMelder {
        let gemeldet = gemeldet
        return SiriMelder { gemeldet.liste.append($0) }
    }

    private let ehrenberg = SiriMeldung.mensaHeute(mensa: .mensaEhrenberg, ernaehrung: nil)

    @Test func hoechstensEinmalProOeffnen() async {
        let melder = melder()
        #expect(melder.melde(ehrenberg, in: .mensa, router: nil))
        // Neuladen, Scrollen, erneutes Auswerten: dieselbe Meldung geht nicht noch einmal hinaus.
        #expect(!melder.melde(ehrenberg, in: .mensa, router: nil))
        #expect(!melder.melde(ehrenberg, in: .mensa, router: nil))
        await melder.warteAufAbgaben()
        #expect(gemeldet.liste == [ehrenberg])

        // Neues Öffnen: wieder eine Meldung.
        melder.neueOeffnung(.mensa)
        #expect(melder.melde(ehrenberg, in: .mensa, router: nil))
        await melder.warteAufAbgaben()
        #expect(gemeldet.liste == [ehrenberg, ehrenberg])
    }

    @Test func eineAndereMensaOderEinAndererFilterIstEineNeueMeldung() async {
        let melder = melder()
        melder.melde(ehrenberg, in: .mensa, router: nil)
        melder.melde(.mensaHeute(mensa: .nanoteria, ernaehrung: nil), in: .mensa, router: nil)
        melder.melde(.mensaHeute(mensa: .nanoteria, ernaehrung: .vegan), in: .mensa, router: nil)
        melder.melde(.mensaHeute(mensa: .nanoteria, ernaehrung: .vegan), in: .mensa, router: nil)
        await melder.warteAufAbgaben()
        #expect(gemeldet.liste == [
            ehrenberg, .mensaHeute(mensa: .nanoteria, ernaehrung: nil), .mensaHeute(mensa: .nanoteria, ernaehrung: .vegan)
        ])
    }

    @Test func jedeAnsichtZaehltFuerSich() async {
        let melder = melder()
        melder.melde(.heuteAbend, in: .events, router: nil)
        melder.melde(.merkliste, in: .merkliste, router: nil)
        melder.melde(.thoskaAuslesen, in: .thoska, router: nil)
        melder.melde(.abendessen, in: .mensaAbendessen, router: nil)
        melder.melde(ehrenberg, in: .mensa, router: nil)
        await melder.warteAufAbgaben()
        #expect(gemeldet.liste == [.heuteAbend, .merkliste, .thoskaAuslesen, .abendessen, ehrenberg])
    }

    // Aktionen, die gerade durch Siri, ein Widget oder einen Vorschlag ausgelöst wurden, meldet die App nicht.
    @Test func nichtsMeldenWasGeradeVonAussenKam() async {
        let melder = melder()
        let router = AppRouter()
        let jetzt = Date()
        router.oeffne(.eventsHeuteAbend, jetzt: jetzt)

        #expect(!melder.melde(.heuteAbend, in: .events, router: router, jetzt: jetzt))
        await melder.warteAufAbgaben()
        #expect(gemeldet.liste.isEmpty)

        // Später, nach einer Handlung des Nutzers, geht es wieder.
        #expect(melder.melde(.heuteAbend, in: .events, router: router, jetzt: jetzt.addingTimeInterval(10)))
        await melder.warteAufAbgaben()
        #expect(gemeldet.liste == [.heuteAbend])
    }

    @Test func abgabenBleibenInDerReihenfolge() async {
        let melder = melder()
        melder.melde(.heuteAbend, in: .events, router: nil)
        melder.melde(.merkliste, in: .merkliste, router: nil)
        await melder.warteAufAbgaben()
        #expect(gemeldet.liste == [.heuteAbend, .merkliste])
    }
}

@MainActor
struct SiriMeldungTests {
    @Test func mensaMitErnaehrungNurBeiVegetarischOderVegan() {
        #expect(SiriMeldung.mensa(.nanoteria, filter: MensaFilter()) == .mensaHeute(mensa: .nanoteria, ernaehrung: nil))
        #expect(SiriMeldung.mensa(.nanoteria, filter: MensaFilter(diet: .vegetarisch)) == .mensaHeute(mensa: .nanoteria, ernaehrung: .vegetarisch))
        #expect(SiriMeldung.mensa(.nanoteria, filter: MensaFilter(diet: .vegan)) == .mensaHeute(mensa: .nanoteria, ernaehrung: .vegan))
        // „Nur Bio“ und Allergene gehören nicht dazu: Die Meldung kennt nur die Ernährungsstufe.
        #expect(SiriMeldung.mensa(.nanoteria, filter: MensaFilter(onlyBio: true, excludedAllergens: ["Milch und Milchzucker"]))
            == .mensaHeute(mensa: .nanoteria, ernaehrung: nil))
    }

    @Test func jedeMensaWirdAlsMensaOrtGemeldet() {
        for venue in MensaVenue.allCases {
            #expect(SiriMeldung.mensa(venue, filter: MensaFilter()) == .mensaHeute(mensa: MensaOrt(venue), ernaehrung: nil))
        }
    }

    /// Nachmittags ist die Phase des Widgets: ab der Schließzeit des Mittags (Cafeteria Ehrenberg im Beispiel 14 Uhr).
    @Test func abendessenNurNachmittagsHeuteInDerCafeteriaEhrenberg() {
        let tag = zeit("2026-10-29", "00:00")
        func zeigt(_ uhr: String, venue: MensaVenue = .cafeteriaEhrenberg, mealtime: MensaMealtime = .dinner, tag: Date = tag) -> Bool {
            SiriMeldung.zeigtAbendessen(venue: venue, mealtime: mealtime, tag: tag, jetzt: zeit("2026-10-29", uhr), snapshot: mensaDaten())
        }
        #expect(zeigt("14:00"))                 // Schließzeit des Mittags
        #expect(zeigt("15:10"))
        #expect(zeigt("17:40"))                 // Abendessen läuft
        // Vormittags und mittags nicht, auch wenn der Reiter „Abendessen“ offen ist.
        #expect(!zeigt("11:45"))
        #expect(!zeigt("13:59"))
        // Nach dem Abendessen: nichts mehr.
        #expect(!zeigt("20:15"))
        // Mittagsplan, andere Mensa oder anderer Tag: nein.
        #expect(!zeigt("15:10", mealtime: .lunch))
        #expect(!zeigt("15:10", venue: .nanoteria))
        #expect(!zeigt("15:10", tag: zeit("2026-10-30", "00:00")))
    }

    /// Schließt die Cafeteria vor 14:00, beginnt der Nachmittag früher; schließt sie später (Abendessen eingerechnet),
    /// beginnt er mit dem Abendessen. Es gibt keine feste Uhrzeit.
    @Test func derNachmittagFolgtDerSchliesszeitDerCafeteria() {
        let tag = zeit("2026-10-29", "00:00")
        func daten(schliesst: String) -> WidgetSnapshot {
            var snapshot = mensaDaten()
            snapshot.mensen[1].oeffnungszeiten = ["thu"].map { WidgetOeffnung(wochentag: $0, oeffnet: "08:00", schliesst: schliesst) }
            return snapshot
        }
        func zeigt(_ uhr: String, _ snapshot: WidgetSnapshot) -> Bool {
            SiriMeldung.zeigtAbendessen(venue: .cafeteriaEhrenberg, mealtime: .dinner, tag: tag, jetzt: zeit("2026-10-29", uhr), snapshot: snapshot)
        }
        let frueh = daten(schliesst: "13:00")
        #expect(!zeigt("12:59", frueh))
        #expect(zeigt("13:00", frueh))

        let spaet = daten(schliesst: "20:00")
        #expect(!zeigt("15:00", spaet))         // Mittag läuft laut Öffnungszeit noch
        #expect(zeigt("16:30", spaet))          // ab dem Abendessen
    }

    @Test func amWochenendeNie() {
        let daten = mensaDaten(heute: "2026-10-31", naechster: "2026-11-02", leer: true)
        let tag = zeit("2026-10-31", "00:00")
        #expect(!SiriMeldung.zeigtAbendessen(venue: .cafeteriaEhrenberg, mealtime: .dinner, tag: tag, jetzt: zeit("2026-10-31", "15:10"), snapshot: daten))
    }
}
