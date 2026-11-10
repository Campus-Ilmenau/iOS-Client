import Foundation

/// Nur für Debug-Builds: lässt die Widgets so rechnen, als wäre es eine bestimmte Uhrzeit (Berliner Zeit, heutiger Tag),
/// damit sich Bilder für die Website zu jeder Tageszeit aufnehmen lassen. In Release-Builds ist das ohne Wirkung.
///
/// Gesetzt wird der Wert beim Start der App mit dem Launch-Argument `-WidgetUhr 11:45` (siehe `Campus_IlmenauApp`);
/// `-WidgetUhr aus` hebt ihn auf. Die Widgets legen dann nur einen Eintrag ab, der sofort gilt.
nonisolated enum WidgetUhr {
    static let schluessel = "debugWidgetUhr"

    /// Die Zeit, mit der das Widget rechnet.
    static var jetzt: Date {
        #if DEBUG
        if let text = AppGroup.defaults.string(forKey: schluessel), let minuten = HeuteUhr.minuten(aus: text) {
            return HeuteUhr.datum(am: .now, minuten: minuten)
        }
        #endif
        return .now
    }

    static var istUebersteuert: Bool {
        #if DEBUG
        return AppGroup.defaults.string(forKey: schluessel) != nil
        #else
        return false
        #endif
    }

    /// Bei übersteuerter Uhr gilt nur der erste Eintrag, und zwar jetzt; die Einträge danach lägen in der Zukunft
    /// der falschen Uhr.
    static func eintraege<E>(_ liste: [E], datum: (inout E, Date) -> Void) -> [E] {
        guard istUebersteuert, var erster = liste.first else { return liste }
        datum(&erster, .now)
        return [erster]
    }
}
