import SwiftUI
import Observation

/// Welcher Tab gerade offen ist, und Wünsche an einen Tab (z. B. „zeig diese Mensa“).
/// Die Hülle (`ContentView`) hält den Router und reicht ihn über die Umgebung weiter.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .heute
    /// Mensa, die der Mensa-Tab beim nächsten Erscheinen zeigen soll. Der Tab setzt sie danach zurück.
    var mensaWunsch: MensaVenue?

    func zeigeMensa(_ venue: MensaVenue? = nil) {
        mensaWunsch = venue
        tab = .mensa
    }

    /// Der Mensa-Tab öffnet beim nächsten Erscheinen die Öffnungszeiten.
    var mensaOeffnungszeiten = false
    /// Der Events-Tab schaltet beim nächsten Erscheinen „Heute Abend“ ein.
    var eventsHeuteAbend = false

    func zeigeOeffnungszeiten(_ venue: MensaVenue? = nil) {
        mensaOeffnungszeiten = true
        zeigeMensa(venue)
    }

    func zeigeEvents() {
        tab = .events
    }

    /// „Alle“ bei „Heute Abend“: Events-Tab mit aktivem Filter.
    func zeigeEventsHeuteAbend() {
        eventsHeuteAbend = true
        tab = .events
    }

    // MARK: Deeplinks

    /// Ein Gericht, das der Mensa-Tab beim nächsten Erscheinen öffnen soll (Link aus dem Widget).
    struct GerichtWunsch: Equatable {
        let id: String
        /// Berliner Tag `yyyy-MM-dd`, an dem es das Gericht gibt; `nil` heißt heute.
        let tag: String?
    }

    var gerichtWunsch: GerichtWunsch?
    /// Der Events-Tab öffnet beim nächsten Erscheinen das Detail dieser Veranstaltung.
    var eventWunsch: String?
    /// Der Thoska-Tab startet beim nächsten Erscheinen sofort das Auslesen (NFC-Sheet).
    var thoskaAuslesen = false
    /// Der Bibliothek-Tab öffnet beim nächsten Erscheinen die Katalogsuche mit offener Tastatur.
    var katalogSuche = false

    /// Wählt Tab und Ziel zu einem Deeplink (`campusilmenau://…`). Die Tabs lesen den Wunsch beim Erscheinen,
    /// auch wenn sie erst durch den Link zum ersten Mal aufgebaut werden.
    func oeffne(_ link: DeepLink) {
        switch link {
        case .mensa(let id):
            zeigeMensa(id.flatMap(MensaVenue.init(rawValue:)))
        case .gericht(let id, let tag):
            gerichtWunsch = GerichtWunsch(id: id, tag: tag)
            tab = .mensa
        case .eventsHeuteAbend:
            zeigeEventsHeuteAbend()
        case .event(let id):
            eventWunsch = id
            tab = .events
        case .thoskaAuslesen:
            thoskaAuslesen = true
            tab = .thoska
        case .katalogSuche:
            katalogSuche = true
            tab = .bibliothek
        }
    }
}
