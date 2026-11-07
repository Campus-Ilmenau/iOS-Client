import Foundation

/// Die App Group, die App und Widget-Extension teilen. Hier liegt nur, was nicht veraltet: Mensa auf der Startseite,
/// Preisgruppe und der Speicher für Widgets (`WidgetStore`). Keine Kontodaten (kein Thoska-Guthaben, keine Ausleihen,
/// kein Bibliotheks-Token).
///
/// Diese Datei gehört zu App und Widget-Extension. Ihre Typen sind darum ausdrücklich `nonisolated`.
nonisolated enum AppGroup {
    static let kennung = "group.de.kai-gothe.Campus-Ilmenau"

    /// Die gemeinsamen Einstellungen. Fehlt die Gruppe (z. B. in Tests ohne Entitlement), gilt `.standard`.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: kennung) ?? .standard
    }

    /// Ordner der Gruppe für Dateien; `nil` ohne Entitlement.
    static var ordner: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kennung)
    }

    // MARK: Einstellungen

    /// Schlüssel „Mensa auf der Startseite“ (Wert: `MensaVenue.rawValue`).
    static let heuteMensaSchluessel = "heuteMensa"
    /// Schlüssel der Preisgruppe (Wert: `MensaPriceGroup.rawValue`).
    static let preisgruppeSchluessel = "mensaPriceGroup"

    private static let migrationsSchluessel = "appGroupEinstellungenUebernommen"

    /// Übernimmt einmalig die bisherigen Werte aus den Standard-Einstellungen der App und entfernt sie dort,
    /// damit es nur noch eine Quelle gibt. Ein Wert, der in der Gruppe schon steht, bleibt unberührt.
    static func uebernimmEinstellungenEinmalig(von alt: UserDefaults = .standard, nach neu: UserDefaults = AppGroup.defaults) {
        guard alt !== neu, !neu.bool(forKey: migrationsSchluessel) else { return }
        for schluessel in [heuteMensaSchluessel, preisgruppeSchluessel] {
            if neu.object(forKey: schluessel) == nil, let wert = alt.string(forKey: schluessel) {
                neu.set(wert, forKey: schluessel)
            }
            alt.removeObject(forKey: schluessel)
        }
        neu.set(true, forKey: migrationsSchluessel)
    }
}

/// Namen der Widgets (`kind`). Die App lädt damit gezielt deren Zeitleisten neu.
nonisolated enum WidgetKinds {
    static let mensa = "de.kai-gothe.Campus-Ilmenau.widget.mensa"
    static let heuteAbend = "de.kai-gothe.Campus-Ilmenau.widget.heute-abend"
    static let events = "de.kai-gothe.Campus-Ilmenau.widget.events"

    /// Alle Widgets, deren Daten aus dem `WidgetStore` stammen.
    static let alle = [mensa, heuteAbend, events]
}
