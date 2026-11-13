import Testing
import Foundation
@testable import Campus_Ilmenau

/// Die Karte „Heute Abend“: höchstens 3, nie hängen, bei Fehler leer.
@MainActor
private final class Ende { var erreicht = false }

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct HeuteAbendTests {
    private func abend(_ id: String, status: EventStatus = .findetStatt) -> CampusEvent {
        CampusEvent(id: id, titel: "E\(id)", beginn: EventsVorschauQuelle.zeit(0, "20:00"), status: status)
    }

    /// Ohne eigene Uhr läuft das Zeitlimit nie ab: Diese Tests prüfen die Auswahl, nicht die Zeit. Mit der echten Uhr und
    /// 2 s kippte ein Lauf auf einem ausgelasteten Rechner (der Hauptakteur stand für Sekunden still) in „Zeitablauf“.
    private func modell(
        _ quelle: any EventsDatenquelle, zeitlimit: Duration = .seconds(2), clock: any Clock<Duration> = ManualClock()
    ) -> HeuteAbendModel {
        HeuteAbendModel(quelle: quelle, zeitlimit: zeitlimit, jetzt: { EventsVorschauQuelle.jetzt }, clock: clock)
    }

    @Test func showsAtMostThree() async {
        let modell = modell(AufzeichnendeQuelle(events: (1...5).map { abend("\($0)") }))
        await modell.laden()
        #expect(modell.events.map(\.id) == ["1", "2", "3"])
    }

    @Test func fewerEntriesAreKept() async {
        let modell = modell(AufzeichnendeQuelle(events: [abend("1"), abend("2")]))
        await modell.laden()
        #expect(modell.events.count == 2)
    }

    @Test func asksForTonightWithoutCancelledOnce() async {
        let quelle = AufzeichnendeQuelle(events: [abend("1")])
        await modell(quelle).laden()
        #expect(quelle.filter.count == 1)
        #expect(quelle.filter.first?.heuteAbend == true)
        #expect(quelle.filter.first?.abgesagteAusblenden == true)
        #expect(quelle.filter.first?.tag == nil)
        #expect(quelle.seiten == [1])
    }

    @Test func cancelledOnesAreDroppedEvenIfTheServerSendsThem() async {
        let modell = modell(AufzeichnendeQuelle(events: [abend("1", status: .abgesagt), abend("2")]))
        await modell.laden()
        #expect(modell.events.map(\.id) == ["2"])
    }

    @Test func emptyAnswerMeansNoCard() async {
        let modell = modell(AufzeichnendeQuelle(events: []))
        await modell.laden()
        #expect(modell.events.isEmpty)
    }

    @Test func errorMeansNoCardAndDoesNotThrow() async {
        let quelle = AufzeichnendeQuelle(events: [abend("1")])
        quelle.fehler = true
        let modell = modell(quelle)
        await modell.laden()
        #expect(modell.events.isEmpty)
    }

    @Test func errorAfterSuccessRemovesTheCard() async {
        let quelle = AufzeichnendeQuelle(events: [abend("1")])
        let modell = modell(quelle)
        await modell.laden()
        #expect(modell.events.count == 1)
        quelle.fehler = true
        await modell.laden()
        #expect(modell.events.isEmpty)
    }

    @Test func aSourceThatNeverAnswersEndsAtTheTimeLimit() async {
        // Die Quelle antwortet nie. Das Limit läuft nach der Uhr des Tests: erst mit 100 ms ist Schluss, nicht davor.
        let clock = ManualClock()
        let modell = modell(EventsVorschauQuelle(verhalten: .laedt), zeitlimit: .milliseconds(100), clock: clock)
        let ende = Ende()
        let aufgabe = Task { await modell.laden(); ende.erreicht = true }
        await clock.warte(bisFrist: .milliseconds(100))
        await clock.advance(by: .milliseconds(99))
        #expect(!ende.erreicht)
        await clock.advance(by: .milliseconds(1))
        await aufgabe.value
        #expect(modell.events.isEmpty)
        #expect(ende.erreicht)
    }

    @Test func tonightSelectionForTheAllLink() {
        let auswahl = EventsAuswahl.heuteAbend(jetzt: EventsVorschauQuelle.jetzt)
        #expect(auswahl.heuteAbend)
        #expect(auswahl.tag == EventKalender.tagesbeginn(EventsVorschauQuelle.jetzt))
        #expect(auswahl.unterzeile(jetzt: EventsVorschauQuelle.jetzt) == "Heute ab 17 Uhr")
    }
}

/// Merkt sich, wonach gefragt wurde.
@MainActor
private final class AufzeichnendeQuelle: EventsDatenquelle {
    let events: [CampusEvent]
    var fehler = false
    private(set) var filter: [EventFilter] = []
    private(set) var seiten: [Int] = []

    init(events: [CampusEvent]) { self.events = events }

    func liste(filter: EventFilter, seite: Int, jetzt: Date) async throws -> EventSeite {
        self.filter.append(filter)
        seiten.append(seite)
        if fehler { throw EventsAPIError.invalidResponse }
        return EventSeite(events: events, seite: seite, hatWeitere: false, gesamt: events.count)
    }

    func veranstalter() async throws -> [Veranstalter] { [] }
    func detail(id: String) async throws -> CampusEvent { throw EventsAPIError.notFound }
}
