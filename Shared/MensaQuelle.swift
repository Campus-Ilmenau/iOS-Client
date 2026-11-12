import Foundation

// MARK: - Mensa

/// Woher Speiseplan und Öffnungszeiten kommen. Die App (Heute-Seite) und das Mensa-Widget nutzen dieselbe Quelle;
/// Tests und Previews setzen eine eigene. Die Mensa-API braucht keine Anmeldung.
@MainActor
protocol MensaDatenquelle {
    /// Alle gelieferten Gerichte aller Mensen für den Tag.
    func speiseplan(am tag: Date) async throws -> [MensaMeal]
    func mensen() async throws -> [Canteen]
}

/// Die echte Quelle. Jede Anfrage bekommt einen eigenen `MensaService`, weil dieser nur ein gemeinsames `meals`-Feld hat
/// und parallele Anfragen sich sonst überschreiben würden.
@MainActor
struct MensaHeuteQuelle: MensaDatenquelle {
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

// MARK: - Zeitlimit

private struct HeuteZeitablauf: Error {}

/// Führt `arbeit` mit Zeitlimit aus. Fehler und Zeitablauf ergeben `nil`, die Seite hängt nie.
/// Bei Abbruch der Aufgabe kommt ebenfalls `nil`.
/// - Parameter clock: Die Uhr, nach der das Limit läuft. Tests geben eine, die nur vorläuft, wenn sie es sagen.
@MainActor
func heuteMitZeitlimit<T: Sendable>(
    _ limit: Duration,
    clock: any Clock<Duration> = ContinuousClock(),
    _ arbeit: @escaping @MainActor @Sendable () async throws -> T
) async -> T? {
    do {
        return try await withThrowingTaskGroup(of: T.self) { gruppe in
            gruppe.addTask { try await arbeit() }
            gruppe.addTask {
                try await clock.sleep(for: limit)
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
