import Foundation

/// Was das Widget „Heute Abend“ zu einem Zeitpunkt zeigt, fertig als Text. Die Regeln stehen in `AbendWidgetPhasen`;
/// die Ansichten zeichnen nur. Aus `WidgetEvents.dc.html` und `WidgetHeuteAbend.dc.html`.
nonisolated struct AbendWidgetAnzeige: Equatable, Sendable {
    struct Zeile: Equatable, Sendable, Identifiable {
        let id: String
        /// „19:00“
        let zeit: String
        let titel: String
        /// Ort und Veranstalter, bei einem laufenden Event mit „bis 23:00“.
        let ort: String
        let laeuft: Bool
        let abgesagt: Bool
        /// Der Stern hinter dem Titel (nur Anzeige).
        let gemerkt: Bool
        /// `campusilmenau://events/<id>`
        let link: URL
    }

    /// Das kleine Widget: ein Event, immer auf Nachtblau.
    struct Klein: Equatable, Sendable {
        /// „Heute Abend“ oder „Läuft gerade“
        var kicker: String
        var laeuft: Bool
        /// Beginn der nächsten, bei einer laufenden das Ende („bis“ steht davor). `nil`, wenn nichts eingetragen ist.
        var zeit: String?
        var titel: String
        var ort: String
        /// „+2 weitere heute“ oder „Morgen: 20:00 Filmabend“
        var fuss: String
        /// Zweite Zeile im leeren Zustand: „Morgen · 20:00 Filmabend“
        var leerText: String
        /// Das Event, sonst die Veranstaltungsliste.
        var link: URL

        var hatEvent: Bool { zeit != nil }
    }

    /// Mittleres Widget: bis zu 3 Zeilen und eventuell die Zeile „Morgen“ darunter.
    struct Mittel: Equatable, Sendable {
        var zeilen: [Zeile]
        var tail: String?
    }

    /// Großes Widget: Heute Abend, darunter „Morgen Abend“, unten der Fuß.
    struct Gross: Equatable, Sendable {
        var zeilen: [Zeile]
        var morgenZeilen: [Zeile]
        /// „+N weitere heute“ bzw. „Diese Woche: 14 Veranstaltungen“; leer, wenn beides unbekannt ist.
        var fuss: String
    }

    /// Das Widget auf dem Sperrbildschirm (Zeile, Rechteck, Kreis). Das System färbt es einfarbig.
    struct Sperrbildschirm: Equatable, Sendable {
        /// Die Zeile über der Uhr, ohne den Mond davor: „19:00 Spieleabend · Studi-Club“.
        var zeile: String

        struct Rechteck: Equatable, Sendable {
            /// „Heute Abend“, „Läuft gerade“ oder „Morgen Abend“
            var kicker: String
            /// „19:00“; bei einer laufenden gibt es keine Uhrzeit
            var zeit: String?
            var name: String
            /// „19:00 Spieleabend“, bei einer laufenden nur der Titel
            var titel: String { zeit.map { "\($0) \(name)" } ?? name }
            /// „Studi-Club · dann Open Stage“, „Studi-Club · bis 23:00“ oder „… · fällt aus“
            var unterzeile: String
            var abgesagt: Bool
            var gemerkt: Bool
        }
        var rechteck: Rechteck

        struct Kreis: Equatable, Sendable {
            /// „19:00“, bei einer laufenden die nächste; am nächsten Abend der Wochentag („Fr“). Leer: nichts da (nur der Mond).
            var gross: String
            /// „+2“, „danach“, „bis“ oder am nächsten Abend die Uhrzeit
            var klein: String
            /// „Nächste Veranstaltung 19:00, 2 weitere“ für VoiceOver
            var beschriftung: String
        }
        var kreis: Kreis

        /// Es gibt weder heute noch morgen etwas Anzeigbares.
        var leer: Bool
        /// Zeile und Rechteck: das gezeigte Event, sonst die Veranstaltungsliste.
        var link: URL
        /// Der Kreis öffnet „Heute Abend“, bei nichts die Veranstaltungsliste.
        var kreisLink: URL
    }

    var klein: Klein
    var sperre: Sperrbildschirm
    /// „Heute Abend“, oder „Morgen Abend“, wenn heute alles vorbei ist.
    var titel: String
    /// „Do 29. Okt.“
    var datum: String
    /// Die Hauptliste: heute offene Events (laufende zuerst), sonst die vom nächsten Abend.
    var zeilen: [Zeile]
    /// Die Hauptliste zeigt schon den nächsten Abend (heute ist alles vorbei).
    var zeigtMorgen: Bool
    /// Es ist nichts eingetragen: weder heute noch (bei `zeigtMorgen`) am nächsten Abend.
    var leer: Bool
    /// „Morgen · 21:00 Halloween-Party, Studi-Club“ für den leeren Zustand des mittleren Widgets.
    var leerHinweis: String
    var morgenKopf: String
    /// „Fr 30. Okt.“
    var morgenDatum: String
    /// Events des nächsten Abends, wenn heute noch etwas offen ist.
    var morgenZeilen: [Zeile]
    /// „Morgen · 20:00 Filmabend: Lola rennt“: die Zeile unter wenigen Events im mittleren Widget.
    var morgenTail: String?
    var woche: Int?
    /// `campusilmenau://events?filter=heute-abend`
    var kopfLink: URL
    /// `campusilmenau://events`
    var listeLink: URL

    // MARK: Aufteilung auf die Größen

    /// Mittel: bis zu `maxZeilen` Zeilen (3, bei großer Schrift 2). Die Morgen-Zeile steht nur, wenn alle heutigen
    /// hineinpassen und ein Morgen da ist.
    func mittel(maxZeilen: Int) -> Mittel {
        let sichtbar = Array(zeilen.prefix(maxZeilen))
        let passt = !zeigtMorgen && !leer && zeilen.count < maxZeilen
        return Mittel(zeilen: sichtbar, tail: passt ? morgenTail : nil)
    }

    /// Groß: heute bis `maxHeute`, zusammen höchstens `gesamt` Zeilen, und der nächste Abend bekommt mindestens eine.
    /// Normal 4 und 5, bei großer Schrift 3 und 4.
    func gross(maxHeute: Int, gesamt: Int) -> Gross {
        let heute = Array(zeilen.prefix(maxHeute))
        var morgen: [Zeile] = []
        if !zeigtMorgen {
            morgen = Array(morgenZeilen.prefix(max(1, gesamt - heute.count)))
        }
        let weitere = zeilen.count - heute.count
        let fuss: String
        if weitere > 0 {
            fuss = "+\(weitere) weitere " + (zeigtMorgen ? "morgen" : "heute")
        } else {
            fuss = woche.map { "Diese Woche: \($0) Veranstaltungen" } ?? ""
        }
        return Gross(zeilen: heute, morgenZeilen: morgen, fuss: fuss)
    }
}

