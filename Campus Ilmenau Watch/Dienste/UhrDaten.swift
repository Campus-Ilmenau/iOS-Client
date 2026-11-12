import Foundation
import Observation

/// „Andere Mensa“: gilt nur auf der Uhr und nur bis Mitternacht (Berliner Zeit).
struct AndereMensa: Codable, Equatable {
    var mensaID: String
    var gueltigBis: Date

    init(mensa: MensaVenue, jetzt: Date) {
        mensaID = mensa.rawValue
        gueltigBis = EventKalender.tag(EventKalender.tagesbeginn(jetzt), plus: 1)
    }

    func mensa(jetzt: Date) -> MensaVenue? {
        jetzt < gueltigBis ? MensaVenue(rawValue: mensaID) : nil
    }
}

/// Die Daten der Uhr: Speiseplan und Veranstaltungen im `WidgetStore` der Watch-Gruppe, geladen mit denselben Routinen
/// wie die Widgets. Beim Öffnen ist sofort der letzte Stand da; das Laden hat ein Zeitlimit von 4 s
/// (`heuteMitZeitlimit`) und lässt bei Misserfolg den Stand, wie er war.
@MainActor
@Observable
final class UhrDaten {
    static let shared = UhrDaten()

    /// Zeitlimit für Mensa und Veranstaltungen, jeweils.
    static let zeitlimit: Duration = .seconds(4)

    private(set) var snapshot: WidgetSnapshot
    private(set) var laedt = false
    private(set) var andereMensa: AndereMensa?

    @ObservationIgnored private let store: WidgetStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let mensaQuelle: any MensaDatenquelle
    @ObservationIgnored private let eventsQuelle: any EventsDatenquelle

    private enum Schluessel {
        static let andereMensa = "uhrAndereMensa"
    }

    /// - Parameters:
    ///   - store: Vorgabe ist die Datei in der App Group der Uhr.
    ///   - defaults: Ablage für Zusatzstoffe und „Andere Mensa“.
    init(
        store: WidgetStore = WidgetStore(),
        defaults: UserDefaults = AppGroup.defaults,
        mensaQuelle: (any MensaDatenquelle)? = nil,
        eventsQuelle: (any EventsDatenquelle)? = nil
    ) {
        self.store = store
        self.defaults = defaults
        self.mensaQuelle = mensaQuelle ?? MensaHeuteQuelle()
        self.eventsQuelle = eventsQuelle ?? EventsService()
        snapshot = store.lesen()
        andereMensa = defaults.data(forKey: Schluessel.andereMensa).flatMap { try? JSONDecoder().decode(AndereMensa.self, from: $0) }
    }

    /// Für Previews: fester Stand, nichts wird geladen oder gespeichert.
    init(vorschau snapshot: WidgetSnapshot, andereMensa: AndereMensa? = nil) {
        store = WidgetStore(dateiURL: nil)
        defaults = UserDefaults(suiteName: "uhr-vorschau-\(UUID().uuidString)") ?? .standard
        mensaQuelle = MensaHeuteQuelle()
        eventsQuelle = EventsService()
        self.snapshot = snapshot
        self.andereMensa = andereMensa
    }

    /// Es gibt noch keine Mensa-Daten, auch nicht vom letzten Mal.
    var hatKeinenSpeiseplan: Bool { snapshot.mensen.isEmpty }

    /// Es gab noch nie Veranstaltungen (Speicher nie geschrieben): wie bei Siri „keine Daten“.
    var hatKeineVeranstaltungen: Bool {
        snapshot.stand == nil && snapshot.events.isEmpty && snapshot.woche == nil
    }

    /// Die Mensa, die gerade gilt: die „Andere Mensa“ von heute, sonst die vom iPhone.
    func mensa(einstellungen: UhrEinstellungen, jetzt: Date) -> MensaVenue {
        andereMensa?.mensa(jetzt: jetzt) ?? einstellungen.mensa
    }

    func waehleAndereMensa(_ mensa: MensaVenue, jetzt: Date = .now) {
        let neu = AndereMensa(mensa: mensa, jetzt: jetzt)
        andereMensa = neu
        defaults.set(try? JSONEncoder().encode(neu), forKey: Schluessel.andereMensa)
    }

    func gericht(id: String) -> WidgetGericht? {
        for mensa in snapshot.mensen {
            for plan in [mensa.heute, mensa.naechsterOeffnungstag] {
                if let gericht = plan?.gerichte.first(where: { $0.id == id }) { return gericht }
            }
        }
        return nil
    }

    /// Lädt Speiseplan und Veranstaltungen, beides mit 4 s Zeitlimit und gleichzeitig. Scheitert es, bleibt der letzte Stand.
    func laden(gemerkteEvents: [String], jetzt: Date = .now) async {
        guard !laedt else { return }
        laedt = true
        defer { laedt = false }

        let store = store, mensaQuelle = mensaQuelle, eventsQuelle = eventsQuelle
        async let mensa = WidgetMensaAktualisierung(store: store).ladeUndSpeichere(quelle: mensaQuelle, jetzt: jetzt, zeitlimit: Self.zeitlimit)
        async let events = WidgetEventsAktualisierung(store: store).ladeUndSpeichere(quelle: eventsQuelle, jetzt: jetzt, zeitlimit: Self.zeitlimit)
        _ = await (mensa, events)
        snapshot = store.lesen()

        uebernimm(gemerkteEvents: gemerkteEvents)
    }

    /// Die Beschreibung einer Veranstaltung für die Kurzinfo, auf 400 Zeichen gekürzt. Sie steht nicht im Speicher und
    /// kommt beim Öffnen aus der Events-API (Zeitlimit 4 s); ohne sie bleibt die Kurzinfo ohne Beschreibung.
    func beschreibung(eventID: String) async -> String? {
        let quelle = eventsQuelle
        let event = await heuteMitZeitlimit(Self.zeitlimit) { try await quelle.detail(id: eventID) }
        guard let text = event?.beschreibung?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return Self.gekuerzt(text, auf: 400)
    }

    static func gekuerzt(_ text: String, auf grenze: Int) -> String {
        guard text.count > grenze else { return text }
        return text.prefix(grenze).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    /// Die gemerkten Veranstaltungen des iPhones (Stern), ohne neu zu laden.
    func uebernimm(gemerkteEvents: [String]) {
        if store.aendern({ $0.gemerkteEventIDs = gemerkteEvents.sorted() }) {
            snapshot = store.lesen()
        }
    }
}
