import Testing
import Foundation
@testable import Campus_Ilmenau

/// Zustellung der Links auf Veranstaltungen auf dem iPad: Ziel der Seitenleiste, Filter und Auswahl.
@MainActor
@Suite(.serialized)
struct EventsLinkTests {
    private func link(_ text: String) -> DeepLink {
        DeepLink(url: URL(string: text)!)!
    }

    private func padRouter(ziel: PadZiel) -> AppRouter {
        let router = AppRouter()
        router.padHuelleAktiv = true
        router.waehle(ziel)
        router.ansichtErschienen(ziel.tab)
        // Die Ansicht hat die Wünsche des Wechsels übernommen (sie setzt sie zurück).
        router.eventsAlle = false
        router.eventsHeuteAbend = false
        return router
    }

    private func geladenesModell(auswahl: EventsAuswahl = EventsAuswahl()) async -> EventsModel {
        let modell = EventsModel(
            auswahl: auswahl,
            quelle: EventsVorschauQuelle(),
            merkStore: EventsMerkStore(fileURL: nil),
            jetzt: { EventsVorschauQuelle.jetzt }
        )
        await modell.laden()
        return modell
    }

    // MARK: Ziel der Seitenleiste

    @Test func eventsLinkMarktAlleVeranstaltungenUndSetztDieAuswahlZurueck() {
        let router = padRouter(ziel: .eventsAbend)
        router.eingang(link("campusilmenau://events"))
        // „Heute Abend“ und „Alle“ teilen sich die Ansicht: Das Ziel wechselt, der Wunsch kommt mit der neuen Ansicht an.
        #expect(router.ziel == .eventsAlle)
        #expect(!router.eventsAlle && router.wunschUnterwegs)
        router.ansichtErschienen(.events)
        #expect(router.eventsAlle && !router.eventsHeuteAbend && !router.wunschUnterwegs)
    }

    @Test func heuteAbendLinkMarktHeuteAbendUndWuenschtDenFilter() {
        let router = padRouter(ziel: .eventsAlle)
        router.eingang(link("campusilmenau://events?filter=heute-abend"))
        #expect(router.ziel == .eventsAbend)
        #expect(!router.eventsHeuteAbend && router.wunschUnterwegs)
        router.ansichtErschienen(.events)
        #expect(router.eventsHeuteAbend && !router.eventsAlle && !router.wunschUnterwegs)
    }

    @Test func eventLinkBehaeltDasMarkierteZielUndStelltDenWunschSofortZu() {
        let router = padRouter(ziel: .eventsAbend)
        router.eingang(link("campusilmenau://events/evt_1"))
        // Dieselbe Ansicht bleibt stehen, sie bekommt den Wunsch gleich; ob die Veranstaltung in der Liste „Heute Abend“
        // liegt, klärt die Ansicht (siehe `EventsLinkPlan`).
        #expect(router.ziel == .eventsAbend)
        #expect(router.eventWunsch == "evt_1" && !router.wunschUnterwegs)
    }

    @Test func eventLinkAusEinemAnderenTabLandetBeimLetztenZielDerEvents() {
        let router = padRouter(ziel: .eventsAbend)
        router.waehle(.mensa)
        router.eingang(link("campusilmenau://events/evt_2"))
        #expect(router.ziel == .eventsAbend)
        #expect(router.eventWunsch == "evt_2")
    }

    // MARK: Entscheidung, wenn die Veranstaltung nicht in der Liste liegt

    @Test func eineVeranstaltungInDerListeWirdGewaehlt() {
        #expect(EventsLinkPlan.entscheide(steht: true, auswahlIstStandard: false, ziel: .eventsAbend, padHuelleAktiv: true) == .inListe)
        #expect(EventsLinkPlan.entscheide(steht: true, auswahlIstStandard: true, ziel: .eventsAlle, padHuelleAktiv: true) == .inListe)
    }

