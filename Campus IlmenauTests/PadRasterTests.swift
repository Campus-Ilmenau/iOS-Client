import Testing
import SwiftUI
@testable import Campus_Ilmenau

/// Das Raster der iPad-Ansichten: Die Breite der Ansicht entscheidet, nicht das Gerät.
@MainActor
struct PadRasterTests {
    @Test func anordnungSpringtBei700Und900() {
        func anordnung(_ breite: CGFloat) -> PadRaster.Anordnung { PadRaster(breite: breite).anordnung }
        #expect(anordnung(0) == .untereinander)
        #expect(anordnung(320) == .untereinander)
        #expect(anordnung(699.5) == .untereinander)
        #expect(anordnung(700) == .zweiSpalten)
        #expect(anordnung(899.5) == .zweiSpalten)
        #expect(anordnung(900) == .voll)
        #expect(anordnung(1376) == .voll)
    }

    @Test func einIPhoneBleibtBeiDerIPhoneAnordnungAuchBreitUndQuer() {
        let quer = PadRaster(breite: 932, geraetIstPad: false)
        #expect(quer.anordnung == .untereinander)
        #expect(!quer.istPad)
        #expect(quer.rand == 16)
        #expect(quer.seitentitel(telefon: 32) == 32)
    }

    @Test func werteAufDemIPadUndDarunter() {
        let pad = PadRaster(breite: 1096)
        #expect(pad.rand == 32)
        #expect(pad.seitentitel(telefon: 32) == 38)
        #expect(PadRaster.textBreite == 680)
        // Darunter gelten die bisherigen Werte.
        let schmal = PadRaster(breite: 438)
        #expect(schmal.rand == 16)
        #expect(schmal.seitentitel(telefon: 32) == 32)
    }

    @Test func linkeSpalteHatDasVerhaeltnis145Zu1() {
        let raster = PadRaster(breite: 1376)
        let nutz = 1376 - 2 * 32 - PadRaster.spaltenAbstand
        let links = raster.linkeSpalte
        let rechts = nutz - links
        #expect(abs(links / rechts - 1.45) < 0.001)
        #expect(abs(links - 762.2) < 0.2)
    }
}
