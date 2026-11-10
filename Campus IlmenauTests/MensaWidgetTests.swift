import Testing
import Foundation
@testable import Campus_Ilmenau

// MARK: - Fixtures

/// Donnerstag, 29. Oktober 2026 (Berlin), Freitag der 30., Samstag der 31., Montag der 2. November.
private func zeit(_ tag: String, _ uhr: String) -> Date {
    let datum = tag.split(separator: "-").compactMap { Int($0) }
    let teile = uhr.split(separator: ":").compactMap { Int($0) }
    return EventKalender.kalender.date(from: DateComponents(
        year: datum[0], month: datum[1], day: datum[2], hour: teile[0], minute: teile[1]
    ))!
}

private func gericht(_ name: String, abend: Bool = false, chips: [WidgetChip] = [], preis: Double = 2.9) -> WidgetGericht {
    WidgetGericht(
        id: "id-\(name)", name: name, gruppe: abend ? "Abendessen" : "Mittag", abendessen: abend,
        preisStudierende: preis, preisBedienstete: preis + 1, preisGaeste: nil, waehrung: "EUR", chips: chips
    )
}

private func mensa(
    _ venue: MensaVenue, von: String, bis: String, heute: String, mittag: [WidgetGericht], abend: [WidgetGericht] = [],
    naechster: String, morgen: [WidgetGericht]
) -> WidgetMensa {
    WidgetMensa(
        id: venue.rawValue, name: venue.displayName, kurzname: venue.shortName,
        oeffnungszeiten: ["mon", "tue", "wed", "thu", "fri"].map { WidgetOeffnung(wochentag: $0, oeffnet: von, schliesst: bis) },
        heute: WidgetSpeiseplan(tag: heute, gerichte: mittag + abend),
        naechsterOeffnungstag: WidgetSpeiseplan(tag: naechster, gerichte: morgen)
    )
}

/// Normalfall wie im Mockup: Mittag in allen Mensen, Abendessen in der Cafeteria Ehrenberg.
private func snapshot(heute: String = "2026-10-29", naechster: String = "2026-10-30", heuteLeer: Bool = false) -> WidgetSnapshot {
    func plan(_ liste: [WidgetGericht]) -> [WidgetGericht] { heuteLeer ? [] : liste }
    return WidgetSnapshot(mensen: [
        mensa(.mensaEhrenberg, von: "11:00", bis: "14:00", heute: heute,
              mittag: plan([gericht("Linsen-Dal", chips: [WidgetChip(titel: "Vegan", art: .gruen)]), gericht("Schnitzel", preis: 3.8), gericht("Pasta")]),
              naechster: naechster, morgen: [gericht("Suppe"), gericht("Lasagne"), gericht("Falafel")]),
        mensa(.cafeteriaEhrenberg, von: "08:00", bis: "15:00", heute: heute, mittag: [],
              abend: plan([gericht("Flammkuchen", abend: true), gericht("Bowl", abend: true), gericht("Ofenkartoffel", abend: true)]),
              naechster: naechster, morgen: [gericht("Abendbrot", abend: true)]),
        mensa(.nanoteria, von: "08:00", bis: "15:00", heute: heute, mittag: plan([gericht("Curry"), gericht("Spätzle")]),
              naechster: naechster, morgen: [gericht("Kartoffel")]),
        mensa(.roentgenbau, von: "08:00", bis: "14:00", heute: heute, mittag: plan([gericht("Couscous")]),
              naechster: naechster, morgen: [gericht("Tomatensuppe")])
    ])
}

private func anzeige(
    _ uhr: String, tag: String = "2026-10-29", mensa: MensaVenue = .mensaEhrenberg,
    daten: WidgetSnapshot? = nil, gruppe: MensaPriceGroup = .studierende
) -> MensaWidgetAnzeige {
    MensaWidgetPhasen.anzeige(snapshot: daten ?? snapshot(), mensaID: mensa.rawValue, preisgruppe: gruppe, jetzt: zeit(tag, uhr))
}

// MARK: - Phasen

struct MensaWidgetPhasenTests {
    @Test func vorMittagVorschau() {
        let a = anzeige("08:15")
        #expect(a.phase == .morgen)
        #expect(a.kicker == "Heute ab 11:00")
        #expect(a.titel == "Mensa Ehrenberg")
        #expect(a.unterzeile == "Vorschau aufs Mittagsangebot")
        #expect(a.zeilen.map(\.name) == ["Linsen-Dal", "Schnitzel", "Pasta"])
        #expect(a.termine.map(\.text) == ["Öffnet · Ehrenberg", "Schließt · Ehrenberg"])
        #expect(a.termine.map(\.zeit) == ["11:00", "14:00"])
    }

