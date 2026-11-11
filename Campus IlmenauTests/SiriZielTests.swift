import Testing
import Foundation
@testable import Campus_Ilmenau

// Die Siri-Karten sollen dort landen, wo sie hinzeigen: Suchbegriff, Titel, Merkliste.

@MainActor
struct SiriZielTests {
    @Test func einLinkZumTitelLiefertPPNUndPlatzhalterTitel() {
        let route = LibraryTitleRoute(id: "med_123456")
        #expect(route.media.id == "med_123456")
        #expect(route.media.ppn == "123456")
        #expect(route.media.title == "Titel 123456")
    }

    @Test func eineIDOhnePraefixHatKeinePPN() {
        #expect(LibraryTitleRoute(id: "abc").media.ppn == nil)
    }

    @Test func dasSuchfeldBekommtDenBegriffOhneRandLeerzeichen() {
        #expect(LibrarySearchModel.fuerSuchbegriff("  Analysis \n").text == "Analysis")
    }

    @Test func leereOderFehlendeBegriffeLassenDasSuchfeldLeer() {
        #expect(LibrarySearchModel.fuerSuchbegriff(nil).text.isEmpty)
        #expect(LibrarySearchModel.fuerSuchbegriff("   ").text.isEmpty)
    }

    @Test func derRouterMerktSichDieWuenscheDerBibliothek() throws {
        let router = AppRouter()
        router.oeffne(try #require(DeepLink(url: URL(string: "campusilmenau://katalog/suche?q=Analysis")!)))
        #expect(router.tab == .bibliothek)
        #expect(router.katalogBegriff == "Analysis")

        router.oeffne(try #require(DeepLink(url: URL(string: "campusilmenau://katalog/titel/med_42")!)))
        #expect(router.katalogTitelWunsch == "med_42")

        router.oeffne(try #require(DeepLink(url: URL(string: "campusilmenau://bibliothek/merkliste")!)))
        #expect(router.merklisteOeffnen)
    }
}
