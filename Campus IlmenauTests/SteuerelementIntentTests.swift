import Testing
import Foundation
@testable import Campus_Ilmenau

/// Die Intents hinter den Steuerelementen führen über denselben Weg wie die Deeplinks in den `AppRouter`.
/// Serialisiert, weil der `DeepLinkEingang` ein gemeinsamer Zustand ist.
@MainActor
@Suite(.serialized)
struct SteuerelementIntentTests {
    /// Hängt einen eigenen Router an den Eingang und stellt danach den der App wieder her.
    private func mitRouter(_ router: AppRouter, _ pruefung: () async throws -> Void) async rethrows {
        DeepLinkEingang.trenne()
        router.verbinden()
        defer {
            DeepLinkEingang.trenne()
            AppRouter.gemeinsam.verbinden()
        }
        try await pruefung()
    }

    @Test func thoskaAuslesenOeffnetThoskaUndStartetDasNFCSheet() async throws {
        let router = AppRouter()
        try await mitRouter(router) {
            _ = try await ThoskaAuslesenIntent().perform()
        }
        #expect(router.tab == .thoska)
        #expect(router.thoskaAuslesen)
        #expect(!router.katalogSuche)
    }

    @Test func imKatalogSuchenOeffnetDieKatalogsucheOhneAnmeldung() async throws {
        let router = AppRouter()
        try await mitRouter(router) {
            _ = try await KatalogSuchenIntent().perform()
        }
        #expect(router.tab == .bibliothek)
        #expect(router.katalogSuche)
        #expect(!router.thoskaAuslesen)
    }

    /// Gleiches Ziel wie der Deeplink, nicht ein zweiter Weg.
    @Test func dieIntentsLandenWieDieDeeplinks() async throws {
        let ueberIntent = AppRouter(), ueberLink = AppRouter()

        try await mitRouter(ueberIntent) { _ = try await ThoskaAuslesenIntent().perform() }
        ueberLink.oeffne(DeepLink(url: URL(string: "campusilmenau://thoska/auslesen")!)!)
        #expect(ueberIntent.tab == ueberLink.tab)
        #expect(ueberIntent.thoskaAuslesen == ueberLink.thoskaAuslesen)

        let katalogIntent = AppRouter(), katalogLink = AppRouter()
        try await mitRouter(katalogIntent) { _ = try await KatalogSuchenIntent().perform() }
        katalogLink.oeffne(DeepLink(url: URL(string: "campusilmenau://katalog/suche")!)!)
        #expect(katalogIntent.tab == katalogLink.tab)
        #expect(katalogIntent.katalogSuche == katalogLink.katalogSuche)
    }

    /// Kaltstart: Das Ziel wartet auf das Ende der Start-Animation und geht nicht verloren.
    @Test func beimKaltstartWartetDasZielAufDieStartAnimation() async throws {
        let router = AppRouter(wartetAufStart: true)
        try await mitRouter(router) {
            _ = try await ThoskaAuslesenIntent().perform()
            #expect(router.tab == .heute)
            #expect(!router.thoskaAuslesen)
        }
        router.startBeendet()
        #expect(router.tab == .thoska)
        #expect(router.thoskaAuslesen)
        #expect(!router.wartetAufStart)
    }

    @Test func nachDemStartGehtEsSofort() async throws {
        let router = AppRouter(wartetAufStart: true)
        router.startBeendet()
        try await mitRouter(router) { _ = try await KatalogSuchenIntent().perform() }
        #expect(router.tab == .bibliothek)
        #expect(router.katalogSuche)
    }

    @Test func beiMehrerenZielenvorDemStartZaehltDasLetzte() {
        let router = AppRouter(wartetAufStart: true)
        router.eingang(.thoskaAuslesen)
        router.eingang(.katalogSuche)
        router.startBeendet()
        #expect(router.tab == .bibliothek)
        #expect(!router.thoskaAuslesen)
    }

    /// Der Intent kommt vor dem Router (die App wird erst vom Intent gestartet): Er wartet am Eingang.
    @Test func einIntentVorDemRouterWartetAmEingang() async throws {
        DeepLinkEingang.trenne()
        defer {
            DeepLinkEingang.trenne()
            AppRouter.gemeinsam.verbinden()
        }
        _ = try await ThoskaAuslesenIntent().perform()

        let router = AppRouter()
        router.verbinden()
        #expect(router.tab == .thoska)
        #expect(router.thoskaAuslesen)
    }

    @Test func dieIntentsOeffnenDieApp() {
        #expect(ThoskaAuslesenIntent.openAppWhenRun)
        #expect(KatalogSuchenIntent.openAppWhenRun)
    }
}
