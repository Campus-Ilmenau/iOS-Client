import WidgetKit

/// Sagt den Watch-Widgets, wann sie neu lesen sollen. Die Watch-App füllt die App Group und meldet jede Änderung
/// hierüber; beim Laden ihrer Zeitleiste holen Mensa und Heute Abend außerdem selbst frische Daten (Zeitlimit 4 s).
enum UhrWidgetSync {
    static func neuLaden(_ kinds: [String]) {
        for kind in kinds { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
    }

    /// Neuer Speiseplan oder neue Einstellungen (Mensa, Preisgruppe, Filter).
    static func mensaGeaendert() { neuLaden([UhrWidgetKinds.mensa]) }

    /// Neue Veranstaltungen oder neue gemerkte Veranstaltungen.
    static func veranstaltungenGeaendert() { neuLaden([UhrWidgetKinds.heuteAbend]) }

    /// Abgehakt, neuer Stand vom iPhone oder neue Standorte.
    static func merklisteGeaendert() { neuLaden([UhrWidgetKinds.merkliste]) }
}
