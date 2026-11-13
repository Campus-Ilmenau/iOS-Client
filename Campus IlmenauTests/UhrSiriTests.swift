import Testing
import Foundation
import AppIntents
@testable import Campus_Ilmenau

// Siri auf der Uhr: Sätze und Karten-Daten je Intent mit fester Uhrzeit (Donnerstag, 29. Oktober 2026, Berlin), die
// Ziele von „In der App öffnen“, der Thoska-Hinweis, die Merkliste mit und ohne Gefundene und die Meldungen an Siri.
// Die Sätze selbst rechnet `Shared/` (dasselbe wie auf dem iPhone, getestet in `SiriMensaTests` usw.); hier steht, was die
// Uhr daraus macht und dass die Texte aus dem Artboard `WatchSiri.dc.html` herauskommen.

// MARK: - Fixtures

private func zeit(_ uhr: String, tag: String = "2026-10-29") -> Date { MensaWidgetVorschau.zeit(tag, uhr) }

private let vegan = WidgetChip(titel: "Vegan", art: .gruen)
private let vegetarisch = WidgetChip(titel: "Vegetarisch", art: .neutral)

private func gericht(_ name: String, abend: Bool = false, chips: [WidgetChip] = [], preis: Double = 2.9) -> WidgetGericht {
    WidgetGericht(
        id: "id-\(name)", name: name, gruppe: abend ? "Abendessen" : "Mittag", abendessen: abend,
        preisStudierende: preis, preisBedienstete: preis + 1.6, preisGaeste: preis + 2.9, waehrung: "EUR", chips: chips, allergene: []
    )
}

private func mensa(_ venue: MensaVenue, von: String, bis: String, plan: [WidgetGericht], morgen: [WidgetGericht]) -> WidgetMensa {
    WidgetMensa(
        id: venue.rawValue, name: venue.displayName, kurzname: venue.shortName,
        oeffnungszeiten: ["mon", "tue", "wed", "thu", "fri"].map { WidgetOeffnung(wochentag: $0, oeffnet: von, schliesst: bis) },
        heute: WidgetSpeiseplan(tag: "2026-10-29", gerichte: plan),
        naechsterOeffnungstag: WidgetSpeiseplan(tag: "2026-10-30", gerichte: morgen)
    )
}

/// Normalfall aus dem Mockup: Mittag in allen Mensen, Abendessen in der Cafeteria Ehrenberg (11–14 Uhr), Nanoteria 8–15,
/// Röntgenbau 10:30–14.
private let plan = WidgetSnapshot(mensen: [
    mensa(.mensaEhrenberg, von: "11:00", bis: "14:00", plan: [
        gericht("Linsen-Dal mit Basmatireis", chips: [vegan]), gericht("Hähnchenschnitzel, Kartoffelsalat", preis: 3.8),
        gericht("Pasta Arrabbiata", chips: [vegan], preis: 2.6), gericht("Gulasch", preis: 3.9),
        gericht("Quarkkeulchen", chips: [vegetarisch], preis: 2.7), gericht("Salatteller", chips: [vegan], preis: 2.4)
    ], morgen: [gericht("Linsen-Dal mit Basmatireis"), gericht("Lasagne")]),
    mensa(.cafeteriaEhrenberg, von: "11:00", bis: "14:00", plan: [
        gericht("Baguette"),
        gericht("Flammkuchen mit Lauch und Speck", abend: true, preis: 3.2),
        gericht("Gemüse-Bowl mit Erdnusssoße", abend: true, chips: [vegan], preis: 3.0),
        gericht("Ofenkartoffel mit Quark", abend: true, chips: [vegetarisch], preis: 2.5)
    ], morgen: [gericht("Abendbrot", abend: true)]),
    mensa(.nanoteria, von: "08:00", bis: "15:00", plan: [gericht("Käsespätzle mit Röstzwiebeln"), gericht("Curry")], morgen: [gericht("Kartoffel")]),
    mensa(.roentgenbau, von: "10:30", bis: "14:00", plan: [gericht("Couscous")], morgen: [gericht("Tomatensuppe")])
])

