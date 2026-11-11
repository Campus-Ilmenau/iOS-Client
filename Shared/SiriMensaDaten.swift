import Foundation

/// Die Daten für die Mensa-Antworten von Siri, auf demselben Weg wie das Widget „Mensa heute“: erst selbst laden
/// (Mensa-API, ohne Anmeldung) mit kurzem Zeitlimit, klappt das nicht, gilt der Speicher in der App Group.
@MainActor
enum SiriMensaDaten {
    /// Siri wartet nicht lange; das Limit gilt für alle Anfragen zusammen.
    static let zeitlimit: Duration = .seconds(4)

    /// - Parameter quelle: Vorgabe ist die Mensa-API; Tests geben eine eigene.
    static func laden(quelle: (any MensaDatenquelle)? = nil, store: WidgetStore = WidgetStore(), jetzt: Date) async -> WidgetSnapshot {
        await WidgetMensaAktualisierung(store: store)
            .ladeUndSpeichere(quelle: quelle ?? MensaHeuteQuelle(), jetzt: jetzt, zeitlimit: zeitlimit)
        return store.lesen()
    }
}
