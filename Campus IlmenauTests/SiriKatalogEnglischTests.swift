import Testing
import Foundation
@testable import Campus_Ilmenau

/// Katalogsuche, Merkliste und „Heute Abend“ auf Englisch (nur für diesen Test, siehe `AppLanguage.test`).
struct SiriKatalogEnglischTests {
    private func englisch<T>(_ block: () throws -> T) rethrows -> T {
        try AppLanguage.$test.withValue(.en, operation: block)
    }

    private func treffer(_ titel: String, status: SiriKatalogStatus? = nil) -> SiriKatalogTreffer {
        SiriKatalogTreffer(id: "med_1", titel: titel, meta: "", status: status)
    }

    @Test func katalogMitStatus() {
        let a = englisch {
            SiriKatalog.antwort(SiriKatalogErgebnis(
                begriff: "Regelungstechnik", korrigiert: nil, gesamt: 128,
                treffer: [treffer("Regelungstechnik für Ingenieure", status: SiriKatalogStatus(art: .ausleihbar, chipText: "Ausleihbar"))]
            ))
        }
        #expect(a.sagt == "I found 128 results for “Regelungstechnik”. The first, “Regelungstechnik für Ingenieure”, is available to borrow.")
    }

    @Test func katalogEinTrefferOhneTreffer() {
        let eins = englisch {
            SiriKatalog.antwort(SiriKatalogErgebnis(
                begriff: "X", korrigiert: nil, gesamt: 1,
                treffer: [treffer("T", status: SiriKatalogStatus(art: .online, chipText: "Online lesen"))]
            ))
        }
        #expect(eins.sagt == "I found one result for “X”: “T”. It’s available online.")
        let keine = englisch { SiriKatalog.antwort(SiriKatalogErgebnis(begriff: "X", korrigiert: nil, gesamt: 0, treffer: [])) }
        #expect(keine.sagt == "I didn’t find anything for “X”.")
        #expect(keine.karte?.titel == "No results")
        englisch {
            #expect(SiriKatalog.nichtErreichbar.sagt == "I can’t reach the catalogue right now. Try again in a moment.")
            #expect(SiriKatalog.ungueltig.sagt == "That search term doesn’t work. Try a few keywords.")
        }
    }

    @Test func katalogKorrigiert() {
        let a = englisch {
            SiriKatalog.antwort(SiriKatalogErgebnis(
                begriff: "Regelungstechnk", korrigiert: "Regelungstechnik", gesamt: 5, treffer: [treffer("T")]
            ))
        }
        #expect(a.sagt == "I searched for “Regelungstechnik”. That’s 5 results. The first one is “T”.")
        #expect(a.karte?.untertitel == "for “Regelungstechnik” instead of “Regelungstechnk”")
    }

    @Test func merkliste() {
        let leer = englisch { SiriMerkliste.antwort([]) }
        #expect(leer.sagt == "Your saved list is empty. Save titles from the catalogue.")
        let eintraege = [
            SiriMerklisteEintrag(id: "1", titel: "A", stand: .imRegal(standort: "60 ELT", signatur: nil)),
            SiriMerklisteEintrag(id: "2", titel: "B", stand: .imRegal(standort: "60 ELT", signatur: nil)),
            SiriMerklisteEintrag(id: "3", titel: "C", stand: .imRegal(standort: "70 MB", signatur: nil)),
            SiriMerklisteEintrag(id: "4", titel: "D", stand: .ausgeliehen)
        ]
        let a = englisch { SiriMerkliste.antwort(eintraege) }
        #expect(a.sagt == "Three titles are on the shelf: two in 60 ELT, one in 70 MB. One is on loan.")
        #expect(a.karte?.titel == "3 titles on the shelf")
    }

    @Test func abendOhneDaten() {
        englisch {
            #expect(SiriAbend.keineDaten == "I can’t reach the events right now. Try again in a moment.")
            #expect(SiriSprache.ortsangabe("Studi-Club") == " – Studi-Club" || SiriSprache.ortsangabe("Studi-Club") == " at Studi-Club")
            #expect(SiriSprache.ortsangabe("Studi-Club") == " at Studi-Club")
        }
    }
}