private func mensaHeute(
    _ uhr: String, mensa: MensaOrt? = nil, ernaehrung: Ernaehrung? = nil, einstellungen: UhrEinstellungen = .vorgabe
) throws -> SiriMensaAntwort {
    let ergebnis = SiriMensa.heute(
        SiriMensaFrage(mensa: mensa, ernaehrung: ernaehrung), snapshot: plan,
        einstellungen: UhrSiri.mensaEinstellungen(einstellungen), jetzt: zeit(uhr)
    )
    guard case .antwort(let antwort) = ergebnis else {
        Issue.record("Rückfrage statt Antwort")
        throw CancellationError()
    }
    return antwort
}

private func url(_ text: String) -> URL { URL(string: text)! }

/// Die Mensa, die die Mensa-Ansicht der Watch-App zu dieser Uhrzeit zeigt (mit „Andere Mensa“ von heute).
private func gezeigt(_ uhr: String, einstellungen: UhrEinstellungen = .vorgabe, andere: AndereMensa? = nil) -> MensaVenue {
    UhrSiri.gezeigteMensa(snapshot: plan, einstellungen: einstellungen, andere: andere, jetzt: zeit(uhr))
}

private func mensaLink(_ venue: MensaVenue, waehlen: Bool) -> URL {
    url("campusilmenau://mensa?mensa=\(venue.rawValue)" + (waehlen ? "&waehlen=1" : ""))
}

// MARK: - Mensa heute

struct UhrSiriMensaTests {
    /// „Mensa heute“, Tweak „Mensa heute“ (11:45): Satz, Kicker, drei Gerichte mit Kurzname und Preis, Fuß.
    @Test func mensaHeuteMittags() throws {
        let a = try mensaHeute("11:45")
        #expect(a.sagt == "Zum Mittag gibt es in Ehrenberg Linsen-Dal für 2,90 €, Hähnchenschnitzel und Pasta Arrabbiata. Geöffnet bis 14 Uhr.")
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Geöffnet bis 14:00")
        #expect(MensaVenue.mensaEhrenberg.shortName == "Ehrenberg")
        // Normale Kappung: drei Zeilen, der Rest steht im Fuß.
        let zeilen = UhrSiriGerichtZeile.zeilen(karte)
        #expect(zeilen.map(\.name) == ["Linsen-Dal", "Hähnchenschnitzel", "Pasta Arrabbiata"])
        #expect(zeilen.map(\.preis) == ["2,90 €", "3,80 €", "2,60 €"])
        #expect(karte.fuss == "+3 weitere Gerichte")
        // Die gewählte Mensa: kein Wählen nötig.
        #expect(UhrSiri.mensaZiel(karte, gezeigt: gezeigt("11:45")) == mensaLink(.mensaEhrenberg, waehlen: false))
    }

    /// Tweak „Vegetarisch abends“ (17:40): Ernährung aus der Frage, Zeile „Vegetarisch – aus deiner Frage“, Fuß „Ohne Filter“.
    @Test func vegetarischAbends() throws {
        let a = try mensaHeute("17:40", ernaehrung: .vegetarisch)
        #expect(a.sagt == "Zum Abendessen gibt es bis 19:30 Uhr in der Cafeteria Ehrenberg zwei vegetarische Gerichte: Gemüse-Bowl für 3,00 € und Ofenkartoffel.")
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Abendessen · bis 19:30")
        #expect(karte.titel == "Cafeteria Ehrenberg")
        #expect(karte.filterzeile == "Vegetarisch – aus deiner Frage")
        #expect(UhrSiriGerichtZeile.zeilen(karte).map(\.name) == ["Gemüse-Bowl", "Ofenkartoffel"])
        #expect(karte.fuss == "Ohne Filter: 3 Gerichte")
        // Die Antwort nennt die Cafeteria, gewählt ist die Mensa. Um 17:40 zeigt die Watch-App aber ohnehin die Cafeteria
        // (Phase Abendessen): Es wird nichts gewählt.
        #expect(gezeigt("17:40") == .cafeteriaEhrenberg)
        #expect(UhrSiri.mensaZiel(karte, gezeigt: gezeigt("17:40")) == mensaLink(.cafeteriaEhrenberg, waehlen: false))
    }

