import SwiftUI

/// Die Bereiche von „Mehr & Einstellungen“ auf dem iPad (Liste links, Untermenü rechts), nach `PadMehr.dc.html`.
/// Der Rohwert ist zugleich der Wert im Link `campusilmenau://mehr?bereich=<darstellung|mensa|konto|sprache|ueber>`.
enum MehrBereich: String, CaseIterable, Identifiable, Hashable {
    case konto
    case darstellung
    case mensa
    case sprache
    case ueber

    var id: String { rawValue }

    /// Beim Öffnen gewählt: Mensa, die häufigste Einstellung.
    static let standard: MehrBereich = .mensa

    /// Die Gruppe unter der Konto-Karte.
    static let gruppe: [MehrBereich] = [.darstellung, .mensa, .sprache, .ueber]

    /// Aus dem Wert des Links; unbekannte Werte ergeben `nil` (dann gilt `standard`).
    init?(link wert: String?) {
        guard let wert, let bereich = MehrBereich(rawValue: wert.lowercased()) else { return nil }
        self = bereich
    }

    var titel: LocalizedStringKey {
        switch self {
        case .konto: "Bibliothekskonto"
        case .darstellung: "Darstellung"
        case .mensa: "Mensa"
        case .sprache: "Sprache"
        case .ueber: "Über die App"
        }
    }

    var symbol: String {
        switch self {
        case .konto: "person"
        case .darstellung: "circle.lefthalf.filled"
        case .mensa: "fork.knife"
        case .sprache: "globe"
        case .ueber: "info.circle"
        }
    }

    /// Farbe der Symbol-Kachel (30 pt): Blau und Grün nur als Fläche, sonst `surfaceSecondary`.
    enum Kachel { case blau, gruen, neutral }

    var kachel: Kachel {
        switch self {
        case .konto, .darstellung: .blau
        case .mensa: .gruen
        case .sprache, .ueber: .neutral
        }
    }

    /// Der nächste (`+1`) bzw. vorige (`−1`) Bereich in der Reihenfolge der Liste (Pfeiltasten ↓/↑).
    func nachbar(_ schritt: Int) -> MehrBereich {
        let alle = Self.allCases
        let index = alle.firstIndex(of: self) ?? 0
        return alle[min(max(index + schritt, 0), alle.count - 1)]
    }
}
