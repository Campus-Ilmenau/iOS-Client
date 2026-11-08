import Foundation

/// Woher die Ansicht ihre Daten holt. Der `EventsService` ist die echte Quelle, Previews und Tests setzen eine eigene.
@MainActor
protocol EventsDatenquelle {
    func liste(filter: EventFilter, seite: Int, jetzt: Date) async throws -> EventSeite
    func veranstalter() async throws -> [Veranstalter]
    func detail(id: String) async throws -> CampusEvent
}

extension EventsService: EventsDatenquelle {}