    /// Preise und Mensa kommen aus `UhrEinstellungen`, nicht aus der iPhone-App.
    @Test func einstellungenDerUhrGelten() throws {
        let einstellungen = UhrEinstellungen(mensa: .nanoteria, preisgruppe: .gaeste)
        let siri = UhrSiri.mensaEinstellungen(einstellungen)
        #expect(siri.startseite == .nanoteria)
        #expect(siri.preisgruppe == .gaeste)
        #expect(siri.appFilter == einstellungen.filter)

        let a = try mensaHeute("11:45", einstellungen: einstellungen)
        #expect(a.sagt.hasPrefix("Zum Mittag gibt es in der Nanoteria Käsespätzle für 5,80 €"), "Gästepreis 2,90 + 2,90")
        #expect(UhrSiri.mensaZiel(a.karte, gezeigt: gezeigt("11:45", einstellungen: einstellungen)) == mensaLink(.nanoteria, waehlen: false))
    }

    /// Eine genannte Mensa, die nicht die gewählte ist, wählt „In der App öffnen“ bis Mitternacht.
    @Test func eineAndereGenannteMensaWirdGewaehlt() throws {
        let a = try mensaHeute("11:45", mensa: .nanoteria)
        let karte = try #require(a.karte)
        #expect(karte.titel == "Cafeteria Nanoteria")
        #expect(UhrSiri.mensaZiel(karte, gezeigt: gezeigt("11:45")) == mensaLink(.nanoteria, waehlen: true))
    }

    /// Hat die Uhr die Nanoteria als „Andere Mensa“ gewählt, zeigt die Ansicht sie schon: nichts zu wählen. Die Wahl gilt
    /// nur bis Mitternacht; am nächsten Tag zeigt die Ansicht wieder die Mensa vom iPhone.
    @Test func eineAndereMensaAufDerUhrZaehltBisMitternacht() throws {
        let andere = AndereMensa(mensa: .nanoteria, jetzt: zeit("11:00"))
        #expect(gezeigt("11:45", andere: andere) == .nanoteria)
        let a = try mensaHeute("11:45", mensa: .nanoteria)
        #expect(UhrSiri.mensaZiel(a.karte, gezeigt: gezeigt("11:45", andere: andere)) == mensaLink(.nanoteria, waehlen: false))

        let amNaechstenTag = AndereMensa(mensa: .nanoteria, jetzt: zeit("11:00", tag: "2026-10-28"))
        #expect(gezeigt("11:45", andere: amNaechstenTag) == .mensaEhrenberg, "Gestern gewählt: abgelaufen")
        #expect(UhrSiri.mensaZiel(a.karte, gezeigt: gezeigt("11:45", andere: amNaechstenTag)) == mensaLink(.nanoteria, waehlen: true))
    }

    @Test func ohneKarteBleibtDasZielDerSpeiseplan() {
        #expect(UhrSiri.mensaZiel(nil, gezeigt: .mensaEhrenberg) == url("campusilmenau://mensa"))
    }

    /// Ohne Daten: der Fehlersatz, keine Karte, wie auf dem iPhone.
    @Test func ohneDatenKommtDerFehlersatz() {
        let ergebnis = SiriMensa.heute(
            SiriMensaFrage(), snapshot: WidgetSnapshot(), einstellungen: UhrSiri.mensaEinstellungen(.vorgabe), jetzt: zeit("11:45")
        )
        #expect(ergebnis == .antwort(SiriMensaAntwort(sagt: "Ich komme gerade nicht an den Speiseplan. Versuch es gleich noch mal.", karte: nil)))
    }

