import Foundation

/// Beispieldaten für Platzhalter und Previews, mit den Veranstaltungen aus `WidgetHeuteAbend.dc.html`.
/// Donnerstag, 29. Oktober 2026 (Berlin); der nächste Abend ist Freitag, der 30.
nonisolated enum AbendWidgetVorschau {
    enum Szenario: CaseIterable {
        /// 18:30: nächste Veranstaltungen, eine fällt aus
        case abend1830
        /// 19:40: eine läuft, eine andere wurde abgesagt
        case laeuft1940
        /// 23:50: heute ist alles vorbei, der nächste Abend steht oben
        case naechsterAbend
        /// Heute ist nichts eingetragen, morgen schon
        case leer
        /// Weder heute noch morgen ist etwas eingetragen
        case nichts

        var jetzt: Date {
            switch self {
            case .abend1830: AbendWidgetVorschau.zeit(18.5)
            case .laeuft1940: AbendWidgetVorschau.zeit(19 + 40.0 / 60)
            case .naechsterAbend: AbendWidgetVorschau.zeit(23 + 50.0 / 60)
            case .leer, .nichts: AbendWidgetVorschau.zeit(19.5)
            }
        }
    }

    static func anzeige(_ szenario: Szenario) -> AbendWidgetAnzeige {
        AbendWidgetPhasen.anzeige(
            events: events(szenario), gemerkteIDs: ["stage", "halloween"], woche: WidgetWoche(von: "2026-10-29", anzahl: 14),
            jetzt: szenario.jetzt
        )
    }

    static func zeit(_ stunden: Double, tag: String = "2026-10-29") -> Date {
        let teile = tag.split(separator: "-").compactMap { Int($0) }
        let beginn = EventKalender.kalender.date(from: DateComponents(year: teile[0], month: teile[1], day: teile[2])) ?? .now
        return beginn.addingTimeInterval(stunden * 3600)
    }

    private static func event(
        _ id: String, _ titel: String, _ von: Double, _ bis: Double, _ ort: String, veranstalter: String? = nil,
        abgesagt: Bool = false, morgen: Bool = false
    ) -> WidgetEvent {
        let tag = morgen ? "2026-10-30" : "2026-10-29"
        return WidgetEvent(
            id: id, titel: titel, beginn: zeit(von, tag: tag), ende: zeit(bis, tag: tag), ganztaegig: false,
            ort: ort, veranstalter: veranstalter, abgesagt: abgesagt
        )
    }

    static func events(_ szenario: Szenario) -> [WidgetEvent] {
        let morgen = [
            event("lola", "Filmabend: Lola rennt", 20, 22.5, "Faraday-Hörsaal", veranstalter: "hsf", morgen: true),
            event("halloween", "Halloween-Party", 21, 27, "Studi-Club", morgen: true),
            event("elektro", "Elektro-Nacht", 22, 28, "BC-Club", morgen: true)
        ]
        switch szenario {
        case .abend1830:
            return [
                event("spiel", "Spieleabend", 19, 23, "Studi-Club"),
                event("quiz", "Kneipenquiz", 20, 23, "Baracke5", abgesagt: true),
                event("stage", "Open Stage", 21, 25, "BC-Club")
            ] + morgen
        case .laeuft1940:
            return [
                event("spiel", "Spieleabend", 19, 23, "Studi-Club"),
                event("stage", "Open Stage", 21, 25, "BC-Club", abgesagt: true),
                event("karaoke", "Karaoke-Nacht", 22, 26, "Baracke5")
            ] + morgen
        case .naechsterAbend:
            // Alles von heute ist um 23:50 vorbei.
            return [
                event("spiel", "Spieleabend", 19, 23, "Studi-Club"),
                event("quiz", "Kneipenquiz", 20, 23, "Baracke5", abgesagt: true),
                event("vortrag", "Vortrag: Nachhaltig studieren", 18, 19.5, "Humboldtbau", veranstalter: "StuRa")
            ] + morgen
        case .leer:
            return morgen
        case .nichts:
            return []
        }
    }
}
