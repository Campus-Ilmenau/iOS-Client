import Foundation

// „Mensa heute“ für Siri: der gesprochene Satz und die Karte dazu, als reine Logik ohne SwiftUI.
// Phasen, Filter und Preise kommen aus `MensaWidgetPhasen` (dasselbe wie das Widget „Mensa heute“); hier steht nur,
// was Siri daraus sagt. Die Sätze folgen `Uebergabe.md`, Kapitel „Siri & Kurzbefehle“ → „Mensa heute“.

/// Die Karte unter der Antwort: Kopf, bis zu 3 Gerichte, Fuß.
nonisolated struct SiriMensaKarte: Equatable, Sendable {
    /// „Geöffnet bis 14:00“, „Abendessen · bis 19:30“, „Mittag morgen · ab 11:00“
    var kicker: String
    /// „Mensa Ehrenberg“
    var titel: String
    /// „Gefiltert: Vegan · ohne Milch“ oder „Vegetarisch – aus deiner Frage“
    var filterzeile: String?
    var gerichte: [MensaWidgetAnzeige.Zeile]
    /// „+3 weitere Gerichte“, „6 Gerichte ohne Filter“, „Ohne Filter: 3 Gerichte“ oder „Mittagsangebot“
    var fuss: String
    /// `campusilmenau://mensa?mensa=<id>`
    var kopfLink: URL
}

nonisolated struct SiriMensaAntwort: Equatable, Sendable {
    /// Der gesprochene Satz. Er muss allein reichen.
    var sagt: String
    /// `nil`, wenn es nichts zu zeigen gibt (kein Plan, keine Daten).
    var karte: SiriMensaKarte?
}

/// Was in der App eingestellt ist und Siri mitliest: Mensa auf der Startseite, Preisgruppe und Filter.
nonisolated struct SiriMensaEinstellungen: Equatable, Sendable {
    var startseite: MensaVenue = .mensaEhrenberg
    var preisgruppe: MensaPriceGroup = .studierende
    var appFilter = MensaFilter()

    static func lesen(defaults: UserDefaults = AppGroup.defaults) -> SiriMensaEinstellungen {
        SiriMensaEinstellungen(
            startseite: defaults.string(forKey: AppGroup.heuteMensaSchluessel).flatMap(MensaVenue.init(rawValue:)) ?? .mensaEhrenberg,
            preisgruppe: defaults.string(forKey: AppGroup.preisgruppeSchluessel).flatMap(MensaPriceGroup.init(rawValue:)) ?? .studierende,
            appFilter: MensaFilterStore.load(defaults: defaults)
        )
    }
}

/// Die Frage an „Mensa heute“.
nonisolated struct SiriMensaFrage: Equatable, Sendable {
    var mensa: MensaOrt?
    var ernaehrung: Ernaehrung?
    var filterAnwenden = true
}

/// Mittags haben mehrere Cafeterien offen: Siri fragt nach. Zur Wahl stehen nur die offenen.
nonisolated struct SiriCafeteriaRueckfrage: Equatable, Sendable {
    struct Option: Equatable, Sendable {
        let ort: MensaOrt
        /// „offen bis 14:00“
        let status: String
    }

    var optionen: [Option]
}

nonisolated enum SiriMensaErgebnis: Equatable, Sendable {
    case antwort(SiriMensaAntwort)
    case rueckfrage(SiriCafeteriaRueckfrage)
}