    /// „Cafeteria“ mittags: mehrere offen, das System fragt nach, mit kurzen Namen ohne Untertitel (Sprache und Tippen).
    @Test func cafeteriaFragtNachMitKurzenNamen() throws {
        let ergebnis = SiriMensa.heute(
            SiriMensaFrage(mensa: .cafeteria), snapshot: plan, einstellungen: UhrSiri.mensaEinstellungen(.vorgabe), jetzt: zeit("11:45")
        )
        guard case .rueckfrage(let rueckfrage) = ergebnis else {
            Issue.record("Keine Rückfrage")
            return
        }
        #expect(rueckfrage.optionen.map(\.ort) == [.cafeteriaEhrenberg, .nanoteria, .roentgenbau])
        // Was das System vorliest und zeichnet: nur der Titel, nie ein Untertitel.
        for ort in MensaOrt.allCases {
            let darstellung = try #require(MensaOrt.caseDisplayRepresentations[ort])
            #expect(darstellung.subtitle == nil, "\(ort)")
        }
        let titel = MensaOrt.allCases.compactMap { MensaOrt.caseDisplayRepresentations[$0] }.map { String(localized: $0.title) }
        #expect(titel == ["Mensa Ehrenberg", "Cafeteria Ehrenberg", "Nanoteria", "Röntgenbau", "Cafeteria"])
    }
}

// MARK: - Mensa offen?

struct UhrSiriOffenTests {
    private func offen(_ uhr: String, mensa: MensaOrt? = nil, gewaehlt: MensaVenue = .mensaEhrenberg) -> (SiriOffenAntwort, URL) {
        let einstellungen = UhrEinstellungen(mensa: gewaehlt)
        let antwort = SiriOffen.antwort(
            mensa: mensa, snapshot: plan, einstellungen: UhrSiri.mensaEinstellungen(einstellungen), jetzt: zeit(uhr)
        )
        let ziel = UhrSiri.offenZiel(
            antwort.karte, mensa: mensa, startseite: gewaehlt, gezeigt: gezeigt(uhr, einstellungen: einstellungen)
        )
        return (antwort, ziel)
    }

    /// Tweak „Mensa offen?“ (14:35): Ehrenberg hat zu, die Nanoteria noch 25 Minuten. „In der App öffnen“ wählt sie.
    @Test func ehrenbergHatZuDieNanoteriaNoch() throws {
        let (a, ziel) = offen("14:35")
        #expect(a.sagt == "Ehrenberg hat seit 14 Uhr zu. Die Nanoteria hat noch 25 Minuten offen, bis 15 Uhr.")
        let karte = try #require(a.karte)
        #expect(karte.gross == "Nein, seit 14:00 zu")
        #expect(karte.zeilen.map(\.name) == ["Cafeteria Nanoteria", "Cafeteria Ehrenberg", "Mensa Ehrenberg", "Cafeteria Röntgenbau"])
        #expect(karte.zeilen.first?.chip == "noch 25 Min.")
        #expect(karte.zeilen.first?.stat == "bis 15:00")
        #expect(karte.zeilen.map(\.offen) == [true, false, false, false])
        #expect(ziel == mensaLink(.nanoteria, waehlen: true))
    }

    /// Hat die gewählte Mensa offen, gilt sie: nichts zu wählen.
    @Test func hatDieGewaehlteOffenWirdNichtGewaehlt() throws {
        let (a, ziel) = offen("11:45")
        #expect(a.karte?.gross == "Ja, bis 14:00")
        #expect(ziel == mensaLink(.mensaEhrenberg, waehlen: false))
    }

    @Test func eineGenannteMensaWirdGewaehlt() {
        let (_, ziel) = offen("11:45", mensa: .roentgenbau)
        #expect(ziel == mensaLink(.roentgenbau, waehlen: true))
    }

