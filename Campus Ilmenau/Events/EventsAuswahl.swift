import Foundation

/// Die „Art“ im Filter-Sheet. Fest vorgegeben, weil die API keine Kategorien-Liste hat.
enum EventArt: String, CaseIterable, Sendable {
    case alle
    case veranstaltung
    case frist

    /// Wert für den API-Parameter `category`.
    var kategorie: String? {
        switch self {
        case .alle: nil
        case .veranstaltung: "Veranstaltung"
        case .frist: "Frist"
        }
    }
}

/// Alles, was man in der Ansicht „Veranstaltungen“ wählen kann: Tag, „Heute Abend“, „Gemerkt“, Veranstalter und
/// die beiden Einstellungen aus dem Filter-Sheet. Daraus wird der `EventFilter` für die API.
struct EventsAuswahl: Equatable, Hashable, Sendable {
    /// `nil` heißt „Ab heute“.
    var tag: Date?
    var heuteAbend = false
    /// Gilt nur in der App, die API kennt kein Merken.
    var nurGemerkt = false
    /// Name des gewählten Veranstalters, nur für die Anzeige („Alles von Café Bohne“).
    var veranstalter: String?
    /// ID des gewählten Veranstalters (`cafe-bohne`). Die API filtert nur nach der ID, nicht nach dem Namen.
    var veranstalterID: String?
    var art: EventArt = .alle
    var abgesagteAusblenden = false

    /// „Heute Abend“ für heute, so öffnet „Alle“ auf der Heute-Seite die Liste.
    static func heuteAbend(jetzt: Date = .now) -> EventsAuswahl {
        var auswahl = EventsAuswahl()
        auswahl.schalteHeuteAbend(jetzt: jetzt)
        return auswahl
    }

    /// Tag wählen; „Ab heute“ (`nil`) schaltet „Heute Abend“ aus, weil es sich nicht mit einem Zeitraum verträgt.
    mutating func waehleTag(_ neuerTag: Date?) {
        tag = neuerTag.map(EventKalender.tagesbeginn)
        if neuerTag == nil { heuteAbend = false }
    }

    /// „Heute Abend“ ein- oder ausschalten. Läuft gerade „Ab heute“, wird daraus „Heute“.
    mutating func schalteHeuteAbend(jetzt: Date) {
        heuteAbend.toggle()
        if heuteAbend, tag == nil { tag = EventKalender.tagesbeginn(jetzt) }
    }

    /// Immer nur ein Veranstalter; derselbe nochmal hebt die Wahl auf.
    mutating func schalteVeranstalter(_ name: String, id: String) {
        if veranstalterID == id {
            veranstalter = nil
            veranstalterID = nil
        } else {
            waehleVeranstalter(name, id: id)
        }
    }

    /// Setzt den Veranstalter, ohne ihn bei erneutem Aufruf abzuwählen („Alle kommenden von …“ im Detail).
    mutating func waehleVeranstalter(_ name: String, id: String) {
        veranstalter = name
        veranstalterID = id
    }

    // MARK: Filter-Sheet

    /// Zahl an der Filter-Taste: gesetzte Einstellungen im Sheet.
    var sheetAnzahl: Int {
        (art == .alle ? 0 : 1) + (abgesagteAusblenden ? 1 : 0)
    }

    mutating func sheetZuruecksetzen() {
        art = .alle
        abgesagteAusblenden = false
    }

    // MARK: Ableitungen

    func filter() -> EventFilter {
        EventFilter(
            tag: tag,
            heuteAbend: heuteAbend,
            veranstalter: veranstalterID,
            abgesagteAusblenden: abgesagteAusblenden,
            kategorie: art.kategorie
        )
    }

    /// Unterzeile unter dem Titel: „Was in Ilmenau ansteht“, „Heute ab 17 Uhr · Baracke5“, „Alles von Baracke5“.
    func unterzeile(jetzt: Date) -> String {
        let heute = EventKalender.tagesbeginn(jetzt)
        let zusatz = veranstalter.map { " · \($0)" } ?? ""
        if heuteAbend {
            let abend = EventKalender.tagesbeginn(tag ?? heute)
            let wann = abend == heute ? "Heute" : EventZeitFormatter.kurz(abend)
            return "\(wann) ab 17 Uhr\(zusatz)"
        }
        if let tag {
            return EventZeitFormatter(jetzt: jetzt).abschnittstitel(fuer: tag) + zusatz
        }
        if let veranstalter { return "Alles von \(veranstalter)" }
        return "Was in Ilmenau ansteht"
    }

    /// Welcher Leer-Zustand passt, wenn nichts gefunden wurde. „Gemerkt“ geht vor „Heute Abend“.
    enum LeerArt: Equatable {
        case gemerkt
        case abend(heute: Bool)
        case allgemein
    }

    func leerArt(jetzt: Date) -> LeerArt {
        if nurGemerkt { return .gemerkt }
        if heuteAbend {
            return .abend(heute: EventKalender.tagesbeginn(tag ?? jetzt) == EventKalender.tagesbeginn(jetzt))
        }
        return .allgemein
    }
}

/// Eine Tagesgruppe der Liste.
struct EventAbschnitt: Identifiable, Equatable {
    let tag: Date
    var events: [CampusEvent]

    var id: Date { tag }

    /// „1 Veranstaltung“, „3 Veranstaltungen“.
    var zaehler: String {
        events.count == 1 ? "1 Veranstaltung" : "\(events.count) Veranstaltungen"
    }
}

/// Gruppiert die geladenen Veranstaltungen nach Tagen.
enum EventGruppierung {
    /// Kommende, aufsteigend. Gewählter Tag bzw. „Heute Abend“: alles steht unter diesem Tag, auch Mehrtägige, die
    /// vorher begonnen haben. Sonst unter dem Beginn, Mehrtägige, die schon laufen, unter heute.
    static func kommende(_ events: [CampusEvent], auswahl: EventsAuswahl, jetzt: Date) -> [EventAbschnitt] {
        let heute = EventKalender.tagesbeginn(jetzt)
        let feststehend = auswahl.tag.map(EventKalender.tagesbeginn)
        let gruppen = Dictionary(grouping: events) { event in
            feststehend ?? max(heute, event.ersterTag)
        }
        return gruppen.keys.sorted().map { tag in
            EventAbschnitt(tag: tag, events: (gruppen[tag] ?? []).sorted { $0.beginn < $1.beginn })
        }
    }

    /// Vergangene, der neueste Tag zuerst. Innerhalb eines Tages bleibt die Uhrzeit aufsteigend.
    static func vergangene(_ events: [CampusEvent]) -> [EventAbschnitt] {
        let gruppen = Dictionary(grouping: events, by: \.ersterTag)
        return gruppen.keys.sorted(by: >).map { tag in
            EventAbschnitt(tag: tag, events: (gruppen[tag] ?? []).sorted { $0.beginn < $1.beginn })
        }
    }
}