/// Die Regeln des Widgets „Heute Abend“: Welcher Abend gilt, was ist offen, was läuft, und wann ändert sich die
/// Anzeige. Das Widget zeigt immer den Abend: heute ab 17 Uhr, nach dem letzten Ende den nächsten.
nonisolated enum AbendWidgetPhasen {
    /// So viele Zeilen hat das mittlere Widget.
    static let maxMittel = 3
    /// Groß: heute bis 4 Zeilen, zusammen höchstens 5.
    static let maxGrossHeute = 4
    static let maxGrossGesamt = 5
    /// Wie lange das System die Zeitleiste behalten soll, bis das Widget die Events neu holt (Absagen sehen).
    static let neuladenNach: TimeInterval = 60 * 60

    static func anzeige(
        events: [WidgetEvent],
        gemerkteIDs: Set<String> = [],
        woche: WidgetWoche? = nil,
        jetzt: Date
    ) -> AbendWidgetAnzeige {
        Rechner(events: events, gemerkt: gemerkteIDs, woche: woche, jetzt: jetzt).anzeige()
    }

    /// Die Zeitpunkte nach `jetzt`, an denen sich die Anzeige ändert: jeder Beginn und jedes Ende der Events von
    /// heute und morgen (dann wechselt „Läuft gerade“ ohne Nachladen) und der Tageswechsel um 6 Uhr.
    static func wechsel(events: [WidgetEvent], nach jetzt: Date) -> [Date] {
        let heute = AbendBezug.tag(jetzt)
        let bis = jetzt.addingTimeInterval(36 * 3600)
        var zeiten: [Date] = []
        for event in events where !event.ganztaegig {
            let tag = AbendBezug.tag(von: event)
            guard tag == heute || tag == EventKalender.tag(heute, plus: 1) else { continue }
            zeiten.append(event.beginn)
            zeiten.append(AbendBezug.ende(event))
        }
        // 6 Uhr: Danach gehört die Nacht zum neuen Abend.
        zeiten.append(HeuteUhr.datum(am: EventKalender.tag(heute, plus: 1), minuten: AbendBezug.tageswechselStunde * 60))
        return Array(Set(zeiten.filter { $0 > jetzt && $0 <= bis })).sorted()
    }

    static func zeitleistenEnde(nach jetzt: Date) -> Date {
        jetzt.addingTimeInterval(neuladenNach)
    }

    /// „Do 29. Okt.“
    static func datumText(_ tag: Date) -> String {
        "\(HeuteUhr.wochentagKurz(tag)) \(EventKalender.format(tag, "d. MMM"))"
    }
}