    @Test func nanoteriaIstMorgensSchonOffen() {
        let a = anzeige("08:15", mensa: .nanoteria)
        #expect(a.kicker == "Geöffnet bis 15:00")
        #expect(a.termine.map(\.text) == ["Schließt · Nanoteria", "Abendessen · Ehrenberg"])
    }

    @Test func mittag() {
        let a = anzeige("11:45")
        #expect(a.phase == .mittag)
        #expect(a.kicker == "Geöffnet bis 14:00")
        #expect(a.unterzeile == "Mittagsangebot")
        #expect(a.zeilen.first?.preis == "2,90\u{00A0}€")
        #expect(a.zeilen.first?.chips == [WidgetChip(titel: "Vegan", art: .gruen)])
        #expect(a.termine == [.init(zeit: "14:00", text: "Schließt · Ehrenberg"), .init(zeit: "16:30", text: "Abendessen · Ehrenberg")])
    }

    @Test func nachmittagTippAbendessen() {
        // Nanoteria schließt um 15:00: danach der Tipp.
        let a = anzeige("15:10", mensa: .nanoteria)
        #expect(a.phase == .nachmittag)
        #expect(a.kicker == "Nanoteria hat geschlossen")
        #expect(a.titel == "Abendessen Ehrenberg")
        #expect(a.unterzeile == "Tipp · ab 16:30 in der Cafeteria")
        #expect(a.zeilen.map(\.name) == ["Flammkuchen", "Bowl", "Ofenkartoffel"])
        #expect(a.kopfLink == DeepLink.mensa(id: "cafeteriaEhrenberg").url)
        #expect(a.termine.first == .init(zeit: "16:30", text: "Abendessen · Ehrenberg"))
        #expect(a.termine.last == .init(zeit: "Fr", text: "Mittag · Nanoteria ab 08:00"))
    }

    @Test func nachmittagMensaEhrenbergHatDasAbendessenSelbst() {
        let a = anzeige("15:10")
        #expect(a.kicker == "Abendessen ab 16:30")
        #expect(a.titel == "Mensa Ehrenberg")
        #expect(a.unterzeile == "Abendangebot in der Cafeteria")
        #expect(a.termine == [.init(zeit: "16:30", text: "Abendessen öffnet"), .init(zeit: "19:30", text: "Schließt")])
    }

    @Test func abend() {
        let eigene = anzeige("17:40")
        #expect(eigene.phase == .abend)
        #expect(eigene.kicker == "Geöffnet bis 19:30")
        #expect(eigene.titel == "Mensa Ehrenberg")
        #expect(eigene.unterzeile == "Abendessen in der Cafeteria")
        #expect(eigene.termine == [.init(zeit: "19:30", text: "Schließt"), .init(zeit: "Fr", text: "Mittag ab 11:00")])

        let tipp = anzeige("17:40", mensa: .roentgenbau)
        #expect(tipp.kicker == "Röntgenbau hat geschlossen")
        #expect(tipp.titel == "Abendessen Ehrenberg")
        #expect(tipp.unterzeile == "Tipp · jetzt geöffnet bis 19:30")
    }

    @Test func nachtZeigtMittagMorgen() {
        let a = anzeige("21:30")
        #expect(a.phase == .nacht)
        #expect(a.kicker == "Mittag morgen · ab 11:00")
        #expect(a.titel == "Mensa Ehrenberg")
        #expect(a.unterzeile == "Freitag, 30. Oktober")
        #expect(a.zeilen.map(\.name) == ["Suppe", "Lasagne", "Falafel"])
        #expect(a.planTag == "2026-10-30")
        #expect(a.termine.map(\.zeit) == ["Fr", "Fr"])
        #expect(a.termine.first?.text == "Öffnet 11:00 · Ehrenberg")
    }

    @Test func freitagAbendZeigtDenMontag() {
        let daten = snapshot(heute: "2026-10-30", naechster: "2026-11-02")
        let a = anzeige("21:30", tag: "2026-10-30", daten: daten)
        #expect(a.kicker == "Mittag Montag · ab 11:00")
        #expect(a.unterzeile == "Montag, 2. November")
        #expect(a.planTag == "2026-11-02")
    }

