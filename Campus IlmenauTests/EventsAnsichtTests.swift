import Testing
import Foundation
@testable import Campus_Ilmenau

/// Auswahl, Gruppierung und Modell der Ansicht „Veranstaltungen“, ohne Netz.
@MainActor
struct EventsAnsichtTests {
    private let jetzt = EventsVorschauQuelle.jetzt
    private var heute: Date { EventKalender.tagesbeginn(jetzt) }

    private func tag(_ offset: Int) -> Date { EventKalender.tag(heute, plus: offset) }

    private func event(_ id: String, tag offset: Int, uhr: String = "20:00", bis: Int? = nil,
                       veranstalter: String? = nil) -> CampusEvent {
        let ende = bis.map { EventsVorschauQuelle.zeit($0 + 1, "00:00") }
        return CampusEvent(
            id: id, titel: "Event \(id)", beginn: EventsVorschauQuelle.zeit(offset, uhr), ende: ende,
            ganztaegig: bis != nil, veranstalter: veranstalter
        )
    }

    private func modell(
        quelle: (any EventsDatenquelle)? = nil,
        modus: EventsModel.Modus = .kommende,
        auswahl: EventsAuswahl = EventsAuswahl(),
        gemerkt: [String] = []
    ) -> EventsModel {
        let speicher = EventsMerkStore(fileURL: nil)
        for id in gemerkt { speicher.umschalten(id) }
        let jetzt = jetzt
        return EventsModel(
            modus: modus, auswahl: auswahl, quelle: quelle ?? EventsVorschauQuelle(), merkStore: speicher, jetzt: { jetzt }
        )
    }

    // MARK: Auswahl

    @Test func heuteAbendSwitchesAbHeuteToToday() {
        var auswahl = EventsAuswahl()
        auswahl.schalteHeuteAbend(jetzt: jetzt)
        #expect(auswahl.heuteAbend)
        #expect(auswahl.tag == heute)
    }

    @Test func heuteAbendKeepsAnAlreadyChosenDay() {
        var auswahl = EventsAuswahl()
        auswahl.waehleTag(tag(3))
        auswahl.schalteHeuteAbend(jetzt: jetzt)
        #expect(auswahl.tag == tag(3))
        auswahl.schalteHeuteAbend(jetzt: jetzt)
        #expect(!auswahl.heuteAbend)
        #expect(auswahl.tag == tag(3))
    }

    @Test func pickingAbHeuteTurnsHeuteAbendOff() {
        var auswahl = EventsAuswahl()
        auswahl.schalteHeuteAbend(jetzt: jetzt)
        auswahl.waehleTag(nil)
        #expect(!auswahl.heuteAbend)
        #expect(auswahl.tag == nil)
    }

    @Test func onlyOneOrganizerAndTappingAgainClearsIt() {
        var auswahl = EventsAuswahl()
        auswahl.schalteVeranstalter("Baracke5", id: "baracke5")
        auswahl.schalteVeranstalter("Hans-Club", id: "hans-club")
        #expect(auswahl.veranstalter == "Hans-Club")
        #expect(auswahl.veranstalterID == "hans-club")
        auswahl.schalteVeranstalter("Hans-Club", id: "hans-club")
        #expect(auswahl.veranstalter == nil)
        #expect(auswahl.veranstalterID == nil)
    }

    @Test func theApiGetsTheOrganizerIdWhileTheScreenShowsTheName() {
        var auswahl = EventsAuswahl()
        auswahl.schalteVeranstalter("Café Bohne", id: "cafe-bohne")
        #expect(auswahl.filter().veranstalter == "cafe-bohne")
        #expect(auswahl.unterzeile(jetzt: jetzt) == "Alles von Café Bohne")
        let items = auswahl.filter().anfrage(jetzt: jetzt).items
        #expect(items.first { $0.name == "organizer" }?.value == "cafe-bohne")
    }

    @Test func choosingAnOrganizerFromTheDetailDoesNotToggleItOff() {
        var auswahl = EventsAuswahl()
        auswahl.waehleVeranstalter("Café Bohne", id: "cafe-bohne")
        auswahl.waehleVeranstalter("Café Bohne", id: "cafe-bohne")
        #expect(auswahl.veranstalterID == "cafe-bohne")
    }

