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

    /// Das gewählte Ziel der Navigation. Auf dem iPhone zählt nur sein Tab; auf dem iPad ist es auch der Eintrag der
    /// Seitenleiste (Katalog, Merkliste, Heute Abend …). Links setzen es mit, damit die Seitenleiste das Richtige markiert.
    var ziel: PadZiel = .heute {
        didSet { if ziel.teiltTabAnsicht { letztes[ziel.tab] = ziel } }
    }
    /// Welches Ziel eines Tabs zuletzt gewählt war: Es baut die geteilte Ansicht des Tabs auf (`PadZiel.teiltTabAnsicht`).
    private(set) var letztes: [AppTab: PadZiel] = [.bibliothek: .ausleihen, .events: .eventsAlle]

    /// Ein Wunsch an die neue Ansicht ist unterwegs: Er kommt erst an, wenn die bisherige Ansicht des Tabs abgebaut ist.
    /// Die Bibliothek zeigt solange kein Anmelde-Sheet.
    private(set) var wunschUnterwegs = false
    /// Die Seitenleiste des iPads ist sichtbar (angedockt oder darübergelegt). Die Ansicht des Tabs meldet es über
    /// `tabBarPlacement`; `PadRootView` wählt danach die Tint (Kontrast der Auswahl).
    var seitenleisteSichtbar = false
    /// ⌘R („Neu laden“): zählt hoch; die Ansicht des gewählten Tabs lädt dann neu.
    private(set) var neuLadenZaehler = 0
    func neuLaden() { neuLadenZaehler += 1 }

    /// Die iPad-Hülle ist zu sehen. Nur dort teilen sich Ziele die Ansicht eines Tabs (`PadZiel.teiltTabAnsicht`).
    var padHuelleAktiv = false

    /// Der gewählte Tab. Ihn zu setzen wählt dessen zuletzt gewähltes Ziel, sofern er nicht schon gewählt ist.
    var tab: AppTab {
        get { ziel.tab }
        set { if ziel.tab != newValue { ziel = letztes[newValue] ?? .standard(fuer: newValue) } }
    }

    /// Zustand, der den Wechsel der Hülle (iPad voll ↔ schmaler Split View) überleben soll: Die Ansichten entstehen
    /// dabei neu, diese Werte nicht.
    @ObservationIgnored lazy var eventsModel = EventsModel(widgetSync: .shared)
    var mensaTagIndex = 0
    var mensaMahlzeit: MensaMealtime = .lunch

    /// Solange die Start-Animation läuft, wartet ein Ziel von außen. Sonst käme es unter der Animation an (oder das
    /// NFC-Sheet startete mitten in der Animation) und ginge verloren.
    private(set) var wartetAufStart: Bool
    private var wartendesZiel: DeepLink?

    init(wartetAufStart: Bool = false) {
        self.wartetAufStart = wartetAufStart
    }

    /// Wann zuletzt ein Ziel von außen geöffnet wurde (Widget, Steuerelement, Siri, Vorschlag). Dafür meldet die App
    /// nichts an Siri, denn iOS zählt solche Aktionen selbst.
    @ObservationIgnored private var letzteAussenAktion: Date?
    /// So lange gilt eine Öffnung von außen als „gerade ausgelöst“.
    static let aussenFenster: TimeInterval = 3

    /// Wurde die Ansicht gerade durch ein Widget, ein Steuerelement, Siri oder einen Vorschlag geöffnet?
    /// Dann zählt die Aktion nicht als Handlung in der App.
    func kamGeradeVonAussen(jetzt: Date = .now) -> Bool {
        guard let letzteAussenAktion else { return false }
        return jetzt.timeIntervalSince(letzteAussenAktion) < Self.aussenFenster
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
        wechsle(zu: .eventsAbend) { self.eventsHeuteAbend = true }
    }

    /// Der Wunsch, der auf das Erscheinen der neuen Ansicht eines Tabs wartet (siehe `wechsle`).
    @ObservationIgnored private var ausstehenderWunsch: (tab: AppTab, aktion: @MainActor () -> Void)?

    /// Wählt ein Ziel und stellt danach den Wunsch an dessen Ansicht. Teilen sich mehrere Ziele die Ansicht ihres Tabs und
    /// wechselt sie zu einem anderen Ziel, wird die bisherige Ansicht abgebaut und eine neue aufgebaut. Käme der Wunsch
    /// gleich, schluckte ihn noch die alte (und öffnete ihn in einer Ansicht, die gleich verschwindet). Darum wartet er, bis
    /// die neue Ansicht erscheint und sich meldet (`ansichtErschienen`); nach 0,6 s kommt er auch ohne sie an.
    func wechsle(zu neu: PadZiel, wunsch: @escaping @MainActor () -> Void) {
        let wechseltAnsicht = padHuelleAktiv && neu.teiltTabAnsicht && letztes[neu.tab] != neu
        ziel = neu
        guard wechseltAnsicht else { wunsch(); return }
        wunschUnterwegs = true
        ausstehenderWunsch = (neu.tab, wunsch)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            liefereAusstehendenWunsch()
        }
    }

    /// Die Ansicht eines Tabs ist erschienen: Ein auf sie wartender Wunsch kommt jetzt an.
    func ansichtErschienen(_ tab: AppTab) {
        if ausstehenderWunsch?.tab == tab { liefereAusstehendenWunsch() }
    }

    private func liefereAusstehendenWunsch() {
        guard let wartend = ausstehenderWunsch else { return }
        ausstehenderWunsch = nil
        wartend.aktion()
        wunschUnterwegs = false
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
    /// Der Bibliothek-Tab öffnet beim nächsten Erscheinen die Katalogsuche ohne Fokus im Suchfeld (Seitenleiste).
    var katalogOeffnen = false
    /// Der Bibliothek-Tab öffnet beim nächsten Erscheinen die Katalogsuche und lädt die Treffer zu diesem Begriff (ohne Fokus).
    var katalogBegriff: String?
    /// Der Bibliothek-Tab öffnet beim nächsten Erscheinen das Detail dieses Katalog-Titels.
    var katalogTitelWunsch: String?
    /// Der Bibliothek-Tab startet beim nächsten Erscheinen die Abfrage für den Bibliotheksausweis (Seitenleiste „Ausweis“).
    var ausweisWunsch = false
    /// Der Bibliothek-Tab öffnet beim nächsten Erscheinen die Merkliste.
    var merklisteOeffnen = false

    /// Wählt Tab und Ziel zu einem Deeplink (`campusilmenau://…`). Die Tabs lesen den Wunsch beim Erscheinen,
    /// auch wenn sie erst durch den Link zum ersten Mal aufgebaut werden.
    func oeffne(_ link: DeepLink, jetzt: Date = .now) {
        // Alles, was hier ankommt, kam von außen: aus einem Link, einem Steuerelement oder einem Intent.
        letzteAussenAktion = jetzt
        switch link {
        case .mensa(let id):
            zeigeMensa(id.flatMap(MensaVenue.init(rawValue:)))
        case .gericht(let id, let tag):
            gerichtWunsch = GerichtWunsch(id: id, tag: tag)
            tab = .mensa
        case .events:
            wechsle(zu: .eventsAlle) { self.eventsAlle = true }
        case .eventsHeuteAbend:
            zeigeEventsHeuteAbend()
        case .event(let id):
            eventWunsch = id
            tab = .events
        case .thoskaAuslesen:
            // Ohne NFC (iPad) gibt es keinen Thoska-Tab, also auch kein Ziel dorthin.
            guard NFCVerfuegbarkeit.vorhanden else { return }
            thoskaAuslesen = true
            tab = .thoska
        case .katalogSuche:
            wechsle(zu: .katalog) { self.katalogSuche = true }
        case .katalogSuchen(let begriff):
            wechsle(zu: .katalog) { self.katalogBegriff = begriff }
        case .katalogTitel(let id):
            wechsle(zu: .katalog) { self.katalogTitelWunsch = id }
        case .mensaZeiten:
            zeigeOeffnungszeiten()
        case .merkliste:
            wechsle(zu: .merkliste) { self.merklisteOeffnen = true }
        }
    }
}
