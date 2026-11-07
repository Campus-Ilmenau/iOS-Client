import Foundation
import EventKit
import Observation

/// Was die Detailansicht aus einer Veranstaltung ableitet: welche Teile und Tasten es gibt und wie sie heißen.
/// Fehlendes entfällt ohne Lücke; „knapp“ (nur Titel, Beginn, Status) ist kein eigener Fall, sondern ergibt sich daraus.
struct EventDetailAnzeige: Equatable {
    let event: CampusEvent

    /// Ab etwa 40 Zeichen wird der Titel kleiner.
    var titelGroesse: CGFloat { event.titel.count > 40 ? 26 : 32 }

    var abgesagt: Bool { event.status == .abgesagt }
    var unbestaetigt: Bool { event.status == .unbestaetigt }

    var veranstalter: String? { nonEmpty(event.veranstalter) }
    var ort: String? { nonEmpty(event.ort) }
    var adresse: String? { nonEmpty(event.adresse) }
    var beschreibung: String? { nonEmpty(event.beschreibung) }

    /// Link „In Karten öffnen“: nur mit Adresse. Apple Maps mit der Adresse als Suche, keine Koordinaten.
    var kartenURL: URL? {
        guard let adresse else { return nil }
        var teile = URLComponents()
        teile.scheme = "maps"
        teile.host = ""
        teile.queryItems = [URLQueryItem(name: "q", value: adresse)]
        return teile.url
    }

    /// Tickets gibt es nur mit Link und solange die Veranstaltung nicht abgesagt ist.
    var zeigtTickets: Bool { event.ticketURL != nil && !abgesagt }
    var zeigtKalender: Bool { !abgesagt }
    /// Der Kalender-Button ist der Hauptbutton, wenn es keine Tickets gibt.
    var kalenderIstHauptbutton: Bool { !zeigtTickets }
    var zeigtInfoseite: Bool { event.infoURL != nil }
    /// Der Hinweis „öffnet eine Seite außerhalb der App“ steht nur, wenn es einen solchen Button gibt.
    var zeigtExternHinweis: Bool { zeigtTickets || zeigtInfoseite }
    var hatInfokarteOrtOderVeranstalter: Bool { ort != nil || veranstalter != nil }

    /// Was das Teilen-Blatt anbietet: der Info- oder Ticket-Link, sonst Titel und Datum als Text.
    var teilenURL: URL? { event.infoURL ?? event.ticketURL }

    private func nonEmpty(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}

/// Alles, was in den Kalender geschrieben wird.
struct KalenderEintrag: Equatable {
    /// So lange dauert eine Veranstaltung ohne Ende.
    static let standardDauer: TimeInterval = 2 * 3600

    let titel: String
    let beginn: Date
    let ende: Date
    let ganztaegig: Bool
    /// „Ort, Adresse“.
    let ort: String?
    let url: URL?

    init(event: CampusEvent) {
        titel = event.titel
        ganztaegig = event.ganztaegig
        if event.ganztaegig {
            // Ein ganztägiger Eintrag endet am letzten Tag selbst (EventKit zählt ihn mit), nicht an der Mitternacht danach.
            beginn = event.ersterTag
            ende = event.letzterTag
        } else {
            beginn = event.beginn
            if let ende = event.ende, ende > event.beginn {
                self.ende = ende
            } else {
                ende = event.beginn.addingTimeInterval(Self.standardDauer)
            }
        }
        let teile = [event.ort, event.adresse]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        ort = teile.isEmpty ? nil : teile.joined(separator: ", ")
        url = event.infoURL
    }
}

enum KalenderErgebnis: Equatable {
    case eingetragen
    /// Der Zugriff wurde nicht erlaubt.
    case verweigert
    case fehler
}

/// Schreibt eine Veranstaltung in den Kalender. Der Rest der App kennt EventKit nicht.
@MainActor
protocol EventKalenderSchreiber {
    func eintragen(_ eintrag: KalenderEintrag) async -> KalenderErgebnis
}

/// EventKit mit reinem Schreibzugriff: Die App sieht die Termine der Person nicht.
@MainActor
struct SystemKalender: EventKalenderSchreiber {
    func eintragen(_ eintrag: KalenderEintrag) async -> KalenderErgebnis {
        let store = EKEventStore()
        do {
            guard try await store.requestWriteOnlyAccessToEvents() else { return .verweigert }
            guard let kalender = store.defaultCalendarForNewEvents else { return .fehler }
            let termin = EKEvent(eventStore: store)
            termin.calendar = kalender
            termin.title = eintrag.titel
            termin.startDate = eintrag.beginn
            termin.endDate = eintrag.ende
            termin.isAllDay = eintrag.ganztaegig
            termin.location = eintrag.ort
            termin.url = eintrag.url
            try store.save(termin, span: .thisEvent)
            return .eingetragen
        } catch {
            return .fehler
        }
    }
}

/// Zustand der Detailansicht: zeigt zuerst, was aus der Liste mitkommt, und lädt dann die Einzelheiten.
@MainActor
@Observable
final class EventDetailModel {
    enum Zustand: Equatable {
        case laedt
        case geladen
        /// Die Veranstaltung gibt es nicht (mehr), 404.
        case nichtGefunden
        case fehler
    }

    let id: String
    let quelle: any EventsDatenquelle
    let kalender: any EventKalenderSchreiber

    private(set) var event: CampusEvent?
    private(set) var zustand: Zustand
    private(set) var traegtKalender = false

    init(
        id: String,
        event: CampusEvent? = nil,
        quelle: (any EventsDatenquelle)? = nil,
        kalender: (any EventKalenderSchreiber)? = nil
    ) {
        self.id = id
        self.event = event
        self.quelle = quelle ?? EventsService()
        self.kalender = kalender ?? SystemKalender()
        zustand = .laedt
    }

    /// Lädt die Veranstaltung. Mit Daten aus der Liste bleibt die Ansicht bei einem Fehler stehen,
    /// nur ein 404 ersetzt sie: Die Veranstaltung gibt es dann nicht mehr.
    func laden() async {
        zustand = event == nil ? .laedt : .geladen
        do {
            event = try await quelle.detail(id: id)
            zustand = .geladen
        } catch is CancellationError {
            return
        } catch EventsAPIError.notFound {
            zustand = .nichtGefunden
        } catch {
            if Task.isCancelled { return }
            if event == nil { zustand = .fehler }
        }
    }

    /// Für „Erneut versuchen“.
    func nochmal() async {
        await laden()
    }

    func inKalenderEintragen() async -> KalenderErgebnis {
        guard let event, !traegtKalender else { return .fehler }
        traegtKalender = true
        defer { traegtKalender = false }
        return await kalender.eintragen(KalenderEintrag(event: event))
    }
}
