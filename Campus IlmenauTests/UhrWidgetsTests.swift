import Foundation
import Testing
@testable import Campus_Ilmenau

/// Die Rechnung der Watch-Widgets (`WatchShared/UhrWidgets.swift`) mit fester Uhrzeit: Die Uhrzeit wird hineingegeben,
/// die echte Uhr spielt keine Rolle. Beispieldaten: Donnerstag, 29. Oktober 2026 (Berlin), wie bei den iPhone-Widgets.
@MainActor
struct UhrWidgetsTests {
    // MARK: - Hilfen

    private func zeit(_ uhr: String, tag: String = "2026-10-29") -> Date { MensaWidgetVorschau.zeit(tag, uhr) }

    private let mittag = MensaWidgetVorschau.snapshot(.mittag)
    private let wochenende = MensaWidgetVorschau.snapshot(.wochenende)

    private func mensa(_ uhr: String, einstellungen: UhrEinstellungen = .vorgabe, snapshot: WidgetSnapshot? = nil, tag: String = "2026-10-29")
        -> UhrMensaZeitleiste.Eintrag {
        UhrMensaZeitleiste.eintraege(snapshot: snapshot ?? mittag, einstellungen: einstellungen, ab: zeit(uhr, tag: tag))[0]
    }

    // MARK: - Mensa: Relevanz (80 / 40 / 0)

    @Test func mensaRelevanzFolgtDenPhasenEhrenbergSchliesstUm14Uhr() {
        let erwartet: [(String, Float)] = [
            ("00:30", 40), ("08:15", 40), ("10:29", 40),
            ("10:30", 80), ("11:45", 80), ("13:59", 80),
            ("14:00", 40), ("15:10", 40), ("16:29", 40),
            ("16:30", 80), ("17:40", 80), ("19:29", 80),
            ("19:30", 0), ("21:30", 0), ("23:59", 0)
        ]
        for (uhr, score) in erwartet {
            #expect(mensa(uhr).relevanz.score == score, "um \(uhr)")
        }
    }

    @Test func mensaRelevanzAmWochenendeIstNull() {
        // Samstag: zu, es gilt der nächste Öffnungstag.
        for uhr in ["08:15", "11:45", "17:40", "21:30"] {
            #expect(mensa(uhr, snapshot: wochenende, tag: "2026-10-31").relevanz.score == 0, "um \(uhr)")
        }
    }

    @Test func mensaRelevanzKommtAusDenSchliesszeitenDerDaten() {
        // Die Röntgenbau-Cafeteria schließt um 14:00, die Nanoteria um 15:00: nicht fest, sondern aus den Daten.
        let nanoteria = UhrEinstellungen(mensa: .nanoteria)
        #expect(mensa("14:30", einstellungen: nanoteria).relevanz.score == 80)
        #expect(mensa("14:30").relevanz.score == 40)   // Ehrenberg hat um 14:30 schon zu
        #expect(mensa("15:00", einstellungen: nanoteria).relevanz.score == 40)
    }

    @Test func mensaZeitleisteHatEinenEintragZuJedemWechselDerRelevanz() {
        // Die Zeitleiste reicht höchstens 3 Stunden voraus (danach lädt das Widget neu): je Wechsel ein Start davor.
        let wechsel: [(start: String, wechsel: String, score: Float)] = [
            ("10:00", "10:30", 80), ("12:30", "14:00", 40), ("15:30", "16:30", 80), ("17:30", "19:30", 0)
        ]
        for (start, uhr, score) in wechsel {
            let eintraege = UhrMensaZeitleiste.eintraege(snapshot: mittag, einstellungen: .vorgabe, ab: zeit(start))
            let eintrag = eintraege.first { $0.date == zeit(uhr) }
            #expect(eintrag?.relevanz.score == score, "Wechsel um \(uhr)")
        }
    }

    @Test func mensaRelevanzGiltBisZumNaechstenEintrag() {
        let eintraege = UhrMensaZeitleiste.eintraege(snapshot: mittag, einstellungen: .vorgabe, ab: zeit("11:45"))
        #expect(eintraege.count > 1)
        for (eintrag, naechster) in zip(eintraege, eintraege.dropFirst()) {
            #expect(eintrag.relevanz.dauer == naechster.date.timeIntervalSince(eintrag.date))
        }
    }

