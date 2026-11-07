import SwiftUI

/// Stand des Ladens für den gewählten Tag.
enum MensaLoadState: Equatable {
    case loading
    case loaded
    case failed
}

/// Status-Chip einer Mensa aus den Öffnungszeiten der API.
enum MensaStatus {
    struct Info {
        let text: String
        let variant: Chip.Variant
    }

    /// `nil`, solange keine Öffnungszeiten der Mensa bekannt sind.
    static func chip(
        for venue: MensaVenue,
        canteens: [Canteen],
        day: Date,
        mealtime: MensaMealtime,
        now: Date,
        calendar: Calendar = .current
    ) -> Info? {
        guard let canteen = canteens.first(where: { venue.matches(canteenName: $0.name) }) else { return nil }

        let key = weekdayKey(calendar.component(.weekday, from: day))
        guard let hours = canteen.openingHours.first(where: { $0.weekday.lowercased() == key }),
              let opens = minutes(hours.opensAt), let closes = minutes(hours.closesAt) else {
            return Info(text: "Geschlossen", variant: .dangerSoft)
        }

        let isToday = calendar.isDate(day, inSameDayAs: now)
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        if isToday, nowMinutes >= closes {
            return Info(text: "Geschlossen", variant: .dangerSoft)
        }
        if venue.hasMealtimes, mealtime == .dinner {
            return Info(text: "Bis \(clock(hours.closesAt)) Uhr", variant: .neutral)
        }
        guard isToday else {
            return Info(text: "\(short(hours.opensAt))–\(short(hours.closesAt)) Uhr", variant: .neutral)
        }
        if nowMinutes < opens {
            return Info(text: "Ab \(clock(hours.opensAt)) Uhr", variant: .neutral)
        }
        if closes - nowMinutes <= 30 {
            return Info(text: "Gleich zu", variant: .warning)
        }
        return Info(text: "Geöffnet · \(short(hours.opensAt))–\(short(hours.closesAt)) Uhr", variant: .green)
    }

    private static func weekdayKey(_ weekday: Int) -> String {
        ["sun", "mon", "tue", "wed", "thu", "fri", "sat"][max(0, min(6, weekday - 1))]
    }

    private static func minutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    /// „11:00“ → „11“, „10:30“ → „10:30“
    private static func short(_ time: String) -> String {
        guard let total = minutes(time) else { return time }
        return total % 60 == 0 ? "\(total / 60)" : clock(time)
    }

    /// „08:00“ → „8:00“
    private static func clock(_ time: String) -> String {
        guard let total = minutes(time) else { return time }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

