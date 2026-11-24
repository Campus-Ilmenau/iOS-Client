import SwiftUI
import WidgetKit

/// Auswahl in „Mehr“: dem Gerät folgen oder eine Sprache fest wählen.
enum SpracheWahl: Hashable, CaseIterable, Identifiable {
    case automatisch
    case deutsch
    case englisch

    var id: Self { self }

    init(_ sprache: AppLanguage?) {
        switch sprache {
        case nil: self = .automatisch
        case .de?: self = .deutsch
        case .en?: self = .englisch
        }
    }

    var sprache: AppLanguage? {
        switch self {
        case .automatisch: nil
        case .deutsch: .de
        case .englisch: .en
        }
    }

    /// Die Sprachen heißen in der eigenen Sprache, damit man sie auch erkennt, wenn die Oberfläche unverständlich ist.
    var titel: Text {
        switch self {
        case .automatisch: Text("Automatisch")
        case .deutsch: Text(verbatim: "Deutsch")
        case .englisch: Text(verbatim: "English")
        }
    }
}

/// Die Sprache der laufenden App. Wer sie in „Mehr“ ändert, ändert sie sofort: `AppLanguage.wahl` merkt sich die Wahl
/// (auch für die Widgets), `Bundle.main` liest danach aus der neuen Sprache, und die Oberfläche bekommt die neue `Locale`.
@MainActor
@Observable
final class AppSprache {
    static let gemeinsam = AppSprache()

    /// Die Sprache, in der die App gerade läuft.
    private(set) var aktuell = AppLanguage.current
    /// Die eigene Wahl; `nil` heißt „Automatisch“.
    private(set) var wahl = AppLanguage.wahl
    /// Die Sprache des Geräts, nach der „Automatisch“ sich richtet.
    var geraet: AppLanguage { AppLanguage.geraet() }

    var auswahl: SpracheWahl { SpracheWahl(wahl) }

    func waehle(_ neu: SpracheWahl) {
        guard neu.sprache != wahl else { return }
        AppLanguage.wahl = neu.sprache
        wahl = neu.sprache
        aktuell = AppLanguage.current
        // Die Widgets bauen ihre Texte in der neuen Sprache.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