    /// „Cafeteria“ meint nur die Cafeterien, auch wenn die Mensa die erste offene ist.
    @Test func cafeteriaMeintNurCafeterien() {
        let (_, ziel) = offen("11:45", mensa: .cafeteria)
        #expect(ziel == mensaLink(.cafeteriaEhrenberg, waehlen: true))
    }

    /// Hat gar keine offen: der Speiseplan der gewählten, nichts wird gewählt.
    @Test func hatKeineOffenWirdNichtsGewaehlt() {
        let (_, ziel) = offen("21:00")
        #expect(ziel == url("campusilmenau://mensa/zeiten"))
    }
}

// MARK: - Abendessen

struct UhrSiriAbendessenTests {
    /// Tweak „Abendessen“ (15:10).
    @Test func abendessenNachmittags() throws {
        let einstellungen = UhrSiri.mensaEinstellungen(.vorgabe)
        let a = SiriAbendessen.antwort(snapshot: plan, einstellungen: einstellungen, jetzt: zeit("15:10"))
        #expect(a.sagt == "Ja. Zum Abendessen gibt es ab 16:30 Uhr in der Cafeteria Ehrenberg Flammkuchen für 3,20 €, Gemüse-Bowl und Ofenkartoffel.")
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Abendessen · 16:30–19:30")
        #expect(karte.titel == "Cafeteria Ehrenberg")
        #expect(UhrSiriGerichtZeile.zeilen(karte).map(\.name) == ["Flammkuchen", "Gemüse-Bowl", "Ofenkartoffel"])
        #expect(UhrSiriGerichtZeile.zeilen(karte).map(\.preis) == ["3,20 €", "3,00 €", "2,50 €"])
        // Um 15:10 hat Ehrenberg zu: Die Watch-App zeigt schon das Abendessen in der Cafeteria. Nichts wählen.
        #expect(gezeigt("15:10") == .cafeteriaEhrenberg)
        #expect(UhrSiri.mensaZiel(karte, gezeigt: gezeigt("15:10")) == mensaLink(.cafeteriaEhrenberg, waehlen: false))
    }

    /// Mittags zeigt die Watch-App die Mensa Ehrenberg, die Antwort nennt die Cafeteria: Sie wird gewählt.
    @Test func abendessenMittagsWaehltDieCafeteria() throws {
        let a = SiriAbendessen.antwort(snapshot: plan, einstellungen: UhrSiri.mensaEinstellungen(.vorgabe), jetzt: zeit("12:00"))
        let karte = try #require(a.karte)
        #expect(gezeigt("12:00") == .mensaEhrenberg)
        #expect(UhrSiri.mensaZiel(karte, gezeigt: gezeigt("12:00")) == mensaLink(.cafeteriaEhrenberg, waehlen: true))
    }

    @Test func abendessenVorbei() {
        let a = SiriAbendessen.antwort(snapshot: plan, einstellungen: UhrSiri.mensaEinstellungen(.vorgabe), jetzt: zeit("20:15"))
        #expect(a.sagt.hasPrefix("Das Abendessen ist für heute vorbei."))
    }
}

// MARK: - Heute Abend

struct UhrSiriAbendTests {
    private func event(_ id: String, _ titel: String, von: Double, bis: Double, ort: String, abgesagt: Bool = false) -> WidgetEvent {
        WidgetEvent(
            id: id, titel: titel, beginn: AbendWidgetVorschau.zeit(von), ende: AbendWidgetVorschau.zeit(bis),
            ganztaegig: false, ort: ort, veranstalter: nil, abgesagt: abgesagt
        )
    }

    private var daten: WidgetSnapshot {
        WidgetSnapshot(events: [
            event("spiel", "Spieleabend", von: 19, bis: 23, ort: "Studi-Club"),
            event("quiz", "Kneipenquiz", von: 20, bis: 23, ort: "Baracke5", abgesagt: true),
            event("stage", "Open Stage", von: 21, bis: 25, ort: "BC-Club"),
            event("karaoke", "Karaoke-Nacht", von: 22, bis: 26, ort: "Baracke5")
        ], gemerkteEventIDs: ["stage"], stand: AbendWidgetVorschau.zeit(12))
    }

