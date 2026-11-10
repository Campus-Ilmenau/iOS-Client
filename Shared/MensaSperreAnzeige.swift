import Foundation

/// Was das Widget „Mensa heute“ auf dem Sperrbildschirm zu einem Zeitpunkt zeigt (Zeile, Rechteck, Kreis): ein
/// Gericht, fertig als Text. Die Regeln stehen in `MensaSperrePhasen`; die Ansichten zeichnen nur.
nonisolated struct MensaSperreAnzeige: Equatable, Sendable {
    /// Weicht von den Phasen des Home-Widgets ab (siehe „Sperrbildschirm · Mensa“ in `Uebergabe.md`).
    enum Phase: String, Sendable {
        /// Bis 10:30: Vorschau der Mensa auf der Startseite.
        case vorschau
        /// Die Mensa auf der Startseite hat offen.
        case mittag
        /// Sie hat zu, aber eine andere hat noch Mittag.
        case nochOffen
        /// Alle haben mittags zu, bis Ende des Abendessens (Ort aus den Daten, egal welche Mensa gewählt ist).
        case abend
        /// Mittag des nächsten Öffnungstags (freitags und am Wochenende: Montag).
        case naechsterTag
    }

    struct Gericht: Equatable, Sendable {
        let id: String
        let name: String
        /// „2,90 €“ in der Preisgruppe aus „Mehr“; „–“ ohne Preis.
        let preis: String
        /// `campusilmenau://mensa/gericht/<id>?tag=<Tag des gezeigten Plans>`
        let link: URL
    }

    var phase: Phase
    /// Die Mensa, deren Gericht gezeigt wird (`MensaVenue.rawValue`).
    var mensaID: String
    /// „Ehrenberg · bis 14:00“; das Rechteck setzt ihn in Versalien.
    var kicker: String
    /// „bis 14:00“, „Abendessen ab 16:30“, „morgen ab 11:00“: Anfang der Zeile.
    var zeitText: String
    /// Kreis: „14:00“ / „bis“, „16:30“ / „Abend“, „Fr“ / „11:00“.
    var kreisGross: String
    var kreisKlein: String
    /// Das Gericht dieses Zeitpunkts; `nil` ohne Plan oder wenn der Filter nichts durchlässt.
    var gericht: Gericht?
    /// 1-basiert; 0 ohne Gericht.
    var position: Int
    /// Anzahl der Gerichte, die rotieren (mit Filter nur die passenden).
    var anzahl: Int
    /// Der Filter der App ist angewendet, siehe `MensaWidgetAnzeige.filterung`.
    var filterung: MensaWidgetAnzeige.Filterung?
    /// `campusilmenau://mensa?mensa=<id>`: Speiseplan der gezeigten Mensa.
    var speiseplanLink: URL

    /// Es gibt Gerichte, aber der Filter lässt keins davon durch.
    var nichtsPasst: Bool {
        guard let filterung else { return false }
        return gericht == nil && filterung.ohneFilterAnzahl > 0
    }

    /// „1/3“; leer bei höchstens einem Gericht.
    var positionText: String { anzahl > 1 ? "\(position)/\(anzahl)" : "" }

    /// Tippen aufs Rechteck: das Gericht, sonst der Speiseplan.
    var rechteckLink: URL { gericht?.link ?? speiseplanLink }

    /// Ohne Gericht: was an dessen Stelle steht.
    var leerTitel: String { nichtsPasst ? "Nichts passt zu deinem Filter" : "Noch kein Plan" }
    var leerDetail: String {
        guard let filterung else { return "Tippen zum Laden" }
        return nichtsPasst ? filterung.kurztext : "Tippen zum Laden"
    }

    /// Die Zeile über der Uhr: „bis 14:00 · Linsen-Dal mit Basmatireis“.
    var zeile: String {
        "\(zeitText) · \(gericht?.name ?? (nichtsPasst ? "Nichts passt" : "Noch kein Plan"))"
    }

    /// VoiceOver für den Kreis: „Mensa, bis 14:00“.
    var kreisBeschriftung: String {
        "Mensa, \(kreisKlein) \(kreisGross)"
    }
}