    @Test func wochenendeZeigtDenNaechstenOeffnungstag() {
        let daten = snapshot(heute: "2026-10-31", naechster: "2026-11-02", heuteLeer: true)
        let a = anzeige("11:45", tag: "2026-10-31", daten: daten)
        #expect(a.phase == .geschlossen)
        #expect(a.kicker == "Heute geschlossen")
        #expect(a.unterzeile == "Montag ab 11:00")
        #expect(a.zeilen.map(\.name) == ["Suppe", "Lasagne", "Falafel"])
        #expect(a.termine.map(\.zeit) == ["Mo", "Mo"])
    }

    @Test func wochenendeAuchOhneGeladenenPlanVonHeute() {
        // Der Speicher kennt nur den Montag: Samstag hat keine Öffnungszeit, also zu.
        var daten = snapshot(heute: "2026-10-30", naechster: "2026-11-02")
        for index in daten.mensen.indices { daten.mensen[index].heute = nil }
        let a = anzeige("08:15", tag: "2026-10-31", daten: daten)
        #expect(a.phase == .geschlossen)
        #expect(a.planTag == "2026-11-02")
    }

    @Test func keinPlan() {
        let a = anzeige("11:45", daten: WidgetSnapshot())
        #expect(!a.hatPlan)
        #expect(a.zeilen.isEmpty)
        #expect(a.kopfLink == DeepLink.mensa(id: "mensaEhrenberg").url)
    }

    @Test func veralteterSpeicherGiltNichtAlsHeute() {
        // Der Speicher stammt von gestern: heute ist unbekannt, es gibt keinen Plan statt eines falschen.
        let daten = snapshot(heute: "2026-10-28", naechster: "2026-10-29")
        let a = anzeige("11:45", tag: "2026-10-30", daten: daten)
        #expect(!a.hatPlan)
    }

    @Test func umMitternachtGiltDerNaechsteTagAlsHeute() {
        // Der „nächste Öffnungstag“ von gestern ist heute der Plan von heute.
        let a = anzeige("08:15", tag: "2026-10-30", daten: snapshot())
        #expect(a.phase == .morgen)
        #expect(a.zeilen.map(\.name) == ["Suppe", "Lasagne", "Falafel"])
        #expect(a.planTag == "2026-10-30")
    }

    @Test func preiseNachPreisgruppe() {
        #expect(anzeige("11:45", gruppe: .studierende).zeilen.first?.preis == "2,90\u{00A0}€")
        #expect(anzeige("11:45", gruppe: .bedienstete).zeilen.first?.preis == "3,90\u{00A0}€")
        #expect(anzeige("11:45", gruppe: .gaeste).zeilen.first?.preis == "–")
    }
}

// MARK: - Links

struct MensaWidgetLinkTests {
    @Test func gerichtLinkTraegtDenTagDesGezeigtenPlans() throws {
        let heute = anzeige("11:45")
        let link = try #require(heute.zeilen.first?.link)
        #expect(DeepLink(url: link) == .gericht(id: "id-Linsen-Dal", tag: "2026-10-29"))

        let nacht = anzeige("21:30")
        #expect(DeepLink(url: try #require(nacht.zeilen.first?.link)) == .gericht(id: "id-Suppe", tag: "2026-10-30"))
    }

    @Test func amWochenendeFuehrtDerLinkAufDenMontag() throws {
        let daten = snapshot(heute: "2026-10-31", naechster: "2026-11-02", heuteLeer: true)
        let a = anzeige("11:45", tag: "2026-10-31", daten: daten)
        for zeile in a.zeilen {
            let link = DeepLink(url: zeile.link)
            #expect(link == .gericht(id: zeile.id, tag: "2026-11-02"))
        }
        #expect(a.kopfLink == DeepLink.mensa(id: "mensaEhrenberg").url)
    }
}

// MARK: - Zeitleiste

