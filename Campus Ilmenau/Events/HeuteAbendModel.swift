import Foundation
import Observation

/// Daten für die Karte „Heute Abend“ auf der Heute-Seite: die ersten Veranstaltungen ab 17 Uhr, ohne abgesagte.
///
/// Die Karte darf die Seite nie aufhalten. Deshalb läuft das Laden mit Zeitlimit, und bei einem Fehler oder
/// Zeitablauf bleibt die Liste leer. Eine leere Liste heißt für die Ansicht: Karte weglassen.
@MainActor
@Observable
final class HeuteAbendModel {
    /// So viele Einträge zeigt die Karte höchstens.
    static let maxEintraege = 3

    private struct Zeitablauf: Error {}

    let quelle: any EventsDatenquelle
    let zeitlimit: Duration

    private(set) var events: [CampusEvent] = []

    @ObservationIgnored private let jetzt: @MainActor () -> Date
    /// Die Uhr für das Zeitlimit. Tests geben eine, die nur vorläuft, wenn sie es sagen.
    @ObservationIgnored private let clock: any Clock<Duration>

    init(
        quelle: (any EventsDatenquelle)? = nil,
        zeitlimit: Duration = .seconds(5),
        jetzt: @escaping @MainActor () -> Date = { .now },
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.quelle = quelle ?? EventsService()
        self.zeitlimit = zeitlimit
        self.jetzt = jetzt
        self.clock = clock
    }

    /// Die Uhrzeit, auf die sich „heute“ in den Zeitzeilen bezieht.
    var jetztZeit: Date { jetzt() }

    /// Der Filter der Karte, derselbe wie bei „Heute Abend“ in der Liste.
    static var filter: EventFilter {
        EventFilter(heuteAbend: true, abgesagteAusblenden: true)
    }

    /// Lädt die Karte. Fehler und Zeitablauf lassen sie verschwinden, sie werfen nie.
    func laden() async {
        let quelle = quelle
        let zeit = jetzt()
        do {
            let seite = try await mitZeitlimit {
                try await quelle.liste(filter: Self.filter, seite: 1, jetzt: zeit)
            }
            events = Array(seite.events.filter { $0.status != .abgesagt }.prefix(Self.maxEintraege))
        } catch is CancellationError {
            return
        } catch {
            events = []
        }
    }

    private func mitZeitlimit<T: Sendable>(_ arbeit: @escaping @MainActor @Sendable () async throws -> T) async throws -> T {
        let limit = zeitlimit, clock = clock
        return try await withThrowingTaskGroup(of: T.self) { gruppe in
            gruppe.addTask { try await arbeit() }
            gruppe.addTask {
                try await clock.sleep(for: limit)
                throw Zeitablauf()
            }
            defer { gruppe.cancelAll() }
            guard let erstes = try await gruppe.next() else { throw Zeitablauf() }
            return erstes
        }
    }
}
