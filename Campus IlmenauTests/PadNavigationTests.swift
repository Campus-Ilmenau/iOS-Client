import Testing
import Foundation
import SwiftUI
import UIKit
import AppIntents
@testable import Campus_Ilmenau

/// Die Navigation des iPads (und die NFC-Regel für beide Hüllen) am `AppRouter`, den beide Hüllen teilen.
/// Serialisiert, weil `NFCVerfuegbarkeit` und der `DeepLinkEingang` gemeinsamer Zustand sind.
@MainActor
@Suite(.serialized)
struct PadNavigationTests {
    private func mitNFC(_ vorhanden: Bool, _ pruefung: () async throws -> Void) async rethrows {
        NFCVerfuegbarkeit.ueberschreibung = vorhanden
        defer { NFCVerfuegbarkeit.ueberschreibung = nil }
        try await pruefung()
    }

    // MARK: Deeplinks kommen am gemeinsamen Router an

    @Test func mensaLinkWaehltDenMensaTab() {
        let router = AppRouter()
        router.eingang(DeepLink(url: URL(string: "campusilmenau://mensa?mensa=mensaEhrenberg")!)!)
        #expect(router.tab == .mensa)
        #expect(router.mensaWunsch == .mensaEhrenberg)
        #expect(PadZiel.standard(fuer: router.tab) == .mensa)
    }

    @Test func eventLinkWaehltDenEventsTabMitWunsch() {
        let router = AppRouter()
        router.eingang(DeepLink(url: URL(string: "campusilmenau://events/abc123")!)!)
        #expect(router.tab == .events)
        #expect(router.eventWunsch == "abc123")
        #expect(PadZiel.standard(fuer: router.tab).tab == .events)
    }

    // MARK: Hülle

    @Test func padHuelleNurAufDemIPadBeiRegularBreite() {
        #expect(ContentView.nutztPadHuelle(breite: .regular, geraet: .pad))
        #expect(!ContentView.nutztPadHuelle(breite: .compact, geraet: .pad))
        #expect(!ContentView.nutztPadHuelle(breite: nil, geraet: .pad))
        // iPhone Max im Querformat ist `.regular`, bleibt aber in der iPhone-Hülle.
        #expect(!ContentView.nutztPadHuelle(breite: .regular, geraet: .phone))
        #expect(!ContentView.nutztPadHuelle(breite: .compact, geraet: .phone))
    }

    // MARK: Ein Link markiert das richtige Ziel der Seitenleiste

    private func ziel(_ url: String) -> PadZiel {
        let router = AppRouter()
        router.eingang(DeepLink(url: URL(string: url)!)!)
        return router.ziel
    }

    @Test func linksMarkierenDasRichtigeZiel() {
        #expect(ziel("campusilmenau://mensa") == .mensa)
        #expect(ziel("campusilmenau://mensa/gericht/42") == .mensa)
        #expect(ziel("campusilmenau://mensa/zeiten") == .mensa)
        #expect(ziel("campusilmenau://events") == .eventsAlle)
        #expect(ziel("campusilmenau://events?filter=heute-abend") == .eventsAbend)
        #expect(ziel("campusilmenau://katalog/suche") == .katalog)
        #expect(ziel("campusilmenau://katalog/suche?q=Analysis") == .katalog)
        #expect(ziel("campusilmenau://katalog/titel/ppn_1") == .katalog)
        #expect(ziel("campusilmenau://bibliothek/merkliste") == .merkliste)
    }

    @Test func eventLinkMitIDBehaeltDenGewaehltenEintragDerEvents() {
        let router = AppRouter()
        router.waehle(.eventsAbend)
        router.eingang(DeepLink(url: URL(string: "campusilmenau://events/abc123")!)!)
        #expect(router.ziel == .eventsAbend)
        #expect(router.eventWunsch == "abc123")

        // Aus einem anderen Tab kommt der zuletzt gewählte Eintrag der Events zurück.
        router.waehle(.mensa)
        router.eingang(DeepLink(url: URL(string: "campusilmenau://events/xyz")!)!)
        #expect(router.ziel == .eventsAbend)
        #expect(router.eventWunsch == "xyz")
    }