struct MensaWidgetZeitleisteTests {
    @Test func einEintragProPhasenwechsel() {
        let wechsel = MensaWidgetPhasen.wechsel(snapshot: snapshot(), mensaID: "mensaEhrenberg", nach: zeit("2026-10-29", "08:15"))
        #expect(wechsel == [zeit("2026-10-29", "10:30"), zeit("2026-10-29", "14:00"), zeit("2026-10-29", "16:30"),
                            zeit("2026-10-29", "19:30"), zeit("2026-10-30", "00:00")])
    }

    @Test func nanoteriaSchliesstUmFuenfzehnUhr() {
        let wechsel = MensaWidgetPhasen.wechsel(snapshot: snapshot(), mensaID: "nanoteria", nach: zeit("2026-10-29", "11:00"))
        #expect(wechsel.first == zeit("2026-10-29", "15:00"))
        #expect(wechsel.count == 4)
    }

    @Test func nurWasNochKommt() {
        let wechsel = MensaWidgetPhasen.wechsel(snapshot: snapshot(), mensaID: "mensaEhrenberg", nach: zeit("2026-10-29", "20:00"))
        #expect(wechsel == [zeit("2026-10-30", "00:00")])
    }

    @Test func neuladenAmNaechstenMorgenUmSechs() {
        #expect(MensaWidgetPhasen.naechsteNeuladung(nach: zeit("2026-10-29", "11:45")) == zeit("2026-10-30", "06:00"))
        #expect(MensaWidgetPhasen.naechsteNeuladung(nach: zeit("2026-10-29", "03:00")) == zeit("2026-10-29", "06:00"))
        #expect(MensaWidgetPhasen.naechsteNeuladung(nach: zeit("2026-10-29", "06:00")) == zeit("2026-10-30", "06:00"))
    }
}

// MARK: - Speicher pflegen

@MainActor
struct WidgetMensaPflegeTests {
    private func meal(_ name: String, mensa: String) -> MensaMeal {
        MensaMeal(
            id: "m-\(name)", category: "Mittag", name: name, description: nil,
            price: MensaMealPrice(student: 2.9, staff: 3.9, guest: 4.9, currency: "EUR"),
            allergies: [], badges: [], additives: [], categories: [], co2GramPerPortion: nil, components: [],
            canteenName: mensa, date: zeit("2026-10-29", "12:00")
        )
    }

    @Test func nurWochenendeDazwischen() {
        let donnerstag = zeit("2026-10-29", "12:00")
        #expect(WidgetMensaPflege.nurWochenendeDazwischen(heute: donnerstag, tag: zeit("2026-10-30", "00:00")))
        // Freitag liegt zwischen Donnerstag und Montag.
        #expect(!WidgetMensaPflege.nurWochenendeDazwischen(heute: donnerstag, tag: zeit("2026-11-02", "00:00")))
        let freitag = zeit("2026-10-30", "12:00")
        #expect(WidgetMensaPflege.nurWochenendeDazwischen(heute: freitag, tag: zeit("2026-11-02", "00:00")))
        #expect(!WidgetMensaPflege.nurWochenendeDazwischen(heute: freitag, tag: zeit("2026-11-03", "00:00")))
    }

    @Test func fruehererTagErsetztSpaeteren() {
        var daten = WidgetSnapshot()
        let jetzt = zeit("2026-10-29", "12:00")
        WidgetMensaPflege.uebernehmeNaechsten(
            [meal("Montag", mensa: "Mensa Ehrenberg")], tag: zeit("2026-11-02", "12:00"), jetzt: jetzt, verbuergt: false, in: &daten
        )
        // Ein nicht verbürgter früherer Tag darf den gemerkten nicht ersetzen …
        WidgetMensaPflege.uebernehmeNaechsten(
            [meal("Freitag", mensa: "Mensa Ehrenberg")], tag: zeit("2026-10-30", "12:00"), jetzt: jetzt, verbuergt: false, in: &daten
        )
        #expect(daten.mensa(id: "mensaEhrenberg")?.naechsterOeffnungstag?.tag == "2026-11-02")
        // … ein verbürgter schon.
        WidgetMensaPflege.uebernehmeNaechsten(
            [meal("Freitag", mensa: "Mensa Ehrenberg")], tag: zeit("2026-10-30", "12:00"), jetzt: jetzt, verbuergt: true, in: &daten
        )
        #expect(daten.mensa(id: "mensaEhrenberg")?.naechsterOeffnungstag?.tag == "2026-10-30")
    }

