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
}