    /// Tweak „Heute Abend“ (19:40): Läuft gerade, Open Stage mit Stern, die Absage am Ende; Fuß „+1 weitere heute“.
    @Test func heuteAbendUm1940() throws {
        let a = SiriAbend.antwort(snapshot: daten, jetzt: AbendWidgetVorschau.zeit(19 + 40.0 / 60))
        // Derselbe Satz wie auf dem iPhone (`SiriAbendTests`). Das Artboard der Uhr kürzt ihn („Um 21 Uhr Open Stage … Karaoke-Nacht –
        // Baracke5“); gesprochen gilt der aus `Shared/`.
        #expect(a.sagt == "Gerade läuft Spieleabend im Studi-Club. Um 21 Uhr ist Open Stage im BC-Club, um 22 Uhr Karaoke-Nacht in der Baracke5. Kneipenquiz fällt aus.")
        let karte = try #require(a.karte)
        #expect(karte.titel == "Heute Abend")
        #expect(karte.datum == "Do 29. Okt.")
        #expect(karte.zeilen.count == 3, "Höchstens 3 Zeilen")
        #expect(karte.zeilen.map(\.titel) == ["Spieleabend", "Kneipenquiz", "Open Stage"])
        #expect(karte.zeilen.map(\.laeuft) == [true, false, false])
        #expect(karte.zeilen.map(\.abgesagt) == [false, true, false])
        #expect(karte.zeilen.map(\.gemerkt) == [false, false, true])
        #expect(karte.zeilen[2].zeit == "21:00")
        #expect(karte.fuss == "+1 weitere heute")
        #expect(UhrSiri.abendZiel(karte) == url("campusilmenau://events?filter=heute-abend"))
    }

    @Test func ohneKarteFuehrtDasZielZurListe() {
        #expect(UhrSiri.abendZiel(nil) == url("campusilmenau://events?filter=heute-abend"))
    }

    @Test func ohneDatenKommtDerFehlersatz() {
        let a = SiriAbend.antwort(snapshot: WidgetSnapshot(), jetzt: AbendWidgetVorschau.zeit(19))
        #expect(a.sagt == "Ich komme gerade nicht an die Veranstaltungen. Versuch es gleich noch mal.")
        #expect(a.karte == nil)
    }
}

// MARK: - Thoska

struct UhrSiriThoskaTests {
    /// Der Satz steht in `Siri.xcstrings` (Tabelle „Siri“), nicht im Code: gesprochen, ohne Ansicht, ohne Guthaben, wie beim
    /// HomePod. Vorerst nur Deutsch, die englische Fassung kommt nach den Tests am Gerät.
    @Test func derHinweisStehtInDerSiriTabelle() throws {
        let tabelle = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("SiriShared/Siri.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: tabelle)) as? [String: Any]
        let texte = try #require(json?["strings"] as? [String: Any])
        let satz = "Das geht nur auf dem iPhone. Öffne dort Campus Ilmenau."
        #expect(texte[satz] != nil)
        #expect(!satz.contains("€"))
        #expect(!satz.lowercased().contains("guthaben"))
    }
}

// MARK: - Merkliste

struct UhrSiriMerklisteTests {
    private func eintrag(_ id: String, _ titel: String, gefunden: Bool = false) -> UhrMerklisteEintrag {
        UhrMerklisteEintrag(
            id: id, titel: titel, foundAt: gefunden ? Date(timeIntervalSinceReferenceDate: 800_000_000) : nil,
            changedAt: Date(timeIntervalSinceReferenceDate: 790_000_000)
        )
    }

