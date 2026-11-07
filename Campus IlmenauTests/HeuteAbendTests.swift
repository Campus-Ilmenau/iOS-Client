import Testing
import Foundation
@testable import Campus_Ilmenau

/// Die Karte „Heute Abend“: höchstens 3, nie hängen, bei Fehler leer.
@MainActor
struct HeuteAbendTests {
    private func abend(_ id: String, status: EventStatus = .findetStatt) -> CampusEvent {
        CampusEvent(id: id, titel: "E\(id)", beginn: EventsVorschauQuelle.zeit(0, "20:00"), status: status)
    }

    private func modell(_ quelle: any EventsDatenquelle, zeitlimit: Duration = .seconds(2)) -> HeuteAbendModel {
        HeuteAbendModel(quelle: quelle, zeitlimit: zeitlimit, jetzt: { EventsVorschauQuelle.jetzt })
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
        let modell = modell(EventsVorschauQuelle(verhalten: .laedt), zeitlimit: .milliseconds(100))
        let start = ContinuousClock.now
        await modell.laden()
        #expect(modell.events.isEmpty)
        #expect(ContinuousClock.now - start < .seconds(2))
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
