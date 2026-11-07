import Foundation

/// Ein teilbarer Inhalt. `title` ist der Titel für `SharePreview`, `text` der reine Text für „Als Text teilen“
/// (ohne Markdown, höchstens eine Leerzeile am Stück, die Markenzeile als letzte Zeile).
protocol ShareContent {
    var title: String { get }
    var text: String { get }
}

// MARK: - Texte aus der Localizable.xcstrings

/// Holt die Texte in der Sprache der App (oder einer übergebenen, für Tests). Das Muster der Texte steht in
/// `Localizable.xcstrings`, Schlüssel `share.…`.
struct ShareStrings {
    let locale: Locale
    private let bundle: Bundle

    private final class BundleToken {}

    init(locale: Locale) {
        self.locale = locale
        let appBundle = Bundle(for: BundleToken.self)
        let code = locale.language.languageCode?.identifier ?? "de"
        // Unbekannte Sprachen fallen wie in der App auf Englisch zurück.
        let path = appBundle.path(forResource: code, ofType: "lproj") ?? appBundle.path(forResource: "en", ofType: "lproj")
        bundle = path.flatMap(Bundle.init(path:)) ?? appBundle
    }

    /// Sprache, in der die App gerade läuft (Deutsch oder Englisch).
    static var appLocale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "de")
    }

    func callAsFunction(_ key: String, _ arguments: CVarArg...) -> String {
        let pattern = bundle.localizedString(forKey: key, value: key, table: nil)
        return arguments.isEmpty ? pattern : String(format: pattern, locale: locale, arguments: arguments)
    }
}

// MARK: - Bausteine

enum ShareText {
    /// Setzt die Blöcke zu einem Text zusammen: Zeilen eines Blocks untereinander, zwischen den Blöcken eine Leerzeile,
    /// leere Blöcke entfallen, die Markenzeile steht zuletzt.
    static func compose(_ blocks: [[String]], locale: Locale) -> String {
        let all = blocks + [[ShareBranding.line(locale: locale)]]
        return all
            .map { $0.filter { !$0.isEmpty } }
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: "\n") }
            .joined(separator: "\n\n")
    }

    /// Entfernt Leerraum an den Rändern; Leeres wird zu `nil`.
    static func clean(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Ein Preis wie „2,90 €“ mit festem Leerzeichen als normalem Leerzeichen, damit der Text überall gleich aussieht.
    static func plainSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// Kürzt am Wortende auf höchstens `limit` Zeichen (inklusive „…“). Absätze bleiben, mehr als eine Leerzeile
    /// am Stück nicht.
    static func shortened(_ text: String, limit: Int = 280) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "[ \\t]+\\n", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }

        let budget = limit - 1
        var cut = normalized.prefix(budget)
        // Steht der Schnitt mitten im Wort, geht es bis zum letzten Leerzeichen davor zurück.
        let following = normalized[normalized.index(normalized.startIndex, offsetBy: budget)]
        if !following.isWhitespace, let space = cut.lastIndex(where: \.isWhitespace) {
            cut = cut[..<space]
        }
        let trimmed = String(cut).trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:–-")))
        return trimmed + "…"
    }
}

/// Datum immer ausgeschrieben, nie „Heute“. `timeZone` ist beim Speiseplan die des Geräts, bei Veranstaltungen Berlin.
enum ShareDate {
    private static func style(_ locale: Locale, _ timeZone: TimeZone) -> Date.FormatStyle {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        return Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
    }

    /// „Donnerstag, 29. Oktober“
    static func full(_ date: Date, locale: Locale, timeZone: TimeZone = .current) -> String {
        date.formatted(style(locale, timeZone).weekday(.wide).day().month(.wide))
    }

    /// „Do 29. Okt.“ (Wochentag ohne Punkt)
    static func short(_ date: Date, locale: Locale, timeZone: TimeZone = .current) -> String {
        let weekday = date.formatted(style(locale, timeZone).weekday(.abbreviated)).replacingOccurrences(of: ".", with: "")
        return "\(weekday) \(date.formatted(style(locale, timeZone).day().month(.abbreviated)))"
    }
}