    @Test func tabSchreibtHeuteUndMorgenAberNichtUebermorgen() {
        let store = WidgetStore(dateiURL: FileManager.default.temporaryDirectory.appendingPathComponent("w-\(UUID().uuidString).json"))
        var gemeldet: [[String]] = []
        let sync = WidgetSync(store: store, neuLaden: { gemeldet.append($0) })
        let jetzt = zeit("2026-10-29", "12:00")

        sync.speichereSpeiseplan(tag: zeit("2026-10-29", "00:00"), speiseplan: [meal("Heute", mensa: "Mensa Ehrenberg")], jetzt: jetzt)
        sync.speichereSpeiseplan(tag: zeit("2026-10-31", "00:00"), speiseplan: [meal("Samstag", mensa: "Mensa Ehrenberg")], jetzt: jetzt)
        sync.speichereSpeiseplan(tag: zeit("2026-10-30", "00:00"), speiseplan: [meal("Morgen", mensa: "Mensa Ehrenberg")], jetzt: jetzt)

        let ehrenberg = store.lesen().mensa(id: "mensaEhrenberg")
        #expect(ehrenberg?.heute?.gerichte.map(\.name) == ["Heute"])
        #expect(ehrenberg?.naechsterOeffnungstag?.gerichte.map(\.name) == ["Morgen"])
        #expect(gemeldet.allSatisfy { $0 == [WidgetKinds.mensa] })
    }

    @Test func eventsAusDerListeNurBeiVollstaendigemTag() {
        let store = WidgetStore(dateiURL: FileManager.default.temporaryDirectory.appendingPathComponent("w-\(UUID().uuidString).json"))
        let sync = WidgetSync(store: store, neuLaden: { _ in })
        let jetzt = zeit("2026-10-29", "09:00")
        let abend = CampusEvent(id: "abend", titel: "Abend", beginn: zeit("2026-10-29", "20:00"))

        // Veranstalter-Filter: unvollständig, nichts wird geschrieben.
        sync.speichereEvents(aus: [abend], hatWeitere: false, filter: EventFilter(veranstalter: "bi-club"), jetzt: jetzt)
        #expect(store.lesen().events.isEmpty)

        // Liste „ab heute“ mit weiteren Seiten, die erst nach morgen weitergeht: heute und morgen sind vollständig.
        let spaeter = CampusEvent(id: "spaet", titel: "Später", beginn: zeit("2026-11-03", "20:00"))
        sync.speichereEvents(aus: [abend, spaeter], hatWeitere: true, filter: .abHeute, jetzt: jetzt)
        #expect(store.lesen().events.map(\.id) == ["abend"])

        // Die Liste hört noch heute auf und hat weitere Seiten: kein Tag ist sicher vollständig, der Speicher bleibt.
        let ende = CampusEvent(id: "ende", titel: "Ende", beginn: zeit("2026-10-29", "21:00"))
        sync.speichereEvents(aus: [ende], hatWeitere: true, filter: .abHeute, jetzt: jetzt)
        #expect(store.lesen().events.map(\.id) == ["abend"])
    }
}

// MARK: - Wechsel-Knopf

struct MensaWechselTests {
    @Test func schaltetEineMensaWeiterUndDannVonVorn() {
        let reihenfolge = MensaVenue.allCases
        #expect(reihenfolge.count == 4)
        for (index, venue) in reihenfolge.enumerated() {
            #expect(venue.naechste == reihenfolge[(index + 1) % reihenfolge.count])
        }
        #expect(MensaVenue.roentgenbau.naechste == .mensaEhrenberg)
    }

    @Test func vierSchritteFuehrenZurueck() {
        var venue = MensaVenue.nanoteria
        for _ in 0..<4 { venue = venue.naechste }
        #expect(venue == .nanoteria)
    }
}

// MARK: - Filter aus der App

private func filterGericht(_ name: String, chips: [WidgetChip] = [], allergene: [String] = []) -> WidgetGericht {
    var g = gericht(name, chips: chips)
    g.allergene = allergene
    return g
}

private func filterDaten() -> WidgetSnapshot {
    var daten = snapshot()
    let vegan = [WidgetChip(titel: "Vegan", art: .gruen)]
    daten.mensen[0].heute?.gerichte = [
        filterGericht("Linsen-Dal", chips: vegan),
        filterGericht("Schnitzel", allergene: ["Milch und Milchzucker"]),
        filterGericht("Pasta", chips: vegan, allergene: ["Milch und Milchzucker"])
    ]
    daten.mensen[1].heute?.gerichte = [
        filterGericht("Flammkuchen", allergene: ["Weizen"]).abend(), filterGericht("Bowl", chips: vegan).abend()
    ]
    daten.mensen[0].naechsterOeffnungstag?.gerichte = [filterGericht("Suppe", chips: vegan), filterGericht("Lasagne")]
    return daten
}

