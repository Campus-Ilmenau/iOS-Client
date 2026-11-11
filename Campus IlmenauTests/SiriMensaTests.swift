import Testing
import Foundation
import AppIntents
@testable import Campus_Ilmenau

// Die gesprochenen Sätze und Karten von „Mensa heute“, „Mensa offen?“ und „Abendessen“.
// Die Daten sind der Normalfall aus dem Mockup (`Siri.dc.html`): Donnerstag, 29. Oktober 2026 (Berlin), Freitag der 30.,
// Samstag der 31., Montag der 2. November.

// MARK: - Fixtures

private func zeit(_ tag: String, _ uhr: String) -> Date {
    let datum = tag.split(separator: "-").compactMap { Int($0) }
    let teile = uhr.split(separator: ":").compactMap { Int($0) }
    return EventKalender.kalender.date(from: DateComponents(
        year: datum[0], month: datum[1], day: datum[2], hour: teile[0], minute: teile[1]
    ))!
}

private let vegan = WidgetChip(titel: "Vegan", art: .gruen)
private let vegetarisch = WidgetChip(titel: "Vegetarisch", art: .neutral)
private let bio = WidgetChip(titel: "Bio", art: .gruen)
private let regional = WidgetChip(titel: "Regional", art: .blau)

private func gericht(
    _ name: String, abend: Bool = false, chips: [WidgetChip] = [], preis: Double = 2.9, allergene: [String] = []
) -> WidgetGericht {
    WidgetGericht(
        id: "id-\(name)", name: name, gruppe: abend ? "Abendessen" : "Mittag", abendessen: abend,
        preisStudierende: preis, preisBedienstete: preis + 1, preisGaeste: nil, waehrung: "EUR", chips: chips,
        allergene: allergene
    )
}

private func mensa(
    _ venue: MensaVenue, von: String, bis: String, heute: String, plan: [WidgetGericht], naechster: String, morgen: [WidgetGericht]
) -> WidgetMensa {
    WidgetMensa(
        id: venue.rawValue, name: venue.displayName, kurzname: venue.shortName,
        oeffnungszeiten: ["mon", "tue", "wed", "thu", "fri"].map { WidgetOeffnung(wochentag: $0, oeffnet: von, schliesst: bis) },
        heute: WidgetSpeiseplan(tag: heute, gerichte: plan),
        naechsterOeffnungstag: WidgetSpeiseplan(tag: naechster, gerichte: morgen)
    )
}

/// Normalfall: Mittag in allen Mensen, Abendessen in der Cafeteria Ehrenberg. Zeiten wie im Mockup (Cafeteria Ehrenberg
/// 11–14, Nanoteria 8–15, Röntgenbau 10:30–14).
private func daten(
    heute: String = "2026-10-29", naechster: String = "2026-10-30", heuteLeer: Bool = false, abendHeute: Bool = true,
    abendOhneVegetarisches: Bool = false
) -> WidgetSnapshot {
    func plan(_ liste: [WidgetGericht]) -> [WidgetGericht] { heuteLeer ? [] : liste }
    let abend = abendHeute ? [
        gericht("Flammkuchen mit Lauch und Speck", abend: true, preis: 3.2),
        gericht(abendOhneVegetarisches ? "Burger" : "Gemüse-Bowl mit Erdnusssoße", abend: true, chips: abendOhneVegetarisches ? [] : [vegan], preis: 3.0),
        gericht(abendOhneVegetarisches ? "Currywurst" : "Ofenkartoffel mit Quark", abend: true, chips: abendOhneVegetarisches ? [] : [vegetarisch], preis: 2.5)
    ] : []
    return WidgetSnapshot(mensen: [
        mensa(.mensaEhrenberg, von: "11:00", bis: "14:00", heute: heute, plan: plan([
            gericht("Linsen-Dal mit Basmatireis", chips: [vegan, bio, regional]),
            gericht("Hähnchenschnitzel, Kartoffelsalat", preis: 3.8),
            gericht("Pasta Arrabbiata", chips: [vegan], preis: 2.6),
            gericht("Gulasch", preis: 3.9),
            gericht("Quarkkeulchen", chips: [vegetarisch], preis: 2.7),
            gericht("Salatteller", chips: [vegan], preis: 2.4, allergene: ["Milch und Milchzucker"])
        ]), naechster: naechster, morgen: [
            gericht("Linsen-Dal mit Basmatireis", chips: [vegan]), gericht("Lasagne"), gericht("Falafel", chips: [vegan])
        ]),
        mensa(.cafeteriaEhrenberg, von: "11:00", bis: "14:00", heute: heute, plan: plan([gericht("Baguette")] + abend),
              naechster: naechster, morgen: [gericht("Abendbrot", abend: true)]),
        mensa(.nanoteria, von: "08:00", bis: "15:00", heute: heute, plan: plan([gericht("Curry"), gericht("Spätzle")]),
              naechster: naechster, morgen: [gericht("Kartoffel")]),
        mensa(.roentgenbau, von: "10:30", bis: "14:00", heute: heute, plan: plan([gericht("Couscous")]),
              naechster: naechster, morgen: [gericht("Tomatensuppe")])
    ])
}

