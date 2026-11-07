import Foundation
import Observation

/// Woher die Ansicht ihre Daten holt. Der `EventsService` ist die echte Quelle, Previews und Tests setzen eine eigene.
@MainActor
protocol EventsDatenquelle {
    func liste(filter: EventFilter, seite: Int, jetzt: Date) async throws -> EventSeite
    func veranstalter() async throws -> [Veranstalter]
    func detail(id: String) async throws -> CampusEvent
}

extension EventsService: EventsDatenquelle {}

/// Zustand der Ansicht „Veranstaltungen“ und der Ansicht „Vergangene“: Auswahl, geladene Seiten, Laden und Fehler.
///
/// Wechselt die Auswahl, startet die Ansicht `laden()` über `task(id: ladeSchluessel)` neu; SwiftUI bricht die laufende
/// Anfrage ab. Nachzügler, die trotzdem noch ankommen, verwirft die `generation`.
@MainActor
@Observable
final class EventsModel {
    enum Modus: Sendable {
        case kommende
        case vergangene
    }

    enum Zustand: Equatable {
        case laedt
        case geladen
        case fehler
    }

    /// Alles, was eine neue Abfrage an die API auslöst. „Gemerkt“ gehört nicht dazu, das filtert die App.
    struct LadeSchluessel: Hashable {
        var tag: Date?
        var heuteAbend: Bool
        var veranstalter: String?
        var art: EventArt
        var abgesagteAusblenden: Bool
        var versuch: Int
    }

    /// Wie viele Tage die Tagesleiste zeigt.
    static let tageAnzahl = 14
    /// So viele Tage zurück zeigt „Vergangene“.
    static let vergangeneTage = 30
    /// Obergrenze für das Nachladen am Stück (Seiten à 100), damit nichts endlos läuft.
    static let maxSeiten = 10

    let modus: Modus
    let merkStore: EventsMerkStore
    let quelle: any EventsDatenquelle

    var auswahl: EventsAuswahl

    private(set) var zustand: Zustand = .laedt
    private(set) var events: [CampusEvent] = []
    private(set) var hatWeitere = false
    private(set) var laedtWeitere = false
    private(set) var veranstalter: [Veranstalter] = []
    /// Tage der Tagesleiste, an denen etwas stattfindet.
    private(set) var tageMitEvents: Set<Date> = []
    /// Wird erhöht, um dieselbe Abfrage nochmal auszulösen („Erneut versuchen“).
    private(set) var versuch = 0

    @ObservationIgnored private var seite = 0
    @ObservationIgnored private var geladenFuer: LadeSchluessel?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let jetzt: @MainActor () -> Date
    /// Gibt geladene Events an die Widgets weiter. `nil` in Previews und Tests.
    @ObservationIgnored private let widgetSync: WidgetSync?

    init(
        modus: Modus = .kommende,
        auswahl: EventsAuswahl = EventsAuswahl(),
        quelle: (any EventsDatenquelle)? = nil,
        merkStore: EventsMerkStore? = nil,
        jetzt: @escaping @MainActor () -> Date = { .now },
        widgetSync: WidgetSync? = nil
    ) {
        self.widgetSync = widgetSync
        self.modus = modus
        self.auswahl = auswahl
        self.quelle = quelle ?? EventsService()
        self.merkStore = merkStore ?? .shared
        self.jetzt = jetzt
    }

    // MARK: - Ableitungen

    var ladeSchluessel: LadeSchluessel {
        LadeSchluessel(
            tag: auswahl.tag,
            heuteAbend: auswahl.heuteAbend,
            veranstalter: auswahl.veranstalterID,
            art: auswahl.art,
            abgesagteAusblenden: auswahl.abgesagteAusblenden,
            versuch: versuch
        )
    }

    var jetztZeit: Date { jetzt() }

    /// Die 14 Tage der Tagesleiste, beginnend mit heute.
    var tage: [Date] {
        let heute = EventKalender.tagesbeginn(jetzt())
        return (0..<Self.tageAnzahl).map { EventKalender.tag(heute, plus: $0) }
    }

    var sichtbareEvents: [CampusEvent] {
        switch modus {
        case .kommende:
            guard auswahl.nurGemerkt else { return events }
            return events.filter { merkStore.istGemerkt($0.id) }
        case .vergangene:
            // Eine mehrtägige Veranstaltung, die heute noch läuft, gehört zu den kommenden.
            let heute = EventKalender.tagesbeginn(jetzt())
            return events.filter { $0.letzterTag < heute }
        }
    }

    var abschnitte: [EventAbschnitt] {
        switch modus {
        case .kommende: EventGruppierung.kommende(sichtbareEvents, auswahl: auswahl, jetzt: jetzt())
        case .vergangene: EventGruppierung.vergangene(sichtbareEvents)
        }
    }

    var unterzeile: String {
        switch modus {
        case .kommende: auswahl.unterzeile(jetzt: jetzt())
        case .vergangene: "Der letzte Monat, neueste zuerst"
        }
    }

    var leerArt: EventsAuswahl.LeerArt {
        modus == .kommende ? auswahl.leerArt(jetzt: jetzt()) : .allgemein
    }

    // MARK: - Aktionen

    func zuruecksetzen() {
        auswahl = EventsAuswahl()
    }

    func nochmalVersuchen() {
        versuch += 1
    }

