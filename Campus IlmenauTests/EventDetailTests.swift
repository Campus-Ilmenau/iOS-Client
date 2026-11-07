import Testing
import Foundation
@testable import Campus_Ilmenau

/// Ableitungen, Kalender-Eintrag und Laden der Detailansicht, ohne Netz und ohne EventKit.
@MainActor
struct EventDetailTests {
    private func event(
        titel: String = "Halloween-Party",
        status: EventStatus = .findetStatt,
        ort: String? = "Studi-Club",
        adresse: String? = "Max-Planck-Ring 6, 98693 Ilmenau",
        veranstalter: String? = "Studi-Club",
        ticket: Bool = true,
        info: Bool = true
    ) -> CampusEvent {
        CampusEvent(
            id: "4", titel: titel, beginn: EventsVorschauQuelle.zeit(1, "21:00"), ende: EventsVorschauQuelle.zeit(2, "03:00"),
            status: status, ort: ort, adresse: adresse, veranstalter: veranstalter,
            infoURL: info ? URL(string: "https://studi-club.example/info") : nil,
            ticketURL: ticket ? URL(string: "https://tickets.example/t") : nil
        )
    }

    // MARK: Anzeige

    @Test func titleGetsSmallerFromAboutFortyCharacters() {
        #expect(EventDetailAnzeige(event: event(titel: "Halloween-Party")).titelGroesse == 32)
        let lang = String(repeating: "a", count: 41)
        #expect(EventDetailAnzeige(event: event(titel: lang)).titelGroesse == 26)
    }

    @Test func ticketsOnlyWithLinkAndNotCancelled() {
        #expect(EventDetailAnzeige(event: event()).zeigtTickets)
        #expect(!EventDetailAnzeige(event: event(ticket: false)).zeigtTickets)
        #expect(!EventDetailAnzeige(event: event(status: .abgesagt)).zeigtTickets)
        #expect(EventDetailAnzeige(event: event(status: .unbestaetigt)).zeigtTickets)
    }

    @Test func calendarIsPrimaryWithoutTicketsAndMissingWhenCancelled() {
        #expect(!EventDetailAnzeige(event: event()).kalenderIstHauptbutton)
        #expect(EventDetailAnzeige(event: event(ticket: false)).kalenderIstHauptbutton)
        #expect(!EventDetailAnzeige(event: event(status: .abgesagt)).zeigtKalender)
        #expect(EventDetailAnzeige(event: event(status: .unbestaetigt)).zeigtKalender)
    }

    @Test func externalNoteOnlyWhenAnExternalButtonExists() {
        #expect(EventDetailAnzeige(event: event()).zeigtExternHinweis)
        #expect(EventDetailAnzeige(event: event(ticket: false)).zeigtExternHinweis)
        #expect(!EventDetailAnzeige(event: event(ticket: false, info: false)).zeigtExternHinweis)
        // Abgesagt ohne Info-Link: kein Tickets-Button, also auch kein Hinweis.
        #expect(!EventDetailAnzeige(event: event(status: .abgesagt, info: false)).zeigtExternHinweis)
    }

    @Test func mapsLinkNeedsAnAddressAndSearchesForIt() throws {
        let url = try #require(EventDetailAnzeige(event: event()).kartenURL)
        #expect(url.scheme == "maps")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(items?.first(where: { $0.name == "q" })?.value == "Max-Planck-Ring 6, 98693 Ilmenau")
        #expect(url.absoluteString.hasPrefix("maps://?q="))
        #expect(!url.absoluteString.contains(" "))

        #expect(EventDetailAnzeige(event: event(adresse: nil)).kartenURL == nil)
        #expect(EventDetailAnzeige(event: event(adresse: "  ")).kartenURL == nil)
    }

    @Test func emptyTextsCountAsMissing() {
        let anzeige = EventDetailAnzeige(event: event(ort: " ", veranstalter: ""))
        #expect(anzeige.ort == nil)
        #expect(anzeige.veranstalter == nil)
        #expect(!anzeige.hatInfokarteOrtOderVeranstalter)
    }

    @Test func shareUsesInfoThenTicketLink() {
        #expect(EventDetailAnzeige(event: event()).teilenURL?.host == "studi-club.example")
        #expect(EventDetailAnzeige(event: event(info: false)).teilenURL?.host == "tickets.example")
        #expect(EventDetailAnzeige(event: event(ticket: false, info: false)).teilenURL == nil)
    }

    // MARK: Kalender-Eintrag

    @Test func calendarEntryTakesTitleTimesPlaceAndLink() {
        let eintrag = KalenderEintrag(event: event())
        #expect(eintrag.titel == "Halloween-Party")
        #expect(eintrag.beginn == EventsVorschauQuelle.zeit(1, "21:00"))
        #expect(eintrag.ende == EventsVorschauQuelle.zeit(2, "03:00"))
        #expect(!eintrag.ganztaegig)
        #expect(eintrag.ort == "Studi-Club, Max-Planck-Ring 6, 98693 Ilmenau")
        #expect(eintrag.url?.host == "studi-club.example")
    }