    @Test func nurEinZielBautDieGeteilteAnsichtAuf() {
        let router = AppRouter()
        router.waehle(.eventsAbend)
        #expect(router.baueAnsichtAuf(fuer: .eventsAbend))
        #expect(!router.baueAnsichtAuf(fuer: .eventsAlle))
        // Der Tab ist nicht mehr gewählt: Die Ansicht bleibt beim zuletzt gewählten Ziel.
        router.waehle(.mensa)
        #expect(router.baueAnsichtAuf(fuer: .eventsAbend))
        #expect(!router.baueAnsichtAuf(fuer: .eventsAlle))
        #expect(router.baueAnsichtAuf(fuer: .mensa))
    }

    @Test func tabWechselKehrtZumZuletztGewaehltenZielZurueck() {
        let router = AppRouter()
        router.waehle(.merkliste)
        router.tab = .events
        #expect(router.ziel == .eventsAlle)
        router.tab = .bibliothek
        #expect(router.ziel == .merkliste)
        router.tab = .bibliothek
        #expect(router.ziel == .merkliste)
    }

    // MARK: Katalog: ohne Tastatur aus der Seitenleiste, mit Fokus über ⌘F

    @Test func katalogAusDerSeitenleisteOeffnetOhneFokus() async {
        let router = AppRouter()
        router.padHuelleAktiv = true
        router.waehle(.katalog)
        router.ansichtErschienen(.bibliothek)  // die neue Ansicht erscheint, der Wunsch kommt an
        #expect(router.katalogOeffnen)
        #expect(!router.katalogSuche)
    }

    @Test func kommandF_UndLinkOeffnenDenKatalogMitFokus() async {
        let router = AppRouter()
        router.padHuelleAktiv = true
        router.zeigeKatalogSuche()
        router.ansichtErschienen(.bibliothek)  // die neue Ansicht erscheint, der Wunsch kommt an
        #expect(router.katalogSuche)
        #expect(!router.katalogOeffnen)
        #expect(router.ziel == .katalog)
    }

    // MARK: Ziele der Seitenleiste

    @Test func zielGehoertZuSeinemTab() {
        #expect(PadZiel.ausleihen.tab == .bibliothek)
        #expect(PadZiel.katalog.tab == .bibliothek)
        #expect(PadZiel.merkliste.tab == .bibliothek)
        #expect(PadZiel.ausweis.tab == .bibliothek)
        #expect(PadZiel.eventsAlle.tab == .events)
        #expect(PadZiel.eventsAbend.tab == .events)
        #expect(PadZiel.mehr.tab == .heute)
    }

    @Test func jederTabHatEinStandardZielImselbenTab() {
        for tab in AppTab.allCases {
            #expect(PadZiel.standard(fuer: tab).tab == tab)
        }
    }

    @Test func seitenleistenZieleStellenDieWuenscheWieDeeplinks() async {
        let router = AppRouter()
        router.padHuelleAktiv = true
        router.waehle(.merkliste)
        #expect(router.tab == .bibliothek)
        // Der Wunsch wartet, bis die neue Ansicht erscheint (siehe `AppRouter.wechsle`).
        #expect(!router.merklisteOeffnen && router.wunschUnterwegs)
        router.ansichtErschienen(.bibliothek)  // die neue Ansicht erscheint, der Wunsch kommt an
        #expect(router.merklisteOeffnen && !router.wunschUnterwegs)

        let katalog = AppRouter()
        katalog.padHuelleAktiv = true
        katalog.waehle(.katalog)
        katalog.ansichtErschienen(.bibliothek)  // die neue Ansicht erscheint, der Wunsch kommt an
        #expect(katalog.tab == .bibliothek)
        #expect(katalog.katalogOeffnen)

        let abend = AppRouter()
        abend.padHuelleAktiv = true
        abend.waehle(.eventsAbend)
        abend.ansichtErschienen(.events)  // die neue Ansicht erscheint, der Wunsch kommt an
        #expect(abend.tab == .events)
        #expect(abend.eventsHeuteAbend)

        // „Alle“ ist die Ansicht, die der Tab ohnehin zeigt: Der Wunsch kommt sofort.
        let alle = AppRouter()
        alle.tab = .events
        alle.waehle(.eventsAlle)
        #expect(alle.eventsAlle && !alle.wunschUnterwegs)
        #expect(!alle.eventsHeuteAbend)
    }