// MARK: - Rechnung

private nonisolated struct Rechner {
    let events: [WidgetEvent]
    let gemerkt: Set<String>
    let woche: WidgetWoche?
    let jetzt: Date

    typealias Anzeige = AbendWidgetAnzeige

    private var bezug: Date { AbendBezug.tag(jetzt) }
    private var morgen: Date { EventKalender.tag(bezug, plus: 1) }

    /// Alle Events eines Abends nach Beginn; Ganztägige gehören nie dazu.
    private func abend(_ tag: Date) -> [WidgetEvent] {
        events
            .filter { !$0.ganztaegig && AbendBezug.tag(von: $0) == tag }
            .sorted { $0.beginn < $1.beginn }
    }

    private func laeuft(_ event: WidgetEvent) -> Bool {
        !event.abgesagt && event.beginn <= jetzt && jetzt < AbendBezug.ende(event)
    }

    private func ort(_ event: WidgetEvent) -> String {
        [event.ort, event.veranstalter]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func zeile(_ event: WidgetEvent) -> Anzeige.Zeile {
        let live = laeuft(event)
        var ort = ort(event)
        if live, event.ende != nil {
            ort = ort.isEmpty ? "bis \(HeuteUhr.uhrzeit(AbendBezug.ende(event)))" : "\(ort) · bis \(HeuteUhr.uhrzeit(AbendBezug.ende(event)))"
        }
        return Anzeige.Zeile(
            id: event.id, zeit: HeuteUhr.uhrzeit(event.beginn), titel: event.titel, ort: ort,
            laeuft: live, abgesagt: event.abgesagt, gemerkt: gemerkt.contains(event.id), link: DeepLink.event(id: event.id).url
        )
    }

    func anzeige() -> Anzeige {
        let heuteAlle = abend(bezug)
        // Offen heißt: noch nicht zu Ende. Laufende zuerst, dann nach Beginn.
        let heuteOffen = heuteAlle
            .filter { AbendBezug.ende($0) > jetzt }
            .enumerated()
            .sorted { a, b in
                let la = laeuft(a.element), lb = laeuft(b.element)
                if la != lb { return la }
                if a.element.beginn != b.element.beginn { return a.element.beginn < b.element.beginn }
                return a.offset < b.offset
            }
            .map(\.element)
        let morgenAlle = abend(morgen)
        let morgenErstes = morgenAlle.first { !$0.abgesagt }

        // Hauptliste: heute offen; ist heute alles vorbei, der nächste Abend; war heute nichts, ist es leer.
        let zeigtMorgen = heuteOffen.isEmpty && !heuteAlle.isEmpty
        let leer = heuteOffen.isEmpty && (heuteAlle.isEmpty || morgenAlle.isEmpty)
        let hauptEvents = zeigtMorgen ? morgenAlle : heuteOffen

        let morgenText = morgenErstes.map { "Morgen · \(HeuteUhr.uhrzeit($0.beginn)) \($0.titel)" }
        let leerHinweis = morgenErstes.map { event -> String in
            let wo = event.ort?.trimmingCharacters(in: .whitespacesAndNewlines).nilWennLeer
                ?? event.veranstalter?.trimmingCharacters(in: .whitespacesAndNewlines).nilWennLeer
            return "Morgen · \(HeuteUhr.uhrzeit(event.beginn)) \(event.titel)" + (wo.map { ", \($0)" } ?? "")
        } ?? "Schau, was in den nächsten Tagen los ist."

        return Anzeige(
            klein: klein(heuteOffen: heuteOffen, morgenErstes: morgenErstes, morgenText: morgenText),
            sperre: sperre(heuteOffen: heuteOffen, morgenErstes: morgenErstes),
            titel: zeigtMorgen ? "Morgen Abend" : "Heute Abend",
            datum: AbendWidgetPhasen.datumText(zeigtMorgen ? morgen : bezug),
            zeilen: hauptEvents.map(zeile),
            zeigtMorgen: zeigtMorgen,
            leer: leer,
            leerHinweis: leerHinweis,
            morgenKopf: "Morgen Abend",
            morgenDatum: AbendWidgetPhasen.datumText(morgen),
            morgenZeilen: zeigtMorgen ? [] : morgenAlle.map(zeile),
            morgenTail: morgenText,
            woche: woche?.anzahl,
            kopfLink: DeepLink.eventsHeuteAbend.url,
            listeLink: DeepLink.events.url
        )
    }

    // MARK: Sperrbildschirm

    private func ortNur(_ event: WidgetEvent) -> String? {
        event.ort?.trimmingCharacters(in: .whitespacesAndNewlines).nilWennLeer
    }

    private func mitOrt(_ text: String, _ event: WidgetEvent) -> String {
        ortNur(event).map { "\(text) · \($0)" } ?? text
    }

    /// Zeile, Rechteck und Kreis. Abgesagte werden übersprungen; sind heute nur noch Abgesagte da, zeigt das Rechteck
    /// die erste mit „fällt aus“. Ist heute nichts mehr, springt alles auf den nächsten Abend.
    private func sperre(heuteOffen: [WidgetEvent], morgenErstes: WidgetEvent?) -> Anzeige.Sperrbildschirm {
        let liste = DeepLink.events.url
        let zeigbar = heuteOffen.filter { !$0.abgesagt }
        let uhr: (Date) -> String = { HeuteUhr.uhrzeit($0) }

        if let erstes = zeigbar.first {
            let live = laeuft(erstes)
            let danach = zeigbar.dropFirst().first
            let rest = zeigbar.count - 1

            let unterzeile: String
            if live {
                unterzeile = [ortNur(erstes), erstes.ende != nil ? "bis \(uhr(AbendBezug.ende(erstes)))" : nil]
                    .compactMap { $0 }.joined(separator: " · ")
            } else {
                unterzeile = [ortNur(erstes), danach.map { "dann \($0.titel)" }].compactMap { $0 }.joined(separator: " · ")
            }

            let kreis: Anzeige.Sperrbildschirm.Kreis
            if live {
                if let danach {
                    kreis = .init(gross: uhr(danach.beginn), klein: "danach", beschriftung: "Danach \(uhr(danach.beginn)) \(danach.titel)")
                } else if erstes.ende != nil {
                    kreis = .init(gross: uhr(AbendBezug.ende(erstes)), klein: "bis", beschriftung: "Läuft bis \(uhr(AbendBezug.ende(erstes)))")
                } else {
                    kreis = .init(gross: uhr(erstes.beginn), klein: "läuft", beschriftung: "Läuft seit \(uhr(erstes.beginn))")
                }
            } else {
                kreis = .init(
                    gross: uhr(erstes.beginn), klein: rest > 0 ? "+\(rest)" : "",
                    beschriftung: "Nächste Veranstaltung \(uhr(erstes.beginn))" + (rest > 0 ? ", \(rest) weitere" : "")
                )
            }
            return Anzeige.Sperrbildschirm(
                zeile: live ? mitOrt("Läuft · \(erstes.titel)", erstes) : mitOrt("\(uhr(erstes.beginn)) \(erstes.titel)", erstes),
                rechteck: .init(
                    kicker: live ? "Läuft gerade" : "Heute Abend",
                    zeit: live ? nil : uhr(erstes.beginn), name: erstes.titel,
                    unterzeile: unterzeile, abgesagt: false, gemerkt: gemerkt.contains(erstes.id)
                ),
                kreis: kreis, leer: false,
                link: DeepLink.event(id: erstes.id).url, kreisLink: DeepLink.eventsHeuteAbend.url
            )
        }

        // Heute bleiben nur Abgesagte, oder es ist schon alles vorbei.
        let abgesagt = heuteOffen.first
        let morgenKreis: Anzeige.Sperrbildschirm.Kreis = morgenErstes.map {
            .init(
                gross: HeuteUhr.wochentagKurz($0.beginn), klein: uhr($0.beginn),
                beschriftung: "Nächste Veranstaltung \(HeuteUhr.wochentagKurz($0.beginn)) \(uhr($0.beginn))"
            )
        } ?? .init(gross: "", klein: "", beschriftung: "Heute Abend nichts eingetragen")

        if let abgesagt {
            return Anzeige.Sperrbildschirm(
                zeile: morgenErstes.map { "Morgen \(uhr($0.beginn)) \($0.titel)" } ?? "Heute Abend nichts eingetragen",
                rechteck: .init(
                    kicker: "Heute Abend", zeit: uhr(abgesagt.beginn), name: abgesagt.titel,
                    unterzeile: [ortNur(abgesagt), "fällt aus"].compactMap { $0 }.joined(separator: " · "),
                    abgesagt: true, gemerkt: gemerkt.contains(abgesagt.id)
                ),
                kreis: morgenKreis, leer: morgenErstes == nil,
                link: DeepLink.event(id: abgesagt.id).url,
                kreisLink: morgenErstes == nil ? liste : DeepLink.eventsHeuteAbend.url
            )
        }

        if let morgen = morgenErstes {
            return Anzeige.Sperrbildschirm(
                zeile: "Morgen \(uhr(morgen.beginn)) \(morgen.titel)",
                rechteck: .init(
                    kicker: "Morgen Abend", zeit: uhr(morgen.beginn), name: morgen.titel,
                    unterzeile: ortNur(morgen) ?? "", abgesagt: false, gemerkt: gemerkt.contains(morgen.id)
                ),
                kreis: morgenKreis, leer: false,
                link: DeepLink.event(id: morgen.id).url, kreisLink: DeepLink.eventsHeuteAbend.url
            )
        }

        return Anzeige.Sperrbildschirm(
            zeile: "Heute Abend nichts eingetragen",
            rechteck: .init(
                kicker: "Heute Abend", zeit: nil, name: "Nichts eingetragen", unterzeile: "Schau in die Veranstaltungen",
                abgesagt: false, gemerkt: false
            ),
            kreis: morgenKreis, leer: true, link: liste, kreisLink: liste
        )
    }

    private func klein(heuteOffen: [WidgetEvent], morgenErstes: WidgetEvent?, morgenText: String?) -> Anzeige.Klein {
        // Abgesagte werden übersprungen.
        let zeigbar = heuteOffen.filter { !$0.abgesagt }
        guard let erstes = zeigbar.first else {
            return Anzeige.Klein(
                kicker: "Heute Abend", laeuft: false, zeit: nil, titel: "", ort: "", fuss: "",
                leerText: morgenErstes.map { "Morgen · \(HeuteUhr.uhrzeit($0.beginn)) \($0.titel)" } ?? "Mehr in den Veranstaltungen",
                link: DeepLink.events.url
            )
        }
        let live = laeuft(erstes)
        let rest = zeigbar.count - 1
        let fuss: String
        if rest > 0 {
            fuss = "+\(rest) weitere heute"
        } else {
            fuss = morgenErstes.map { "Morgen: \(HeuteUhr.uhrzeit($0.beginn)) \($0.titel)" } ?? ""
        }
        return Anzeige.Klein(
            kicker: live ? "Läuft gerade" : "Heute Abend",
            laeuft: live,
            zeit: HeuteUhr.uhrzeit(live && erstes.ende != nil ? AbendBezug.ende(erstes) : erstes.beginn),
            titel: erstes.titel,
            ort: ort(erstes),
            fuss: fuss,
            leerText: "",
            link: DeepLink.event(id: erstes.id).url
        )
    }
}

private extension String {
    var nilWennLeer: String? { isEmpty ? nil : self }
}
