import Foundation

/// Alle Tage und Uhrzeiten der Veranstaltungen laufen in der Zeitzone Europe/Berlin, nicht in der des Geräts.
nonisolated enum EventKalender {
    static let zeitzone = TimeZone(identifier: "Europe/Berlin") ?? .gmt

    static let kalender: Calendar = {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zeitzone
        kalender.locale = Locale(identifier: "de_DE")
        return kalender
    }()

    /// Beginn des Berliner Tages.
    static func tagesbeginn(_ datum: Date) -> Date {
        kalender.startOfDay(for: datum)
    }

    static func tag(_ datum: Date, plus tage: Int) -> Date {
        kalender.date(byAdding: .day, value: tage, to: tagesbeginn(datum)) ?? datum
    }

    /// `YYYY-MM-DD` des Berliner Tages (so erwartet es `date`).
    static func berlinDatum(_ datum: Date) -> String {
        format(datum, "yyyy-MM-dd", zeitzone: zeitzone)
    }

    /// `YYYY-MM-DD` des UTC-Tages (so zählen `from` und `to`).
    static func utcDatum(_ datum: Date) -> String {
        format(datum, "yyyy-MM-dd", zeitzone: .gmt)
    }

    static func format(_ datum: Date, _ muster: String, zeitzone: TimeZone = EventKalender.zeitzone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = zeitzone
        formatter.dateFormat = muster
        return formatter.string(from: datum)
    }
}