private let standard = SiriMensaEinstellungen()

private func heute(
    _ uhr: String, tag: String = "2026-10-29", mensa: MensaOrt? = nil, ernaehrung: Ernaehrung? = nil, filterAnwenden: Bool = true,
    daten snapshot: WidgetSnapshot? = nil, einstellungen: SiriMensaEinstellungen = standard
) -> SiriMensaErgebnis {
    SiriMensa.heute(
        SiriMensaFrage(mensa: mensa, ernaehrung: ernaehrung, filterAnwenden: filterAnwenden),
        snapshot: snapshot ?? daten(), einstellungen: einstellungen, jetzt: zeit(tag, uhr)
    )
}

/// Die Antwort, wenn keine Rückfrage kommt.
private func antwort(
    _ uhr: String, tag: String = "2026-10-29", mensa: MensaOrt? = nil, ernaehrung: Ernaehrung? = nil, filterAnwenden: Bool = true,
    daten snapshot: WidgetSnapshot? = nil, einstellungen: SiriMensaEinstellungen = standard
) throws -> SiriMensaAntwort {
    guard case .antwort(let antwort) = heute(
        uhr, tag: tag, mensa: mensa, ernaehrung: ernaehrung, filterAnwenden: filterAnwenden, daten: snapshot, einstellungen: einstellungen
    ) else {
        Issue.record("Rückfrage statt Antwort")
        throw CancellationError()
    }
    return antwort
}

// MARK: - Mensa heute: Phasen

struct SiriMensaPhasenTests {
    @Test func vorMittagIstEineVorschau() throws {
        let a = try antwort("08:15")
        #expect(a.sagt == "Heute Mittag gibt es ab 11 Uhr in Ehrenberg Linsen-Dal für 2,90 €, Hähnchenschnitzel und Pasta Arrabbiata.")
        #expect(a.karte?.kicker == "Heute ab 11:00")
    }

    @Test func mittagWieImMockup() throws {
        let a = try antwort("11:45")
        #expect(a.sagt == "Zum Mittag gibt es in Ehrenberg Linsen-Dal für 2,90 €, Hähnchenschnitzel und Pasta Arrabbiata. Geöffnet bis 14 Uhr.")
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Geöffnet bis 14:00")
        #expect(karte.titel == "Mensa Ehrenberg")
        #expect(karte.filterzeile == nil)
        #expect(karte.gerichte.count == 3)
        #expect(karte.gerichte.first?.preis == "2,90\u{00A0}€")
        #expect(karte.fuss == "+3 weitere Gerichte")
        #expect(karte.kopfLink == DeepLink.mensa(id: "mensaEhrenberg").url)
        #expect(karte.gerichte.first?.link == DeepLink.gericht(id: "id-Linsen-Dal mit Basmatireis", tag: "2026-10-29").url)
    }

    @Test func nachmittagsIstEsDasAbendessen() throws {
        let a = try antwort("15:10")
        #expect(a.sagt == "Zum Abendessen gibt es ab 16:30 Uhr in der Cafeteria Ehrenberg Flammkuchen für 3,20 €, Gemüse-Bowl und Ofenkartoffel.")
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Abendessen · ab 16:30")
        #expect(karte.titel == "Cafeteria Ehrenberg")
        #expect(karte.fuss == "Abendangebot")
        #expect(karte.kopfLink == DeepLink.mensa(id: "cafeteriaEhrenberg").url)
    }

