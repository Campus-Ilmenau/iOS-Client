import Foundation

/// Uhrzeit-Rechnung der Heute-Seite. Alles läuft in der Zeitzone Europe/Berlin, nicht in der des Geräts.
nonisolated enum HeuteUhr {
    /// Minuten seit Mitternacht (Berlin).
    static func minuten(_ datum: Date) -> Int {
        let teile = EventKalender.kalender.dateComponents([.hour, .minute], from: datum)
        return (teile.hour ?? 0) * 60 + (teile.minute ?? 0)
    }

    /// „08:15“
    static func uhrzeit(_ datum: Date) -> String {
        uhrzeit(minuten: minuten(datum))
    }

    /// 630 → „10:30“
    static func uhrzeit(minuten: Int) -> String {
        String(format: "%02d:%02d", minuten / 60, minuten % 60)
    }

    /// „11:00“ → 660; `nil`, wenn der Text keine Uhrzeit ist.
    static func minuten(aus text: String) -> Int? {
        let teile = text.split(separator: ":")
        guard teile.count >= 2, let stunde = Int(teile[0]), let minute = Int(teile[1]) else { return nil }
        return stunde * 60 + minute
    }

    /// Der Zeitpunkt `minuten` nach Mitternacht am Berliner Tag von `tag`.
    static func datum(am tag: Date, minuten: Int) -> Date {
        let beginn = EventKalender.tagesbeginn(tag)
        return EventKalender.kalender.date(bySettingHour: minuten / 60, minute: minuten % 60, second: 0, of: beginn)
            ?? beginn.addingTimeInterval(TimeInterval(minuten * 60))
    }

    /// „Fr“
    static func wochentagKurz(_ datum: Date) -> String {
        EventKalender.format(datum, "EEE").replacingOccurrences(of: ".", with: "")
    }

    static func istGleicherTag(_ a: Date, _ b: Date) -> Bool {
        EventKalender.kalender.isDate(a, inSameDayAs: b)
    }

    /// Schlüssel des Wochentags, wie ihn die Mensa-API nennt („mon“ … „sun“).
    static func wochentagSchluessel(_ datum: Date) -> String {
        let tag = EventKalender.kalender.component(.weekday, from: datum)
        return ["sun", "mon", "tue", "wed", "thu", "fri", "sat"][max(0, min(6, tag - 1))]
    }
}
