import Foundation

// Wie wichtig ein Zeitleisten-Eintrag der Widgets „Mensa heute“ und „Heute Abend“ im Smart Stack gerade ist.
// Die Werte stehen in `Uebergabe.md`, Kapitel „Siri & Kurzbefehle“ → „Siri-Vorschläge und Smart Stack“, und gelten nur
// im Verhältnis der beiden Widgets zueinander; beim Testen am Gerät anpassen. Ohne WidgetKit, damit die Regeln
// testbar bleiben; die Widgets machen daraus `TimelineEntryRelevance(score:duration:)`.

nonisolated enum SmartStack {
    /// Das Widget ist jetzt das, was man sehen will.
    static let hoch: Float = 80
    /// Es wird bald wichtig oder ist es zwischendurch.
    static let mittel: Float = 40
    /// Nichts Dringendes: danach, am Wochenende, tagsüber ohne Anlass, nichts eingetragen.
    static let niedrig: Float = 0

    /// Relevanz eines Eintrags: der Wert und wie lange er gilt.
    struct Relevanz: Equatable, Sendable {
        var score: Float
        var dauer: TimeInterval
    }

    /// Zu jedem Zeitpunkt der Zeitleiste der Wert und die Dauer: Ein Eintrag gilt bis zum nächsten, der letzte bis `ende`.
    /// `zeitpunkte` und `scores` gehören zusammen und sind nach Zeit sortiert.
    static func relevanzen(scores: [Float], zeitpunkte: [Date], ende: Date) -> [Relevanz] {
        precondition(scores.count == zeitpunkte.count, "Zu jedem Zeitpunkt gehört ein Wert.")
        return zeitpunkte.indices.map { index in
            let bis = index + 1 < zeitpunkte.count ? zeitpunkte[index + 1] : ende
            return Relevanz(score: scores[index], dauer: max(0, bis.timeIntervalSince(zeitpunkte[index])))
        }
    }
}

// MARK: - Mensa heute

extension MensaWidgetPhasen {
    /// Hoch ab 10:30 bis zur Schließzeit und während des Abendessens, mittel bis 10:30 und zwischen Mittag und
    /// Abendessen, niedrig danach und am Wochenende. Die Phase kennt all das schon.
    static func relevanz(_ phase: MensaWidgetAnzeige.Phase) -> Float {
        switch phase {
        case .mittag, .abend: SmartStack.hoch
        case .morgen, .nachmittag: SmartStack.mittel
        case .nacht, .geschlossen: SmartStack.niedrig
        }
    }

    /// Relevanz für die Einträge einer Zeitleiste „Mensa heute“. Sie wechselt nur mit der Phase, und zu jedem
    /// Phasenwechsel gibt es ohnehin einen Eintrag.
    static func relevanzen(anzeigen: [MensaWidgetAnzeige], zeitpunkte: [Date], ende: Date) -> [SmartStack.Relevanz] {
        SmartStack.relevanzen(scores: anzeigen.map { relevanz($0.phase) }, zeitpunkte: zeitpunkte, ende: ende)
    }
}

// MARK: - Heute Abend

extension AbendWidgetPhasen {
    /// Ab so lange vor dem Beginn ist das Widget hochrelevant (30 Minuten).
    static let relevanzVorlauf: TimeInterval = 30 * 60

    /// So weit plant die Zeitleiste voraus (Beginn und Ende der Events von heute und morgen).
    static let zeitleistenHorizont: TimeInterval = 36 * 3600

    /// Hoch ab 30 Minuten vor Beginn eines Events und solange eins läuft, mittel ab 17 Uhr, niedrig tagsüber und
    /// wenn nichts (mehr) eingetragen ist. Abgesagte zählen nicht, ebenso wenig, was schon zu Ende ist: Ist der
    /// Abend vorbei, zeigt das Widget zwar den nächsten, aber heute Abend gibt es nichts mehr.
    static func relevanz(events: [WidgetEvent], jetzt: Date) -> Float {
        let bezug = AbendBezug.tag(jetzt)
        let offen = events.filter {
            !$0.ganztaegig && !$0.abgesagt && AbendBezug.tag(von: $0) == bezug && AbendBezug.ende($0) > jetzt
        }
        guard !offen.isEmpty else { return SmartStack.niedrig }
        // Läuft schon (Beginn liegt nicht nach jetzt) oder beginnt in höchstens 30 Minuten.
        if offen.contains(where: { $0.beginn.timeIntervalSince(jetzt) <= relevanzVorlauf }) { return SmartStack.hoch }
        return jetzt >= AbendBezug.beginn(an: bezug) ? SmartStack.mittel : SmartStack.niedrig
    }

    /// Relevanz für die Einträge einer Zeitleiste „Heute Abend“.
    static func relevanzen(events: [WidgetEvent], zeitpunkte: [Date]) -> [SmartStack.Relevanz] {
        let ende = (zeitpunkte.first ?? .now).addingTimeInterval(zeitleistenHorizont)
        return SmartStack.relevanzen(
            scores: zeitpunkte.map { relevanz(events: events, jetzt: $0) }, zeitpunkte: zeitpunkte, ende: ende
        )
    }

    /// Zeitpunkte, an denen sich die Relevanz ändert, ohne dass sich die Anzeige ändert: 17 Uhr und 30 Minuten vor
    /// jedem Beginn. Die Zeitleiste braucht dafür eigene Einträge, denn ein Eintrag hat nur einen Wert.
    static func relevanzWechsel(events: [WidgetEvent], heute: Date) -> [Date] {
        let morgen = EventKalender.tag(heute, plus: 1)
        var zeiten = [AbendBezug.beginn(an: heute), AbendBezug.beginn(an: morgen)]
        for event in events where !event.ganztaegig && !event.abgesagt {
            let tag = AbendBezug.tag(von: event)
            guard tag == heute || tag == morgen else { continue }
            zeiten.append(event.beginn.addingTimeInterval(-relevanzVorlauf))
        }
        return zeiten
    }
}