    @Test func sheetCountOnlyCountsTheSheetSettings() {
        var auswahl = EventsAuswahl()
        auswahl.nurGemerkt = true
        auswahl.waehleVeranstalter("Baracke5", id: "baracke5")
        auswahl.schalteHeuteAbend(jetzt: jetzt)
        #expect(auswahl.sheetAnzahl == 0)
        auswahl.art = .frist
        auswahl.abgesagteAusblenden = true
        #expect(auswahl.sheetAnzahl == 2)
        auswahl.sheetZuruecksetzen()
        #expect(auswahl.sheetAnzahl == 0)
        #expect(auswahl.veranstalter == "Baracke5")
    }

    @Test func filterMapsEverythingForTheAPI() {
        var auswahl = EventsAuswahl()
        auswahl.schalteHeuteAbend(jetzt: jetzt)
        auswahl.waehleVeranstalter("Baracke5", id: "baracke5")
        auswahl.art = .frist
        auswahl.abgesagteAusblenden = true
        let filter = auswahl.filter()
        #expect(filter.heuteAbend)
        #expect(filter.tag == heute)
        #expect(filter.veranstalter == "baracke5")
        #expect(filter.kategorie == "Frist")
        #expect(filter.abgesagteAusblenden)
        #expect(EventsAuswahl().filter().kategorie == nil)
    }

    @Test func subtitlesFollowTheFilter() {
        var auswahl = EventsAuswahl()
        #expect(auswahl.unterzeile(jetzt: jetzt) == "Was in Ilmenau ansteht")

        auswahl.waehleVeranstalter("Baracke5", id: "baracke5")
        #expect(auswahl.unterzeile(jetzt: jetzt) == "Alles von Baracke5")

        auswahl.schalteHeuteAbend(jetzt: jetzt)
        #expect(auswahl.unterzeile(jetzt: jetzt) == "Heute ab 17 Uhr · Baracke5")

        auswahl.waehleTag(tag(2))
        #expect(auswahl.unterzeile(jetzt: jetzt) == "Sa 31. Okt. ab 17 Uhr · Baracke5")

        auswahl.heuteAbend = false
        #expect(auswahl.unterzeile(jetzt: jetzt) == "Samstag, 31. Okt. · Baracke5")

        auswahl.waehleTag(tag(0))
        auswahl.veranstalter = nil
        auswahl.veranstalterID = nil
        #expect(auswahl.unterzeile(jetzt: jetzt) == "Heute · Donnerstag")
    }

    @Test func emptyKindPrefersSavedOverTonight() {
        var auswahl = EventsAuswahl()
        #expect(auswahl.leerArt(jetzt: jetzt) == .allgemein)
        auswahl.schalteHeuteAbend(jetzt: jetzt)
        #expect(auswahl.leerArt(jetzt: jetzt) == .abend(heute: true))
        auswahl.waehleTag(tag(2))
        #expect(auswahl.leerArt(jetzt: jetzt) == .abend(heute: false))
        auswahl.nurGemerkt = true
        #expect(auswahl.leerArt(jetzt: jetzt) == .gemerkt)
    }

    // MARK: Gruppierung

    @Test func runningMultiDayEventStandsUnderTodayAndFutureOnesUnderTheirStart() {
        let laufend = event("a", tag: -1, bis: 3)
        let spaeter = event("b", tag: 2, bis: 5)
        let abend = event("c", tag: 0, uhr: "19:00")
        let abschnitte = EventGruppierung.kommende([spaeter, abend, laufend], auswahl: EventsAuswahl(), jetzt: jetzt)
        #expect(abschnitte.map(\.tag) == [tag(0), tag(2)])
        #expect(abschnitte[0].events.map(\.id) == ["a", "c"])
        #expect(abschnitte[1].events.map(\.id) == ["b"])
    }

    @Test func chosenDayCollectsEverythingUnderThatDay() {
        var auswahl = EventsAuswahl()
        auswahl.waehleTag(tag(1))
        let abschnitte = EventGruppierung.kommende(
            [event("a", tag: -1, bis: 3), event("b", tag: 1)], auswahl: auswahl, jetzt: jetzt
        )
        #expect(abschnitte.count == 1)
        #expect(abschnitte[0].tag == tag(1))
        #expect(abschnitte[0].events.count == 2)
    }