private extension WidgetGericht {
    func abend() -> WidgetGericht { var kopie = self; kopie.abendessen = true; kopie.gruppe = "Abendessen"; return kopie }
}

private func gefiltert(_ uhr: String, _ filter: MensaFilter?, tag: String = "2026-10-29", mensa: MensaVenue = .mensaEhrenberg) -> MensaWidgetAnzeige {
    MensaWidgetPhasen.anzeige(snapshot: filterDaten(), mensaID: mensa.rawValue, preisgruppe: .studierende, jetzt: zeit(tag, uhr), filter: filter)
}

struct MensaWidgetFilterTests {
    let veganOhneMilch = MensaFilter(diet: .vegan, excludedAllergens: ["Milch und Milchzucker"])

    @Test func mittagZeigtNurPassendes() {
        let a = gefiltert("11:45", veganOhneMilch)
        #expect(a.zeilen.map(\.name) == ["Linsen-Dal"])
        #expect(a.filterung == .init(kurztext: "Vegan · ohne Milch und Milchzucker", ohneFilterAnzahl: 3))
        #expect(a.unterzeile == "Mittagsangebot · Vegan · ohne Milch und Milchzucker")
        #expect(!a.nichtsPasst)
    }

    @Test func abendessenUndNaechsterTagWerdenGefiltert() {
        let abend = gefiltert("17:40", MensaFilter(diet: .vegan))
        #expect(abend.zeilen.map(\.name) == ["Bowl"])
        let nacht = gefiltert("21:30", MensaFilter(diet: .vegan))
        #expect(nacht.zeilen.map(\.name) == ["Suppe"])
        #expect(nacht.filterung?.ohneFilterAnzahl == 2)
    }

    @Test func ohneFilterOderMitLeeremFilterBleibtAllesWieEs() {
        let ohne = gefiltert("11:45", nil)
        #expect(gefiltert("11:45", MensaFilter()) == ohne)
        #expect(ohne.zeilen.count == 3)
        #expect(ohne.filterung == nil)
    }

    @Test func nichtsPasst() {
        let a = gefiltert("11:45", MensaFilter(diet: .vegan, onlyBio: true))
        #expect(a.zeilen.isEmpty)
        #expect(a.nichtsPasst)
        #expect(a.filterung?.ohneFilterText == "3 Gerichte ohne Filter")
        #expect(a.kopfLink == DeepLink.mensa(id: MensaVenue.mensaEhrenberg.rawValue).url)
    }

    @Test func keinPlanIstNichtNichtsPasst() {
        let a = MensaWidgetPhasen.anzeige(
            snapshot: WidgetSnapshot(), mensaID: MensaVenue.mensaEhrenberg.rawValue, preisgruppe: .studierende,
            jetzt: zeit("2026-10-29", "11:45"), filter: MensaFilter(diet: .vegan)
        )
        #expect(!a.nichtsPasst)
        #expect(!a.hatPlan)
    }
}

// MARK: - Sperrbildschirm

private func sperre(
    _ uhr: String, tag: String = "2026-10-29", mensa: MensaVenue = .mensaEhrenberg,
    daten: WidgetSnapshot? = nil, filter: MensaFilter? = nil
) -> MensaSperreAnzeige {
    MensaSperrePhasen.anzeige(
        snapshot: daten ?? snapshot(), mensaID: mensa.rawValue, preisgruppe: .studierende, jetzt: zeit(tag, uhr), filter: filter
    )
}

/// Wie `snapshot()`, aber am Freitag: der nächste Öffnungstag ist der Montag.
private func freitagsDaten() -> WidgetSnapshot {
    snapshot(heute: "2026-10-30", naechster: "2026-11-02")
}

/// Ohne Abendessen: die Cafeteria hat heute nur ihre Öffnungszeiten.
private func ohneAbendessen() -> WidgetSnapshot {
    var daten = snapshot()
    daten.mensen[1].heute?.gerichte = []
    return daten
}

struct MensaSperrePhasenTests {
    @Test func vormittagsIstDieGewaehlteMensaVorschau() {
        let a = sperre("08:15")
        #expect(a.phase == .vorschau)
        #expect(a.kicker == "Ehrenberg · ab 11:00")
        #expect(a.zeitText == "ab 11:00")
        #expect((a.kreisGross, a.kreisKlein) == ("11:00", "öffnet"))
        #expect(a.mensaID == MensaVenue.mensaEhrenberg.rawValue)
    }

