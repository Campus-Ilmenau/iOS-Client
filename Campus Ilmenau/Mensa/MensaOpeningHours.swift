import Foundation

/// Öffnungszeiten aus den Daten der API (`Canteen.openingHours`): Wochenzeilen, heutige Zeit und Status.
enum MensaOpeningHours {
    /// Montag bis Sonntag, wie die API die Wochentage nennt.
    private static let weekdays: [(key: String, name: String)] = [
        ("mon", "Montag"), ("tue", "Dienstag"), ("wed", "Mittwoch"), ("thu", "Donnerstag"),
        ("fri", "Freitag"), ("sat", "Samstag"), ("sun", "Sonntag")
    ]

    /// Zeit als „11:00–14:00“ oder `nil`, wenn der Tag fehlt.
    static func range(for key: String, in hours: [OpeningHour]) -> String? {
        hours.first { $0.weekday.lowercased() == key }.map { "\($0.opensAt)–\($0.closesAt)" }
    }

    /// Wochenzeilen: Tage mit gleicher Zeit nebeneinander zusammengefasst, z. B.
    /// „Montag – Donnerstag“ / „11:00–14:00“, „Freitag“ / „11:00–13:30“, „Samstag, Sonntag“ / „geschlossen“.
    static func weekRows(for hours: [OpeningHour]) -> [(label: String, value: String)] {
        let days = weekdays.map { day in (name: day.name, value: range(for: day.key, in: hours) ?? "geschlossen") }
        var rows: [(label: String, value: String)] = []
        var start = 0
        while start < days.count {
            var end = start
            while end + 1 < days.count, days[end + 1].value == days[start].value { end += 1 }
            let label: String
            switch end - start {
            case 0: label = days[start].name
            case 1: label = "\(days[start].name), \(days[end].name)"
            default: label = "\(days[start].name) – \(days[end].name)"
            }
            rows.append((label, days[start].value))
            start = end + 1
        }
        return rows
    }

    /// Heutige Zeit, z. B. „11:00–14:00 Uhr“; „geschlossen“ ohne Eintrag.
    static func todayText(for hours: [OpeningHour], now: Date, calendar: Calendar = .current) -> String {
        range(for: weekdayKey(now, calendar: calendar), in: hours).map { "\($0) Uhr" } ?? "heute geschlossen"
    }

    /// Abendessen der Cafeteria Ehrenberg: Die API nennt keinen Beginn, nur das Ende der Öffnungszeit.
    static func dinnerText(for hours: [OpeningHour]) -> String? {
        guard let weekday = hours.first(where: { $0.weekday.lowercased() == "mon" }) else { return nil }
        var text = "bis \(weekday.closesAt) Uhr"
        if let friday = hours.first(where: { $0.weekday.lowercased() == "fri" }), friday.closesAt != weekday.closesAt {
            text += ", Freitag bis \(friday.closesAt) Uhr"
        }
        return text
    }

    enum State: Equatable {
        case open
        /// Schließt in weniger als 30 Minuten.
        case closingSoon
        /// Heute geschlossen, vor der Öffnung oder nach dem Schließen.
        case closed
    }

    static func state(for hours: [OpeningHour], now: Date, calendar: Calendar = .current) -> State {
        guard let today = hours.first(where: { $0.weekday.lowercased() == weekdayKey(now, calendar: calendar) }),
              let opens = minutes(today.opensAt), let closes = minutes(today.closesAt) else { return .closed }
        let current = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        guard current >= opens, current < closes else { return .closed }
        return closes - current < 30 ? .closingSoon : .open
    }

    private static func weekdayKey(_ date: Date, calendar: Calendar) -> String {
        weekdays[(calendar.component(.weekday, from: date) + 5) % 7].key
    }

    private static func minutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}
