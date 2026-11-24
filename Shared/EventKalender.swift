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

    /// Datum oder Uhrzeit für die Anzeige: Berliner Zeit, Schreibweise und Wochentagsnamen der App-Sprache.
    /// `EventKalender.lokal(datum) { $0.weekday(.wide).day().month(.wide) }` → „Dienstag, 24. November“ / „Tuesday, 24 November“.
    static func lokal(_ datum: Date, _ stil: (Date.FormatStyle) -> Date.FormatStyle) -> String {
        datum.formatted(stil(Date.FormatStyle(locale: .current, calendar: kalender, timeZone: zeitzone)))
    }

    static func format(_ datum: Date, _ muster: String, zeitzone: TimeZone = EventKalender.zeitzone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = zeitzone
        formatter.dateFormat = muster
        return formatter.string(from: datum)
    }
}
