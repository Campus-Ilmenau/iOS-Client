import Foundation

// MARK: - Mensa

/// Woher die Heute-Seite Speiseplan und Öffnungszeiten holt. Tests und Previews setzen eine eigene Quelle.
@MainActor
protocol HeuteMensaDatenquelle {
    /// Alle gelieferten Gerichte aller Mensen für den Tag.
    func speiseplan(am tag: Date) async throws -> [MensaMeal]
    func mensen() async throws -> [Canteen]
}

/// Die echte Quelle. Jede Anfrage bekommt einen eigenen `MensaService`, weil dieser nur ein gemeinsames `meals`-Feld hat
/// und parallele Anfragen sich sonst überschreiben würden.
@MainActor
struct MensaHeuteQuelle: HeuteMensaDatenquelle {
    func speiseplan(am tag: Date) async throws -> [MensaMeal] {
        let service = MensaService()
        // Mittag des Berliner Tages, damit der API-Tag auch bei anderer Gerätezeitzone stimmt.
        try await service.fetchMeals(date: HeuteUhr.datum(am: tag, minuten: 12 * 60))
        return service.meals
    }

    func mensen() async throws -> [Canteen] {
        let service = MensaService()
        try await service.fetchCanteens()
        return service.canteens
    }
}

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

// MARK: - Zeitlimit

private struct HeuteZeitablauf: Error {}

/// Führt `arbeit` mit Zeitlimit aus. Fehler und Zeitablauf ergeben `nil`, die Seite hängt nie.
/// Bei Abbruch der Aufgabe kommt ebenfalls `nil`.
@MainActor
func heuteMitZeitlimit<T: Sendable>(
    _ limit: Duration,
    _ arbeit: @escaping @MainActor @Sendable () async throws -> T
) async -> T? {
    do {
        return try await withThrowingTaskGroup(of: T.self) { gruppe in
            gruppe.addTask { try await arbeit() }
            gruppe.addTask {
                try await Task.sleep(for: limit)
                throw HeuteZeitablauf()
            }
            defer { gruppe.cancelAll() }
            guard let erstes = try await gruppe.next() else { throw HeuteZeitablauf() }
            return erstes
        }
    } catch {
        return nil
    }
}
