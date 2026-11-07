import Foundation

/// Filter der Event-Liste. Die Regeln für Zeit und „Heute Abend“ stehen in `anfrage(jetzt:)`.
struct EventFilter: Equatable, Sendable {
    /// Zeitraum nach Berliner Tagen: ab `von` (Tagesbeginn), bis `bis` (exklusiv, Tagesbeginn).
    struct Zeitraum: Equatable, Sendable {
        var von: Date
        var bis: Date?

        init(von: Date, bis: Date? = nil) {
            self.von = von
            self.bis = bis
        }
    }

    var zeitraum: Zeitraum?
    /// Ein einzelner Tag. Enthält auch mehrtägige Veranstaltungen, die vorher begonnen haben.
    var tag: Date?
    /// Ab 17 Uhr am Tag; ganztägige fallen weg.
    var heuteAbend = false
    /// ID des Veranstalters (z. B. `cafe-bohne`). Die API akzeptiert für `organizer` nur die ID, keinen Namen
    /// (sonst Fehler 400 `invalid_parameter_format`).
    var veranstalter: String?
    var abgesagteAusblenden = false
    /// „Veranstaltung“ oder „Frist“ (Groß- und Kleinschreibung egal).
    var kategorie: String?

    init(
        zeitraum: Zeitraum? = nil,
        tag: Date? = nil,
        heuteAbend: Bool = false,
        veranstalter: String? = nil,
        abgesagteAusblenden: Bool = false,
        kategorie: String? = nil
    ) {
        self.zeitraum = zeitraum
        self.tag = tag
        self.heuteAbend = heuteAbend
        self.veranstalter = veranstalter
        self.abgesagteAusblenden = abgesagteAusblenden
        self.kategorie = kategorie
    }

    /// Ab heute, ohne weitere Filter.
    static let abHeute = EventFilter()

    /// Der Zeitfilter, der tatsächlich gilt. „Heute Abend“ lässt sich nicht mit einem Zeitraum kombinieren; dann gilt
    /// der Tag (Standard: heute). Ein Tag geht jedem Zeitraum vor. Ohne beides gilt ab heute 00:00,
    /// sonst kämen vergangene Veranstaltungen.
    enum Zeitfilter: Equatable, Sendable {
        case abend(Date)
        case tag(Date)
        case zeitraum(von: Date, bis: Date?)
    }

    func zeitfilter(jetzt: Date) -> Zeitfilter {
        let heute = EventKalender.tagesbeginn(jetzt)
        if heuteAbend {
            return .abend(EventKalender.tagesbeginn(tag ?? heute))
        }
        if let tag {
            return .tag(EventKalender.tagesbeginn(tag))
        }
        let von = EventKalender.tagesbeginn(zeitraum?.von ?? heute)
        return .zeitraum(von: von, bis: zeitraum?.bis.map(EventKalender.tagesbeginn))
    }

    /// Alles, was die App für die Abfrage braucht.
    struct Anfrage: Equatable, Sendable {
        /// Parameter ohne Zeitfilter (Veranstalter, Kategorie, abgesagte).
        var gemeinsam: [URLQueryItem]
        /// Parameter des Zeitfilters.
        var zeit: [URLQueryItem]
        /// Berliner Beginn des Zeitraums: Treffer davor schneidet die App ab.
        var vonGrenze: Date?
        /// Berliner Ende des Zeitraums (exklusiv): Treffer ab hier schneidet die App ab.
        var bisGrenze: Date?
        /// Bei „ab Tag X“ auch laufende mehrtägige Veranstaltungen dieses Tages holen.
        var laufendeAm: Date?

        var items: [URLQueryItem] { zeit + gemeinsam }
    }

    func anfrage(jetzt: Date) -> Anfrage {
        var anfrage = Anfrage(gemeinsam: [], zeit: [], vonGrenze: nil, bisGrenze: nil, laufendeAm: nil)

        switch zeitfilter(jetzt: jetzt) {
        case .abend(let tag):
            anfrage.zeit = [
                URLQueryItem(name: "date", value: EventKalender.berlinDatum(tag)),
                URLQueryItem(name: "evening", value: "true")
            ]
        case .tag(let tag):
            anfrage.zeit = [URLQueryItem(name: "date", value: EventKalender.berlinDatum(tag))]
        case .zeitraum(let von, let bis):
            // `from` und `to` zählen in UTC-Tagen, die Berliner Mitternacht liegt aber am Vortag um 22/23 Uhr UTC.
            // Damit z. B. ein ganztägiges Event, das heute um 00:00 beginnt, nicht fehlt, wird das Fenster verbreitert.
            // Das Zuschneiden auf Berliner Tage übernimmt der Service.
            anfrage.zeit = [URLQueryItem(name: "from", value: EventKalender.utcDatum(von))]
            anfrage.vonGrenze = von
            anfrage.laufendeAm = von
            if let bis {
                let nachBis = EventKalender.kalender.date(byAdding: .day, value: 1, to: bis).map(EventKalender.utcDatum)
                anfrage.zeit.append(URLQueryItem(name: "to", value: nachBis ?? EventKalender.utcDatum(bis)))
                anfrage.bisGrenze = bis
            }
        }

        if let veranstalter = veranstalter?.trimmingCharacters(in: .whitespacesAndNewlines), !veranstalter.isEmpty {
            anfrage.gemeinsam.append(URLQueryItem(name: "organizer", value: veranstalter))
        }
        if let kategorie = kategorie?.trimmingCharacters(in: .whitespacesAndNewlines), !kategorie.isEmpty {
            anfrage.gemeinsam.append(URLQueryItem(name: "category", value: kategorie))
        }
        // Immer ausdrücklich senden, damit nicht die Voreinstellung des Servers entscheidet.
        anfrage.gemeinsam.append(URLQueryItem(name: "include_cancelled", value: abgesagteAusblenden ? "false" : "true"))
        return anfrage
    }
}