    // MARK: - Mensa: Anzeige (Rechteck, Kreis, Zeile)

    @Test func mensaRechteckZeigtKickerGerichtPreisUndPosition() {
        let sperre = mensa("11:45").sperre
        #expect(sperre.kicker == "Ehrenberg · bis 14:00")
        #expect(sperre.gericht?.name != nil)
        #expect(sperre.gericht?.preis.hasSuffix("€") == true)
        #expect(sperre.positionText == "\(sperre.position)/\(sperre.anzahl)")
        #expect(sperre.anzahl == 3)
    }

    @Test func mensaKreisZeigtUhrzeitUndWort() {
        let erwartet: [(String, String, String)] = [
            ("08:15", "11:00", "öffnet"), ("11:45", "14:00", "bis"), ("14:20", "15:00", "Nanoteria"),
            ("16:00", "16:30", "Abend"), ("17:40", "19:30", "bis"), ("21:30", "Fr", "11:00")
        ]
        for (uhr, gross, klein) in erwartet {
            let sperre = mensa(uhr).sperre
            #expect(sperre.kreisGross == gross, "um \(uhr)")
            #expect(sperre.kreisKlein == klein, "um \(uhr)")
        }
    }

    @Test func nachMittagWechseltDieUhrVonSelbstZurMensaDieNochOffenHat() {
        // Ehrenberg ist gewählt und hat um 14:20 zu, die Nanoteria bis 15:00.
        let sperre = mensa("14:20").sperre
        #expect(sperre.phase == .nochOffen)
        #expect(sperre.kicker == "Noch offen · Nanoteria")
        #expect(sperre.mensaID == MensaVenue.nanoteria.rawValue)
        #expect(sperre.zeile.hasPrefix("Nanoteria bis 15:00 · "))
    }

    @Test func nochOffenGibtDieMensaMitUndBittetDieUhrSieZuWaehlen() throws {
        let sperre = mensa("14:20").sperre
        // Alle Familien, das Rechteck eingeschlossen: Es führt zur Mensa, nicht zum Gericht einer geschlossenen.
        for rechteck in [false, true] {
            let url = UhrMensaLink.url(sperre, rechteck: rechteck)
            #expect(DeepLink(url: url) == .mensa(id: MensaVenue.nanoteria.rawValue), "Rechteck: \(rechteck)")
            #expect(UhrMensaLink.gewaehlteMensa(url) == .nanoteria, "Rechteck: \(rechteck)")
        }
    }

    @Test func ohneNochOffenWaehltDerLinkNichtsUndBleibtWieAufDemIPhone() {
        for uhr in ["08:15", "11:45", "17:40", "21:30"] {
            let sperre = mensa(uhr).sperre
            #expect(sperre.phase != .nochOffen, "um \(uhr)")
            #expect(UhrMensaLink.url(sperre) == sperre.speiseplanLink, "um \(uhr)")
            #expect(UhrMensaLink.url(sperre, rechteck: true) == sperre.rechteckLink, "um \(uhr)")
            #expect(UhrMensaLink.gewaehlteMensa(UhrMensaLink.url(sperre, rechteck: true)) == nil, "um \(uhr)")
        }
    }

    @Test func nurLinksMitWaehlenWaehlenEineMensa() {
        let ohne = DeepLink.mensa(id: MensaVenue.nanoteria.rawValue).url
        #expect(UhrMensaLink.gewaehlteMensa(ohne) == nil)
        #expect(UhrMensaLink.gewaehlteMensa(DeepLink.mensa(id: nil).url) == nil)
        #expect(UhrMensaLink.gewaehlteMensa(DeepLink.merkliste.url) == nil)
        #expect(UhrMensaLink.gewaehlteMensa(URL(string: "campusilmenau://mensa?mensa=unbekannt&waehlen=1")!) == nil)
    }

