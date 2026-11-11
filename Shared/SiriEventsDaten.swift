import Foundation

/// Die Daten für „Heute Abend“ bei Siri, auf demselben Weg wie das Widget „Heute Abend“: erst selbst laden
/// (Events-API, ohne Anmeldung, mit Abgesagten) mit kurzem Zeitlimit, klappt das nicht, gilt der Speicher der App Group.
@MainActor
enum SiriEventsDaten {
    /// Siri wartet nicht lange; das Limit gilt für alle Anfragen zusammen.
    static let zeitlimit: Duration = .seconds(4)

    /// - Parameter quelle: Vorgabe ist die Events-API; Tests geben eine eigene.
    static func laden(quelle: (any EventsDatenquelle)? = nil, store: WidgetStore = WidgetStore(), jetzt: Date) async -> WidgetSnapshot {
        await WidgetEventsAktualisierung(store: store)
            .ladeUndSpeichere(quelle: quelle ?? EventsService(), jetzt: jetzt, zeitlimit: zeitlimit)
        return store.lesen()
    }
}
