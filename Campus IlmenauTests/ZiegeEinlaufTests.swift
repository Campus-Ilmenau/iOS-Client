import Testing
import Foundation
import SwiftUI
import UIKit
@testable import Campus_Ilmenau

/// Der Einlauf der Logo-Ziege (`ZiegeEinlaufRechnung`): Füße stehen fest, Endpose ist das Logo.
@MainActor
struct ZiegeEinlaufTests {
    typealias R = ZiegeEinlaufRechnung

    /// Fuß-x in der Welt: Körperversatz plus Fußpunkt nach der Drehung um das Gelenk.
    private func fussX(_ bein: R.Bein, t: Double) -> Double {
        let z = R.zustand(bei: t)
        let b = z.beine[bein]!
        let j = R.gelenk[bein]!, f = R.fuss[bein]!
        let theta = b.winkel * .pi / 180
        return z.koerperX + j.x + (f.x - j.x) * cos(theta) - (f.y - j.y) * sin(theta)
    }

    /// Größte Abweichung des Fuß-x innerhalb einer zusammenhängenden Standphase, über alle Beine.
    private func groessteFussabweichung() -> (abweichung: Double, standphasen: Int) {
        var groesste = 0.0
        var anzahl = 0
        for bein in R.Bein.allCases {
            var lauf: [Double] = []
            var t = 0.0
            while t <= R.trab + 1e-9 {
                if R.steht(bein, phase: R.startphase + t / R.zyklus) {
                    lauf.append(fussX(bein, t: t))
                } else if !lauf.isEmpty {
                    groesste = max(groesste, lauf.max()! - lauf.min()!)
                    anzahl += 1
                    lauf = []
                }
                t += 0.001
            }
            if !lauf.isEmpty {
                groesste = max(groesste, lauf.max()! - lauf.min()!)
                anzahl += 1
            }
        }
        return (groesste, anzahl)
    }

    @Test func fussStehtInJederStandphaseFest() {
        let (abweichung, standphasen) = groessteFussabweichung()
        print("Größte Fußabweichung in der Standphase: \(abweichung) Einheiten über \(standphasen) Standphasen")
        #expect(standphasen >= 4 * 6)          // 4 Beine, 6 Zyklen (am Rand teilweise)
        #expect(abweichung < 0.5)
    }

    @Test func amEndeStehtDasLogo() {
        let z = R.zustand(bei: R.dauer)
        #expect(abs(R.dauer - 3.36) < 1e-9)
        #expect(z.koerperX == 0)
        for bein in R.Bein.allCases {
            #expect(z.beine[bein] == R.BeinZustand(winkel: 0, skala: 1))
        }
        #expect(z.kopfWinkel == 0)
        #expect(z.kopfSkalaX == 1)
        // Auch nach dem Ende bleibt es dabei, kein Nachfedern.
        #expect(R.zustand(bei: R.dauer + 5) == z)
    }

    @Test func amAnfangKommtDieZiegeVonLinksUndSchautNachVorn() {
        let z = R.zustand(bei: 0)
        #expect(z.koerperX == -2200)
        #expect(z.kopfSkalaX == -1)
        #expect(z.kopfWinkel == 0)
        // Startphase 0,3: Paar A Mitte Stand (Beine fast senkrecht), Paar B Mitte Schwung (angehoben).
        #expect(z.beine[.fo]!.skala == 1)
        #expect(z.beine[.fi]!.skala < 1)
    }

    @Test func derKoerperLaeuftLinearUndSteht() {
        #expect(R.zustand(bei: R.trab / 2).koerperX == -1100)
        #expect(R.zustand(bei: R.trab).koerperX == 0)
        #expect(R.zustand(bei: R.trab + 0.1).koerperX == 0)
    }

    @Test func kopfWipptImTaktUndDrehtErstNachDemAufsetzen() {
        // Wippen: zweimal pro Zyklus bis 3° (sin²), solange sie geht.
        #expect(abs(R.zustand(bei: R.zyklus / 4).kopfWinkel - 3) < 1e-9)
        #expect(abs(R.zustand(bei: R.zyklus / 2).kopfWinkel) < 1e-9)
        // Aufsetzen und Pause: noch gespiegelt, steht ohne Wippen.
        let nachAufsetzen = R.zustand(bei: R.trab + R.aufsetzen + R.pause / 2)
        #expect(nachAufsetzen.kopfSkalaX == -1)
        #expect(nachAufsetzen.kopfWinkel == 0)
        // Drehen: Mitte der Drehung = scaleX 0.
        let mitte = R.zustand(bei: R.trab + R.aufsetzen + R.pause + R.drehen / 2)
        #expect(abs(mitte.kopfSkalaX) < 1e-9)
    }

