import Foundation

/// Der „Abend“, zu dem ein Zeitpunkt gehört. Er beginnt um 17 Uhr und reicht bis 6 Uhr am nächsten Morgen: Wer um
/// 1 Uhr nachts schaut, sieht noch den Abend von gestern.
nonisolated enum AbendBezug {
    /// Beginn des Abends in Stunden (17 Uhr), wie bei „Heute Abend“ in der App.
    static let beginnStunde = 17
    /// Bis hierher (6 Uhr) gehört die Nacht noch zum Vortag.
    static let tageswechselStunde = 6

    /// Der Berliner Tag des Abends von `zeitpunkt`.
    static func tag(_ zeitpunkt: Date) -> Date {
        HeuteUhr.minuten(zeitpunkt) < tageswechselStunde * 60
            ? EventKalender.tag(zeitpunkt, plus: -1)
            : EventKalender.tagesbeginn(zeitpunkt)
    }

    /// Zu welchem Abend ein Event zählt: eins, das nach Mitternacht beginnt, gehört noch zum Vortag.
    static func tag(von event: WidgetEvent) -> Date {
        tag(event.beginn)
    }

    /// Wann der Abend des Tages beginnt (17:00).
    static func beginn(an tag: Date) -> Date {
        HeuteUhr.datum(am: tag, minuten: beginnStunde * 60)
    }

    /// Das Ende eines Events; ohne Angabe läuft es bis zum Ende seines Abends (6 Uhr am nächsten Morgen).
    static func ende(_ event: WidgetEvent) -> Date {
        event.ende ?? HeuteUhr.datum(am: EventKalender.tag(tag(von: event), plus: 1), minuten: tageswechselStunde * 60)
    }
}

/// Pflegt die Events im `WidgetStore`: aus den Veranstaltungen der API werden die Speicher-Typen.
@MainActor
enum WidgetEventPflege {
    /// So viele Events gehen höchstens in den Speicher.
    static let maxEvents = 24

    /// Ein Event gehört zum Abend eines Tages, wenn es an dem Tag beginnt, nicht ganztägig ist und ab 17 Uhr
    /// beginnt oder nach 17 Uhr noch läuft. Abgesagte gehören dazu: Das Widget zeigt sie als „Fällt aus“.
    static func gehoertZumAbend(_ event: CampusEvent, an tag: Date) -> Bool {
        guard !event.ganztaegig,
              EventKalender.kalender.isDate(event.beginn, inSameDayAs: tag),
              let grenze = EventKalender.kalender.date(bySettingHour: AbendBezug.beginnStunde, minute: 0, second: 0, of: tag)
        else { return false }
        return event.beginn >= grenze || (event.ende ?? event.beginn) > grenze
    }

    static func widgetEvent(_ event: CampusEvent) -> WidgetEvent {
        WidgetEvent(
            id: event.id,
            titel: event.titel,
            beginn: event.beginn,
            ende: event.ende,
            ganztaegig: event.ganztaegig,
            ort: event.ort,
            veranstalter: event.veranstalterAnzeigen,
            abgesagt: event.status == .abgesagt
        )
    }

    /// Übernimmt geladene Listen für ganze Tage. Ein Tag ersetzt seine alten Einträge; Tage, die nicht in `listen`
    /// stehen, bleiben, wie sie waren. Vergangene Abende fallen heraus.
    /// - Parameter abgesagteMitgeliefert: Die Liste enthält auch abgesagte Events. Wenn nicht (Heute-Seite blendet
    ///   sie aus), bleiben die abgesagten des Speichers stehen, statt dass die Absage verschwindet.
    static func uebernehme(
        _ listen: [(tag: Date, events: [CampusEvent])],
        jetzt: Date,
        abgesagteMitgeliefert: Bool,
        in snapshot: inout WidgetSnapshot
    ) {
        let bezug = AbendBezug.tag(jetzt)
        var behalten = snapshot.events.filter { AbendBezug.tag(von: $0) >= bezug }

        var neu: [WidgetEvent] = []
        for (tag, events) in listen {
            let kandidaten = events.filter { gehoertZumAbend($0, an: tag) }.map(widgetEvent)
            let neueIDs = Set(kandidaten.map(\.id))
            behalten.removeAll { alt in
                guard EventKalender.kalender.isDate(alt.beginn, inSameDayAs: tag) else { return false }
                return abgesagteMitgeliefert || !alt.abgesagt || neueIDs.contains(alt.id)
            }
            neu += kandidaten
        }

        var gesehen = Set<String>()
        snapshot.events = (behalten + neu)
            .sorted { $0.beginn < $1.beginn }
            .filter { gesehen.insert($0.id).inserted }
            .prefix(maxEvents)
            .map { $0 }
    }

    static func uebernehmeWoche(von tag: Date, anzahl: Int, in snapshot: inout WidgetSnapshot) {
        snapshot.woche = WidgetWoche(von: EventKalender.berlinDatum(tag), anzahl: anzahl)
    }
}

/// Der Weg des Widgets „Heute Abend“: lädt die Events selbst über die öffentliche Events-API (ohne Anmeldung) und
/// schreibt sie in den `WidgetStore`. Klappt das nicht (offline, Zeitablauf), bleibt der Speicher der App, wie er ist.
@MainActor
struct WidgetEventsAktualisierung {
    let store: WidgetStore

    /// - Returns: ob sich der Speicher geändert hat.
    @discardableResult
    func ladeUndSpeichere(quelle: any EventsDatenquelle, jetzt: Date, zeitlimit: Duration) async -> Bool {
        let heute = AbendBezug.tag(jetzt)
        let morgen = EventKalender.tag(heute, plus: 1)
        let ergebnis = await heuteMitZeitlimit(zeitlimit) {
            // Derselbe Filter wie auf Heute (ab 17 Uhr, ohne Ganztägige), aber mit Abgesagten: Das Widget zeigt sie.
            async let abendHeute = try? quelle.liste(
                filter: EventFilter(tag: heute, heuteAbend: true, abgesagteAusblenden: false), seite: 1, jetzt: jetzt
            )
            async let abendMorgen = try? quelle.liste(
                filter: EventFilter(tag: morgen, heuteAbend: true, abgesagteAusblenden: false), seite: 1, jetzt: jetzt
            )
            async let woche = try? quelle.liste(
                filter: EventFilter(
                    zeitraum: .init(von: heute, bis: EventKalender.tag(heute, plus: 7)),
                    abgesagteAusblenden: true, kategorie: "Veranstaltung"
                ),
                seite: 1, jetzt: jetzt
            )
            let daten = await (abendHeute, abendMorgen, woche)

            var listen: [(tag: Date, events: [CampusEvent])] = []
            if let seite = daten.0 { listen.append((heute, seite.events)) }
            if let seite = daten.1 { listen.append((morgen, seite.events)) }
            return store.aendern { snapshot in
                if !listen.isEmpty {
                    WidgetEventPflege.uebernehme(listen, jetzt: jetzt, abgesagteMitgeliefert: true, in: &snapshot)
                }
                if let seite = daten.2 {
                    WidgetEventPflege.uebernehmeWoche(von: heute, anzahl: seite.gesamt, in: &snapshot)
                }
            }
        }
        return ergebnis ?? false
    }
}
