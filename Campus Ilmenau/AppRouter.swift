import SwiftUI
import Observation

/// Welcher Tab gerade offen ist, und Wünsche an einen Tab (z. B. „zeig diese Mensa“).
/// Die Hülle (`ContentView`) hält den Router und reicht ihn über die Umgebung weiter.
@MainActor
@Observable
final class AppRouter {
    /// Der Router der App. Er ist einer für alle: Deeplinks und Intents (Steuerelemente) erreichen ihn schon, bevor
    /// die erste Ansicht steht.
    static let gemeinsam = AppRouter(wartetAufStart: true)

    var tab: AppTab = .heute

    /// Solange die Start-Animation läuft, wartet ein Ziel von außen. Sonst käme es unter der Animation an (oder das
    /// NFC-Sheet startete mitten in der Animation) und ginge verloren.
    private(set) var wartetAufStart: Bool
    private var wartendesZiel: DeepLink?

    init(wartetAufStart: Bool = false) {
        self.wartetAufStart = wartetAufStart
    }

    /// Hängt den Router an den `DeepLinkEingang`, damit auch Intents ihn erreichen.
    func verbinden() {
        DeepLinkEingang.verbinde { [weak self] link in self?.eingang(link) }
    }

    /// Ein Ziel von außen (Link oder Intent): sofort, oder nach der Start-Animation, wenn die App gerade erst startet.
    func eingang(_ link: DeepLink) {
        if wartetAufStart {
            wartendesZiel = link
        } else {
            oeffne(link)
        }
    }

    /// Die Start-Animation ist vorbei: Ein wartendes Ziel wird jetzt geöffnet.
    func startBeendet() {
        wartetAufStart = false
        if let ziel = wartendesZiel {
            wartendesZiel = nil
            oeffne(ziel)
        }
    }
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
    /// Der Events-Tab zeigt beim nächsten Erscheinen die Liste ohne Filter (Link `campusilmenau://events`).
    var eventsAlle = false
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
        case .events:
            eventsAlle = true
            tab = .events
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
