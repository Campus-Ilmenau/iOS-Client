import Foundation

/// Die Sprache der App: Deutsch (Standard) oder Englisch. Sie folgt der Systemsprache bzw. der App-Sprache in den
/// Einstellungen; ist sie weder Deutsch noch Englisch, gilt Deutsch. Die Netzwerkschicht liest `apiCode` und schickt
/// ihn als `lang` an die Mensa-API. Die Datei gehört zu allen Targets, die die API nutzen.
nonisolated enum AppLanguage: String, Sendable, Equatable, CaseIterable {
    case de
    case en

    /// Wert für den Query-Parameter `lang` (`de` oder `en`).
    var apiCode: String { rawValue }

    /// Sprache des Geräts bzw. der App. `Locale.current` folgt den Lokalisierungen des Bundles.
    static var current: AppLanguage { AppLanguage(locale: .current) }

    /// Sprachcode `en` → Englisch, alles andere → Deutsch.
    init(locale: Locale) {
        self = locale.language.languageCode?.identifier == "en" ? .en : .de
    }
}