    @Test func abendsLaeuftDasAbendessen() throws {
        let a = try antwort("17:40")
        #expect(a.sagt == "Zum Abendessen gibt es bis 19:30 Uhr in der Cafeteria Ehrenberg Flammkuchen für 3,20 €, Gemüse-Bowl und Ofenkartoffel.")
        #expect(a.karte?.kicker == "Abendessen · bis 19:30")
    }

    @Test func nachDemAbendessenGehtEsUmMorgenMittag() throws {
        let a = try antwort("20:15")
        #expect(a.sagt == "Heute gibt es nichts mehr. Morgen Mittag gibt es ab 11 Uhr in Ehrenberg Linsen-Dal für 2,90 €, Lasagne und Falafel.")
        #expect(a.karte?.kicker == "Mittag morgen · ab 11:00")
    }

    /// Nach der Schließzeit ohne Abendessen liest Siri nicht den Mittagsplan von heute vor.
    @Test func ohneAbendessenHeuteGiltNachmittagsWieNachtsDerNaechsteTag() throws {
        let a = try antwort("15:10", daten: daten(abendHeute: false))
        #expect(a.sagt.hasPrefix("Heute gibt es nichts mehr. Morgen Mittag gibt es ab 11 Uhr in Ehrenberg"))
        #expect(a.karte?.kicker == "Mittag morgen · ab 11:00")
    }

    @Test func amWochenendeGiltDerMontag() throws {
        let a = try antwort("10:00", tag: "2026-10-31", daten: daten(heute: "2026-10-31", naechster: "2026-11-02", heuteLeer: true))
        #expect(a.sagt == "Ehrenberg hat heute zu. Montag Mittag gibt es ab 11 Uhr in Ehrenberg Linsen-Dal für 2,90 €, Lasagne und Falafel.")
        #expect(a.karte?.kicker == "Mittag Montag · ab 11:00")
        #expect(a.karte?.titel == "Mensa Ehrenberg")
    }

    @Test func einGenanntesZielGewinntGegenDieStartseite() throws {
        let a = try antwort("11:45", mensa: .nanoteria)
        #expect(a.sagt == "Zum Mittag gibt es in der Nanoteria Curry für 2,90 € und Spätzle. Geöffnet bis 15 Uhr.")
        #expect(a.karte?.titel == "Cafeteria Nanoteria")
    }

    @Test func dieStartseiteBestimmtDieMensaOhneAngabe() throws {
        var einstellungen = standard
        einstellungen.startseite = .roentgenbau
        let a = try antwort("11:45", einstellungen: einstellungen)
        #expect(a.sagt == "Zum Mittag gibt es in der Cafeteria Röntgenbau Couscous für 2,90 €. Geöffnet bis 14 Uhr.")
    }

    @Test func preiseGeltenFuerDieEigenePreisgruppe() throws {
        var einstellungen = standard
        einstellungen.preisgruppe = .bedienstete
        let a = try antwort("11:45", einstellungen: einstellungen)
        #expect(a.sagt.contains("Linsen-Dal für 3,90 €"))
    }
}

// MARK: - Mensa heute: kein Plan

struct SiriMensaKeinPlanTests {
    @Test func ohneHeutigenPlan() throws {
        let a = try antwort("11:45", daten: daten(heute: "2026-10-28"))
        #expect(a.sagt == "Für heute ist der Speiseplan noch nicht da.")
        #expect(a.karte == nil)
    }

    @Test func ohneIrgendeineDatenlage() throws {
        let a = try antwort("11:45", daten: WidgetSnapshot())
        #expect(a.sagt == "Ich komme gerade nicht an den Speiseplan. Versuch es gleich noch mal.")
        #expect(a.karte == nil)
    }
}

// MARK: - Mensa heute: Filter und Ernährung

struct SiriMensaFilterTests {
    private var veganOhneMilch: SiriMensaEinstellungen {
        var einstellungen = standard
        einstellungen.appFilter = MensaFilter(diet: .vegan, excludedAllergens: ["Milch und Milchzucker"])
        return einstellungen
    }