    private let staende: [String: UhrRegalStand] = [
        "med_1": .regal(standort: "60 ELT", signatur: "ELT ZQ 5200", nurVorOrt: false),
        "med_2": .regal(standort: "60 ELT", signatur: "ELT ZN 4000", nurVorOrt: true),
        "med_3": .regal(standort: "70 MB", signatur: "MB UF 1000", nurVorOrt: false),
        "med_4": .ausgeliehen(bis: nil),
        "med_5": .regal(standort: "60 ELT", signatur: "ELT ZA 1", nurVorOrt: false)
    ]

    private func antwort(gefunden: Bool) -> SiriMerklisteAntwort {
        let liste = [
            eintrag("med_1", "A"), eintrag("med_2", "B"), eintrag("med_3", "C"), eintrag("med_4", "D"),
            eintrag("med_5", "E", gefunden: gefunden)
        ].filter { gefunden || $0.id != "med_5" }
        return SiriMerkliste.antwort(UhrSiri.merklisteEintraege(liste, staende: staende))
    }

    /// Tweak „Merkliste“ ohne Gefundene: Standorte, ausgeliehen; Fuß nur „Nicht im Regal“.
    @Test func ohneGefundene() throws {
        let a = antwort(gefunden: false)
        #expect(a.sagt == "Drei Titel stehen im Regal: zwei im Bereich 60 ELT, einer in 70 MB. Einer ist ausgeliehen.")
        let karte = try #require(a.karte)
        #expect(karte.titel == "3 Titel im Regal")
        #expect(karte.standorte.map(\.name) == ["60 ELT", "70 MB"])
        #expect(karte.standorte.map(\.anzahl) == [2, 1])
        #expect(karte.fuss == "Nicht im Regal: 1")
        #expect(UhrSiri.merklisteZiel == url("campusilmenau://bibliothek/merkliste"))
    }

    /// Mit Gefundenen: Fuß „Nicht im Regal: n · Gefunden: n“, gesprochen kommen sie ans Ende.
    @Test func mitGefundenen() throws {
        let a = antwort(gefunden: true)
        #expect(a.sagt == "Drei Titel stehen im Regal: zwei im Bereich 60 ELT, einer in 70 MB. Einer ist ausgeliehen. Einen hast du schon gefunden.")
        let karte = try #require(a.karte)
        #expect(karte.titel == "3 Titel im Regal", "Gefundene zählen nicht mehr „im Regal“")
        #expect(karte.fuss == "Nicht im Regal: 1 · Gefunden: 1")
    }

    @Test func derStandWirdOhneNeuLadenAusDerGruppeGelesen() throws {
        let suite = "uhr-siri-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        // Leer: der Satz der Merkliste.
        #expect(UhrSiri.merkliste(defaults: defaults) == SiriMerkliste.leer)

        let liste = [eintrag("med_1", "A"), eintrag("med_3", "C"), eintrag("med_2", "B", gefunden: true)]
        defaults.set(liste.map(\.kontext), forKey: UhrSpeicher.eintraege)
        defaults.set(try JSONEncoder().encode(staende), forKey: UhrSpeicher.staende)
        let a = UhrSiri.merkliste(defaults: defaults)
        #expect(a.sagt == "Zwei Titel stehen im Regal: einer im Bereich 60 ELT, einer in 70 MB. Einen hast du schon gefunden.")
        #expect(a.karte?.fuss == "Gefunden: 1")
    }

    @Test func ohneStandKenntSiriDenStandortNicht() {
        let a = SiriMerkliste.antwort(UhrSiri.merklisteEintraege([eintrag("med_1", "A"), eintrag("med_2", "B")], staende: [:]))
        #expect(a.sagt == "Auf deiner Merkliste stehen 2 Titel. Den Stand im Regal kenne ich gerade nicht.")
        #expect(a.karte == nil)
    }

    @Test func leereMerklisteHatIhrenSatz() {
        let a = SiriMerkliste.antwort(UhrSiri.merklisteEintraege([], staende: [:]))
        #expect(a.sagt == "Deine Merkliste ist leer. Titel merkst du dir im Katalog.")
    }
}

// MARK: - Meldungen an Siri

@MainActor
@Suite(.serialized)
struct UhrSiriMeldungTests {
    init() { UhrEingang.trenne() }

