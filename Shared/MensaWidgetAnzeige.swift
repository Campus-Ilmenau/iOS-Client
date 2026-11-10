import Foundation

/// Was das Widget „Mensa heute“ zu einem Zeitpunkt zeigt: Kopf, Gerichte und „Als Nächstes“, fertig als Text.
/// Die Regeln stehen in `MensaWidgetPhasen`; die Ansichten zeichnen nur noch.
nonisolated struct MensaWidgetAnzeige: Equatable, Sendable {
    enum Phase: String, Sendable {
        /// Bis 10:30: Vorschau auf das Mittagsangebot.
        case morgen
        /// Bis zur Schließzeit der Mensa.
        case mittag
        /// Nach dem Mittag bis 16:30.
        case nachmittag
        /// 16:30 bis 19:30.
        case abend
        /// Ab 19:30: Mittag des nächsten Öffnungstags.
        case nacht
        /// Wochenende oder Feiertag: heute zu, gezeigt wird der nächste Öffnungstag.
        case geschlossen
    }

    struct Zeile: Equatable, Sendable, Identifiable {
        let id: String
        let name: String
        /// „2,90 €“, in der Preisgruppe aus „Mehr“; „–“ ohne Preis.
        let preis: String
        let chips: [WidgetChip]
        /// `campusilmenau://mensa/gericht/<id>?tag=<Tag des gezeigten Plans>`
        let link: URL
    }

    struct Termin: Equatable, Sendable {
        /// „14:00“ oder „Mo“
        let zeit: String
        /// „Schließt · Ehrenberg“
        let text: String
    }

    var phase: Phase
    var mensaID: String
    var kicker: String
    var titel: String
    var unterzeile: String
    /// Höchstens 3; die Größe des Widgets nimmt davon 2 oder 3.
    var zeilen: [Zeile]
    /// Höchstens 2.
    var termine: [Termin]
    /// Berliner Tag des gezeigten Plans, `nil` ohne Plan.
    var planTag: String?
    /// `campusilmenau://mensa?mensa=<id>`: Speiseplan der gezeigten Mensa (beim Abendessen-Tipp die Cafeteria).
    var kopfLink: URL

    /// Der Filter der App ist angewendet (Schalter „Filter aus der App anwenden“ an, in der App ist etwas gesetzt).
    /// `nil` ohne Schalter und bei leerem App-Filter: dann verhält sich das Widget wie ohne Schalter.
    var filterung: Filterung?

    var hatPlan: Bool { !zeilen.isEmpty }

    /// Es gibt Gerichte, aber der Filter lässt keins davon durch.
    var nichtsPasst: Bool {
        guard let filterung else { return false }
        return zeilen.isEmpty && filterung.ohneFilterAnzahl > 0
    }

    struct Filterung: Equatable, Sendable {
        /// „Vegan · ohne Milch“
        let kurztext: String
        /// Wie viele Gerichte der gezeigte Plan ohne Filter hat.
        let ohneFilterAnzahl: Int

        /// „3 Gerichte ohne Filter“
        var ohneFilterText: String {
            ohneFilterAnzahl == 1 ? "1 Gericht ohne Filter" : "\(ohneFilterAnzahl) Gerichte ohne Filter"
        }
    }
}

