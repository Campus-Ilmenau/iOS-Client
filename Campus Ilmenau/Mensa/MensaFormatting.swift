import Foundation

enum MensaFormatting {
    /// Datum und Wochentage folgen der App-Sprache.
    private static var locale: Locale { AppLanguage.current.locale }

    /// „Heute“, „Morgen“, sonst „Do., 29. Okt.“ (englisch „Thu, Oct 29“)
    static func dayLabel(_ day: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return LocalizedStringResource("Heute").inAppSprache }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(day, inSameDayAs: tomorrow) {
            return LocalizedStringResource("Morgen").inAppSprache
        }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale))
    }

    /// Für VoiceOver: „Donnerstag, 29. Oktober“
    static func spokenDay(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
    }

    /// „Donnerstag, 29. Oktober 2026“
    static func fullDate(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(locale))
    }

    static func weekdayShort(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.abbreviated).locale(locale)).replacingOccurrences(of: ".", with: "")
    }

    /// 15 Werktage ab heute (3 Wochen), Samstag und Sonntag übersprungen.
    static func workdays(from start: Date, count: Int = 15, calendar: Calendar = .current) -> [Date] {
        var days: [Date] = []
        var day = calendar.startOfDay(for: start)
        while days.count < count {
            if !calendar.isDateInWeekend(day) { days.append(day) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }
}