    @Test func derAppFilterWirdGenanntUndAufDerKarteGezeigt() throws {
        let a = try antwort("11:45", einstellungen: veganOhneMilch)
        #expect(a.sagt == "Zum Mittag passen in Ehrenberg zwei Gerichte zu deinem Filter: Linsen-Dal für 2,90 € und Pasta Arrabbiata. Geöffnet bis 14 Uhr.")
        let karte = try #require(a.karte)
        #expect(karte.filterzeile == "Gefiltert: Vegan · ohne Milch und Milchzucker")
        #expect(karte.fuss == "6 Gerichte ohne Filter")
        #expect(karte.gerichte.count == 2)
    }

    @Test func ohneSchalterGiltDerAppFilterNicht() throws {
        let a = try antwort("11:45", filterAnwenden: false, einstellungen: veganOhneMilch)
        #expect(a.sagt == "Zum Mittag gibt es in Ehrenberg Linsen-Dal für 2,90 €, Hähnchenschnitzel und Pasta Arrabbiata. Geöffnet bis 14 Uhr.")
        #expect(a.karte?.filterzeile == nil)
    }

    @Test func passtNichtsNenntSiriDieZahlOhneFilter() throws {
        var einstellungen = standard
        einstellungen.appFilter = MensaFilter(diet: .vegan)
        let a = try antwort("11:45", mensa: .nanoteria, einstellungen: einstellungen)
        #expect(a.sagt == "Zum Mittag passt heute nichts zu deinem Filter. Ohne Filter gibt es 2 Gerichte.")
        #expect(a.karte?.filterzeile == "Gefiltert: Vegan")
        #expect(a.karte?.fuss == "2 Gerichte ohne Filter")
        #expect(a.karte?.gerichte.isEmpty == true)
    }

    @Test func dieErnaehrungAusDerFrageErsetztDieStufeDesAppFilters() throws {
        var einstellungen = standard
        einstellungen.appFilter = MensaFilter(diet: .vegan)
        // „Vegetarisch“ lässt auch Veganes durch: 3 vegane und 1 vegetarisches Gericht.
        let a = try antwort("11:45", ernaehrung: .vegetarisch, einstellungen: einstellungen)
        #expect(a.sagt == "Zum Mittag gibt es in Ehrenberg 4 vegetarische Gerichte, zum Beispiel Linsen-Dal für 2,90 €, Pasta Arrabbiata und Quarkkeulchen. Geöffnet bis 14 Uhr.")
        #expect(a.karte?.filterzeile == "Vegetarisch – aus deiner Frage")
        #expect(a.karte?.fuss == "Ohne Filter: 6 Gerichte")
    }

    /// Das Wort gilt nur für diese Antwort: weder die Einstellungen noch der gespeicherte Filter ändern sich.
    @Test func dieErnaehrungAusDerFrageGiltNurFuerDieseAntwort() throws {
        let defaults = try #require(UserDefaults(suiteName: "SiriMensaTests-\(UUID().uuidString)"))
        MensaFilterStore.save(MensaFilter(diet: .vegan), defaults: defaults)
        let einstellungen = SiriMensaEinstellungen.lesen(defaults: defaults)

        _ = try antwort("11:45", ernaehrung: .vegetarisch, einstellungen: einstellungen)
        #expect(MensaFilterStore.load(defaults: defaults) == MensaFilter(diet: .vegan))
        #expect(einstellungen.appFilter == MensaFilter(diet: .vegan))

        // Die nächste Frage ohne Wort gilt wieder mit dem Filter der App.
        let danach = try antwort("11:45", einstellungen: einstellungen)
        #expect(danach.sagt.hasPrefix("Zum Mittag passen in Ehrenberg drei Gerichte zu deinem Filter"))
    }

    @Test func nurBioUndAllergeneAusDerAppGeltenMitDerErnaehrungWeiterUndSiriSagtSie() throws {
        var einstellungen = standard
        einstellungen.appFilter = MensaFilter(onlyBio: true)
        let a = try antwort("11:45", ernaehrung: .vegan, einstellungen: einstellungen)
        #expect(a.sagt == "Zum Mittag gibt es in Ehrenberg ein veganes Gericht, nur Bio: Linsen-Dal für 2,90 €. Geöffnet bis 14 Uhr.")
        #expect(a.karte?.filterzeile == "Vegan – aus deiner Frage · Nur Bio")
        #expect(a.karte?.fuss == "Ohne Filter: 6 Gerichte")
    }