    @Test func sectionCounterUsesSingularAndPlural() {
        #expect(EventAbschnitt(tag: heute, events: [event("a", tag: 0)]).zaehler == "1 Veranstaltung")
        #expect(EventAbschnitt(tag: heute, events: [event("a", tag: 0), event("b", tag: 0)]).zaehler == "2 Veranstaltungen")
    }

    @Test func pastEventsComeNewestDayFirst() {
        let abschnitte = EventGruppierung.vergangene([
            event("alt", tag: -6), event("gestern", tag: -1, uhr: "21:00"), event("frueh", tag: -1, uhr: "18:00")
        ])
        #expect(abschnitte.map(\.tag) == [tag(-1), tag(-6)])
        #expect(abschnitte[0].events.map(\.id) == ["frueh", "gestern"])
    }

    @Test func pastSectionTitles() {
        let formatter = EventZeitFormatter(jetzt: jetzt)
        #expect(formatter.vergangenerAbschnittstitel(fuer: tag(-1)) == "Gestern · Mittwoch")
        #expect(formatter.vergangenerAbschnittstitel(fuer: tag(-3)) == "Montag, 26. Okt.")
    }

    // MARK: Modell

    @Test func loadingFillsListOrganizersAndDayDots() async {
        let modell = modell()
        await modell.laden()
        await modell.ladeBeiwerk()
        #expect(modell.zustand == .geladen)
        #expect(!modell.events.isEmpty)
        // Nur kommende, keine vergangenen.
        #expect(modell.events.allSatisfy { $0.letzterTag >= heute })
        #expect(modell.veranstalter.map(\.name) == ["Baracke5", "BC-Club", "Fotoverein", "Hans-Club", "Studi-Club", "TU Ilmenau", "Uni-Chor"])
        #expect(modell.veranstalter.first?.anzahlKommende == 3)
        #expect(modell.tageMitEvents.contains(tag(0)))
        #expect(modell.tageMitEvents.contains(tag(4)))
        #expect(modell.tageMitEvents.contains(tag(3)))
        #expect(!modell.tageMitEvents.contains(tag(7)))
        #expect(modell.tage.count == 14)
        #expect(modell.tage.first == heute)
    }

    @Test func tonightAndOrganizerCombine() async {
        var auswahl = EventsAuswahl()
        auswahl.schalteHeuteAbend(jetzt: jetzt)
        auswahl.waehleVeranstalter("Baracke5", id: "baracke5")
        let modell = modell(auswahl: auswahl)
        await modell.laden()
        #expect(modell.events.map(\.id) == ["2"])
        #expect(modell.abschnitte.count == 1)
    }

    @Test func savedFilterRunsInTheApp() async {
        var auswahl = EventsAuswahl()
        auswahl.nurGemerkt = true
        let modell = modell(auswahl: auswahl, gemerkt: ["4"])
        await modell.laden()
        #expect(modell.sichtbareEvents.map(\.id) == ["4"])
        modell.merkStore.umschalten("4")
        #expect(modell.sichtbareEvents.isEmpty)
        #expect(modell.leerArt == .gemerkt)
    }

    @Test func pastModeLoadsTheLastThirtyDaysUpToYesterdayNewestFirst() async {
        let modell = modell(modus: .vergangene)
        await modell.laden()
        #expect(Set(modell.sichtbareEvents.map(\.id)) == ["21", "22", "23"])
        #expect(modell.abschnitte.map(\.tag) == [tag(-1), tag(-3), tag(-6)])
        #expect(modell.unterzeile == "Der letzte Monat, neueste zuerst")
    }

    @Test func failureShowsErrorAndRetryLoadsAgain() async {
        let quelle = SkriptQuelle(seiten: [])
        quelle.fehler = true
        let modell = modell(quelle: quelle)
        await modell.laden()
        #expect(modell.zustand == .fehler)

        quelle.fehler = false
        quelle.seiten = [[event("a", tag: 0)]]
        modell.nochmalVersuchen()
        await modell.ladenWennNoetig()
        #expect(modell.zustand == .geladen)
        #expect(modell.events.map(\.id) == ["a"])
    }

