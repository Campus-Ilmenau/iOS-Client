import Testing
import Foundation
@testable import Campus_Ilmenau

/// Katalog auf dem iPad: Auswahl neben den Treffern, Links und die Suche von außen.
@MainActor
@Suite(.serialized)
struct KatalogPadTests {
    private func treffer(_ szenario: LibrarySearchModel.PreviewScenario = .bestand) -> [LibraryMedia] {
        LibrarySearchModel.preview(szenario).sections.flatMap(\.items)
    }

    // MARK: Auswahl

    @Test func nachJederNeuenSucheIstDerErsteTrefferGewaehlt() {
        let liste = treffer()
        var zustand = KatalogPadZustand()
        zustand.wahl = liste[3]
        zustand.neueSuche(treffer: liste)
        #expect(zustand.wahl?.id == liste.first?.id)
        #expect(zustand.fremdeID == nil)
    }

    @Test func eineSucheOhneTrefferLaesstNichtsGewaehlt() {
        var zustand = KatalogPadZustand()
        zustand.wahl = treffer().first
        zustand.leeren()
        #expect(zustand.wahl == nil && zustand.fremdeID == nil)
    }

    @Test func verschwindetDieGewaehlteIstDerErsteTrefferGewaehlt() {
        let liste = treffer()
        var zustand = KatalogPadZustand()
        zustand.wahl = liste[2]
        zustand.korrigiere(treffer: liste)
        #expect(zustand.wahl?.id == liste[2].id)

        let ohneDritten = liste.filter { $0.id != liste[2].id }
        zustand.korrigiere(treffer: ohneDritten)
        #expect(zustand.wahl?.id == ohneDritten.first?.id)
    }

    // MARK: Link auf einen Titel

    @Test func einTitelAusEinemLinkBleibtGewaehltAuchOhneTrefferInDerListe() {
        let liste = treffer()
        let fremd = treffer(.gemischt).last!
        var zustand = KatalogPadZustand()
        zustand.waehleVonAussen(fremd, treffer: liste.filter { $0.id != fremd.id })
        #expect(zustand.wahl?.id == fremd.id)
        #expect(zustand.fremdeID == fremd.id)

        // Die Korrektur der Liste ersetzt ihn nicht durch den ersten Treffer.
        zustand.korrigiere(treffer: liste.filter { $0.id != fremd.id })
        #expect(zustand.wahl?.id == fremd.id)

        // Eine neue Suche löst ihn ab.
        zustand.neueSuche(treffer: liste)
        #expect(zustand.wahl?.id == liste.first?.id && zustand.fremdeID == nil)
    }

    @Test func einTitelAusEinemLinkStehtInDerListeWennerDarinVorkommt() {
        let liste = treffer()
        var zustand = KatalogPadZustand()
        zustand.waehleVonAussen(liste[1], treffer: liste)
        #expect(zustand.wahl?.id == liste[1].id)
        #expect(zustand.fremdeID == nil)
    }

    // MARK: Suche von außen (`katalog/suche?q=`)

    @Test func dieSucheVonAussenSetztDenBegriffUndSchliesstDieErweiterteSuche() {
        let model = LibrarySearchModel.preview(.jahrFehler)
        #expect(model.advancedOpen && model.formError != nil)
        model.sucheVonAussen("  thermodynamik ")
        #expect(model.text == "thermodynamik")
        #expect(!model.advancedOpen && model.formError == nil)
        #expect(model.phase == .loading)
    }

    @Test func dieSucheVonAussenIgnoriertLeereBegriffe() {
        let model = LibrarySearchModel.preview(.start)
        model.sucheVonAussen("   ")
        #expect(model.text.isEmpty)
        #expect(model.phase == .start)
    }

    @Test func dieAenderungDesTextesNachDerSucheVonAussenSuchtNichtNochEinmal() {
        let model = LibrarySearchModel.preview(.start)
        model.sucheVonAussen("regelung")
        let phase = model.phase
        // Die Ansicht meldet die Änderung des Textes: Das ist dieselbe Suche, es startet keine zweite.
        model.textChanged()
        #expect(model.phase == phase)
        // Tippt jemand danach etwas Neues, gilt wieder die Pause.
        model.text = "regelung 2"
        model.textChanged()
        #expect(model.phase == phase)
    }

    // MARK: Breite

    @Test func dieListeIstAbGrossenBreitenVierhundertvierzigBreit() {
        #expect(PadRaster(breite: 1376).listenbreite == 440)
        #expect(PadRaster(breite: 1150).listenbreite == 440)
        #expect(PadRaster(breite: 1149).listenbreite == 360)
        #expect(PadRaster(breite: 700).listenbreite == 360)
    }
}