    @Test func ohneSchalterZaehltNurDieErnaehrungAusDerFrage() throws {
        var einstellungen = standard
        einstellungen.appFilter = MensaFilter(onlyBio: true)
        let a = try antwort("11:45", ernaehrung: .vegan, filterAnwenden: false, einstellungen: einstellungen)
        #expect(a.sagt.hasPrefix("Zum Mittag gibt es in Ehrenberg drei vegane Gerichte"))
        #expect(!a.sagt.contains("nur Bio"))
    }

    @Test func vegetarischAbendsWieImMockup() throws {
        let a = try antwort("17:40", ernaehrung: .vegetarisch)
        #expect(a.sagt == "Zum Abendessen gibt es bis 19:30 Uhr in der Cafeteria Ehrenberg zwei vegetarische Gerichte: Gemüse-Bowl für 3,00 € und Ofenkartoffel.")
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Abendessen · bis 19:30")
        #expect(karte.filterzeile == "Vegetarisch – aus deiner Frage")
        #expect(karte.fuss == "Ohne Filter: 3 Gerichte")
    }

    @Test func vegetarischNichtsPasstDannDieNaechsteMahlzeitMitPassendem() throws {
        let a = try antwort("17:40", ernaehrung: .vegetarisch, daten: daten(abendOhneVegetarisches: true))
        #expect(a.sagt == "Zum Abendessen gibt es heute nichts Vegetarisches. Morgen Mittag in Ehrenberg: Linsen-Dal und Falafel.")
        // Die Karte zeigt diese nächste Mahlzeit.
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Mittag morgen · ab 11:00")
        #expect(karte.filterzeile == "Vegetarisch – aus deiner Frage")
        #expect(karte.gerichte.map(\.name) == ["Linsen-Dal mit Basmatireis", "Falafel"])
    }

    @Test func mittagsOhnePassendesKommtAbendessenHeute() throws {
        // Röntgenbau mittags: Couscous ist nicht vegan. Später heute hat die Cafeteria Ehrenberg Veganes.
        let a = try antwort("11:45", mensa: .roentgenbau, ernaehrung: .vegan)
        #expect(a.sagt == "Zum Mittag gibt es heute nichts Veganes. Heute Abend in der Cafeteria Ehrenberg: Gemüse-Bowl.")
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Abendessen · ab 16:30")
        #expect(karte.titel == "Cafeteria Ehrenberg")
    }

    @Test func passtAuchSpaeterNichtsBleibtDieKarteBeiDerErstenMahlzeit() throws {
        var snapshot = daten()
        snapshot.mensen[1].heute?.gerichte.removeAll { $0.abendessen && $0.chips.contains(vegan) }
        snapshot.mensen[1].naechsterOeffnungstag?.gerichte = []
        snapshot.mensen[3].naechsterOeffnungstag?.gerichte = [gericht("Couscous")]
        let a = try antwort("11:45", mensa: .roentgenbau, ernaehrung: .vegan, daten: snapshot)
        #expect(a.sagt == "Zum Mittag gibt es heute nichts Veganes.")
        #expect(a.karte?.gerichte.isEmpty == true)
        #expect(a.karte?.fuss == "Ohne Filter: 1 Gericht")
    }
}

// MARK: - Mensa heute: „Cafeteria“ ohne Ort