    @Test func nachAllenMittagenKommtDasAbendessenEgalWelcheMensaGewaehltIst() {
        for venue in [MensaVenue.mensaEhrenberg, .nanoteria, .roentgenbau] {
            let sperre = mensa("17:40", einstellungen: UhrEinstellungen(mensa: venue)).sperre
            #expect(sperre.phase == .abend, "\(venue)")
            #expect(sperre.kicker == "Abendessen · bis 19:30")
        }
    }

    @Test func nachtsZeigtDenNaechstenOeffnungstag() {
        let sperre = mensa("21:30").sperre
        #expect(sperre.phase == .naechsterTag)
        #expect(sperre.kicker == "Mittag morgen · Ehrenberg")
    }

    @Test func mensaFilterUndPreisgruppeKommenVomIPhone() {
        let einstellungen = UhrEinstellungen(preisgruppe: .gaeste, filter: MensaWidgetVorschau.filterVeganOhneMilch)
        let sperre = mensa("11:45", einstellungen: einstellungen).sperre
        #expect(sperre.filterung != nil)
        #expect(sperre.anzahl == 2)   // zwei von drei Gerichten lässt der Filter durch
    }

    @Test func mensaGerichtRotiertImFuenfMinutenTakt() {
        let eintraege = UhrMensaZeitleiste.eintraege(snapshot: mittag, einstellungen: .vorgabe, ab: zeit("11:45"))
        #expect(eintraege[1].date == zeit("11:50"))
        #expect(eintraege[2].date == zeit("11:55"))
        // Jeder Takt zeigt das nächste Gericht; nach dem dritten geht es von vorn los.
        for (eintrag, naechster) in zip(eintraege.prefix(5), eintraege.dropFirst().prefix(5)) {
            #expect(naechster.sperre.position == eintrag.sperre.position % 3 + 1)
        }
    }

    @Test func ohneDatenStehtNochKeinPlan() {
        let sperre = mensa("11:45", snapshot: WidgetSnapshot()).sperre
        #expect(sperre.gericht == nil)
        #expect(sperre.leerTitel == "Noch kein Plan")
    }

    // MARK: - Heute Abend

    private func abendEvent(_ id: String, _ titel: String, von: Double, bis: Double, ort: String, abgesagt: Bool = false) -> WidgetEvent {
        WidgetEvent(
            id: id, titel: titel, beginn: AbendWidgetVorschau.zeit(von), ende: AbendWidgetVorschau.zeit(bis), ort: ort, abgesagt: abgesagt
        )
    }

    /// Wie `WatchEvents.dc.html`: Spieleabend 19–23 (Studi-Club), Kneipenquiz 20 (fällt aus), Open Stage 21, Karaoke 22.
    private var abend: WidgetSnapshot {
        WidgetSnapshot(events: [
            abendEvent("spiel", "Spieleabend", von: 19, bis: 23, ort: "Studi-Club"),
            abendEvent("quiz", "Kneipenquiz", von: 20, bis: 23, ort: "Baracke5", abgesagt: true),
            abendEvent("stage", "Open Stage", von: 21, bis: 25, ort: "BC-Club"),
            abendEvent("karaoke", "Karaoke-Nacht", von: 22, bis: 26, ort: "Baracke5")
        ], gemerkteEventIDs: ["stage"])
    }

    private func abendEintrag(_ stunden: Double, snapshot: WidgetSnapshot? = nil) -> UhrAbendZeitleiste.Eintrag {
        UhrAbendZeitleiste.eintraege(snapshot: snapshot ?? abend, ab: AbendWidgetVorschau.zeit(stunden))[0]
    }

    @Test func abendRelevanzVierzigAb17UndAchtzigVorBeginnUndWaehrendEtwasLaeuft() {
        let erwartet: [(Double, Float)] = [
            (6, 0), (12, 0), (16.99, 0),     // tagsüber
            (17, 40), (18, 40), (18.49, 40), // ab 17 Uhr
            (18.5, 80), (19, 80), (19.67, 80), (22.9, 80), // 30 Minuten vor 19:00 und solange etwas läuft
            (23.5, 80), (25.5, 80)           // Open Stage und Karaoke laufen noch
        ]
        for (stunden, score) in erwartet {
            #expect(abendEintrag(stunden).relevanz.score == score, "um \(stunden)")
        }
    }