    private func melder() -> (SiriMelder, Gesammelt) {
        let gesammelt = Gesammelt()
        return (SiriMelder(abgeben: { gesammelt.liste.append($0) }), gesammelt)
    }

    @MainActor final class Gesammelt { var liste: [SiriMeldung] = [] }

    @Test func einmalProAnsichtUndOeffnen() async {
        let (melder, gesammelt) = melder()
        #expect(melder.melde(.merkliste, in: .merkliste, vonAussen: false))
        #expect(!melder.melde(.merkliste, in: .merkliste, vonAussen: false), "Nicht bei jedem Neuladen")
        melder.neueOeffnung(.merkliste)
        #expect(melder.melde(.merkliste, in: .merkliste, vonAussen: false), "Neu geöffnet: wieder eine Meldung")
        await melder.warteAufAbgaben()
        #expect(gesammelt.liste == [.merkliste, .merkliste])
    }

    @Test func mensaOeffnenOderWechselnMeldetMitDerMensa() async {
        let (melder, gesammelt) = melder()
        melder.melde(.mensaHeute(mensa: MensaOrt(.mensaEhrenberg), ernaehrung: nil), in: .mensa, vonAussen: false)
        melder.melde(.mensaHeute(mensa: MensaOrt(.mensaEhrenberg), ernaehrung: nil), in: .mensa, vonAussen: false)
        melder.melde(.mensaHeute(mensa: MensaOrt(.nanoteria), ernaehrung: nil), in: .mensa, vonAussen: false)
        melder.melde(.abendessen, in: .mensaAbendessen, vonAussen: false)
        melder.melde(.heuteAbend, in: .events, vonAussen: false)
        await melder.warteAufAbgaben()
        #expect(gesammelt.liste == [
            .mensaHeute(mensa: .mensaEhrenberg, ernaehrung: nil), .mensaHeute(mensa: .nanoteria, ernaehrung: nil),
            .abendessen, .heuteAbend
        ])
    }

    @Test func nichtsVonAussenMelden() async {
        let (melder, gesammelt) = melder()
        #expect(!melder.melde(.heuteAbend, in: .events, vonAussen: true))
        await melder.warteAufAbgaben()
        #expect(gesammelt.liste.isEmpty)
    }

    /// Von außen heißt: Die Ansicht erscheint höchstens 3 s nach einem Link (Komplikation, Smart Stack) oder dem Button
    /// unter einer Siri-Antwort.
    @Test func dasFensterVonAussenSindDreiSekunden() {
        let t = Date(timeIntervalSinceReferenceDate: 800_000_000)
        #expect(!UhrEingang.kamGeradeVonAussen(jetzt: t), "Vorher kam nichts")
        UhrEingang.vermerke(jetzt: t)
        #expect(UhrEingang.kamGeradeVonAussen(jetzt: t.addingTimeInterval(2.9)))
        #expect(UhrEingang.kamGeradeVonAussen(jetzt: t.addingTimeInterval(3)))
        #expect(!UhrEingang.kamGeradeVonAussen(jetzt: t.addingTimeInterval(3.1)))
    }

    /// Das Ziel eines Intents wartet, bis die Ansicht da ist, und kommt mit `waehlen=1` an.
    @Test func einZielWartetAufDieAnsichtUndBehaeltWaehlen() {
        let ziel = mensaLink(.nanoteria, waehlen: true)
        UhrEingang.melde(ziel)
        var angekommen: [URL] = []
        UhrEingang.verbinde { angekommen.append($0) }
        #expect(angekommen == [ziel])
        UhrEingang.melde(url("campusilmenau://bibliothek/merkliste"))
        #expect(angekommen.count == 2)
        #expect(UhrMensaLink.gewaehlteMensa(angekommen[0]) == .nanoteria)
    }
}