struct SiriCafeteriaTests {
    @Test func mittagsMitMehrerenOffenenFragtSiriNach() {
        let ergebnis = heute("11:45", mensa: .cafeteria)
        #expect(ergebnis == .rueckfrage(SiriCafeteriaRueckfrage(optionen: [
            .init(ort: .cafeteriaEhrenberg, status: "offen bis 14:00"),
            .init(ort: .nanoteria, status: "offen bis 15:00"),
            .init(ort: .roentgenbau, status: "offen bis 14:00")
        ])))
    }

    @Test func mitNurEinerOffenenKeineRueckfrage() throws {
        // 14:30: Ehrenberg und Röntgenbau haben zu, nur die Nanoteria hat offen.
        let a = try antwort("14:30", mensa: .cafeteria)
        #expect(a.sagt == "Zum Mittag gibt es in der Nanoteria Curry für 2,90 € und Spätzle. Geöffnet bis 15 Uhr.")
    }

    @Test func nachmittagsIstEsDieMitAbendessen() throws {
        let a = try antwort("15:10", mensa: .cafeteria)
        #expect(a.sagt == "Zum Abendessen gibt es ab 16:30 Uhr in der Cafeteria Ehrenberg Flammkuchen für 3,20 €, Gemüse-Bowl und Ofenkartoffel.")
    }

    @Test func abendsAuchOhneRueckfrage() throws {
        let a = try antwort("17:40", mensa: .cafeteria)
        #expect(a.sagt.hasPrefix("Zum Abendessen gibt es bis 19:30 Uhr in der Cafeteria Ehrenberg"))
    }

    @Test func hatKeineOffenNenntSiriDieNaechsteDieOeffnet() throws {
        let a = try antwort(
            "10:00", tag: "2026-10-31", mensa: .cafeteria, daten: daten(heute: "2026-10-31", naechster: "2026-11-02", heuteLeer: true)
        )
        #expect(a.sagt == "Heute haben die Cafeterien zu. Montag Mittag gibt es ab 8 Uhr in der Nanoteria Kartoffel für 2,90 €.")
        #expect(a.karte?.titel == "Cafeteria Nanoteria")
    }

    @Test func abendsNachDemAbendessenOeffnetMorgenDieNanoteria() throws {
        let a = try antwort("20:15", mensa: .cafeteria)
        #expect(a.sagt == "Heute haben die Cafeterien zu. Morgen Mittag gibt es ab 8 Uhr in der Nanoteria Kartoffel für 2,90 €.")
    }

    @Test func dieAntwortNenntImmerNamenUndMahlzeit() throws {
        for uhr in ["14:30", "15:10", "17:40"] {
            let a = try antwort(uhr, mensa: .cafeteria)
            #expect(a.sagt.contains("in der "), "\(uhr)")
            #expect(a.sagt.hasPrefix("Zum "), "\(uhr)")
        }
    }

    @Test func eineGenannteCafeteriaFragtNichtNach() throws {
        let a = try antwort("11:45", mensa: .roentgenbau)
        #expect(a.sagt.hasPrefix("Zum Mittag gibt es in der Cafeteria Röntgenbau"))
    }
}

// MARK: - Mensa offen?

private func offen(
    _ uhr: String, tag: String = "2026-10-29", mensa: MensaOrt? = nil, daten snapshot: WidgetSnapshot? = nil
) -> SiriOffenAntwort {
    SiriOffen.antwort(mensa: mensa, snapshot: snapshot ?? daten(), einstellungen: standard, jetzt: zeit(tag, uhr))
}

struct SiriOffenTests {
    @Test func geschlossenWieImMockup() throws {
        let a = offen("14:35")
        #expect(a.sagt == "Ehrenberg hat seit 14 Uhr zu. Die Nanoteria hat noch 25 Minuten offen, bis 15 Uhr.")
        let karte = try #require(a.karte)
        #expect(karte.gross == "Nein, seit 14:00 zu")
        #expect(karte.klein == "Mensa Ehrenberg · die Nanoteria hat noch offen.")
        #expect(karte.link == DeepLink.mensaZeiten.url)
        // Offene zuerst, dann Abendessen heute, dann der Rest in der Reihenfolge der App.
        #expect(karte.zeilen.map(\.name) == ["Cafeteria Nanoteria", "Cafeteria Ehrenberg", "Mensa Ehrenberg", "Cafeteria Röntgenbau"])
        #expect(karte.zeilen.map(\.stat) == ["bis 15:00", "Abendessen ab 16:30", "zu · morgen 11:00", "zu · morgen 10:30"])
        #expect(karte.zeilen.map(\.offen) == [true, false, false, false])
        #expect(karte.zeilen.map(\.chip) == ["noch 25 Min.", nil, nil, nil])
    }

