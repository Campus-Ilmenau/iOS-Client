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