    @Test func withoutEndTheEntryLastsTwoHours() {
        let ohneEnde = CampusEvent(id: "9", titel: "Pub-Quiz", beginn: EventsVorschauQuelle.zeit(1, "20:00"))
        let eintrag = KalenderEintrag(event: ohneEnde)
        #expect(eintrag.ende == EventsVorschauQuelle.zeit(1, "22:00"))
        #expect(eintrag.ort == nil)
        #expect(eintrag.url == nil)
    }

    @Test func anEndBeforeTheStartIsReplacedByTheDefault() {
        let kaputt = CampusEvent(
            id: "9", titel: "X", beginn: EventsVorschauQuelle.zeit(1, "20:00"), ende: EventsVorschauQuelle.zeit(1, "19:00")
        )
        #expect(KalenderEintrag(event: kaputt).ende == EventsVorschauQuelle.zeit(1, "22:00"))
    }

    @Test func placeWithoutAddressIsJustThePlace() {
        #expect(KalenderEintrag(event: event(adresse: nil)).ort == "Studi-Club")
        #expect(KalenderEintrag(event: event(ort: nil)).ort == "Max-Planck-Ring 6, 98693 Ilmenau")
    }

    @Test func allDayEntryEndsOnTheLastDayItself() {
        let mehrtaegig = EventDetailVorschau.mehrtaegig
        let eintrag = KalenderEintrag(event: mehrtaegig)
        #expect(eintrag.ganztaegig)
        #expect(eintrag.beginn == mehrtaegig.ersterTag)
        // Das Ende des Events ist die Mitternacht nach dem letzten Tag, der Eintrag endet am letzten Tag selbst.
        #expect(eintrag.ende == mehrtaegig.letzterTag)
        #expect(eintrag.ende < mehrtaegig.ende ?? .distantPast)
    }

    // MARK: Modell

    private func modell(
        event: CampusEvent?,
        quelle: any EventsDatenquelle,
        kalender: KalenderErgebnis = .eingetragen
    ) -> EventDetailModel {
        EventDetailModel(id: "4", event: event, quelle: quelle, kalender: VorschauKalender(ergebnis: kalender))
    }

    @Test func loadingReplacesTheListDataWithTheDetail() async {
        let aus = event(adresse: nil)
        let voll = event()
        let modell = modell(event: aus, quelle: EventsVorschauQuelle(events: [voll]))
        #expect(modell.event?.adresse == nil)
        await modell.laden()
        #expect(modell.zustand == .geladen)
        #expect(modell.event?.adresse == "Max-Planck-Ring 6, 98693 Ilmenau")
    }

    @Test func withoutListDataTheViewWaitsAndThenShowsTheEvent() async {
        let modell = modell(event: nil, quelle: EventsVorschauQuelle(events: [event()]))
        #expect(modell.zustand == .laedt)
        #expect(modell.event == nil)
        await modell.laden()
        #expect(modell.zustand == .geladen)
        #expect(modell.event?.titel == "Halloween-Party")
    }

    @Test func missingEventIsNotFoundEvenWithListData() async {
        let modell = modell(event: event(), quelle: EventsVorschauQuelle(events: []))
        await modell.laden()
        #expect(modell.zustand == .nichtGefunden)
    }

    @Test func networkErrorShowsErrorOnlyWithoutListData() async {
        let ohne = modell(event: nil, quelle: EventsVorschauQuelle(verhalten: .fehler))
        await ohne.laden()
        #expect(ohne.zustand == .fehler)

        let mit = modell(event: event(), quelle: EventsVorschauQuelle(verhalten: .fehler))
        await mit.laden()
        #expect(mit.zustand == .geladen)
        #expect(mit.event?.titel == "Halloween-Party")
    }

    @Test func retryRecoversFromAnError() async {
        let quelle = WechselQuelle(event: event())
        quelle.fehler = true
        let modell = modell(event: nil, quelle: quelle)
        await modell.laden()
        #expect(modell.zustand == .fehler)
        quelle.fehler = false
        await modell.nochmal()
        #expect(modell.zustand == .geladen)
        #expect(modell.event != nil)
    }

    @Test func addingToTheCalendarReportsTheOutcome() async {
        for erwartet in [KalenderErgebnis.eingetragen, .verweigert, .fehler] {
            let modell = modell(event: event(), quelle: EventsVorschauQuelle(), kalender: erwartet)
            #expect(await modell.inKalenderEintragen() == erwartet)
            #expect(!modell.traegtKalender)
        }
    }
}

/// Quelle, die zwischen Fehler und Erfolg wechseln kann.
@MainActor
private final class WechselQuelle: EventsDatenquelle {
    let event: CampusEvent
    var fehler = false

    init(event: CampusEvent) { self.event = event }

    func liste(filter: EventFilter, seite: Int, jetzt: Date) async throws -> EventSeite {
        EventSeite(events: [], seite: seite, hatWeitere: false, gesamt: 0)
    }

    func veranstalter() async throws -> [Veranstalter] { [] }

    func detail(id: String) async throws -> CampusEvent {
        if fehler { throw EventsAPIError.invalidResponse }
        return event
    }
}
