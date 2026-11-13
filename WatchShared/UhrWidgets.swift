import Foundation

// Die Rechnung hinter den Watch-Widgets (Zifferblatt und Smart Stack): Zeitleisten, Relevanz und fertige Texte als
// reine Funktionen, damit sie sich mit fester Uhrzeit testen lassen. Die Regeln selbst stehen in `Shared/`
// (`MensaSperrePhasen`, `MensaWidgetPhasen`, `AbendWidgetPhasen`, `SmartStack`); hier steht nur, wie die Uhr sie
// zusammensetzt. Die Widget-Familien zeichnen nur noch.
// Diese Datei gehört zu iPhone-App (nur für die Tests), Watch-App und Watch-Widgets.

/// Namen (`kind`) der Watch-Widgets. Die Watch-App lädt damit gezielt deren Zeitleisten neu.
nonisolated enum UhrWidgetKinds {
    static let mensa = "de.kai-gothe.Campus-Ilmenau.watch.widget.mensa"
    static let heuteAbend = "de.kai-gothe.Campus-Ilmenau.watch.widget.heute-abend"
    static let merkliste = "de.kai-gothe.Campus-Ilmenau.watch.widget.merkliste"

    static let alle = [mensa, heuteAbend, merkliste]
}

// MARK: - Links der Mensa-Widgets

/// Der Link, den ein Mensa-Widget beim Tippen öffnet. Bei „Noch offen · Nanoteria“ gibt er die Mensa mit und bittet
/// die Watch-App, sie bis Mitternacht zu wählen (wie die Hinweiskarte in der Mensa-Ansicht), sonst läge man bei der
/// geschlossenen Mensa. Der Zusatz `waehlen=1` steht nur hier; `DeepLink` liest ihn nicht und bleibt unverändert.
nonisolated enum UhrMensaLink {
    static let waehlen = "waehlen"

    /// - Parameter rechteck: Das Rechteck führt sonst zum Gericht, alle anderen Familien zum Speiseplan.
    static func url(_ sperre: MensaSperreAnzeige, rechteck: Bool = false) -> URL {
        guard sperre.phase == .nochOffen else { return rechteck ? sperre.rechteckLink : sperre.speiseplanLink }
        // Ohne Gericht zeigt auch das Rechteck nur den Speiseplan; die Mensa ist der Sinn des Links.
        return mensa(MensaVenue(rawValue: sperre.mensaID), waehlen: true)
    }

    /// `campusilmenau://mensa?mensa=<id>`; mit `waehlen: true` wählt die Watch-App die Mensa bis Mitternacht (wie die
    /// Hinweiskarte in „Mensa heute“). Ohne Mensa der Speiseplan der gerade gewählten.
    static func mensa(_ venue: MensaVenue?, waehlen wahl: Bool) -> URL {
        let url = DeepLink.mensa(id: venue?.rawValue).url
        guard wahl, var komponenten = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        komponenten.queryItems = (komponenten.queryItems ?? []) + [URLQueryItem(name: waehlen, value: "1")]
        return komponenten.url ?? url
    }

    /// Die Mensa, die der Link wählen soll; `nil` für alle anderen Links.
    static func gewaehlteMensa(_ url: URL) -> MensaVenue? {
        guard case .mensa(let id?)? = DeepLink(url: url),
              URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == waehlen && $0.value == "1" }) == true
        else { return nil }
        return MensaVenue(rawValue: id)
    }
}

// MARK: - Gespeicherter Stand

/// Was die Watch-App in ihrer App Group ablegt und die Watch-Widgets lesen: die Einstellungen vom iPhone und die
/// Merkliste samt Standorten. Die Schlüssel stehen nur hier.
nonisolated enum UhrSpeicher {
    static let eintraege = "uhrMerkliste"
    static let staende = "uhrRegalStaende"

    /// Die Einstellungen vom iPhone; ohne sie Ehrenberg, Studierende, kein Filter.
    static func einstellungen(defaults: UserDefaults = AppGroup.defaults) -> UhrEinstellungen {
        defaults.dictionary(forKey: UhrEinstellungen.speicherSchluessel).flatMap(UhrEinstellungen.init(kontext:)) ?? .vorgabe
    }

    static func merkliste(defaults: UserDefaults = AppGroup.defaults) -> [UhrMerklisteEintrag] {
        (defaults.array(forKey: eintraege) as? [[String: Any]])?.compactMap(UhrMerklisteEintrag.init(kontext:)) ?? []
    }

    static func regalStaende(defaults: UserDefaults = AppGroup.defaults) -> [String: UhrRegalStand] {
        defaults.data(forKey: staende).flatMap { try? JSONDecoder().decode([String: UhrRegalStand].self, from: $0) } ?? [:]
    }
}