    @Test func returningFromDetailDoesNotReload() async {
        let quelle = SkriptQuelle(seiten: [[event("a", tag: 0)]])
        let modell = modell(quelle: quelle)
        await modell.ladenWennNoetig()
        await modell.ladenWennNoetig()
        #expect(quelle.listenAufrufe == [1])

        modell.auswahl.waehleVeranstalter("Baracke5", id: "baracke5")
        await modell.ladenWennNoetig()
        #expect(quelle.listenAufrufe == [1, 1])
    }

    @Test func savedFilterDoesNotTriggerANewRequest() {
        var auswahl = EventsAuswahl()
        let vorher = modell(auswahl: auswahl).ladeSchluessel
        auswahl.nurGemerkt = true
        #expect(modell(auswahl: auswahl).ladeSchluessel == vorher)
        auswahl.waehleVeranstalter("Baracke5", id: "baracke5")
        #expect(modell(auswahl: auswahl).ladeSchluessel != vorher)
    }

    @Test func nextPageIsAppendedWithoutDuplicates() async {
        let quelle = SkriptQuelle(seiten: [
            [event("a", tag: 0), event("b", tag: 1)],
            [event("b", tag: 1), event("c", tag: 2)]
        ])
        let modell = modell(quelle: quelle)
        await modell.laden()
        #expect(modell.hatWeitere)
        await modell.weiterLaden()
        #expect(modell.events.map(\.id) == ["a", "b", "c"])
        #expect(!modell.hatWeitere)
        await modell.weiterLaden()
        #expect(quelle.listenAufrufe == [1, 2])
    }

    @Test func lateAnswerOfAnOldSelectionIsDropped() async {
        let quelle = SkriptQuelle(seiten: [[event("alt", tag: 0)]])
        quelle.verzoegert = true
        let modell = modell(quelle: quelle)
        let erste = Task { await modell.laden() }
        await Task.yield()

        quelle.verzoegert = false
        quelle.seiten = [[event("neu", tag: 0)]]
        modell.auswahl.waehleVeranstalter("Baracke5", id: "baracke5")
        await modell.laden()

        quelle.freigeben()
        await erste.value
        #expect(modell.events.map(\.id) == ["neu"])
    }

    @Test func pullToRefreshKeepsTheListWhenItFails() async {
        let quelle = SkriptQuelle(seiten: [[event("a", tag: 0)]])
        let modell = modell(quelle: quelle)
        await modell.laden()

        quelle.fehler = true
        await modell.laden(still: true)
        #expect(modell.zustand == .geladen)
        #expect(modell.events.map(\.id) == ["a"])
    }

    @Test func resetBringsBackTheDefaultSelection() {
        let modell = modell()
        modell.auswahl.waehleVeranstalter("Baracke5", id: "baracke5")
        modell.auswahl.nurGemerkt = true
        modell.auswahl.art = .frist
        modell.zuruecksetzen()
        #expect(modell.auswahl == EventsAuswahl())
    }
}

/// Datenquelle mit festen Seiten, die Aufrufe mitzählt. Kann Fehler werfen oder die erste Antwort zurückhalten.
@MainActor
private final class SkriptQuelle: EventsDatenquelle {
    var seiten: [[CampusEvent]]
    var fehler = false
    var verzoegert = false
    private(set) var listenAufrufe: [Int] = []
    private var wartende: [CheckedContinuation<Void, Never>] = []

    init(seiten: [[CampusEvent]]) {
        self.seiten = seiten
    }

    func freigeben() {
        wartende.forEach { $0.resume() }
        wartende = []
    }

    func liste(filter: EventFilter, seite: Int, jetzt: Date) async throws -> EventSeite {
        listenAufrufe.append(seite)
        let antwort = seiten
        if verzoegert {
            await withCheckedContinuation { wartende.append($0) }
        }
        if fehler { throw EventsAPIError.invalidResponse }
        let index = seite - 1
        let events = antwort.indices.contains(index) ? antwort[index] : []
        return EventSeite(events: events, seite: seite, hatWeitere: index + 1 < antwort.count, gesamt: events.count)
    }

    func veranstalter() async throws -> [Veranstalter] { [] }

    func detail(id: String) async throws -> CampusEvent { throw EventsAPIError.notFound }
}
