import AppIntents
import WidgetKit

/// Welche Mensa das Widget zeigt: die „Mensa auf der Startseite“ (Standard) oder eine der vier Mensen der App fest.
/// Die Rohwerte stehen in gespeicherten Widgets und dürfen sich nicht ändern.
enum MensaAuswahl: String, AppEnum {
    case wieStartseite
    case mensaEhrenberg
    case cafeteriaEhrenberg
    case nanoteria
    case roentgenbau

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Mensa" }

    // Die Titel müssen Literale sein: Das System liest sie beim Bauen aus, ohne Code auszuführen.
    // Sie stehen so, wie `MensaVenue.displayName` sie schreibt.
    static var caseDisplayRepresentations: [MensaAuswahl: DisplayRepresentation] {
        [
            .wieStartseite: "Wie auf der Startseite",
            .mensaEhrenberg: "Mensa Ehrenberg",
            .cafeteriaEhrenberg: "Cafeteria Ehrenberg",
            .nanoteria: "Cafeteria Nanoteria",
            .roentgenbau: "Cafeteria Röntgenbau"
        ]
    }

    /// Die feste Mensa; `nil` bei „Wie auf der Startseite“.
    var venue: MensaVenue? {
        switch self {
        case .wieStartseite: nil
        case .mensaEhrenberg: .mensaEhrenberg
        case .cafeteriaEhrenberg: .cafeteriaEhrenberg
        case .nanoteria: .nanoteria
        case .roentgenbau: .roentgenbau
        }
    }
}

/// „Widget bearbeiten“ beim Widget „Mensa heute“.
struct MensaWidgetKonfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Mensa heute" }
    static var description: IntentDescription { "Welche Mensa das Widget zeigt." }

    @Parameter(title: "Mensa", default: .wieStartseite)
    var mensa: MensaAuswahl

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$mensa)")
    }
}

/// Der Wechsel-Knopf im mittleren Widget: schaltet die „Mensa auf der Startseite“ eine weiter. Heute in der App und
/// alle Mensa-Widgets zeigen danach dieselbe Mensa, denn die Einstellung liegt in der App Group.
struct MensaWechselnIntent: AppIntent {
    static var title: LocalizedStringResource { "Mensa wechseln" }
    /// Nur für den Knopf im Widget, nicht für Kurzbefehle.
    static var isDiscoverable: Bool { false }

    func perform() async throws -> some IntentResult {
        let defaults = AppGroup.defaults
        let aktuell = defaults.string(forKey: AppGroup.heuteMensaSchluessel).flatMap(MensaVenue.init(rawValue:))
            ?? .mensaEhrenberg
        defaults.set(aktuell.naechste.rawValue, forKey: AppGroup.heuteMensaSchluessel)
        // Alle Mensa-Widgets, nicht nur das mit dem Knopf.
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKinds.mensa)
        return .result()
    }
}