// MARK: - Mensa heute

/// Zeitleiste des Widgets „Mensa heute“ auf der Uhr. Anders als die Mensa-Ansicht wechselt das Widget wie der
/// iPhone-Sperrbildschirm von selbst: Hat die gewählte Mensa zu und eine andere noch Mittag, zeigt es die, die am
/// längsten offen hat („Noch offen · Nanoteria“).
nonisolated enum UhrMensaZeitleiste {
    struct Eintrag: Equatable, Sendable {
        var date: Date
        var sperre: MensaSperreAnzeige
        /// Wie wichtig der Eintrag im Smart Stack ist (`SmartStack`): Der Wert der Phase der gewählten Mensa, gültig
        /// bis zum nächsten Eintrag.
        var relevanz: SmartStack.Relevanz
    }

    /// Ein Eintrag jetzt und je einer pro Zeitpunkt der Rotation (alle 5 Minuten) und der Phasenwechsel. Folgt auf einen
    /// Eintrag ein gleicher, entfällt er (ein einzelnes Gericht ändert sich nicht alle 5 Minuten). Mensa, Preisgruppe
    /// und Filter kommen vom iPhone.
    static func eintraege(snapshot: WidgetSnapshot, einstellungen: UhrEinstellungen, ab jetzt: Date) -> [Eintrag] {
        let venue = einstellungen.mensa
        let filter = einstellungen.filter.isActive ? einstellungen.filter : nil
        let zeitpunkte = [jetzt] + MensaSperrePhasen.zeitpunkte(snapshot: snapshot, nach: jetzt)
        var letzte: MensaSperreAnzeige?
        let behalten: [(date: Date, sperre: MensaSperreAnzeige)] = zeitpunkte.compactMap { zeit in
            let sperre = MensaSperrePhasen.anzeige(
                snapshot: snapshot, mensaID: venue.rawValue, preisgruppe: einstellungen.preisgruppe, jetzt: zeit, filter: filter
            )
            defer { letzte = sperre }
            return sperre == letzte ? nil : (zeit, sperre)
        }
        // Relevanz nach der Phase der gewählten Mensa (Phasen des Home-Widgets): 80 ab 10:30 bis zur Schließzeit und
        // während des Abendessens, 40 bis 10:30 und zwischen Mittag und Abendessen, danach 0.
        let phasen = behalten.map {
            MensaWidgetPhasen.anzeige(
                snapshot: snapshot, mensaID: venue.rawValue, preisgruppe: einstellungen.preisgruppe, jetzt: $0.date, filter: filter
            )
        }
        let relevanzen = MensaWidgetPhasen.relevanzen(
            anzeigen: phasen, zeitpunkte: behalten.map(\.date), ende: MensaWidgetPhasen.naechsteNeuladung(nach: jetzt)
        )
        return zip(behalten, relevanzen).map { Eintrag(date: $0.date, sperre: $0.sperre, relevanz: $1) }
    }

    /// Wann das Widget neu lädt: nach höchstens 3 Stunden, nie über Mitternacht (6:00) hinaus.
    static func neuladen(nach jetzt: Date) -> Date {
        let ende = MensaSperrePhasen.ende(nach: jetzt)
        return ende < EventKalender.tag(jetzt, plus: 1) ? ende : MensaWidgetPhasen.naechsteNeuladung(nach: jetzt)
    }
}

// MARK: - Heute Abend