    @Test func abendRelevanzNullWennAllesVorbeiNichtsEingetragenOderNurAbgesagtes() {
        // Alles vorbei: Spieleabend und Co. enden spätestens um 2 Uhr; um 6 Uhr beginnt der neue Abend.
        #expect(abendEintrag(26.5).relevanz.score == 0)
        #expect(abendEintrag(19.5, snapshot: WidgetSnapshot()).relevanz.score == 0)
        let nurAbgesagt = WidgetSnapshot(events: [abendEvent("quiz", "Kneipenquiz", von: 20, bis: 23, ort: "Baracke5", abgesagt: true)])
        #expect(abendEintrag(19.5, snapshot: nurAbgesagt).relevanz.score == 0)
        let nurMorgen = WidgetSnapshot(events: AbendWidgetVorschau.events(.leer))
        #expect(abendEintrag(19.5, snapshot: nurMorgen).relevanz.score == 0)
    }

    @Test func abendRelevanzWechseltNachDatenNichtNachFestenUhrzeiten() {
        // Ein Event um 20:00: Hoch ab 19:30. Ein anderes um 18:00: Hoch schon ab 17:30.
        let spaet = WidgetSnapshot(events: [abendEvent("a", "Filmabend", von: 20, bis: 22, ort: "Hörsaal")])
        #expect(abendEintrag(19.49, snapshot: spaet).relevanz.score == 40)
        #expect(abendEintrag(19.5, snapshot: spaet).relevanz.score == 80)
        let frueh = WidgetSnapshot(events: [abendEvent("a", "Vortrag", von: 18, bis: 19, ort: "Hörsaal")])
        #expect(abendEintrag(17.49, snapshot: frueh).relevanz.score == 40)
        #expect(abendEintrag(17.5, snapshot: frueh).relevanz.score == 80)
        // Nach dem Ende des einzigen Events ist es wieder 0.
        #expect(abendEintrag(19.01, snapshot: frueh).relevanz.score == 0)
    }

    @Test func abendZeitleisteHatEintraegeZu17UhrUndDreissigMinutenVorBeginn() {
        let eintraege = UhrAbendZeitleiste.eintraege(snapshot: abend, ab: AbendWidgetVorschau.zeit(12))
        let scores = Dictionary(eintraege.map { ($0.date, $0.relevanz.score) }, uniquingKeysWith: { _, neu in neu })
        #expect(scores[AbendWidgetVorschau.zeit(17)] == 40)
        #expect(scores[AbendWidgetVorschau.zeit(18.5)] == 80)
        #expect(scores[AbendWidgetVorschau.zeit(19)] == 80)   // Beginn: Anzeige wechselt auf „Läuft gerade“
    }

    @Test func abendRechteckWennEtwasLaeuft() {
        let a = abendEintrag(19 + 40.0 / 60).anzeige
        #expect(a.kicker == "Läuft gerade · Studi-Club")
        #expect(a.titel == "Spieleabend")
        #expect(a.links == "Dann 21:00")
        #expect(a.rechts == "Open Stage")
        #expect(a.zeile == "21:00 Open Stage")
        #expect(a.kreisZeit == "21:00")
        #expect(a.kreisWort == "Open Stage")
        #expect(a.link == DeepLink.eventsHeuteAbend.url)
    }

    @Test func abendRechteckAlsNaechstes() {
        let a = abendEintrag(17 + 40.0 / 60).anzeige
        #expect(a.kicker == "Heute Abend")
        #expect(a.titel == "19:00 Spieleabend")
        #expect(a.links == "Studi-Club")
        #expect(a.rechts == "+2 weitere")   // Das Abgesagte zählt nicht.
        #expect(a.zeile == "19:00 Spieleabend")
        #expect(a.kreisZeit == "19:00")
    }