/// Die Phasen des Sperrbildschirm-Widgets und die Rotation der Gerichte. Ohne SwiftUI, damit App, Widget und Tests
/// dieselbe Rechnung nutzen. Das Home-Widget (`MensaWidgetPhasen`) bleibt, wie es ist.
nonisolated enum MensaSperrePhasen {
    /// So oft wechselt das Gericht: alle 5 Minuten, auf :00, :05 … gerundet.
    static let schrittMinuten = 5
    /// So weit reicht die Zeitleiste höchstens voraus; danach lädt das Widget neu.
    static let maxDauer: TimeInterval = 3 * 60 * 60

    // MARK: Anzeige

    static func anzeige(
        snapshot: WidgetSnapshot, mensaID: String, preisgruppe: MensaPriceGroup, jetzt: Date, filter: MensaFilter? = nil
    ) -> MensaSperreAnzeige {
        Rechner(
            snapshot: snapshot, venue: MensaVenue(rawValue: mensaID) ?? .mensaEhrenberg, preisgruppe: preisgruppe, jetzt: jetzt,
            filter: filter.flatMap { $0.isActive ? $0 : nil }
        ).anzeige()
    }

    // MARK: Zeitleiste

    /// Das Ende der Zeitleiste: höchstens `maxDauer` voraus, nie über Mitternacht (Berlin) hinaus.
    static func ende(nach jetzt: Date) -> Date {
        min(jetzt.addingTimeInterval(maxDauer), EventKalender.tag(jetzt, plus: 1))
    }

    /// Die Zeitpunkte nach `jetzt` bis `ende(nach:)`, an denen sich die Anzeige ändern kann: alle 5 Minuten, dazu
    /// die Phasenwechsel (10:30, Schließzeiten, Abendessen) und Mitternacht.
    static func zeitpunkte(snapshot: WidgetSnapshot, nach jetzt: Date) -> [Date] {
        let ende = ende(nach: jetzt)
        var liste: [Date] = []
        var minuten = (HeuteUhr.minuten(jetzt) / schrittMinuten + 1) * schrittMinuten
        while minuten < 24 * 60 {
            let datum = HeuteUhr.datum(am: jetzt, minuten: minuten)
            if datum > ende { break }
            liste.append(datum)
            minuten += schrittMinuten
        }

        let schliesszeiten = MensaVenue.allCases.compactMap { MensaWidgetPhasen.zeiten($0, am: jetzt, in: snapshot)?.schliesst }
        let wechsel = [MensaWidgetPhasen.morgenEnde, MensaWidgetPhasen.abendessenBeginn, MensaWidgetPhasen.abendessenEnde]
            + schliesszeiten
        liste += wechsel.map { HeuteUhr.datum(am: jetzt, minuten: $0) }
        liste.append(EventKalender.tag(jetzt, plus: 1))

        return liste.filter { $0 > jetzt && $0 <= ende }
            .sorted()
            .reduce(into: [Date]()) { alle, datum in if alle.last != datum { alle.append(datum) } }
    }

    // MARK: Rechnung

    private struct Rechner {
        let snapshot: WidgetSnapshot
        let venue: MensaVenue
        let preisgruppe: MensaPriceGroup
        let jetzt: Date
        let filter: MensaFilter?

        typealias P = MensaWidgetPhasen

        private var heuteTag: String { EventKalender.berlinDatum(jetzt) }
        private var minuten: Int { HeuteUhr.minuten(jetzt) }
        private func uhrzeit(_ minuten: Int) -> String { HeuteUhr.uhrzeit(minuten: minuten) }

        /// „Ehrenberg“ für beide Orte im Haus, sonst der Kurzname.
        private func kurz(_ venue: MensaVenue) -> String {
            switch venue {
            case .mensaEhrenberg, .cafeteriaEhrenberg: "Ehrenberg"
            default: venue.shortName
            }
        }

        private func mittag(_ venue: MensaVenue, tag: String) -> [WidgetGericht] {
            P.plan(venue, tag: tag, in: snapshot)?.gerichte.filter { !$0.abendessen } ?? []
        }

        // MARK: Phasen

        func anzeige() -> MensaSperreAnzeige {
            let zeiten = P.zeiten(venue, am: jetzt, in: snapshot)
            let hatZeiten = snapshot.mensa(id: venue.rawValue)?.oeffnungszeiten.isEmpty == false
            let plaene = MensaVenue.allCases.compactMap { P.plan($0, tag: heuteTag, in: snapshot) }
            let keinerKocht = !plaene.isEmpty && plaene.allSatisfy { $0.gerichte.isEmpty }
            // Wochenende, Feiertag: heute ist zu, es gilt der nächste Öffnungstag.
            if (hatZeiten && zeiten == nil) || keinerKocht { return naechsterTag() }

            let schliesst = zeiten?.schliesst ?? P.ersatzSchliesst
            if minuten < P.morgenEnde {
                let ab = zeiten.map { "ab \(uhrzeit($0.oeffnet))" } ?? "heute"
                return inhalt(
                    .vorschau, venue, mittag(venue, tag: heuteTag), tag: heuteTag,
                    kicker: "\(kurz(venue)) · \(ab)", zeit: ab,
                    kreis: zeiten.map { (uhrzeit($0.oeffnet), "öffnet") } ?? ("heute", "")
                )
            }
            if minuten < schliesst {
                return inhalt(
                    .mittag, venue, mittag(venue, tag: heuteTag), tag: heuteTag,
                    kicker: "\(kurz(venue)) · bis \(uhrzeit(schliesst))", zeit: "bis \(uhrzeit(schliesst))",
                    kreis: (uhrzeit(schliesst), "bis")
                )
            }
            if let (ort, ende) = nochOffen {
                return inhalt(
                    .nochOffen, ort, mittag(ort, tag: heuteTag), tag: heuteTag,
                    kicker: "Noch offen · \(kurz(ort))", zeit: "\(kurz(ort)) bis \(uhrzeit(ende))",
                    kreis: (uhrzeit(ende), kurz(ort))
                )
            }
            if minuten < P.abendessenEnde, let ort = abendessenOrt {
                let gerichte = P.plan(ort, tag: heuteTag, in: snapshot)?.gerichte.filter(\.abendessen) ?? []
                let beginnt = minuten < P.abendessenBeginn
                let zeit = beginnt ? "ab \(uhrzeit(P.abendessenBeginn))" : "bis \(uhrzeit(P.abendessenEnde))"
                return inhalt(
                    .abend, ort, gerichte, tag: heuteTag,
                    kicker: "Abendessen · \(zeit)", zeit: "Abendessen \(zeit)",
                    kreis: beginnt ? (uhrzeit(P.abendessenBeginn), "Abend") : (uhrzeit(P.abendessenEnde), "bis")
                )
            }
            return naechsterTag()
        }

        /// Die andere Mensa, die jetzt noch Mittag hat und am längsten offen bleibt, mit ihrer Schließzeit.
        private var nochOffen: (MensaVenue, Int)? {
            MensaVenue.allCases
                .compactMap { ort -> (MensaVenue, Int)? in
                    guard ort != venue, let schliesst = P.zeiten(ort, am: jetzt, in: snapshot)?.schliesst, schliesst > minuten,
                          !mittag(ort, tag: heuteTag).isEmpty else { return nil }
                    return (ort, schliesst)
                }
                .max { $0.1 < $1.1 }
        }

        /// Abendessen heute nach den Daten, die Cafeteria Ehrenberg zuerst (der Normalfall).
        private var abendessenOrt: MensaVenue? {
            [MensaVenue.cafeteriaEhrenberg, .mensaEhrenberg, .nanoteria, .roentgenbau].first { ort in
                P.plan(ort, tag: heuteTag, in: snapshot)?.gerichte.contains { $0.abendessen } == true
            }
        }

        /// Der nächste Tag, an dem die Mensa öffnet: aus dem Speicher, sonst nach den Öffnungszeiten, sonst morgen.
        private var naechsterTagDatum: (tag: String, datum: Date) {
            if let tag = snapshot.mensa(id: venue.rawValue)?.naechsterOeffnungstag?.tag, tag > heuteTag, let datum = P.datum(tag) {
                return (tag, datum)
            }
            for offset in 1...7 {
                let datum = EventKalender.tag(jetzt, plus: offset)
                if P.zeiten(venue, am: datum, in: snapshot) != nil { return (EventKalender.berlinDatum(datum), datum) }
            }
            let morgen = EventKalender.tag(jetzt, plus: 1)
            return (EventKalender.berlinDatum(morgen), morgen)
        }

        private func naechsterTag() -> MensaSperreAnzeige {
            let (tag, datum) = naechsterTagDatum
            let istMorgen = tag == EventKalender.berlinDatum(EventKalender.tag(jetzt, plus: 1))
            let oeffnet = P.zeiten(venue, am: datum, in: snapshot).map { uhrzeit($0.oeffnet) }
            let kurzTag = HeuteUhr.wochentagKurz(datum)
            let wann = istMorgen ? "morgen" : kurzTag
            return inhalt(
                .naechsterTag, venue, mittag(venue, tag: tag), tag: tag,
                kicker: "Mittag \(istMorgen ? "morgen" : EventKalender.format(datum, "EEEE")) · \(kurz(venue))",
                zeit: oeffnet.map { "\(wann) ab \($0)" } ?? wann,
                kreis: (kurzTag, oeffnet ?? "Mittag")
            )
        }

        // MARK: Rotation

        /// Baut die Anzeige für diese Gerichte. Das Gericht dieses Zeitpunkts ist das Stück der Liste, auf das der
        /// 5-Minuten-Takt zeigt; am Ende der Liste geht es von vorn los. Mit Filter zählen nur passende Gerichte.
        private func inhalt(
            _ phase: MensaSperreAnzeige.Phase, _ ort: MensaVenue, _ gerichte: [WidgetGericht], tag: String,
            kicker: String, zeit: String, kreis: (String, String)
        ) -> MensaSperreAnzeige {
            let liste = filter?.apply(to: gerichte) ?? gerichte
            let stelle = liste.isEmpty ? nil : MensaSperrePhasen.takt(minuten: minuten) % liste.count
            let gericht = stelle.map { liste[$0] }.map { gericht in
                MensaSperreAnzeige.Gericht(
                    id: gericht.id, name: gericht.name, preis: P.preis(gericht, preisgruppe),
                    link: DeepLink.gericht(id: gericht.id, tag: tag).url
                )
            }
            return MensaSperreAnzeige(
                phase: phase, mensaID: ort.rawValue, kicker: kicker, zeitText: zeit,
                kreisGross: kreis.0, kreisKlein: kreis.1, gericht: gericht,
                position: stelle.map { $0 + 1 } ?? 0, anzahl: liste.count,
                filterung: filter.map { .init(kurztext: $0.activeDescription, ohneFilterAnzahl: gerichte.count) },
                speiseplanLink: DeepLink.mensa(id: ort.rawValue).url
            )
        }
    }

    /// Der Takt der Rotation: Minuten seit Mitternacht durch 5. Aufeinanderfolgende Takte zeigen aufeinanderfolgende
    /// Gerichte, und jedes Neuladen landet im selben Takt wie die Zeitleiste davor.
    static func takt(minuten: Int) -> Int {
        minuten / schrittMinuten
    }
}