    @Test func mittagsBisZurSchliesszeit() {
        let a = sperre("11:45")
        #expect(a.phase == .mittag)
        #expect(a.kicker == "Ehrenberg · bis 14:00")
        #expect((a.kreisGross, a.kreisKlein) == ("14:00", "bis"))
        #expect(a.zeile.hasPrefix("bis 14:00 · "))
        #expect(["2,90", "3,80"].contains { a.gericht?.preis.hasPrefix($0) == true })
    }

    @Test func nachDerSchliesszeitIstNochOffenWasLaengerOffenHat() {
        let a = sperre("14:20")
        #expect(a.phase == .nochOffen)
        #expect(a.kicker == "Noch offen · Nanoteria")
        #expect((a.kreisGross, a.kreisKlein) == ("15:00", "Nanoteria"))
        #expect(a.zeitText == "Nanoteria bis 15:00")
        #expect(a.mensaID == MensaVenue.nanoteria.rawValue)
        #expect(["Curry", "Spätzle"].contains(a.gericht?.name ?? ""))
        // Die Cafeteria hat bis 15:00 offen, aber kein Mittag: sie zählt nicht.
        #expect(a.mensaID != MensaVenue.cafeteriaEhrenberg.rawValue)
    }

    @Test func nachDemLetztenMittagKommtDasAbendessenAb() {
        let a = sperre("15:40")
        #expect(a.phase == .abend)
        #expect(a.kicker == "Abendessen · ab 16:30")
        #expect((a.kreisGross, a.kreisKlein) == ("16:30", "Abend"))
        #expect(a.mensaID == MensaVenue.cafeteriaEhrenberg.rawValue)
    }

    @Test func abendessenGiltBisZumEndeUndUnabhaengigVonDerGewaehltenMensa() {
        for mensa in MensaVenue.allCases {
            let a = sperre("17:40", mensa: mensa)
            #expect(a.phase == .abend, "\(mensa)")
            #expect(a.kicker == "Abendessen · bis 19:30")
            #expect(a.mensaID == MensaVenue.cafeteriaEhrenberg.rawValue)
            #expect(["Flammkuchen", "Bowl", "Ofenkartoffel"].contains(a.gericht?.name ?? ""))
        }
        #expect((sperre("17:40").kreisGross, sperre("17:40").kreisKlein) == ("19:30", "bis"))
    }

    @Test func abendsIstMittagMorgen() {
        let a = sperre("21:30")
        #expect(a.phase == .naechsterTag)
        #expect(a.kicker == "Mittag morgen · Ehrenberg")
        #expect(a.zeitText == "morgen ab 11:00")
        #expect((a.kreisGross, a.kreisKlein) == ("Fr", "11:00"))
        #expect(["Suppe", "Lasagne", "Falafel"].contains(a.gericht?.name ?? ""))
        #expect(a.gericht?.link.absoluteString.contains("tag=2026-10-30") == true)
    }

    @Test func freitagsAbendsIstMittagMontag() {
        let a = sperre("21:30", tag: "2026-10-30", daten: freitagsDaten())
        #expect(a.phase == .naechsterTag)
        #expect(a.kicker == "Mittag Montag · Ehrenberg")
        #expect(a.zeitText == "Mo ab 11:00")
        #expect((a.kreisGross, a.kreisKlein) == ("Mo", "11:00"))
    }

    @Test func ohneAbendessenFolgtMittagMorgenGleichNachDemLetztenMittag() {
        let a = sperre("15:40", daten: ohneAbendessen())
        #expect(a.phase == .naechsterTag)
        #expect(a.kicker == "Mittag morgen · Ehrenberg")
        // Solange eine andere Mensa Mittag hat, bleibt es dagegen bei „Noch offen“.
        #expect(sperre("14:20", daten: ohneAbendessen()).phase == .nochOffen)
    }

    @Test func amWochenendeIstMittagMontag() {
        var daten = snapshot(heute: "2026-10-31", naechster: "2026-11-02")
        for index in daten.mensen.indices { daten.mensen[index].heute?.gerichte = [] }
        let a = sperre("11:45", tag: "2026-10-31", daten: daten)
        #expect(a.phase == .naechsterTag)
        #expect(a.kicker == "Mittag Montag · Ehrenberg")
    }

    @Test func ohneSpeicherBleibtEsBeiKeinPlan() {
        let a = sperre("11:45", daten: WidgetSnapshot())
        #expect(a.gericht == nil)
        #expect(a.leerTitel == "Noch kein Plan")
        #expect(a.rechteckLink == a.speiseplanLink)
    }
}