/// Was das Widget „Heute Abend“ auf der Uhr in Rechteck, Kreis und Zeile zeigt, fertig als Text.
nonisolated struct UhrAbendWidgetAnzeige: Equatable, Sendable {
    /// „Läuft gerade · Studi-Club“, „Heute Abend“, „Morgen Abend“; das Rechteck setzt ihn in Versalien.
    var kicker: String
    /// „Spieleabend“ (läuft) oder „19:00 Spieleabend“; leer, wenn nichts eingetragen ist.
    var titel: String
    /// Unten links: „Dann 21:00“ (läuft), sonst der Ort.
    var links: String
    /// Unten rechts: „Open Stage“ (das Nächste) oder „+2 weitere“.
    var rechts: String
    /// Der Titel ist abgesagt (durchgestrichen, „fällt aus“ steht links).
    var abgesagt = false
    /// Der Stern hinter dem Titel.
    var gemerkt = false
    /// Die Zeile: „21:00 Open Stage“, „Läuft · Spieleabend · Studi-Club“ oder „Morgen 21:00 Halloween-Party“.
    var zeile: String
    /// Der Kreis: Uhrzeit des Nächsten und Kurztitel; `nil` ohne Veranstaltung (dann nur der Mond).
    var kreisZeit: String?
    var kreisWort: String
    /// VoiceOver für den Kreis: „Heute Abend, als Nächstes 21:00 Open Stage“.
    var kreisBeschriftung: String
    /// Tippen (Rechteck, Zeile, Kreis): „Heute Abend“ in der Watch-App, ohne Veranstaltung die Liste.
    var link: URL

    var istLeer: Bool { titel.isEmpty }

    static func erstelle(snapshot: WidgetSnapshot, jetzt: Date) -> UhrAbendWidgetAnzeige {
        let a = AbendWidgetPhasen.anzeige(
            events: snapshot.events, gemerkteIDs: Set(snapshot.gemerkteEventIDs), woche: snapshot.woche, jetzt: jetzt
        )
        let events = Dictionary(snapshot.events.map { ($0.id, $0) }, uniquingKeysWith: { erstes, _ in erstes })
        func ort(_ zeile: AbendWidgetAnzeige.Zeile) -> String {
            events[zeile.id]?.ort?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        // Abgesagte werden übersprungen, wie auf dem iPhone-Sperrbildschirm; Laufendes steht schon vorn.
        let offen = a.zeilen.filter { !$0.abgesagt }
        let laufend = offen.first { $0.laeuft }
        let kommend = offen.filter { !$0.laeuft }
        let link = a.kopfLink
        let leerLink = a.sperre.link

        if let laufend {
            let danach = kommend.first
            let wo = ort(laufend)
            var bis = ""
            if let event = events[laufend.id], event.ende != nil { bis = "bis \(HeuteUhr.uhrzeit(AbendBezug.ende(event)))" }
            return UhrAbendWidgetAnzeige(
                kicker: wo.isEmpty ? "Läuft gerade" : "Läuft gerade · \(wo)", titel: laufend.titel,
                links: danach.map { "Dann \($0.zeit)" } ?? bis, rechts: danach?.titel ?? "",
                gemerkt: laufend.gemerkt,
                zeile: danach.map { "\($0.zeit) \($0.titel)" } ?? a.sperre.zeile,
                kreisZeit: danach?.zeit ?? nilWennLeer(a.sperre.kreis.gross),
                kreisWort: danach?.titel ?? a.sperre.kreis.klein,
                kreisBeschriftung: danach.map { "Heute Abend, läuft gerade, als Nächstes \($0.zeit) \($0.titel)" }
                    ?? "Heute Abend, \(laufend.titel) läuft gerade",
                link: link
            )
        }
        if let erste = kommend.first {
            let weitere = kommend.count - 1
            let morgen = a.zeigtMorgen
            return UhrAbendWidgetAnzeige(
                kicker: morgen ? "Morgen Abend" : "Heute Abend", titel: "\(erste.zeit) \(erste.titel)",
                links: ort(erste), rechts: weitere > 0 ? "+\(weitere) weitere" : "",
                gemerkt: erste.gemerkt,
                zeile: morgen ? a.sperre.zeile : "\(erste.zeit) \(erste.titel)",
                kreisZeit: erste.zeit, kreisWort: erste.titel,
                kreisBeschriftung: "\(morgen ? "Morgen Abend" : "Heute Abend"), als Nächstes \(erste.zeit) \(erste.titel)",
                link: link
            )
        }
        // Nur Abgesagtes oder nichts: so, wie der iPhone-Sperrbildschirm es sagt.
        let r = a.sperre.rechteck
        guard !a.leer || r.abgesagt else {
            return UhrAbendWidgetAnzeige(
                kicker: "Heute Abend", titel: "", links: "", rechts: "", zeile: a.sperre.zeile,
                kreisZeit: nil, kreisWort: "", kreisBeschriftung: "Heute Abend nichts eingetragen", link: leerLink
            )
        }
        return UhrAbendWidgetAnzeige(
            kicker: r.kicker, titel: r.titel, links: r.unterzeile, rechts: "", abgesagt: r.abgesagt, gemerkt: r.gemerkt,
            zeile: a.sperre.zeile, kreisZeit: nilWennLeer(a.sperre.kreis.gross), kreisWort: a.sperre.kreis.klein,
            kreisBeschriftung: a.sperre.kreis.beschriftung, link: link
        )
    }

    private static func nilWennLeer(_ text: String) -> String? { text.isEmpty ? nil : text }
}

/// Zeitleiste des Widgets „Heute Abend“ auf der Uhr: ein Eintrag zu jedem Beginn und Ende (dann wechselt „Läuft gerade“
/// ohne Nachladen), dazu zu 17 Uhr und 30 Minuten vor jedem Beginn (dort ändert sich nur die Relevanz).
nonisolated enum UhrAbendZeitleiste {
    struct Eintrag: Equatable, Sendable {
        var date: Date
        var anzeige: UhrAbendWidgetAnzeige
        /// 40 ab 17 Uhr, 80 ab 30 Minuten vor Beginn und solange etwas läuft, sonst 0 (`AbendWidgetPhasen.relevanz`).
        var relevanz: SmartStack.Relevanz
    }

    static func eintraege(snapshot: WidgetSnapshot, ab jetzt: Date) -> [Eintrag] {
        let zeitpunkte = [jetzt] + AbendWidgetPhasen.wechsel(events: snapshot.events, nach: jetzt)
        let relevanzen = AbendWidgetPhasen.relevanzen(events: snapshot.events, zeitpunkte: zeitpunkte)
        return zip(zeitpunkte, relevanzen).map { zeit, relevanz in
            Eintrag(date: zeit, anzeige: UhrAbendWidgetAnzeige.erstelle(snapshot: snapshot, jetzt: zeit), relevanz: relevanz)
        }
    }

    /// Nach einer Stunde lädt das Widget neu (Absagen sehen).
    static func neuladen(nach jetzt: Date) -> Date {
        AbendWidgetPhasen.zeitleistenEnde(nach: jetzt)
    }
}

// MARK: - Merkliste

/// Der Kreis „3 im Regal“; ohne Einträge nur das Lesezeichen.
nonisolated struct UhrMerklisteWidgetAnzeige: Equatable, Sendable {
    /// Titel im Regal; `nil`, wenn nichts auf der Liste steht.
    var imRegal: Int?
    var beschriftung: String

    static func erstelle(eintraege: [UhrMerklisteEintrag], staende: [String: UhrRegalStand]) -> UhrMerklisteWidgetAnzeige {
        guard !eintraege.isEmpty else { return UhrMerklisteWidgetAnzeige(imRegal: nil, beschriftung: "Merkliste, leer") }
        let anzeige = UhrMerklisteAnzeige.erstelle(eintraege: eintraege, staende: staende)
        let imRegal = anzeige.abschnitte.first { $0.art == .imRegal }?.zeilen.count ?? 0
        return UhrMerklisteWidgetAnzeige(imRegal: imRegal, beschriftung: "Merkliste, \(imRegal) im Regal")
    }

    /// Aus dem Stand in der Watch-App-Group.
    static func gespeichert(defaults: UserDefaults = AppGroup.defaults) -> UhrMerklisteWidgetAnzeige {
        erstelle(eintraege: UhrSpeicher.merkliste(defaults: defaults), staende: UhrSpeicher.regalStaende(defaults: defaults))
    }
}