    @Test func liegtSieNichtInHeuteAbendWechseltDieSeitenleisteZuAlleVeranstaltungen() {
        #expect(
            EventsLinkPlan.entscheide(steht: false, auswahlIstStandard: false, ziel: .eventsAbend, padHuelleAktiv: true)
                == .zuAlleVeranstaltungen
        )
    }

    @Test func liegtSieNichtInDerGefiltertenListeGiltAbHeuteOhneFilter() {
        // „Alle Veranstaltungen“ mit Filter (Veranstalter, Gemerkt, Art …)
        #expect(
            EventsLinkPlan.entscheide(steht: false, auswahlIstStandard: false, ziel: .eventsAlle, padHuelleAktiv: true)
                == .auswahlZuruecksetzen
        )
        // Ohne iPad-Hülle gibt es kein Seitenleisten-Ziel zum Wechseln.
        #expect(
            EventsLinkPlan.entscheide(steht: false, auswahlIstStandard: false, ziel: .eventsAbend, padHuelleAktiv: false)
                == .auswahlZuruecksetzen
        )
    }

    @Test func liegtSieAuchInDerUngefiltertenListeNichtZeigtRechtsNurDasDetail() {
        #expect(EventsLinkPlan.entscheide(steht: false, auswahlIstStandard: true, ziel: .eventsAlle, padHuelleAktiv: true) == .nurDetail)
        #expect(EventsLinkPlan.entscheide(steht: false, auswahlIstStandard: true, ziel: .eventsAbend, padHuelleAktiv: true) == .nurDetail)
    }

    // MARK: Auswahl

    @Test func einLinkAufEineVeranstaltungInDerListeWaehltSieUndScrollt() async {
        let modell = await geladenesModell()
        var zustand = EventsPadZustand()
        zustand.waehleVonAussen(id: "9", aus: modell)
        #expect(zustand.wahl?.id == "9")
        #expect(zustand.wahl?.event?.titel == "Pub-Quiz")
        #expect(zustand.suchtID == nil)
        #expect(zustand.scrollZiel == EventsScrollZiel(id: "9"))
    }

    @Test func einLinkAufEineUnbekannteVeranstaltungWirdGesuchtUndBleibtGewaehlt() async {
        let modell = await geladenesModell(auswahl: .heuteAbend(jetzt: EventsVorschauQuelle.jetzt))
        var zustand = EventsPadZustand()
        // „Pub-Quiz“ (Tag +5) liegt nicht in „Heute Abend“.
        zustand.waehleVonAussen(id: "9", aus: modell)
        #expect(zustand.wahl == .init(id: "9", event: nil))
        #expect(zustand.suchtID == "9")

        // Solange gesucht wird, ersetzt die Korrektur die Wahl nicht durch die erste der Liste.
        zustand.korrigiere(liste: modell.abschnitte.flatMap(\.events))
        #expect(zustand.wahl?.id == "9")

        // Nach der Suche ohne Treffer bleibt sie als „fremd“ stehen, bis sich die Auswahl ändert.
        zustand.suchtID = nil
        zustand.fremdeID = "9"
        zustand.korrigiere(liste: modell.abschnitte.flatMap(\.events))
        #expect(zustand.wahl?.id == "9")
        zustand.fremdeID = nil
        zustand.korrigiere(liste: modell.abschnitte.flatMap(\.events))
        #expect(zustand.wahl?.id != "9")
    }

    @Test func verschwindetDieGewaehlteDurchEinenFilterIstDieErsteDerListeGewaehlt() async {
        let modell = await geladenesModell()
        var zustand = EventsPadZustand()
        let alle = modell.abschnitte.flatMap(\.events)
        zustand.korrigiere(liste: alle)
        #expect(zustand.wahl?.id == alle.first?.id)

        zustand.wahl = .init(id: "9", event: nil)
        zustand.korrigiere(liste: alle)
        #expect(zustand.wahl?.id == "9" && zustand.wahl?.event != nil)

        let ohneQuiz = alle.filter { $0.id != "9" }
        zustand.korrigiere(liste: ohneQuiz)
        #expect(zustand.wahl?.id == ohneQuiz.first?.id)
    }

    @Test func eineLeereListeLaesstNichtsGewaehlt() {
        var zustand = EventsPadZustand()
        zustand.wahl = .init(id: "1", event: nil)
        zustand.korrigiere(liste: [])
        #expect(zustand.wahl == nil)
    }

    @Test func alleVeranstaltungenSetztDieAuswahlZurueck() {
        var zustand = EventsPadZustand()
        zustand.wahl = .init(id: "4", event: nil)
        zustand.zeigtVergangene = true
        zustand.suchtID = "4"
        zustand.zuruecksetzen()
        #expect(zustand.wahl == nil && !zustand.zeigtVergangene && zustand.suchtID == nil && zustand.fremdeID == nil)
    }

    // MARK: Breite noch 0 beim ersten onAppear

    @Test func einLinkWartetAufDieErsteMessungDerBreite() {
        var puffer = EventsLinkPuffer()
        #expect(puffer.empfange("evt_1", breite: 0) == nil)
        #expect(puffer.breiteGeaendert(0) == nil)
        #expect(puffer.breiteGeaendert(1096) == "evt_1")
        // nur einmal
        #expect(puffer.breiteGeaendert(1376) == nil)
    }

    @Test func einLinkMitBekannterBreiteKommtSofortAn() {
        var puffer = EventsLinkPuffer()
        #expect(puffer.empfange("evt_1", breite: 1096) == "evt_1")
        #expect(puffer.breiteGeaendert(1096) == nil)
    }

    @Test func derNeuesteWartendeLinkGewinnt() {
        var puffer = EventsLinkPuffer()
        #expect(puffer.empfange("evt_1", breite: 0) == nil)
        #expect(puffer.empfange("evt_2", breite: 0) == nil)
        #expect(puffer.breiteGeaendert(700) == "evt_2")
    }
}