    @Test func offenMitRestzeit() throws {
        let a = offen("11:45")
        #expect(a.sagt == "Ja, Ehrenberg hat bis 14 Uhr offen.")
        #expect(a.karte?.gross == "Ja, bis 14:00")
        #expect(a.karte?.zeilen.allSatisfy { $0.chip == nil } == true)

        let bald = offen("13:30")
        #expect(bald.sagt == "Ja, Ehrenberg hat noch 30 Minuten offen, bis 14 Uhr.")
        #expect(bald.karte?.zeilen.first { $0.name == "Mensa Ehrenberg" }?.chip == "noch 30 Min.")
    }

    @Test func vorDerOeffnung() {
        let a = offen("08:15")
        #expect(a.sagt == "Ehrenberg öffnet um 11 Uhr. Die Nanoteria hat bis 15 Uhr offen.")
        #expect(a.karte?.gross == "Öffnet um 11:00")
    }

    @Test func eineGenannteMensa() {
        let a = offen("14:35", mensa: .nanoteria)
        #expect(a.sagt == "Ja, die Nanoteria hat noch 25 Minuten offen, bis 15 Uhr.")
    }

    @Test func amWochenendeHabenAlleZu() {
        let a = offen("10:00", tag: "2026-10-31", daten: daten(heute: "2026-10-31", naechster: "2026-11-02", heuteLeer: true))
        #expect(a.sagt == "Heute haben alle Mensen zu. Montag ab 11 Uhr.")
        #expect(a.karte?.gross == "Heute zu")
    }

    @Test func hatKeineMensaMehrOffenNenntSiriDenNaechstenTag() {
        let a = offen("16:00")
        #expect(a.sagt == "Ehrenberg hat seit 14 Uhr zu. Heute hat keine Mensa mehr offen. Morgen ab 11 Uhr.")
    }

    @Test func ohneDatenKeineKarte() {
        let a = offen("14:35", daten: WidgetSnapshot())
        #expect(a.sagt == "Ich komme gerade nicht an die Öffnungszeiten. Versuch es gleich noch mal.")
        #expect(a.karte == nil)
    }

    // „Hat die Cafeteria offen?“: keine Rückfrage, die Antwort gilt für die Cafeterien zusammen.
    @Test func cafeteriaFasstDieCafeterienZusammen() throws {
        let a = offen("13:15", mensa: .cafeteria)
        #expect(a.sagt == "Ja, die Nanoteria hat bis 15 Uhr offen, Ehrenberg und Röntgenbau bis 14 Uhr.")
        let karte = try #require(a.karte)
        #expect(karte.gross == "Ja, bis 15:00")
        #expect(karte.zeilen.count == 4)
    }

    @Test func cafeteriaMitGleicherSchliesszeit() {
        var snapshot = daten()
        snapshot.mensen[2].oeffnungszeiten = ["thu"].map { WidgetOeffnung(wochentag: $0, oeffnet: "08:00", schliesst: "14:00") }
        let a = offen("13:15", mensa: .cafeteria, daten: snapshot)
        #expect(a.sagt == "Ja, Ehrenberg, die Nanoteria und Röntgenbau haben bis 14 Uhr offen.")
    }

    @Test func cafeteriaNachmittagsMitAbendessenEntscheidetKeineRueckfrage() {
        let a = offen("15:10", mensa: .cafeteria)
        #expect(a.sagt == "Die Cafeterien haben zu. Das Abendessen gibt es ab 16:30 Uhr in der Cafeteria Ehrenberg.")
    }

    @Test func cafeteriaAmWochenende() {
        let a = offen("10:00", tag: "2026-10-31", mensa: .cafeteria, daten: daten(heute: "2026-10-31", naechster: "2026-11-02", heuteLeer: true))
        #expect(a.sagt == "Heute haben alle Mensen zu. Montag ab 8 Uhr.")
    }
}

// MARK: - Abendessen

private func abendessen(_ uhr: String, tag: String = "2026-10-29", daten snapshot: WidgetSnapshot? = nil) -> SiriMensaAntwort {
    SiriAbendessen.antwort(snapshot: snapshot ?? daten(), einstellungen: standard, jetzt: zeit(tag, uhr))
}