    func schalteHeuteAbend() {
        auswahl.schalteHeuteAbend(jetzt: jetzt())
    }

    // MARK: - Laden

    /// Lädt nur, wenn für diese Auswahl noch nichts da ist. Kommt man aus dem Detail zurück, startet SwiftUI die Aufgabe
    /// der Ansicht erneut; die Liste soll dann stehen bleiben.
    func ladenWennNoetig() async {
        if zustand == .geladen, geladenFuer == ladeSchluessel { return }
        await laden()
    }

    /// Ziehen zum Aktualisieren: Liste, Veranstalter und Punkte der Tagesleiste neu.
    func aktualisieren() async {
        async let liste: Void = laden(still: true)
        async let beiwerk: Void = ladeBeiwerk()
        _ = await (liste, beiwerk)
    }

    /// Lädt die erste Seite neu. Mit `still` bleibt die alte Liste stehen (Ziehen zum Aktualisieren), und ein Fehler
    /// ersetzt sie nicht.
    func laden(still: Bool = false) async {
        generation += 1
        let meine = generation
        let schluessel = ladeSchluessel
        seite = 0
        laedtWeitere = false
        if !still || events.isEmpty { zustand = .laedt }

        do {
            let ergebnis = try await ladeSeite(1)
            guard meine == generation else { return }
            events = ergebnis.events
            seite = 1
            hatWeitere = ergebnis.hatWeitere
            zustand = .geladen
            geladenFuer = schluessel
            // Was die Liste vollständig kennt, geht auch an die Widgets (nur bei „Kommende“).
            if modus == .kommende {
                widgetSync?.speichereEvents(
                    aus: ergebnis.events, hatWeitere: ergebnis.hatWeitere, filter: auswahl.filter(), jetzt: jetzt()
                )
            }
        } catch {
            guard meine == generation, !Task.isCancelled, !(error is CancellationError) else { return }
            if still, !events.isEmpty { return }
            events = []
            hatWeitere = false
            zustand = .fehler
            return
        }

        // „Vergangene“ braucht alles, um umzudrehen; „Gemerkt“ filtert in der App und muss deshalb alles kennen.
        if modus == .vergangene || auswahl.nurGemerkt {
            await ladeRest()
        }
    }

    /// Nächste Seite, wenn das letzte Element erscheint.
    func weiterLaden() async {
        guard zustand == .geladen, hatWeitere, !laedtWeitere, seite < Self.maxSeiten || modus == .kommende else { return }
        let meine = generation
        laedtWeitere = true
        defer { if meine == generation { laedtWeitere = false } }

        do {
            let ergebnis = try await ladeSeite(seite + 1)
            guard meine == generation else { return }
            // Seiten können sich am Rand überschneiden, wenn sich der Bestand zwischendurch ändert.
            let vorhanden = Set(events.map(\.id))
            events += ergebnis.events.filter { !vorhanden.contains($0.id) }
            seite = ergebnis.seite
            hatWeitere = ergebnis.hatWeitere
        } catch {
            // Die geladene Liste bleibt; beim nächsten Erscheinen des letzten Elements wird neu versucht.
        }
    }

    /// Lädt alle weiteren Seiten, auch wenn „Gemerkt“ erst nach dem Laden eingeschaltet wurde.
    func ladeRest() async {
        let meine = generation
        while meine == generation, hatWeitere, zustand == .geladen, seite < Self.maxSeiten, !Task.isCancelled {
            let vorher = seite
            await weiterLaden()
            if seite == vorher { break }
        }
    }

    /// Veranstalter-Chips und Punkte der Tagesleiste. Fehler bleiben still, die alten Werte bleiben stehen.
    func ladeBeiwerk() async {
        guard modus == .kommende else { return }
        async let tage: Void = ladeTageMitEvents()
        if let neu = try? await quelle.veranstalter() { veranstalter = neu }
        await tage
    }

    /// Einmal die 14 Tage laden und daraus die Tage mit Einträgen ableiten.
    private func ladeTageMitEvents() async {
        let heute = EventKalender.tagesbeginn(jetzt())
        let ende = EventKalender.tag(heute, plus: Self.tageAnzahl)
        let filter = EventFilter(zeitraum: .init(von: heute, bis: ende))
        var alle: [CampusEvent] = []
        var nummer = 1
        while nummer <= 3 {
            guard let ergebnis = try? await quelle.liste(filter: filter, seite: nummer, jetzt: jetzt()) else { return }
            alle += ergebnis.events
            guard ergebnis.hatWeitere else { break }
            nummer += 1
        }
        tageMitEvents = Set(tage.filter { tag in alle.contains { $0.laeuftAm(tag) } })
    }

    private func ladeSeite(_ nummer: Int) async throws -> EventSeite {
        let jetzt = jetzt()
        var filter = auswahl.filter()
        if modus == .vergangene {
            let heute = EventKalender.tagesbeginn(jetzt)
            filter = EventFilter(
                zeitraum: .init(von: EventKalender.tag(heute, plus: -Self.vergangeneTage), bis: heute),
                abgesagteAusblenden: auswahl.abgesagteAusblenden,
                kategorie: auswahl.art.kategorie
            )
        }
        return try await quelle.liste(filter: filter, seite: nummer, jetzt: jetzt)
    }
}
