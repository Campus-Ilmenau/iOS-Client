import Foundation

/// Was das iPhone der Uhr per `WCSession.updateApplicationContext` schickt: Mensa der Startseite, Preisgruppe,
/// Filter der App und die gemerkten Veranstaltungen. Auf der Uhr liegt der letzte Stand in `AppGroup.defaults`, das ist dort die eigene Gruppe.
/// Ohne diese Daten nimmt die Uhr Ehrenberg, Studierende und keinen Filter (`vorgabe`).
nonisolated struct UhrEinstellungen: Equatable, Sendable {
    var mensa: MensaVenue
    var preisgruppe: MensaPriceGroup
    var filter: MensaFilter
    /// IDs der Veranstaltungen, die auf dem iPhone gemerkt sind (Stern in „Heute Abend“), sortiert.
    var gemerkteEvents: [String]

    /// Ohne Daten vom iPhone.
    static let vorgabe = UhrEinstellungen()

    /// Schlüssel, unter dem die Uhr den letzten Stand ablegt.
    static let speicherSchluessel = "uhrEinstellungen"

    private enum Schluessel {
        static let mensa = "mensa"
        static let preisgruppe = "preisgruppe"
        static let filter = "filter"
        static let gemerkteEvents = "gemerkteEvents"
    }

    /// Das Wörterbuch für `updateApplicationContext`; nur Property-List-Typen.
    var kontext: [String: Any] {
        var kontext: [String: Any] = [
            Schluessel.mensa: mensa.rawValue,
            Schluessel.preisgruppe: preisgruppe.rawValue
        ]
        if let daten = try? JSONEncoder().encode(filter) {
            kontext[Schluessel.filter] = daten
        }
        kontext[Schluessel.gemerkteEvents] = gemerkteEvents
        return kontext
    }

    /// `nil`, wenn das Wörterbuch leer ist (noch nichts vom iPhone). Ein einzelnes fehlendes oder unbekanntes
    /// Feld fällt auf seine Vorgabe zurück.
    init?(kontext: [String: Any]) {
        guard !kontext.isEmpty else { return nil }
        mensa = (kontext[Schluessel.mensa] as? String).flatMap(MensaVenue.init(rawValue:)) ?? Self.vorgabe.mensa
        preisgruppe = (kontext[Schluessel.preisgruppe] as? String).flatMap(MensaPriceGroup.init(rawValue:)) ?? Self.vorgabe.preisgruppe
        filter = (kontext[Schluessel.filter] as? Data).flatMap { try? JSONDecoder().decode(MensaFilter.self, from: $0) }
            ?? Self.vorgabe.filter
        gemerkteEvents = (kontext[Schluessel.gemerkteEvents] as? [String]) ?? []
    }

    init(
        mensa: MensaVenue = .mensaEhrenberg, preisgruppe: MensaPriceGroup = .studierende, filter: MensaFilter = MensaFilter(),
        gemerkteEvents: [String] = []
    ) {
        self.mensa = mensa
        self.preisgruppe = preisgruppe
        self.filter = filter
        self.gemerkteEvents = gemerkteEvents.sorted()
    }
}

/// Handoff von der Uhr zum iPhone: Die Uhr bietet beim Tippen auf „Auf iPhone öffnen“ eine `NSUserActivity` an, die den
/// Deeplink (`campusilmenau://events/<id>`) trägt. Das iPhone öffnet ihn über denselben Weg wie jeden Link von außen.
nonisolated enum UhrHandoff {
    /// Muss unter `NSUserActivityTypes` in den Info.plist von iPhone-App und Watch-App stehen.
    static let eventTyp = "de.kai-gothe.Campus-Ilmenau.event"
    static let urlSchluessel = "url"
}