    @Test func dieBeineSetzenAmEndeDesTrabsInDerLuftAuf() {
        let ende = R.zustand(bei: R.trab)
        let halb = R.zustand(bei: R.trab + R.aufsetzen / 2)
        let fertig = R.zustand(bei: R.trab + R.aufsetzen)
        for bein in R.Bein.allCases {
            #expect(abs(halb.beine[bein]!.winkel - ende.beine[bein]!.winkel / 2) < 1e-9)
            #expect(abs(fertig.beine[bein]!.winkel) < 1e-9 && abs(fertig.beine[bein]!.skala - 1) < 1e-9)
        }
    }

    @Test func beinImSchwungWirdBisZuAchtzehnProzentKuerzer() {
        var kleinste = 1.0
        for k in 0..<1000 {
            for bein in R.Bein.allCases {
                kleinste = min(kleinste, R.beinImTrab(bein, phase: Double(k) / 1000).skala)
            }
        }
        #expect(abs(kleinste - 0.82) < 0.001)
    }

    // MARK: Endpose = Logo-Asset

    /// Alphakanal einer View, gerendert mit `scale` Pixeln pro pt.
    private func alpha<V: View>(_ view: V, scale: CGFloat) -> (breite: Int, hoehe: Int, werte: [UInt8])? {
        let renderer = ImageRenderer(content: view.foregroundStyle(Color.black))
        renderer.scale = scale
        guard let bild = renderer.cgImage else { return nil }
        let breite = bild.width, hoehe = bild.height
        var daten = [UInt8](repeating: 0, count: breite * hoehe * 4)
        guard let kontext = CGContext(
            data: &daten, width: breite, height: hoehe, bitsPerComponent: 8, bytesPerRow: breite * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        kontext.draw(bild, in: CGRect(x: 0, y: 0, width: breite, height: hoehe))
        return (breite, hoehe, stride(from: 3, to: daten.count, by: 4).map { daten[$0] })
    }

    @Test func endposeDecktSichMitDemLogoAsset() throws {
        let rahmen = ZiegeEinlaufBild.rahmen
        let ziege = ZiegeEinlaufBild(zustand: .bei(R.dauer))
        // Das Logo liegt im Rahmen rechts, vertikal mit `randOben` Abstand.
        let logoMitte = Image("SymbolWhite")
            .renderingMode(.template).resizable().scaledToFit()
            .frame(width: ZiegeEinlaufBild.kante, height: ZiegeEinlaufBild.kante)
            .position(x: ZiegeEinlaufBild.randLinks + ZiegeEinlaufBild.kante / 2,
                      y: ZiegeEinlaufBild.randOben + ZiegeEinlaufBild.kante / 2)
            .frame(width: rahmen.width, height: rahmen.height)
        let a = try #require(alpha(ziege, scale: 8))
        let b = try #require(alpha(logoMitte, scale: 8))
        #expect(a.breite == b.breite && a.hoehe == b.hoehe)
        // Kanten glättet Canvas anders als das Bild-Asset; verglichen werden darum Umriss, Fläche und Schwerpunkt.
        func kennzahlen(_ x: (breite: Int, hoehe: Int, werte: [UInt8])) -> (box: [Int], flaeche: Double, schwerpunkt: CGPoint) {
            var minX = x.breite, maxX = 0, minY = x.hoehe, maxY = 0, summe = 0.0, sx = 0.0, sy = 0.0
            for yy in 0..<x.hoehe {
                for xx in 0..<x.breite {
                    let w = Double(x.werte[yy * x.breite + xx]) / 255
                    if w > 0.5 { minX = min(minX, xx); maxX = max(maxX, xx); minY = min(minY, yy); maxY = max(maxY, yy) }
                    summe += w; sx += w * Double(xx); sy += w * Double(yy)
                }
            }
            return ([minX, maxX, minY, maxY], summe, CGPoint(x: sx / summe, y: sy / summe))
        }
        let ka = kennzahlen(a), kb = kennzahlen(b)
        let flaechenUnterschied = abs(ka.flaeche - kb.flaeche) / kb.flaeche
        let versatz = hypot(ka.schwerpunkt.x - kb.schwerpunkt.x, ka.schwerpunkt.y - kb.schwerpunkt.y)
        print("Endpose gegen Logo-Asset (8 px je pt): Umriss \(ka.box) / \(kb.box), Fläche \(ka.flaeche) / \(kb.flaeche) (\(flaechenUnterschied * 100) %), Schwerpunkt-Versatz \(versatz) px")
        #expect(ka.box == kb.box, "Umriss \(ka.box) / \(kb.box)")
        #expect(flaechenUnterschied < 0.01, "Fläche \(flaechenUnterschied)")
        #expect(versatz < 0.5, "Versatz \(versatz) px")
        #expect(kb.flaeche > 5000)
    }
}