    @Test func abendOhneVeranstaltungNurDerMond() {
        let a = abendEintrag(19.5, snapshot: WidgetSnapshot()).anzeige
        #expect(a.istLeer)
        #expect(a.kreisZeit == nil)
        #expect(a.link == DeepLink.events.url)
    }

    @Test func abendMarkiertGemerkteUndSkipptAbgesagtes() {
        // 21:30: Spieleabend und Open Stage laufen (gemerkt), danach Karaoke; das Abgesagte kommt nie vor.
        let a = abendEintrag(21.5).anzeige
        #expect(a.titel == "Spieleabend")
        #expect(a.rechts == "Karaoke-Nacht")
        let stage = UhrAbendWidgetAnzeige.erstelle(
            snapshot: WidgetSnapshot(events: [abendEvent("stage", "Open Stage", von: 21, bis: 25, ort: "BC-Club")], gemerkteEventIDs: ["stage"]),
            jetzt: AbendWidgetVorschau.zeit(20)
        )
        #expect(stage.gemerkt)
    }

    // MARK: - Merkliste

    private func eintrag(_ id: String) -> UhrMerklisteEintrag {
        UhrMerklisteEintrag(id: id, titel: id, changedAt: .now)
    }

    @Test func merklisteKreisZaehltDieTitelImRegal() {
        let anzeige = UhrMerklisteWidgetAnzeige.erstelle(
            eintraege: ["a", "b", "c", "d"].map(eintrag),
            staende: [
                "a": .regal(standort: "60 ELT", signatur: "S", nurVorOrt: false), "b": .regal(standort: "70 MB", signatur: "S", nurVorOrt: true),
                "c": .ausgeliehen(bis: nil), "d": .online
            ]
        )
        #expect(anzeige.imRegal == 2)
        #expect(anzeige.beschriftung == "Merkliste, 2 im Regal")
    }

    @Test func merklisteKreisOhneEintraegeNurDasLesezeichen() {
        let anzeige = UhrMerklisteWidgetAnzeige.erstelle(eintraege: [], staende: [:])
        #expect(anzeige.imRegal == nil)
        #expect(anzeige.beschriftung == "Merkliste, leer")
    }

    @Test func merklisteKreisZaehltGefundeneNichtMit() {
        var gefunden = eintrag("a")
        gefunden.foundAt = .now
        let anzeige = UhrMerklisteWidgetAnzeige.erstelle(
            eintraege: [gefunden, eintrag("b")],
            staende: ["a": .regal(standort: "X", signatur: "S", nurVorOrt: false), "b": .regal(standort: "Y", signatur: "S", nurVorOrt: false)]
        )
        #expect(anzeige.imRegal == 1)
    }

    @Test func merklisteWirdAusDerAppGroupGelesen() {
        let suite = "UhrWidgetsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(UhrMerklisteWidgetAnzeige.gespeichert(defaults: defaults).imRegal == nil)

        defaults.set([eintrag("a").kontext, eintrag("b").kontext], forKey: UhrSpeicher.eintraege)
        defaults.set(
            try? JSONEncoder().encode(["a": UhrRegalStand.regal(standort: "60 ELT", signatur: "S", nurVorOrt: false)]),
            forKey: UhrSpeicher.staende
        )
        #expect(UhrMerklisteWidgetAnzeige.gespeichert(defaults: defaults).imRegal == 1)
    }

    @Test func einstellungenWerdenAusDerAppGroupGelesenSonstVorgabe() {
        let suite = "UhrWidgetsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(UhrSpeicher.einstellungen(defaults: defaults) == .vorgabe)
        let gespeichert = UhrEinstellungen(mensa: .nanoteria, preisgruppe: .gaeste)
        defaults.set(gespeichert.kontext, forKey: UhrEinstellungen.speicherSchluessel)
        #expect(UhrSpeicher.einstellungen(defaults: defaults) == gespeichert)
    }

    @Test func dieWidgetNamenSindEindeutigUndGetrenntVomIPhone() {
        #expect(Set(UhrWidgetKinds.alle).count == 3)
        #expect(Set(UhrWidgetKinds.alle).isDisjoint(with: WidgetKinds.alle))
    }
}
