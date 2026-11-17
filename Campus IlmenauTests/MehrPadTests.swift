import Testing
import Foundation
import UIKit
@testable import Campus_Ilmenau

/// „Mehr & Einstellungen“ auf dem iPad: Bereiche, Link `mehr?bereich=`, Sprünge über den Router.
@MainActor
@Suite(.serialized)
struct MehrPadTests {
    private func link(_ text: String) -> DeepLink? {
        URL(string: text).flatMap { DeepLink(url: $0) }
    }

    // MARK: Bereiche

    @Test func beimOeffnenIstMensaGewaehlt() {
        #expect(MehrBereich.standard == .mensa)
    }

    @Test func dieWerteImLinkSindDieRohwerteDerBereiche() {
        #expect(MehrBereich.allCases.map(\.rawValue) == ["konto", "darstellung", "mensa", "sprache", "ueber"])
        for bereich in MehrBereich.allCases {
            #expect(MehrBereich(link: bereich.rawValue) == bereich)
        }
        #expect(MehrBereich(link: "DARSTELLUNG") == .darstellung)
        #expect(MehrBereich(link: "unbekannt") == nil)
        #expect(MehrBereich(link: nil) == nil)
    }

    @Test func pfeiltastenGehenDieListeInDerReihenfolgeDerAnzeigeDurch() {
        // Konto-Karte, dann Darstellung, Mensa, Sprache, Über die App; an den Enden bleibt es stehen.
        #expect(MehrBereich.konto.nachbar(1) == .darstellung)
        #expect(MehrBereich.mensa.nachbar(1) == .sprache)
        #expect(MehrBereich.ueber.nachbar(1) == .ueber)
        #expect(MehrBereich.konto.nachbar(-1) == .konto)
        #expect(MehrBereich.sprache.nachbar(-1) == .mensa)
    }

    // MARK: Link

    @Test func derLinkMehrOeffnetMehrMitOderOhneBereich() {
        #expect(link("campusilmenau://mehr") == .mehr(bereich: nil))
        #expect(link("campusilmenau://mehr?bereich=darstellung") == .mehr(bereich: "darstellung"))
        #expect(link("campusilmenau://mehr?bereich=ueber") == .mehr(bereich: "ueber"))
        // ein leerer Wert gilt wie keiner
        #expect(link("campusilmenau://mehr?bereich=") == .mehr(bereich: nil))
        // Unterpfade gehören nicht dazu
        #expect(link("campusilmenau://mehr/darstellung") == nil)
    }

    @Test func derLinkZuMehrLaesstSichSchreibenUndWiederLesen() {
        for bereich in [nil] + MehrBereich.allCases.map(\.rawValue) {
            let original = DeepLink.mehr(bereich: bereich)
            #expect(DeepLink(url: original.url) == original)
        }
        #expect(DeepLink.mehr(bereich: "mensa").url.absoluteString == "campusilmenau://mehr?bereich=mensa")
        #expect(DeepLink.mehr(bereich: nil).url.absoluteString == "campusilmenau://mehr")
    }

    // MARK: Router

    private func padRouter(seitenleiste: Bool) -> AppRouter {
        let router = AppRouter()
        router.padHuelleAktiv = true
        router.seitenleisteSichtbar = seitenleiste
        return router
    }

    @Test func beiOffenerSeitenleisteIstMehrEinEintragDerSeitenleiste() {
        let router = padRouter(seitenleiste: true)
        router.oeffne(.mehr(bereich: "konto"))
        #expect(router.ziel == .mehr)
        #expect(router.mehrBereich == .konto)
        #expect(!router.mehrOeffnen)
    }

    @Test func beiGeschlossenerSeitenleisteOeffnetMehrImTabHeute() {
        let router = padRouter(seitenleiste: false)
        router.waehle(.mehr)
        router.oeffne(.mehr(bereich: "sprache"))
        // wie der Personen-Button: Heute, und die Seite „Mehr“ wird dort gepusht
        #expect(router.ziel == .heute)
        #expect(router.mehrOeffnen)
        #expect(router.mehrBereich == .sprache)
    }

    @Test func einLinkOhneBereichLaesstDieWahlUnberuehrt() {
        let router = padRouter(seitenleiste: true)
        router.mehrBereich = .konto
        router.oeffne(.mehr(bereich: nil))
        #expect(router.mehrBereich == nil)
    }

    @Test func einUnbekannterBereichImLinkGiltWieKeiner() {
        let router = padRouter(seitenleiste: true)
        router.oeffne(.mehr(bereich: "gibtEsNicht"))
        #expect(router.ziel == .mehr)
        #expect(router.mehrBereich == nil)
    }

    @Test func aufDemIPhoneOeffnetDerLinkMehrDieSeiteInHeute() {
        let router = AppRouter()
        router.oeffne(.mehr(bereich: "mensa"))
        #expect(router.ziel == .heute)
        #expect(router.mehrOeffnen)
    }

    @Test func derFilterEintragOeffnetDieMensaMitFilter() {
        let router = padRouter(seitenleiste: true)
        router.zeigeMensaFilter()
        #expect(router.tab == .mensa)
        #expect(router.mensaFilterOeffnen)
    }

    // MARK: Thoska

    @Test func aufDemIPhoneBleibtThoskaInMehrSichtbar() {
        // Die Tests laufen auf dem iPhone-Simulator (ohne NFC): sichtbar bleibt es dort wegen des Geräts, nicht wegen NFC.
        #expect(UIDevice.current.userInterfaceIdiom != .pad)
        #expect(ThoskaInMehr.sichtbar)
    }
}