/// Die Phasen des Widgets „Mensa heute“, nach der Tabelle in `Uebergabe.md` und den Regeln der Jetzt-Karte auf Heute.
nonisolated enum MensaWidgetPhasen {
    /// Bis hierher gilt „Vorschau“ (10:30).
    static let morgenEnde = 10 * 60 + 30
    /// Beginn des Abendessens (16:30). Die API nennt keinen Beginn.
    static let abendessenBeginn = 16 * 60 + 30
    /// Ende des Abendessens (19:30).
    static let abendessenEnde = 19 * 60 + 30
    /// Ohne Öffnungszeiten rechnet das Widget mit diesen Zeiten (Mittag 11 bis 14 Uhr).
    static let ersatzOeffnet = 11 * 60
    static let ersatzSchliesst = 14 * 60
    static let maxZeilen = 3

    // MARK: Anzeige

    static func anzeige(
        snapshot: WidgetSnapshot,
        mensaID: String,
        preisgruppe: MensaPriceGroup,
        jetzt: Date,
        filter: MensaFilter? = nil
    ) -> MensaWidgetAnzeige {
        Rechner(
            snapshot: snapshot, venue: MensaVenue(rawValue: mensaID) ?? .mensaEhrenberg, preisgruppe: preisgruppe, jetzt: jetzt,
            filter: filter.flatMap { $0.isActive ? $0 : nil }
        ).anzeige()
    }

    /// Das Widget lädt am nächsten Morgen um 6:00 (Berliner Zeit) neu.
    static let neuladenUm = 6 * 60

    /// Das nächste 6:00 Berliner Zeit nach `jetzt`.
    static func naechsteNeuladung(nach jetzt: Date) -> Date {
        let heute = HeuteUhr.datum(am: jetzt, minuten: neuladenUm)
        return heute > jetzt ? heute : HeuteUhr.datum(am: EventKalender.tag(jetzt, plus: 1), minuten: neuladenUm)
    }

    /// Die Zeitpunkte nach `jetzt` bis zum Ende des Berliner Tages, an denen sich die Anzeige ändert
    /// (10:30, Schließzeit, 16:30, 19:30), dazu Mitternacht.
    static func wechsel(snapshot: WidgetSnapshot, mensaID: String, nach jetzt: Date) -> [Date] {
        let venue = MensaVenue(rawValue: mensaID) ?? .mensaEhrenberg
        let schliesst = zeiten(venue, am: jetzt, in: snapshot)?.schliesst ?? ersatzSchliesst
        let minuten = [morgenEnde, schliesst, abendessenBeginn, abendessenEnde]
        let mitternacht = EventKalender.tag(jetzt, plus: 1)
        return (minuten.map { HeuteUhr.datum(am: jetzt, minuten: $0) } + [mitternacht])
            .filter { $0 > jetzt }
            .sorted()
            .reduce(into: [Date]()) { liste, datum in if liste.last != datum { liste.append(datum) } }
    }

    // MARK: Öffnungszeiten und Pläne

    /// Öffnungszeit der Mensa am Tag in Minuten; `nil` bei geschlossen oder ohne Angabe.
    static func zeiten(_ venue: MensaVenue, am tag: Date, in snapshot: WidgetSnapshot) -> (oeffnet: Int, schliesst: Int)? {
        let schluessel = HeuteUhr.wochentagSchluessel(tag)
        guard let eintrag = snapshot.mensa(id: venue.rawValue)?.oeffnungszeiten.first(where: { $0.wochentag == schluessel }),
              let oeffnet = HeuteUhr.minuten(aus: eintrag.oeffnet), let schliesst = HeuteUhr.minuten(aus: eintrag.schliesst)
        else { return nil }
        return (oeffnet, schliesst)
    }

    /// Der Plan der Mensa für einen Berliner Tag, wenn der Speicher ihn kennt (als „heute“ oder „nächster Tag“).
    static func plan(_ venue: MensaVenue, tag: String, in snapshot: WidgetSnapshot) -> WidgetSpeiseplan? {
        guard let eintrag = snapshot.mensa(id: venue.rawValue) else { return nil }
        if let heute = eintrag.heute, heute.tag == tag { return heute }
        if let naechster = eintrag.naechsterOeffnungstag, naechster.tag == tag { return naechster }
        return nil
    }

    /// Der Berliner Tag zu `yyyy-MM-dd`.
    static func datum(_ tag: String) -> Date? {
        let teile = tag.split(separator: "-").compactMap { Int($0) }
        guard teile.count == 3 else { return nil }
        return EventKalender.kalender.date(from: DateComponents(year: teile[0], month: teile[1], day: teile[2]))
    }

    /// „2,90 €“; ein fehlender Preis ist „–“.
    static func preis(_ gericht: WidgetGericht, _ gruppe: MensaPriceGroup) -> String {
        let wert: Double? = switch gruppe {
        case .studierende: gericht.preisStudierende
        case .bedienstete: gericht.preisBedienstete
        case .gaeste: gericht.preisGaeste
        }
        guard let wert else { return "–" }
        let code = gericht.waehrung.count == 3 ? gericht.waehrung.uppercased() : "EUR"
        return wert.formatted(.currency(code: code).locale(Locale(identifier: "de_DE")))
    }
}