    @Test func linkZurMerklisteKommtAuchBeiAufgebauterBibliothekAn() async {
        let router = AppRouter()
        router.padHuelleAktiv = true
        router.waehle(.ausleihen)
        router.eingang(DeepLink(url: URL(string: "campusilmenau://bibliothek/merkliste")!)!)
        // Das Ziel steht sofort; der Wunsch kommt an, wenn die neue Ansicht erscheint.
        #expect(router.ziel == .merkliste)
        #expect(!router.merklisteOeffnen && router.wunschUnterwegs)
        router.ansichtErschienen(.bibliothek)  // die neue Ansicht erscheint, der Wunsch kommt an
        #expect(router.merklisteOeffnen && !router.wunschUnterwegs)
    }

    @Test func einWunschWartetBisDieNeueAnsichtErscheint() async throws {
        let router = AppRouter()
        router.padHuelleAktiv = true
        router.waehle(.merkliste)
        // Kein Zeitablauf als Rückfall: Der Wunsch kommt erst mit `ansichtErschienen` an.
        try await Task.sleep(for: .milliseconds(800))
        #expect(!router.merklisteOeffnen && router.wunschUnterwegs)
        router.ansichtErschienen(.bibliothek)
        #expect(router.merklisteOeffnen && !router.wunschUnterwegs)
    }

    @Test func ohnePadHuelleKommenWuenscheSofortAn() {
        let router = AppRouter()
        router.eingang(DeepLink(url: URL(string: "campusilmenau://bibliothek/merkliste")!)!)
        #expect(router.merklisteOeffnen && !router.wunschUnterwegs)
    }

    @Test func ausleihenUndAusweisStellenKeinenWunsch() {
        for ziel in [PadZiel.ausleihen, .ausweis] {
            let router = AppRouter()
            router.waehle(ziel)
            #expect(router.tab == .bibliothek)
            #expect(!router.katalogSuche && !router.merklisteOeffnen)
        }
    }

    @Test func seitenleistenZielZaehltNichtAlsAktionVonAussen() {
        let router = AppRouter()
        router.waehle(.merkliste)
        #expect(!router.kamGeradeVonAussen())
    }

    // MARK: Thoska nur mit NFC

    @Test func ohneNFCKeinThoskaTab() async {
        await mitNFC(false) { #expect(!AppTab.sichtbar.contains(.thoska)) }
        await mitNFC(true) { #expect(AppTab.sichtbar.contains(.thoska)) }
    }

    @Test func ohneNFCBleibtDerThoskaLinkOhneWirkung() async {
        await mitNFC(false) {
            let router = AppRouter()
            router.eingang(.thoskaAuslesen)
            #expect(router.tab == .heute)
            #expect(!router.thoskaAuslesen)
        }
    }

    @Test func ohneNFCOeffnetDasSteuerelementDieAppNicht() async {
        guard #available(iOS 18.0, *) else { return }
        await mitNFC(false) {
            await #expect(throws: ThoskaAuslesenFehler.self) {
                _ = try await ThoskaSteuerelementIntent().perform()
            }
        }
        // Mit NFC läuft der Intent durch (er gibt den Link zurück, den das System öffnet) und wirft nichts.
        await mitNFC(true) {
            _ = try? await ThoskaSteuerelementIntent().perform()
        }
        #expect(!ThoskaSteuerelementIntent.openAppWhenRun)
    }

    @Test func ohneNFCSagtDerIntentDassEsNurAufDemIPhoneGeht() async {
        await mitNFC(false) {
            DeepLinkEingang.trenne()
            let router = AppRouter()
            router.verbinden()
            defer {
                DeepLinkEingang.trenne()
                AppRouter.gemeinsam.verbinden()
            }
            await #expect(throws: ThoskaAuslesenFehler.self) {
                _ = try await ThoskaAuslesenIntent().perform()
            }
            #expect(router.tab == .heute)
            #expect(!router.thoskaAuslesen)
        }
    }
}
