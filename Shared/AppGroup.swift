import Foundation

/// Die App Group, die App und Widget-Extension teilen (auf der Uhr die eigene Gruppe von Watch-App und Watch-Widgets). Hier liegt nur, was nicht veraltet: Mensa auf der Startseite,
/// Preisgruppe und der Speicher für Widgets (`WidgetStore`). Keine Kontodaten (kein Thoska-Guthaben, keine Ausleihen,
/// kein Bibliotheks-Token).
///
/// Diese Datei gehört zu App und Widget-Extension. Ihre Typen sind darum ausdrücklich `nonisolated`.
nonisolated enum AppGroup {
    #if os(watchOS)
    /// Die Uhr kann die Gruppe des iPhones nicht lesen; Watch-App und Watch-Widgets haben eine eigene.
    static let kennung = "group.de.kai-gothe.Campus-Ilmenau.watch"
    #else
    static let kennung = "group.de.kai-gothe.Campus-Ilmenau"
    #endif

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
    private static let filterMigrationsSchluessel = "mensaFilterUebernommen"

    /// Übernimmt einmalig die bisherigen Werte aus den Standard-Einstellungen der App und entfernt sie dort,
    /// damit es nur noch eine Quelle gibt. Ein Wert, der in der Gruppe schon steht, bleibt unberührt.
    /// Der Mensa-Filter hat eine eigene Marke: Er kam später dazu, die App kann also schon übernommen haben.
    static func uebernimmEinstellungenEinmalig(von alt: UserDefaults = .standard, nach neu: UserDefaults = AppGroup.defaults) {
        guard alt !== neu else { return }
        uebernimm([heuteMensaSchluessel, preisgruppeSchluessel], marke: migrationsSchluessel, von: alt, nach: neu) {
            $0.string(forKey: $1)
        }
        // Filter (auch der Stand des alten Drei-Zustände-Filters, den `MensaFilterStore` beim Laden umrechnet).
        uebernimm([MensaFilterStore.key, MensaFilterStore.legacyKey], marke: filterMigrationsSchluessel, von: alt, nach: neu) {
            $0.data(forKey: $1)
        }
    }

    private static func uebernimm(
        _ schluessel: [String], marke: String, von alt: UserDefaults, nach neu: UserDefaults,
        wert: (UserDefaults, String) -> Any?
    ) {
        guard !neu.bool(forKey: marke) else { return }
        for eintrag in schluessel {
            if neu.object(forKey: eintrag) == nil, let gefunden = wert(alt, eintrag) {
                neu.set(gefunden, forKey: eintrag)
            }
            alt.removeObject(forKey: eintrag)
        }
        neu.set(true, forKey: marke)
    }
}

/// Namen der Widgets (`kind`). Die App lädt damit gezielt deren Zeitleisten neu.
nonisolated enum WidgetKinds {
    static let mensa = "de.kai-gothe.Campus-Ilmenau.widget.mensa"
    static let heuteAbend = "de.kai-gothe.Campus-Ilmenau.widget.heute-abend"

    /// Alle Widgets, deren Daten aus dem `WidgetStore` stammen.
    static let alle = [mensa, heuteAbend]
}
