import Foundation

// MARK: - Mensa

/// Woher die Heute-Seite Speiseplan und Öffnungszeiten holt (`MensaDatenquelle`, gemeinsam mit dem Widget).
/// Tests und Previews setzen eine eigene Quelle.
typealias HeuteMensaDatenquelle = MensaDatenquelle

// MARK: - Hinweise

/// Redaktioneller Hinweis für die Startseite, mit Zeitraum und Priorität.
struct Hinweis: Identifiable, Equatable, Sendable {
    enum Farbe: Equatable, Sendable {
        case blau
        case gruen
    }

    let id: String
    /// „Studium“
    var kategorie: String
    /// „ab Mo, 9. Nov.“
    var zeitangabe: String?
    var titel: String
    var text: String
    /// SF-Symbol-Name der Icon-Fläche.
    var symbol: String
    var farbe: Farbe
    /// Angezeigt von … bis (exklusiv); `nil` heißt unbegrenzt.
    var von: Date?
    var bis: Date?
    /// Höhere Zahl zuerst.
    var prioritaet: Int

    init(
        id: String, kategorie: String, zeitangabe: String? = nil, titel: String, text: String,
        symbol: String = "info.circle", farbe: Farbe = .blau, von: Date? = nil, bis: Date? = nil, prioritaet: Int = 0
    ) {
        self.id = id
        self.kategorie = kategorie
        self.zeitangabe = zeitangabe
        self.titel = titel
        self.text = text
        self.symbol = symbol
        self.farbe = farbe
        self.von = von
        self.bis = bis
        self.prioritaet = prioritaet
    }

    func gilt(am zeitpunkt: Date) -> Bool {
        if let von, zeitpunkt < von { return false }
        if let bis, zeitpunkt >= bis { return false }
        return true
    }
}

/// Woher die Hinweise kommen. Einen Endpunkt gibt es noch nicht, siehe `LeereHinweiseQuelle`.
@MainActor
protocol HinweiseQuelle {
    func hinweise(jetzt: Date) async throws -> [Hinweis]
}

/// Platzhalter, bis der Server Hinweise liefert: keine Hinweise, der Abschnitt entfällt.
struct LeereHinweiseQuelle: HinweiseQuelle {
    func hinweise(jetzt: Date) async throws -> [Hinweis] { [] }
}
