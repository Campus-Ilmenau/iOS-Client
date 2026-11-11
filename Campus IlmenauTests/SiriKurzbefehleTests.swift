import Testing
import AppIntents
@testable import Campus_Ilmenau

// Kurzbefehle-App, Mehr und Siri-Tipps (`Uebergabe.md`, „Kurzbefehle-App, Spotlight, Tipps“).

struct SiriTippTests {
    @Test func speiseplanZeigtDenTippAbDemDrittenOeffnen() {
        #expect(SiriTipp.mensaAbOeffnung == 3)
        #expect(!SiriTipp.zeigtMensa(oeffnungen: 0, verborgen: false))
        #expect(!SiriTipp.zeigtMensa(oeffnungen: 1, verborgen: false))
        #expect(!SiriTipp.zeigtMensa(oeffnungen: 2, verborgen: false))
        #expect(SiriTipp.zeigtMensa(oeffnungen: 3, verborgen: false))
        #expect(SiriTipp.zeigtMensa(oeffnungen: 40, verborgen: false))
    }

    @Test func nachDemKreuzNieWieder() {
        for oeffnungen in [0, 3, 100] {
            #expect(!SiriTipp.zeigtMensa(oeffnungen: oeffnungen, verborgen: true))
        }
    }

    @Test func heuteAbendZeigtDenTippEinmal() {
        // Erst wenn „Heute Abend“ aktiv ist, und nur, wenn er noch nie erschienen ist.
        #expect(SiriTipp.zeigtAbendErstmals(heuteAbendAktiv: true, schonGezeigt: false))
        #expect(!SiriTipp.zeigtAbendErstmals(heuteAbendAktiv: false, schonGezeigt: false))
        #expect(!SiriTipp.zeigtAbendErstmals(heuteAbendAktiv: true, schonGezeigt: true))
    }

    @Test func dieSchluesselGehoerenNurDemTipp() {
        #expect(Set([SiriTipp.mensaOeffnungen, SiriTipp.mensaVerborgen, SiriTipp.abendGezeigt]).count == 3)
    }
}

@MainActor
struct SiriKurzbefehleTests {
    @Test func dieKachelnSindNachtblau() {
        #expect(CampusShortcuts.shortcutTileColor == .navy)
    }

    @Test func siebenKurzbefehle() {
        #expect(CampusShortcuts.appShortcuts.count == 7)
    }

    /// Reihenfolge, Titel und Symbole der Kurzbefehle-App, wie in `Uebergabe.md`.
    @Test func dieListeInMehrFolgtDerReihenfolgeDerKachelnMitIhrenSymbolen() {
        #expect(SiriFragenView.abschnitte.map(\.symbol) == [
            "fork.knife", "clock", "fork.knife.circle", "moon.fill", "text.magnifyingglass", "bookmark", "wave.3.right"
        ])
    }

    @Test func jederKurzbefehlHatSaetzeInDerListe() {
        #expect(SiriFragenView.abschnitte.allSatisfy { !$0.saetze.isEmpty })
    }
}
