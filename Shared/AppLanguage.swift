import Foundation
import ObjectiveC

/// Die Sprache der App: Deutsch (Standard) oder Englisch. Ohne eigene Wahl folgt sie der Sprache des Geräts; ist die
/// weder Deutsch noch Englisch, gilt Deutsch. In „Mehr“ lässt sich die Sprache umstellen (`override`).
/// Die Netzwerkschicht liest `apiCode` und schickt ihn als `lang` an die Mensa-API.
/// Die App wird nur in Deutschland vertrieben: Datums-, Zeit- und Zahlenformate nutzen deshalb immer die Region
/// Deutschland (`locale`), auch bei englischer Sprache („24 November“, „5,20 €“, 24-Stunden-Zeit).
/// Die Datei gehört zu allen Targets.
nonisolated enum AppLanguage: String, Sendable, Equatable, CaseIterable {
    case de
    case en

    /// Wert für den Query-Parameter `lang` (`de` oder `en`).
    var apiCode: String { rawValue }

    /// Schreibweisen der Region Deutschland in der Sprache: `de_DE` bzw. `en_DE`.
    var locale: Locale { Locale(identifier: "\(rawValue)_DE") }

    /// Sprachcode `en` → Englisch, alles andere → Deutsch.
    init(locale: Locale) {
        self = locale.language.languageCode?.identifier == "en" ? .en : .de
    }

    // MARK: Wahl

    /// Schlüssel der eigenen Wahl in den gemeinsamen Einstellungen (`de`, `en`; fehlt: „Automatisch“).
    static let wahlSchluessel = "appSprache"

    /// Die eigene Wahl aus „Mehr“; `nil` heißt „Automatisch“ (Sprache des Geräts).
    static var wahl: AppLanguage? {
        get { AppGroup.defaults.string(forKey: wahlSchluessel).flatMap(AppLanguage.init(rawValue:)) }
        set {
            if let newValue { AppGroup.defaults.set(newValue.rawValue, forKey: wahlSchluessel) }
            else { AppGroup.defaults.removeObject(forKey: wahlSchluessel) }
            SprachBundle.aktualisieren()
        }
    }

    /// Die erste Sprache der Geräteliste, die die App kennt (Deutsch oder Englisch), sonst Deutsch.
    static func geraet(preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        for kennung in preferred {
            switch Locale(identifier: kennung).language.languageCode?.identifier {
            case "de": return .de
            case "en": return .en
            default: continue
            }
        }
        return .de
    }

    /// Nur für Tests: Die Sprache gilt für den laufenden Test, ohne die Wahl der App oder andere Tests zu berühren.
    /// `AppLanguage.$test.withValue(.en) { … }`
    @TaskLocal static var test: AppLanguage?

    /// Sprache der App: die eigene Wahl, sonst die des Geräts.
    static var current: AppLanguage { test ?? bestimmen(wahl: wahl, preferred: Locale.preferredLanguages) }

    /// Die Regel hinter `current`, ohne globalen Zustand (so lässt sie sich prüfen).
    static func bestimmen(wahl: AppLanguage?, preferred: [String]) -> AppLanguage {
        wahl ?? geraet(preferred: preferred)
    }

    /// Muss einmal früh laufen (App, Widgets): Danach lösen `Text` und `NSLocalizedString` in `current` auf, auch wenn
    /// die Wahl von der Gerätesprache abweicht. Texte im Code stehen als `LocalizedStringResource("…").inAppSprache`.
    static func installieren() {
        SprachBundle.installieren()
    }
}

// MARK: - Katalog in der gewählten Sprache

/// Lässt `Bundle.main` Texte aus dem `.lproj` der gewählten Sprache lesen statt aus dem der Gerätesprache. Das ist die
/// einzige Stelle, die dafür nötig ist; Texte im Code und in Views bleiben unverändert.
private nonisolated final class SprachBundle: Bundle, @unchecked Sendable {
    private nonisolated(unsafe) static var installiert = false
    private nonisolated(unsafe) static var teilbundles: [String: Bundle] = [:]
    private static let sperre = NSLock()

    static func installieren() {
        sperre.lock(); defer { sperre.unlock() }
        guard !installiert else { return }
        installiert = true
        object_setClass(Bundle.main, SprachBundle.self)
    }

    /// Die Wahl hat sich geändert: gemerkte Teil-Bundles verwerfen.
    static func aktualisieren() {
        sperre.lock(); defer { sperre.unlock() }
        teilbundles.removeAll()
    }

    private static func teilbundle(fuer bundle: Bundle) -> Bundle? {
        let code = AppLanguage.current.rawValue
        let schluessel = "\(bundle.bundlePath)#\(code)"
        sperre.lock(); defer { sperre.unlock() }
        if let bekannt = teilbundles[schluessel] { return bekannt }
        guard let pfad = bundle.path(forResource: code, ofType: "lproj"), let neu = Bundle(path: pfad) else { return nil }
        teilbundles[schluessel] = neu
        return neu
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard self === Bundle.main, let teil = Self.teilbundle(fuer: self) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return teil.localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - Texte im Code

extension LocalizedStringResource {
    /// Der Text in der Sprache der App. `String(localized:)` ignoriert die Sprachwahl in „Mehr“ und folgt immer dem
    /// Gerät; ein `LocalizedStringResource` mit der `Locale` der App löst dagegen in der gewählten Sprache auf.
    /// Schreibweise im Code: `LocalizedStringResource("Heute").inAppSprache` (der Schlüssel wird vom Compiler in den
    /// Katalog übernommen, auch mit `table:`).
    nonisolated var inAppSprache: String {
        var resource = self
        resource.locale = AppLanguage.current.locale
        return String(localized: resource)
    }
}
