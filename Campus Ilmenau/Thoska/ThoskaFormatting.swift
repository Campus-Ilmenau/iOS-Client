import Foundation

/// Darstellung von Guthaben und Zeitpunkten für die Thoska-Ansicht (deutsch).
enum ThoskaFormatting {
    private static let locale = Locale(identifier: "de_DE")

    /// „12,40 €“
    static func euro(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").locale(locale))
    }

    /// Für VoiceOver: „12,40 Euro“
    static func spokenEuro(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(2)).locale(locale))) Euro"
    }

    /// „− 2,90 €“ mit echtem Minuszeichen und festem Leerzeichen.
    static func minusEuro(_ value: Double) -> String { "\u{2212}\u{00A0}\(euro(value))" }

    /// „+ 20,00 €“
    static func plusEuro(_ value: Double) -> String { "+\u{00A0}\(euro(value))" }

    /// „Gerade eben“, „Heute, 08:42“, „Gestern, 08:42“, sonst „Mo., 02.11., 08:42“.
    static func lastRead(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if abs(now.timeIntervalSince(date)) < 60 {
            return "Gerade eben"
        }

        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale))
        let day: String
        if calendar.isDate(date, inSameDayAs: now) {
            day = "Heute"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday) {
            day = "Gestern"
        } else {
            day = date.formatted(.dateTime.weekday(.abbreviated).day(.twoDigits).month(.twoDigits).locale(locale))
        }
        return "\(day), \(time)"
    }
}
