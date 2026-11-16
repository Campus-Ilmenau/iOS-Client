import SwiftUI

/// Die Ziele der iPad-Navigation: Tabs oben und Einträge der Seitenleiste. Mehrere Ziele können denselben `AppTab`
/// meinen (Bibliothek: Ausleihen, Katalog, Merkliste, Ausweis). Solange es dafür keine eigenen Ansichten gibt, zeigen sie
/// die Ansicht des Tabs, und der `AppRouter` bekommt dieselben Wünsche wie von einem Deeplink.
enum PadZiel: Hashable {
    case heute
    case mensa
    case thoska
    case ausleihen
    case katalog
    case merkliste
    case ausweis
    case eventsAlle
    case eventsAbend
    case mehr

    /// Der Tab, zu dem das Ziel gehört. „Mehr“ liegt wie auf dem iPhone unter „Heute“.
    var tab: AppTab {
        switch self {
        case .heute, .mehr: .heute
        case .mensa: .mensa
        case .thoska: .thoska
        case .ausleihen, .katalog, .merkliste, .ausweis: .bibliothek
        case .eventsAlle, .eventsAbend: .events
        }
    }

    /// Das Ziel, das ein Tab ohne weitere Angabe zeigt (Link, Wechsel der Hülle).
    static func standard(fuer tab: AppTab) -> PadZiel {
        switch tab {
        case .heute: .heute
        case .mensa: .mensa
        case .thoska: .thoska
        case .bibliothek: .ausleihen
        case .events: .eventsAlle
        }
    }

    /// Mehrere Ziele teilen sich die Ansicht ihres Tabs. Nur eines davon baut sie auf (`PadRootView.gemerkt`), damit sie
    /// nicht doppelt lebt und ein Wunsch an den Router nicht in einer unsichtbaren Kopie landet.
    var teiltTabAnsicht: Bool {
        switch self {
        case .ausleihen, .katalog, .merkliste, .ausweis, .eventsAlle, .eventsAbend: true
        case .heute, .mensa, .thoska, .mehr: false
        }
    }
}

extension AppRouter {
    /// Wählt ein Ziel der iPad-Navigation (Tab-Leiste oder Seitenleiste) samt Wunsch an dessen Ansicht.
    /// Dieselben Wünsche wie bei den Deeplinks, aber nicht „von außen“ (`kamGeradeVonAussen` bleibt unberührt).
    func waehle(_ neu: PadZiel) {
        wechsle(zu: neu) { self.wuensche(neu) }
    }

    private func wuensche(_ neu: PadZiel) {
        switch neu {
        // Aus der Seitenleiste öffnet der Katalog ohne Tastatur; den Fokus im Suchfeld gibt es über
        // „Im Katalog suchen“ und ⌘F (`zeigeKatalogSuche`).
        case .katalog: katalogOeffnen = true
        case .merkliste: merklisteOeffnen = true
        case .eventsAlle: eventsAlle = true
        case .eventsAbend: eventsHeuteAbend = true
        case .ausweis: ausweisWunsch = true
        case .heute, .mensa, .thoska, .ausleihen, .mehr: break
        }
    }

    /// ⌘F und „Im Katalog suchen“: die Katalogsuche mit Cursor im Suchfeld.
    func zeigeKatalogSuche() {
        wechsle(zu: .katalog) { self.katalogSuche = true }
    }

    /// Baut dieses Ziel die Ansicht seines Tabs auf? Von Zielen, die sich eine Ansicht teilen, genau eines: das gewählte,
    /// und solange der Tab nicht gewählt ist, das zuletzt gewählte.
    func baueAnsichtAuf(fuer dieses: PadZiel) -> Bool {
        guard dieses.teiltTabAnsicht else { return true }
        if ziel.tab == dieses.tab { return ziel == dieses }
        return letztes[dieses.tab] == dieses
    }
}
