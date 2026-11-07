import Foundation

/// Die Mensa auf der Startseite. Sie gilt für die Jetzt-Karte und „Als Nächstes“ und ist unabhängig von der Auswahl im
/// Mensa-Tab. „Mehr“ und das Auswahl-Sheet auf Heute schreiben hierher. Der Wert liegt in der App Group, damit die
/// Mensa-Widgets dieselbe Mensa zeigen.
final class HeuteMensaSpeicher {
    static let schluessel = AppGroup.heuteMensaSchluessel

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    /// Start ist die Mensa Ehrenberg.
    var venue: MensaVenue {
        get { defaults.string(forKey: Self.schluessel).flatMap(MensaVenue.init(rawValue:)) ?? .mensaEhrenberg }
        set { defaults.set(newValue.rawValue, forKey: Self.schluessel) }
    }
}

/// Merkt sich dauerhaft, welche Hinweise weggetippt wurden.
final class HinweiseAusblendSpeicher {
    static let schluessel = "heuteHinweiseAusgeblendet"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var ids: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.schluessel) ?? []) }
        set { defaults.set(newValue.sorted(), forKey: Self.schluessel) }
    }
}
