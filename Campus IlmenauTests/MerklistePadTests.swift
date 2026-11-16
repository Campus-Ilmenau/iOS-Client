import Testing
import Foundation
@testable import Campus_Ilmenau

/// Merkliste auf dem iPad: welcher Titel rechts steht, und dass die iPad-Anordnung die Daten nicht anfasst.
@MainActor
@Suite(.serialized)
struct MerklistePadTests {
    private typealias Regel = MerklisteAuswahlRegel

    // MARK: Beim Öffnen

    @Test func beimOeffnenIstDerErsteOffeneTitelGewaehlt() {
        #expect(Regel.anfang(offen: ["a", "b"], gefunden: ["c"]) == "a")
        #expect(Regel.korrigiere(aktuell: nil, offen: ["a", "b"], gefunden: ["c"]) == "a")
    }

    @Test func sindAlleGefundenIstDerErsteGefundeneGewaehlt() {
        #expect(Regel.anfang(offen: [], gefunden: ["c", "d"]) == "c")
    }

    @Test func eineLeereListeLaesstNichtsGewaehlt() {
        #expect(Regel.anfang(offen: [], gefunden: []) == nil)
        #expect(Regel.korrigiere(aktuell: "a", offen: [], gefunden: []) == nil)
    }

    @Test func eineGueltigeWahlBleibtStehen() {
        #expect(Regel.korrigiere(aktuell: "c", offen: ["a", "b"], gefunden: ["c"]) == "c")
    }

    @Test func verschwindetDieGewaehlteVonAussenIstDerAnfangGewaehlt() {
        // zum Beispiel entfernt die Uhr den Titel
        #expect(Regel.korrigiere(aktuell: "x", offen: ["a", "b"], gefunden: []) == "a")
    }

    // MARK: Nach Entfernen und Abhaken

    @Test func nachDemEntfernenIstDerNaechsteImAbschnittGewaehlt() {
        #expect(Regel.nachEntfernen("a", offen: ["a", "b", "c"], gefunden: []) == "b")
        #expect(Regel.nachEntfernen("b", offen: ["a", "b", "c"], gefunden: []) == "c")
    }

    @Test func warDerLetzteGewaehltIstDerDarueberGewaehlt() {
        #expect(Regel.nachEntfernen("c", offen: ["a", "b", "c"], gefunden: ["d"]) == "b")
        #expect(Regel.nachEntfernen("d", offen: ["a"], gefunden: ["c", "d"]) == "c")
    }

    @Test func warDerEinzigeOffeneGewaehltIstDerErsteGefundeneGewaehlt() {
        #expect(Regel.nachEntfernen("a", offen: ["a"], gefunden: ["c", "d"]) == "c")
    }

    @Test func nachDemEntfernenDesLetztenIstNichtsGewaehlt() {
        #expect(Regel.nachEntfernen("a", offen: ["a"], gefunden: []) == nil)
    }

    @Test func nachDemAbhakenIstDerNaechsteOffeneGewaehlt() {
        #expect(Regel.nachAbhaken("a", offen: ["a", "b", "c"], gefunden: ["d"]) == "b")
        #expect(Regel.nachAbhaken("c", offen: ["a", "b", "c"], gefunden: ["d"]) == "b")
    }

    @Test func derEinzigeOffeneBleibtNachDemAbhakenGewaehlt() {
        #expect(Regel.nachAbhaken("a", offen: ["a"], gefunden: ["d"]) == "a")
    }

    @Test func nachDemZuruecknehmenIstDerNaechsteGefundeneGewaehlt() {
        #expect(Regel.nachAbhaken("d", offen: ["a"], gefunden: ["d", "e"]) == "e")
    }

    // MARK: Zusammenspiel mit dem Speicher

    @Test func widerrufenSetztDenEintragAnDieAlteStelleZurueck() {
        let store = MerklisteBeispiele.store()
        let vorher = store.eintraege.map(\.id)
        let id = vorher[2]
        let entfernt = store.entfernen(id)
        #expect(entfernt != nil)
        #expect(!store.eintraege.map(\.id).contains(id))
        store.wiederherstellen(entfernt!)
        // dieselbe Reihenfolge wie vorher; die Liste wählt ihn danach wieder (`auswahlID = id`)
        #expect(store.eintraege.map(\.id) == vorher)
        #expect(Regel.korrigiere(aktuell: id, offen: store.offen.map(\.id), gefunden: store.gefunden.map(\.id)) == id)
    }

    @Test func derKreisWandertDenTitelInDenAbschnittGefunden() {
        let store = MerklisteBeispiele.store()
        #expect(store.gefunden.isEmpty)
        _ = store.setzeGefunden(true, fuer: "med_2")
        #expect(store.gefunden.map(\.id) == ["med_2"])
        #expect(!store.offen.map(\.id).contains("med_2"))
        #expect(store.anzahlGefunden == 1)
    }

    // MARK: Pro Gerät

    @Test func dieMerklisteDesIPadsLiegtInEinerEigenenDatei() {
        // Kein iCloud und kein Abgleich: Der Speicher liest und schreibt nur die Datei dieses Geräts.
        let url = BibMerklisteStore.defaultFileURL
        #expect(url?.lastPathComponent == "Merkliste.json")
        #expect(url?.path.contains("Application Support") == true)
    }
}