struct SiriAbendessenTests {
    @Test func nachmittagsKommtEs() throws {
        let a = abendessen("15:10")
        #expect(a.sagt == "Ja. Zum Abendessen gibt es ab 16:30 Uhr in der Cafeteria Ehrenberg Flammkuchen für 3,20 €, Gemüse-Bowl und Ofenkartoffel.")
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Abendessen · 16:30–19:30")
        #expect(karte.titel == "Cafeteria Ehrenberg")
        #expect(karte.fuss == "Abendangebot")
        #expect(karte.gerichte.count == 3)
    }

    @Test func abendsLaeuftEs() {
        let a = abendessen("17:40")
        #expect(a.sagt == "Ja, noch bis 19:30 Uhr gibt es zum Abendessen in der Cafeteria Ehrenberg Flammkuchen für 3,20 €, Gemüse-Bowl und Ofenkartoffel.")
    }

    @Test func nachDemAbendessenZeigtDieKarteMorgen() throws {
        let a = abendessen("20:15")
        #expect(a.sagt == "Das Abendessen ist für heute vorbei. Morgen ab 16:30 in der Cafeteria Ehrenberg.")
        let karte = try #require(a.karte)
        #expect(karte.kicker == "Abendessen morgen · 16:30–19:30")
        #expect(karte.gerichte.map(\.name) == ["Abendbrot"])
        #expect(karte.gerichte.first?.link == DeepLink.gericht(id: "id-Abendbrot", tag: "2026-10-30").url)
    }

    @Test func freitagsGibtEsKeins() throws {
        let a = abendessen("12:00", tag: "2026-10-30", daten: daten(heute: "2026-10-30", naechster: "2026-11-02", abendHeute: false))
        #expect(a.sagt == "Heute gibt es kein Abendessen. Das nächste ist am Montag ab 16:30.")
        #expect(a.karte?.kicker == "Abendessen Montag · 16:30–19:30")
    }

    @Test func keinAbendessenHeuteUndMorgen() {
        let a = abendessen("12:00", daten: daten(abendHeute: false))
        #expect(a.sagt == "Heute gibt es kein Abendessen. Das nächste ist morgen ab 16:30.")
    }

    @Test func ohnePlanOderDaten() {
        #expect(abendessen("12:00", daten: daten(heute: "2026-10-28")).sagt == "Für heute ist der Speiseplan noch nicht da.")
        #expect(abendessen("12:00", daten: WidgetSnapshot()).sagt == "Ich komme gerade nicht an den Speiseplan. Versuch es gleich noch mal.")
    }
}

// MARK: - Sprache und Intents

struct SiriSpracheTests {
    @Test func namenWerdenFuerDieSpracheGekuerzt() {
        #expect(SiriSprache.kurz("Linsen-Dal mit Basmatireis") == "Linsen-Dal")
        #expect(SiriSprache.kurz("Hähnchenschnitzel, Kartoffelsalat") == "Hähnchenschnitzel")
        #expect(SiriSprache.kurz("Pasta Arrabbiata") == "Pasta Arrabbiata")
        #expect(SiriSprache.kurz("Mit Liebe gekocht") == "Mit Liebe gekocht")
    }

    @Test func uhrzeitenUndAufzaehlungen() {
        #expect(SiriSprache.uhr(840) == "14 Uhr")
        #expect(SiriSprache.uhr(990) == "16:30 Uhr")
        #expect(SiriSprache.aufzaehlung(["a"]) == "a")
        #expect(SiriSprache.aufzaehlung(["a", "b"]) == "a und b")
        #expect(SiriSprache.aufzaehlung(["a", "b", "c"]) == "a, b und c")
    }

    @Test func nurBeimErstenGerichtStehtDerPreis() {
        let karte = (try? antwort("11:45"))?.karte
        let satz = SiriSprache.gerichte(karte?.gerichte ?? [])
        #expect(satz.components(separatedBy: "€").count == 2)
    }
}

struct SiriMensaIntentTests {
    @Test func dieIntentsLaufenOhneDieAppZuOeffnen() {
        #expect(!MensaHeuteIntent.openAppWhenRun)
        #expect(!MensaOffenIntent.openAppWhenRun)
        #expect(!AbendessenIntent.openAppWhenRun)
    }

    @Test func filterAnwendenIstStandardmaessigAn() {
        #expect(MensaHeuteIntent().filterAnwenden)
    }
}
