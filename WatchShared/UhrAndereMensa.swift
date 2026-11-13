import Foundation

/// „Andere Mensa“: gilt nur auf der Uhr und nur bis Mitternacht (Berliner Zeit). Die Watch-App legt sie in der Watch-Gruppe
/// ab; Siri liest sie mit, um zu wissen, welche Mensa die Mensa-Ansicht gerade zeigt.
/// Die Datei gehört zu iPhone-App (nur für die Tests) und Watch-App.
nonisolated struct AndereMensa: Codable, Equatable, Sendable {
    /// Schlüssel in `AppGroup.defaults` der Uhr.
    static let speicherSchluessel = "uhrAndereMensa"

    var mensaID: String
    var gueltigBis: Date

    init(mensa: MensaVenue, jetzt: Date) {
        mensaID = mensa.rawValue
        gueltigBis = EventKalender.tag(EventKalender.tagesbeginn(jetzt), plus: 1)
    }

    func mensa(jetzt: Date) -> MensaVenue? {
        jetzt < gueltigBis ? MensaVenue(rawValue: mensaID) : nil
    }

    /// Die gespeicherte Wahl; `nil` ohne Wahl.
    static func gespeichert(defaults: UserDefaults = AppGroup.defaults) -> AndereMensa? {
        defaults.data(forKey: speicherSchluessel).flatMap { try? JSONDecoder().decode(AndereMensa.self, from: $0) }
    }
}