struct MensaSperreRotationTests {
    private func namen(_ uhren: [String], filter: MensaFilter? = nil, daten: WidgetSnapshot? = nil) -> [String?] {
        uhren.map { sperre($0, daten: daten, filter: filter).gericht?.name }
    }

    @Test func alleFuenfMinutenKommtDasNaechsteGerichtUndAmEndeWiederDasErste() {
        let n = namen(["11:45", "11:50", "11:55", "12:00", "12:05"])
        #expect(Set(n).count == 3)
        #expect(n[0] == n[3] && n[1] == n[4])
        // Dazwischen bleibt es beim selben Gericht.
        #expect(namen(["11:45", "11:46", "11:49"]) == [n[0], n[0], n[0]])
        // Reihenfolge wie im Speiseplan.
        let reihenfolge = ["Linsen-Dal", "Schnitzel", "Pasta"]
        let start = reihenfolge.firstIndex(of: n[0] ?? "") ?? -1
        #expect(start >= 0)
        #expect(n[1] == reihenfolge[(start + 1) % 3] && n[2] == reihenfolge[(start + 2) % 3])
    }

    @Test func positionZaehltHochUndStartetNeu() {
        let a = ["11:45", "11:50", "11:55", "12:00"].map { sperre($0) }
        #expect(a.map(\.anzahl) == [3, 3, 3, 3])
        #expect(Set(a.prefix(3).map(\.position)) == [1, 2, 3])
        #expect(a[0].position == a[3].position)
        #expect(a[1].position == a[0].position % 3 + 1)
    }

    @Test func mitFilterRotierenNurPassendeGerichte() {
        let filter = MensaFilter(diet: .vegan)
        let n = namen(["11:45", "11:50", "11:55", "12:00"], filter: filter, daten: filterDaten())
        #expect(Set(n.compactMap { $0 }) == ["Linsen-Dal", "Pasta"])
        #expect(n[0] != n[1] && n[0] == n[2] && n[1] == n[3])
        let a = sperre("11:45", daten: filterDaten(), filter: filter)
        #expect(a.anzahl == 2)
        #expect(a.positionText.hasSuffix("/2"))
        #expect(a.filterung != nil)
    }

    @Test func mitFilterOhneTrefferZeigtNichtsPasst() {
        let a = sperre("11:45", daten: filterDaten(), filter: MensaFilter(diet: .vegan, onlyBio: true))
        #expect(a.gericht == nil)
        #expect(a.nichtsPasst)
        #expect(a.leerTitel == "Nichts passt zu deinem Filter")
        #expect(a.zeile.hasSuffix("Nichts passt"))
        #expect(a.rechteckLink == a.speiseplanLink)
    }

    @Test func einEinzelnesGerichtRotiertNicht() {
        let a = sperre("11:45", daten: filterDaten(), filter: MensaFilter(diet: .vegan, excludedAllergens: ["Milch und Milchzucker"]))
        #expect(a.anzahl == 1)
        #expect(a.positionText.isEmpty)
        #expect(sperre("11:50", daten: filterDaten(), filter: MensaFilter(diet: .vegan, excludedAllergens: ["Milch und Milchzucker"])).gericht == a.gericht)
    }

    @Test func zeitleisteIstKurzUndGerundet() {
        let jetzt = zeit("2026-10-29", "11:47")
        let punkte = MensaSperrePhasen.zeitpunkte(snapshot: snapshot(), nach: jetzt)
        #expect(punkte.first == zeit("2026-10-29", "11:50"))
        #expect(punkte.last == zeit("2026-10-29", "14:45"))
        #expect(punkte.count <= 40)
        #expect(punkte == punkte.sorted() && Set(punkte).count == punkte.count)
        #expect(punkte.allSatisfy { HeuteUhr.minuten($0) % 5 == 0 })
        #expect(punkte.contains(zeit("2026-10-29", "14:00")))
    }

    @Test func zeitleisteEndetSpaetestensAmTagesende() {
        let punkte = MensaSperrePhasen.zeitpunkte(snapshot: snapshot(), nach: zeit("2026-10-29", "22:10"))
        #expect(punkte.last == EventKalender.tag(zeit("2026-10-29", "22:10"), plus: 1))
        #expect(MensaSperrePhasen.ende(nach: zeit("2026-10-29", "22:10")) == punkte.last)
    }
}