nonisolated enum SiriMensa {
    typealias P = MensaWidgetPhasen
    typealias Anzeige = MensaWidgetAnzeige

    static let keineDaten = "Ich komme gerade nicht an den Speiseplan. Versuch es gleich noch mal."

    /// Die Cafeterien, die „Cafeteria“ ohne Ort meint.
    static let cafeterien: [MensaVenue] = [.cafeteriaEhrenberg, .nanoteria, .roentgenbau]

    // MARK: Einstieg

    static func heute(
        _ frage: SiriMensaFrage, snapshot: WidgetSnapshot, einstellungen: SiriMensaEinstellungen, jetzt: Date
    ) -> SiriMensaErgebnis {
        guard !snapshot.mensen.isEmpty else { return .antwort(SiriMensaAntwort(sagt: keineDaten, karte: nil)) }
        let kontext = Kontext(frage: frage, snapshot: snapshot, einstellungen: einstellungen, jetzt: jetzt)

        var venue = einstellungen.startseite
        var cafeteriaZu = false
        if let ort = frage.mensa {
            if let gewaehlt = ort.venue {
                venue = gewaehlt
            } else {
                switch cafeteria(snapshot: snapshot, jetzt: jetzt) {
                case .eine(let gefunden, let zu):
                    venue = gefunden
                    cafeteriaZu = zu
                case .rueckfrage(let rueckfrage):
                    return .rueckfrage(rueckfrage)
                }
            }
        }
        return .antwort(antwort(venue: venue, kontext: kontext, vorsatz: cafeteriaZu ? "Heute haben die Cafeterien zu." : nil))
    }

    // MARK: „Cafeteria“ ohne Ort

    enum CafeteriaWahl: Equatable, Sendable {
        /// Genau eine passt. `keineOffen`: Es hat heute keine mehr offen, es ist die nächste, die öffnet.
        case eine(MensaVenue, keineOffen: Bool)
        case rueckfrage(SiriCafeteriaRueckfrage)
    }

    /// Welche Cafeteria „Cafeteria“ meint:
    /// - mittags die einzige offene, bei mehreren die Rückfrage mit den offenen,
    /// - hat jetzt keine offen, aber später heute eine, die zuerst öffnende,
    /// - nachmittags und abends die mit Abendessen (aus den Daten),
    /// - sonst die, die am nächsten Öffnungstag zuerst öffnet.
    static func cafeteria(snapshot: WidgetSnapshot, jetzt: Date) -> CafeteriaWahl {
        let minuten = HeuteUhr.minuten(jetzt)
        func zeiten(_ venue: MensaVenue) -> (oeffnet: Int, schliesst: Int)? { P.zeiten(venue, am: jetzt, in: snapshot) }
        func frage(_ venues: [MensaVenue], _ status: (MensaVenue) -> String) -> CafeteriaWahl {
            .rueckfrage(SiriCafeteriaRueckfrage(optionen: venues.map { .init(ort: MensaOrt($0), status: status($0)) }))
        }

        if minuten < P.abendessenBeginn {
            let offen = cafeterien.filter { venue in zeiten(venue).map { $0.oeffnet <= minuten && minuten < $0.schliesst } ?? false }
            if offen.count == 1 { return .eine(offen[0], keineOffen: false) }
            if offen.count > 1 {
                return frage(offen) { "offen bis " + HeuteUhr.uhrzeit(minuten: zeiten($0)?.schliesst ?? 0) }
            }
            let spaeter = cafeterien.compactMap { venue in zeiten(venue).flatMap { $0.oeffnet > minuten ? (venue, $0.oeffnet) : nil } }
            if let fruehestes = spaeter.map(\.1).min() {
                let kandidaten = spaeter.filter { $0.1 == fruehestes }.map(\.0)
                if kandidaten.count == 1 { return .eine(kandidaten[0], keineOffen: false) }
                return frage(kandidaten) { _ in "öffnet um " + HeuteUhr.uhrzeit(minuten: fruehestes) }
            }
        }
        if minuten < P.abendessenEnde {
            let orte = P.abendessenOrte(snapshot: snapshot, tag: EventKalender.berlinDatum(jetzt)).filter(cafeterien.contains)
            if orte.count == 1 { return .eine(orte[0], keineOffen: false) }
            if orte.count > 1 {
                return frage(orte) { _ in "Abendessen bis " + HeuteUhr.uhrzeit(minuten: P.abendessenEnde) }
            }
        }
        let kandidaten = cafeterien.map { ($0, P.naechsterOeffnungstag(snapshot: snapshot, mensaID: $0.rawValue, jetzt: jetzt)) }
        // Bevorzugt eine, die am nächsten Öffnungstag auch Mittag kocht (die Cafeteria Ehrenberg hat oft nur Abendessen).
        let mitMittag = kandidaten.filter { venue, tag in
            P.plan(venue, tag: tag.tag, in: snapshot)?.gerichte.contains { !$0.abendessen } == true
        }
        let naechste = (mitMittag.isEmpty ? kandidaten : mitMittag)
            .min { ($0.1.tag, $0.1.oeffnet ?? 24 * 60) < ($1.1.tag, $1.1.oeffnet ?? 24 * 60) }
        return .eine(naechste?.0 ?? .cafeteriaEhrenberg, keineOffen: true)
    }

    // MARK: Kontext

    private nonisolated struct Kontext {
        let frage: SiriMensaFrage
        let snapshot: WidgetSnapshot
        let einstellungen: SiriMensaEinstellungen
        let jetzt: Date

        /// Der Filter für diese Antwort. Die Ernährung aus der Frage ersetzt die Stufe des App-Filters und gilt nur hier;
        /// „Nur Bio“ und ausgeschlossene Allergene aus der App gelten weiter, solange `filterAnwenden` an ist.
        var filter: MensaFilter? {
            var filter = frage.filterAnwenden ? einstellungen.appFilter : MensaFilter()
            if let ernaehrung = frage.ernaehrung { filter.diet = ernaehrung.stufe }
            return filter.isActive ? filter : nil
        }

        /// Alles aus dem App-Filter außer der Stufe: „nur Bio und ohne Milch“.
        var zusatz: String {
            let teile = (filter?.summaryParts ?? []).map { $0.prefix(1).lowercased() + $0.dropFirst() }
            return teile.isEmpty ? "" : ", " + teile.joined(separator: " und ")
        }

        func anzeige(_ venue: MensaVenue, _ zeit: Date) -> Anzeige {
            P.anzeige(
                snapshot: snapshot, mensaID: venue.rawValue, preisgruppe: einstellungen.preisgruppe, jetzt: zeit, filter: filter
            )
        }
    }

    /// Die Mahlzeit einer Anzeige: wie Siri sie nennt und wie die Karte sie beschriftet.
    private nonisolated struct Mahlzeit {
        /// „Zum Mittag“, „Heute Mittag“, „Zum Abendessen“, „Morgen Mittag“
        var anfang: String
        /// „ab 11 Uhr“, „bis 19:30 Uhr“
        var zeit: String?
        var ort: MensaVenue
        /// Steht vor dem Satz: „Heute gibt es nichts mehr.“
        var vorsatz: String?
        /// Steht hinter dem Satz: „Geöffnet bis 14 Uhr.“
        var nachsatz: String?
        var kicker: String
        /// „heute“, „morgen“ oder „Montag“, für „Für heute ist der Speiseplan noch nicht da.“
        var tagwort: String
        var istHeute: Bool
        var abend: Bool
        /// „Mittagsangebot“ oder „Abendangebot“, wenn der Fuß sonst nichts zu sagen hat.
        var angebot: String { abend ? "Abendangebot" : "Mittagsangebot" }

        var heuteZusatz: String { istHeute && !anfang.hasPrefix("Heute") ? " heute" : "" }
    }

    // MARK: Antwort

    private static func antwort(venue: MensaVenue, kontext k: Kontext, vorsatz: String?) -> SiriMensaAntwort {
        var rechenzeit = k.jetzt
        var anzeige = k.anzeige(venue, rechenzeit)
        // Nach der Schließzeit und ohne Abendessen heute gilt dasselbe wie nach dem Abendessen: nichts mehr, dann der
        // nächste Öffnungstag. Das Widget zeigt dann noch den Mittagsplan von heute; Siri soll ihn nicht vorlesen.
        if anzeige.phase == .nachmittag || anzeige.phase == .abend,
           P.abendessenOrt(snapshot: k.snapshot, mensaID: venue.rawValue, jetzt: rechenzeit) == nil {
            rechenzeit = HeuteUhr.datum(am: k.jetzt, minuten: P.abendessenEnde)
            anzeige = k.anzeige(venue, rechenzeit)
        }
        let mahlzeit = mahlzeit(anzeige, venue: venue, kontext: k, rechenzeit: rechenzeit, vorsatz: vorsatz)
        return satz(anzeige, mahlzeit, venue: venue, kontext: k)
    }

    private static func mahlzeit(
        _ anzeige: Anzeige, venue: MensaVenue, kontext k: Kontext, rechenzeit: Date, vorsatz: String?
    ) -> Mahlzeit {
        let minuten = HeuteUhr.minuten(rechenzeit)
        let zeiten = P.zeiten(venue, am: rechenzeit, in: k.snapshot)

        switch anzeige.phase {
        case .morgen where zeiten.map({ minuten < $0.oeffnet }) ?? true:
            return Mahlzeit(
                anfang: "Heute Mittag", zeit: zeiten.map { "ab " + SiriSprache.uhr($0.oeffnet) }, ort: venue, vorsatz: vorsatz,
                kicker: anzeige.kicker, tagwort: "heute", istHeute: true, abend: false
            )
        case .morgen, .mittag:
            return Mahlzeit(
                anfang: "Zum Mittag", ort: venue, vorsatz: vorsatz,
                nachsatz: zeiten.map { "Geöffnet bis \(SiriSprache.uhr($0.schliesst))." },
                kicker: anzeige.kicker, tagwort: "heute", istHeute: true, abend: false
            )
        case .nachmittag, .abend:
            let ort = P.abendessenOrt(snapshot: k.snapshot, mensaID: venue.rawValue, jetzt: rechenzeit) ?? venue
            let laeuft = anzeige.phase == .abend
            let zeit = laeuft ? P.abendessenEnde : P.abendessenBeginn
            return Mahlzeit(
                anfang: "Zum Abendessen", zeit: (laeuft ? "bis " : "ab ") + SiriSprache.uhr(zeit), ort: ort, vorsatz: vorsatz,
                kicker: "Abendessen · " + (laeuft ? "bis " : "ab ") + HeuteUhr.uhrzeit(minuten: zeit),
                tagwort: "heute", istHeute: true, abend: true
            )
        case .nacht, .geschlossen:
            let (_, datum, oeffnet) = P.naechsterOeffnungstag(snapshot: k.snapshot, mensaID: venue.rawValue, jetzt: k.jetzt)
            let wort = SiriSprache.tagwort(datum, jetzt: k.jetzt)
            let standard = anzeige.phase == .nacht
                ? "Heute gibt es nichts mehr."
                : "\(SiriSprache.satzanfang(venue.sprechSubjekt)) hat heute zu."
            return Mahlzeit(
                anfang: "\(wort) Mittag", zeit: oeffnet.map { "ab " + SiriSprache.uhr($0) }, ort: venue, vorsatz: vorsatz ?? standard,
                kicker: "Mittag " + (wort == "Morgen" ? "morgen" : wort) + (oeffnet.map { " · ab " + HeuteUhr.uhrzeit(minuten: $0) } ?? ""),
                tagwort: wort == "Morgen" ? "morgen" : wort, istHeute: false, abend: false
            )
        }
    }

    // MARK: Satz und Karte

    private static func satz(_ anzeige: Anzeige, _ mahlzeit: Mahlzeit, venue: MensaVenue, kontext k: Kontext) -> SiriMensaAntwort {
        let vorsatz = mahlzeit.vorsatz.map { $0 + " " } ?? ""
        let ohneFilter = anzeige.filterung?.ohneFilterAnzahl ?? anzeige.zeilen.count

        // Kein Plan (oder der Plan hat in dieser Mahlzeit keine Gerichte).
        if anzeige.planTag == nil || ohneFilter == 0 {
            return SiriMensaAntwort(sagt: "\(vorsatz)Für \(mahlzeit.tagwort) ist der Speiseplan noch nicht da.", karte: nil)
        }

        let standardKarte = karte(anzeige, mahlzeit, k)

        // Der Filter lässt nichts durch.
        if anzeige.zeilen.isEmpty {
            if let ernaehrung = k.frage.ernaehrung {
                var sagt = "\(vorsatz)\(mahlzeit.anfang) gibt es\(mahlzeit.heuteZusatz) nichts \(ernaehrung.nichts)."
                if let (naechste, naechsteMahlzeit) = naechsteMitPassendem(anzeige.phase, venue: venue, kontext: k) {
                    let name = naechsteMahlzeit.abend ? "Heute Abend" : naechsteMahlzeit.anfang
                    sagt += " \(name) \(naechsteMahlzeit.ort.sprechOrt): \(SiriSprache.namen(naechste.zeilen))."
                    return SiriMensaAntwort(sagt: sagt, karte: karte(naechste, naechsteMahlzeit, k))
                }
                return SiriMensaAntwort(sagt: sagt, karte: standardKarte)
            }
            let sagt = "\(vorsatz)\(mahlzeit.anfang) passt\(mahlzeit.heuteZusatz) nichts zu deinem Filter. "
                + "Ohne Filter gibt es \(SiriSprache.gerichteAnzahl(ohneFilter))."
            return SiriMensaAntwort(sagt: sagt, karte: standardKarte)
        }

        let zeit = mahlzeit.zeit.map { " " + $0 } ?? ""
        let ort = mahlzeit.ort.sprechOrt
        let liste = SiriSprache.gerichte(anzeige.zeilen)
        // Hat der Plan mehr passende Gerichte als genannt werden, heißt es „zum Beispiel“.
        let trenner = anzeige.gesamt > anzeige.zeilen.count ? ", zum Beispiel " : ": "

        var haupt: String
        if anzeige.filterung != nil {
            if let ernaehrung = k.frage.ernaehrung {
                haupt = "\(mahlzeit.anfang) gibt es\(zeit) \(ort) \(ernaehrung.gerichte(anzeige.gesamt))\(k.zusatz)\(trenner)\(liste)."
            } else {
                let verb = anzeige.gesamt == 1 ? "passt" : "passen"
                let anzahl = anzeige.gesamt == 1 ? "ein Gericht" : "\(SiriSprache.zahl(anzeige.gesamt)) Gerichte"
                haupt = "\(mahlzeit.anfang) \(verb)\(zeit) \(ort) \(anzahl) zu deinem Filter\(trenner)\(liste)."
            }
        } else {
            haupt = "\(mahlzeit.anfang) gibt es\(zeit) \(ort) \(liste)."
        }
        let nachsatz = mahlzeit.nachsatz.map { " " + $0 } ?? ""
        return SiriMensaAntwort(sagt: vorsatz + haupt + nachsatz, karte: standardKarte)
    }

    /// Die nächste Mahlzeit mit passenden Gerichten: später heute das Abendessen, dann der nächste Öffnungstag.
    /// Gerechnet wird mit der Anzeige des Widgets zu einer späteren Uhrzeit, nicht mit eigenen Regeln.
    private static func naechsteMitPassendem(_ phase: Anzeige.Phase, venue: MensaVenue, kontext k: Kontext) -> (Anzeige, Mahlzeit)? {
        let proben: [Int] = switch phase {
        case .morgen, .mittag: [P.abendessenBeginn, P.abendessenEnde]
        case .nachmittag, .abend: [P.abendessenEnde]
        case .nacht, .geschlossen: []
        }
        for minuten in proben {
            let zeit = HeuteUhr.datum(am: k.jetzt, minuten: minuten)
            if minuten == P.abendessenBeginn, P.abendessenOrt(snapshot: k.snapshot, mensaID: venue.rawValue, jetzt: zeit) == nil {
                continue
            }
            let anzeige = k.anzeige(venue, zeit)
            if !anzeige.zeilen.isEmpty {
                var naechste = mahlzeit(anzeige, venue: venue, kontext: k, rechenzeit: zeit, vorsatz: nil)
                if minuten == P.abendessenBeginn {
                    // Zum Beginn rechnet die Anzeige schon „läuft“; die Vorschau auf das Abendessen heißt „ab 16:30“.
                    naechste.zeit = "ab " + SiriSprache.uhr(minuten)
                    naechste.kicker = "Abendessen · ab " + HeuteUhr.uhrzeit(minuten: minuten)
                }
                return (anzeige, naechste)
            }
        }
        return nil
    }

    private static func karte(_ anzeige: Anzeige, _ mahlzeit: Mahlzeit, _ k: Kontext) -> SiriMensaKarte {
        var filterzeile: String?
        var fuss = mahlzeit.angebot
        if let filterung = anzeige.filterung {
            if let ernaehrung = k.frage.ernaehrung {
                filterzeile = ([ernaehrung.bezeichnung + " – aus deiner Frage"] + (k.filter?.summaryParts ?? [])).joined(separator: " · ")
                fuss = "Ohne Filter: " + SiriSprache.gerichteAnzahl(filterung.ohneFilterAnzahl)
            } else {
                filterzeile = "Gefiltert: " + filterung.kurztext
                fuss = filterung.ohneFilterText
            }
        } else if anzeige.gesamt > anzeige.zeilen.count {
            fuss = "+\(anzeige.gesamt - anzeige.zeilen.count) weitere Gerichte"
        }
        return SiriMensaKarte(
            kicker: mahlzeit.kicker,
            titel: mahlzeit.ort.displayName,
            filterzeile: filterzeile, gerichte: anzeige.zeilen, fuss: fuss, kopfLink: anzeige.kopfLink
        )
    }
}

// MARK: - Ernährung in Sätzen

extension Ernaehrung {
    /// Die Stufe des Filters der App, die diese Frage meint. „Vegetarisch“ lässt auch Veganes durch.
    nonisolated var stufe: MensaDiet {
        switch self {
        case .vegetarisch: .vegetarisch
        case .vegan: .vegan
        }
    }

    /// „Vegetarisch“, „Vegan“ (Karte).
    nonisolated var bezeichnung: String {
        switch self {
        case .vegetarisch: "Vegetarisch"
        case .vegan: "Vegan"
        }
    }

    /// „nichts Vegetarisches“ (Satz).
    nonisolated var nichts: String {
        switch self {
        case .vegetarisch: "Vegetarisches"
        case .vegan: "Veganes"
        }
    }

    /// „ein vegetarisches Gericht“, „zwei vegetarische Gerichte“.
    nonisolated func gerichte(_ anzahl: Int) -> String {
        let (einzahl, mehrzahl) = switch self {
        case .vegetarisch: ("vegetarisches", "vegetarische")
        case .vegan: ("veganes", "vegane")
        }
        return anzahl == 1 ? "ein \(einzahl) Gericht" : "\(SiriSprache.zahl(anzahl)) \(mehrzahl) Gerichte"
    }
}