// MARK: - Rechnung

private nonisolated struct Rechner {
    let snapshot: WidgetSnapshot
    let venue: MensaVenue
    let preisgruppe: MensaPriceGroup
    let jetzt: Date
    /// Der App-Filter, wenn das Widget ihn anwendet und etwas gesetzt ist.
    let filter: MensaFilter?

    typealias Anzeige = MensaWidgetAnzeige
    typealias P = MensaWidgetPhasen

    private var heuteTag: String { EventKalender.berlinDatum(jetzt) }
    private var minuten: Int { HeuteUhr.minuten(jetzt) }
    private var heutigeZeiten: (oeffnet: Int, schliesst: Int)? { P.zeiten(venue, am: jetzt, in: snapshot) }
    private var schliesst: Int { heutigeZeiten?.schliesst ?? P.ersatzSchliesst }

    private func uhrzeit(_ minuten: Int) -> String { HeuteUhr.uhrzeit(minuten: minuten) }

    // MARK: Abendessen

    /// Mensen mit Abendessen heute, die Cafeteria Ehrenberg zuerst (der Normalfall).
    private var abendessenOrte: [MensaVenue] {
        let reihenfolge: [MensaVenue] = [.cafeteriaEhrenberg, .mensaEhrenberg, .nanoteria, .roentgenbau]
        return reihenfolge.filter { ort in
            P.plan(ort, tag: heuteTag, in: snapshot)?.gerichte.contains { $0.abendessen } == true
        }
    }

    /// Der Ort, den das Widget zeigt: die gewählte Mensa, sonst ein Ort im selben Haus, sonst der erste.
    private var abendessenOrt: MensaVenue? {
        let orte = abendessenOrte
        return orte.first { $0 == venue } ?? orte.first { Self.haus($0) == Self.haus(venue) } ?? orte.first
    }

    /// Mensa und Cafeteria Ehrenberg zählen als ein Haus: Wer die Mensa Ehrenberg gewählt hat, bekommt das
    /// Abendessen der Cafeteria nicht als „Tipp“.
    private var eigeneMensaHatAbendessen: Bool {
        abendessenOrte.contains { Self.haus($0) == Self.haus(venue) }
    }

    private static func haus(_ venue: MensaVenue) -> String {
        switch venue {
        case .mensaEhrenberg, .cafeteriaEhrenberg: "Mensa Ehrenberg"
        default: venue.displayName
        }
    }

    /// „Ehrenberg“ für beide Orte im Haus, sonst der Kurzname.
    private static func kurz(_ venue: MensaVenue) -> String {
        switch venue {
        case .mensaEhrenberg, .cafeteriaEhrenberg: "Ehrenberg"
        default: venue.shortName
        }
    }

    private static func ortKurz(_ venue: MensaVenue) -> String {
        venue == .cafeteriaEhrenberg ? "Cafeteria" : venue == .mensaEhrenberg ? "Mensa" : venue.shortName
    }

    // MARK: Zeilen

    private func zeilen(_ gerichte: [WidgetGericht], tag: String?) -> [Anzeige.Zeile] {
        (filter?.apply(to: gerichte) ?? gerichte).prefix(P.maxZeilen).map { gericht in
            Anzeige.Zeile(
                id: gericht.id,
                name: gericht.name,
                preis: P.preis(gericht, preisgruppe),
                chips: gericht.chips,
                link: DeepLink.gericht(id: gericht.id, tag: tag).url
            )
        }
    }

    /// Der Filterzustand für die Anzeige eines Plans mit diesen (ungefilterten) Gerichten.
    private func filterzustand(_ gerichte: [WidgetGericht]) -> Anzeige.Filterung? {
        filter.map { Anzeige.Filterung(kurztext: $0.activeDescription, ohneFilterAnzahl: gerichte.count) }
    }

    /// Hinter der Unterzeile steht der Filter („Mittagsangebot · Vegan · ohne Milch“).
    private func mitFilter(_ text: String, _ filterung: Anzeige.Filterung?) -> String {
        filterung.map { "\(text) · \($0.kurztext)" } ?? text
    }

    private func mittag(tag: String) -> [WidgetGericht] {
        P.plan(venue, tag: tag, in: snapshot)?.gerichte.filter { !$0.abendessen } ?? []
    }

    // MARK: Nächster Öffnungstag

    /// Der nächste Tag, an dem die Mensa öffnet: aus dem Speicher, sonst nach den Öffnungszeiten, sonst morgen.
    private var naechsterTag: (text: String, datum: Date) {
        let morgen = EventKalender.tag(jetzt, plus: 1)
        if let tag = snapshot.mensa(id: venue.rawValue)?.naechsterOeffnungstag?.tag, tag > heuteTag,
           let datum = P.datum(tag) {
            return (tag, datum)
        }
        for offset in 1...7 {
            let datum = EventKalender.tag(jetzt, plus: offset)
            if P.zeiten(venue, am: datum, in: snapshot) != nil { return (EventKalender.berlinDatum(datum), datum) }
        }
        return (EventKalender.berlinDatum(morgen), morgen)
    }

    private func oeffnetAm(_ datum: Date) -> Int? {
        P.zeiten(venue, am: datum, in: snapshot)?.oeffnet
    }

    // MARK: Anzeige

    func anzeige() -> Anzeige {
        let kopf = DeepLink.mensa(id: venue.rawValue).url
        let zeiten = heutigeZeiten
        let hatZeiten = snapshot.mensa(id: venue.rawValue)?.oeffnungszeiten.isEmpty == false
        let plaene = MensaVenue.allCases.compactMap { P.plan($0, tag: heuteTag, in: snapshot) }
        let keinerKocht = !plaene.isEmpty && plaene.allSatisfy { $0.gerichte.isEmpty }

        if (hatZeiten && zeiten == nil) || keinerKocht { return geschlossen(kopf: kopf) }
        if minuten >= P.abendessenEnde { return naechsterTagAnzeige(phase: .nacht, kopf: kopf) }
        if minuten >= P.abendessenBeginn { return abend(phase: .abend, kopf: kopf) }
        if minuten >= schliesst { return abend(phase: .nachmittag, kopf: kopf) }
        if minuten >= P.morgenEnde { return mittagAnzeige(phase: .mittag, kopf: kopf) }
        return mittagAnzeige(phase: .morgen, kopf: kopf)
    }

    // Morgens und mittags

    private func mittagAnzeige(phase: Anzeige.Phase, kopf: URL) -> Anzeige {
        let zeiten = heutigeZeiten
        let kicker: String
        if let zeiten {
            kicker = minuten >= zeiten.oeffnet || phase == .mittag
                ? "Geöffnet bis \(uhrzeit(zeiten.schliesst))"
                : "Heute ab \(uhrzeit(zeiten.oeffnet))"
        } else {
            kicker = "Heute"
        }

        var termine: [Anzeige.Termin] = []
        if let zeiten, minuten < zeiten.oeffnet {
            termine.append(.init(zeit: uhrzeit(zeiten.oeffnet), text: "Öffnet · \(venue.shortName)"))
        }
        termine.append(.init(zeit: uhrzeit(schliesst), text: "Schließt · \(venue.shortName)"))
        if let ort = abendessenOrt {
            termine.append(.init(zeit: uhrzeit(P.abendessenBeginn), text: "Abendessen · \(Self.kurz(ort))"))
        }

        let gerichte = mittag(tag: heuteTag)
        let filterung = filterzustand(gerichte)
        return Anzeige(
            phase: phase, mensaID: venue.rawValue, kicker: kicker, titel: venue.displayName,
            unterzeile: mitFilter(phase == .morgen ? "Vorschau aufs Mittagsangebot" : "Mittagsangebot", filterung),
            zeilen: zeilen(gerichte, tag: heuteTag),
            termine: Array(termine.prefix(2)),
            planTag: P.plan(venue, tag: heuteTag, in: snapshot).map(\.tag),
            kopfLink: kopf,
            filterung: filterung
        )
    }

    // Nachmittags und abends

    private func abend(phase: Anzeige.Phase, kopf: URL) -> Anzeige {
        guard let ort = abendessenOrt else {
            // Kein Abendessen heute: die gewählte Mensa bleibt stehen, wie auf Heute.
            let gerichte = mittag(tag: heuteTag)
            let filterung = filterzustand(gerichte)
            return Anzeige(
                phase: phase, mensaID: venue.rawValue, kicker: "Heute geschlossen", titel: venue.displayName,
                unterzeile: mitFilter("Mittagsangebot", filterung), zeilen: zeilen(gerichte, tag: heuteTag),
                termine: folgetagTermine(), planTag: P.plan(venue, tag: heuteTag, in: snapshot).map(\.tag), kopfLink: kopf,
                filterung: filterung
            )
        }

        let gerichte = P.plan(ort, tag: heuteTag, in: snapshot)?.gerichte.filter(\.abendessen) ?? []
        let eigene = eigeneMensaHatAbendessen
        let ortLink = DeepLink.mensa(id: ort.rawValue).url
        let beginn = uhrzeit(P.abendessenBeginn), ende = uhrzeit(P.abendessenEnde)
        let kicker: String, titel: String, unterzeile: String, termine: [Anzeige.Termin]

        switch (phase, eigene) {
        case (.nachmittag, true):
            kicker = "Abendessen ab \(beginn)"
            titel = Self.haus(ort)
            unterzeile = "Abendangebot in der \(Self.ortKurz(ort))"
            termine = [.init(zeit: beginn, text: "Abendessen öffnet"), .init(zeit: ende, text: "Schließt")]
        case (.nachmittag, false):
            kicker = "\(venue.shortName) hat geschlossen"
            titel = "Abendessen \(Self.kurz(ort))"
            unterzeile = "Tipp · ab \(beginn) in der \(Self.ortKurz(ort))"
            termine = [.init(zeit: beginn, text: "Abendessen · \(Self.kurz(ort))")] + liste(mittagFolgetag())
        case (_, true):
            kicker = "Geöffnet bis \(ende)"
            titel = Self.haus(ort)
            unterzeile = "Abendessen in der \(Self.ortKurz(ort))"
            termine = [.init(zeit: ende, text: "Schließt")] + liste(folgetagMittagKurz())
        default:
            kicker = "\(venue.shortName) hat geschlossen"
            titel = "Abendessen \(Self.kurz(ort))"
            unterzeile = "Tipp · jetzt geöffnet bis \(ende)"
            termine = [.init(zeit: ende, text: "Abendessen schließt")] + liste(mittagFolgetag())
        }

        let filterung = filterzustand(gerichte)
        return Anzeige(
            phase: phase, mensaID: venue.rawValue, kicker: kicker, titel: titel,
            unterzeile: mitFilter(unterzeile, filterung),
            zeilen: zeilen(gerichte, tag: heuteTag), termine: Array(termine.prefix(2)), planTag: heuteTag,
            kopfLink: ortLink, filterung: filterung
        )
    }

    // Nach dem Abendessen und am Wochenende

    private func geschlossen(kopf: URL) -> Anzeige {
        naechsterTagAnzeige(phase: .geschlossen, kopf: kopf)
    }

    private func naechsterTagAnzeige(phase: Anzeige.Phase, kopf: URL) -> Anzeige {
        let (tag, datum) = naechsterTag
        let morgen = tag == EventKalender.berlinDatum(EventKalender.tag(jetzt, plus: 1))
        let wochentag = EventKalender.format(datum, "EEEE")
        let oeffnet = oeffnetAm(datum).map(uhrzeit)
        let ab = oeffnet.map { " · ab \($0)" } ?? ""

        let kicker: String, unterzeile: String
        if phase == .geschlossen {
            kicker = "Heute geschlossen"
            unterzeile = oeffnet.map { "\(wochentag) ab \($0)" } ?? wochentag
        } else {
            kicker = (morgen ? "Mittag morgen" : "Mittag \(wochentag)") + ab
            unterzeile = EventKalender.format(datum, "EEEE, d. MMMM")
        }

        let kurzTag = HeuteUhr.wochentagKurz(datum)
        var termine: [Anzeige.Termin] = []
        if let oeffnet { termine.append(.init(zeit: kurzTag, text: "Öffnet \(oeffnet) · \(venue.shortName)")) }
        if let ort = abendessenOrtAm(tag) {
            termine.append(.init(zeit: kurzTag, text: "Abendessen \(uhrzeit(P.abendessenBeginn)) · \(Self.kurz(ort))"))
        }

        let plan = P.plan(venue, tag: tag, in: snapshot)
        let gerichte = plan?.gerichte.filter { !$0.abendessen } ?? []
        let filterung = filterzustand(gerichte)
        return Anzeige(
            phase: phase, mensaID: venue.rawValue, kicker: kicker, titel: venue.displayName,
            unterzeile: mitFilter(unterzeile, filterung),
            zeilen: zeilen(gerichte, tag: tag),
            termine: Array(termine.prefix(2)), planTag: plan?.tag, kopfLink: kopf, filterung: filterung
        )
    }

    /// Abendessen am Folgetag, wenn der Speicher es kennt.
    private func abendessenOrtAm(_ tag: String) -> MensaVenue? {
        let reihenfolge: [MensaVenue] = [.cafeteriaEhrenberg, .mensaEhrenberg, .nanoteria, .roentgenbau]
        return reihenfolge.first { P.plan($0, tag: tag, in: snapshot)?.gerichte.contains { $0.abendessen } == true }
    }

    // „Als Nächstes“ am Abend

    /// „Fr · Mittag · Nanoteria ab 8:00“
    private func mittagFolgetag() -> Anzeige.Termin? {
        let (_, datum) = naechsterTag
        let ab = oeffnetAm(datum).map { " ab \(uhrzeit($0))" } ?? ""
        return .init(zeit: HeuteUhr.wochentagKurz(datum), text: "Mittag · \(venue.shortName)\(ab)")
    }

    /// „Fr · Mittag ab 11:00“
    private func folgetagMittagKurz() -> Anzeige.Termin? {
        let (_, datum) = naechsterTag
        let ab = oeffnetAm(datum).map { " ab \(uhrzeit($0))" } ?? ""
        return .init(zeit: HeuteUhr.wochentagKurz(datum), text: "Mittag\(ab)")
    }

    private func folgetagTermine() -> [Anzeige.Termin] {
        liste(mittagFolgetag())
    }

    private func liste(_ termin: Anzeige.Termin?) -> [Anzeige.Termin] {
        termin.map { [$0] } ?? []
    }
}
