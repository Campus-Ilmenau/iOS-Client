import SwiftUI

// Einlauf der Logo-Ziege im Kopf der Seitenleiste: Sie trabt von links hinein, die Füße stehen in der Standphase fest,
// am Ende dreht sie den Kopf nach hinten. Die Endpose ist exakt das Logo.
// Beschreibung: Uebergabe.md, „iPad“ → „Navigation“. Die Rechnung steht in `Laden/generate_einlauf.py`, die Teile in
// `Laden/generate.py`. Beides im Logo-Raster 0…1000 („Symbol Orange.svg“); hier wird dasselbe Raster benutzt.

// MARK: - Rechnung

/// Die Bewegung als Funktion der Zeit: je Zeitpunkt Körperversatz, Winkel und Länge der Beine, Kopf. Keine Keyframes;
/// jede Größe kommt wie in `generate_einlauf.py` direkt aus `t`.
enum ZiegeEinlaufRechnung {
    enum Bein: CaseIterable {
        case fo, fi, ro, ri   // vorn nah, vorn fern, hinten nah, hinten fern
    }

    struct BeinZustand: Equatable {
        /// Drehung um das Gelenk in Grad (positiv = im Uhrzeigersinn, wie in SVG).
        var winkel: Double
        /// Länge des Beins (`scaleY` am Gelenk): 1 = voll, im Schwung bis zu 18 % kürzer.
        var skala: Double
    }

    struct Zustand: Equatable {
        /// Versatz des ganzen Körpers nach rechts in Einheiten; −2200 am Anfang, 0 ab dem Ende des Trabs.
        var koerperX: Double
        var beine: [Bein: BeinZustand]
        /// Kopfwippen in Grad.
        var kopfWinkel: Double
        /// −1 = gespiegelt, schaut nach vorn; +1 = Logo, schaut zurück.
        var kopfSkalaX: Double
    }

    // MARK: Konstanten (wie in generate_einlauf.py)

    /// Gelenke der Beine (aus `generate.py`, `LEGS`).
    static let gelenk: [Bein: CGPoint] = [
        .ri: CGPoint(x: 142, y: 790), .fi: CGPoint(x: 628, y: 770),
        .ro: CGPoint(x: 55, y: 775), .fo: CGPoint(x: 798, y: 690),
    ]
    /// Fußpunkt (Mitte der Sohle) je Bein.
    static let fuss: [Bein: CGPoint] = [
        .ri: CGPoint(x: 193.75, y: 996), .fi: CGPoint(x: 510.85, y: 1000),
        .ro: CGPoint(x: 30.03, y: 996), .fo: CGPoint(x: 811.15, y: 996),
    ]
    /// Trab: diagonale Paare im Gleichtakt, um einen halben Zyklus versetzt.
    static let paar: [Bein: Double] = [.fo: 0, .ri: 0, .fi: 0.5, .ro: 0.5]
    /// Drehpunkt des Kopfes: Halsachse und Höhe.
    static let kopfAchse = CGPoint(x: 768.907, y: 420)

    static let weg = 2200.0        // Einheiten von außerhalb der Leiste bis zur Endposition
    static let zyklen = 6.0
    static let schritt = weg / zyklen
    static let zyklus = 0.42       // Sekunden
    static let aufsetzen = 0.14    // Sekunden: Beine in der Luft setzen auf
    static let pause = 0.25        // Sekunden: steht still, schaut noch nach vorn
    static let drehen = 0.45       // Sekunden: Kopf dreht sich nach hinten
    static let wippen = 3.0        // Grad
    static let stand = 0.6         // Anteil Standphase
    static let anheben = 0.18      // Schwung: Bein bis zu 18 % kürzer
    static let startphase = 0.3    // Paar A Mitte Stand, Paar B Mitte Schwung → Beine senkrecht

    static let trab = zyklen * zyklus                          // 2,52 s
    static let dauer = trab + aufsetzen + pause + drehen       // 3,36 s

    // MARK: Rechnung

    /// Winkel θ (Bogenmaß), bei dem der Fuß (`dx`, `dy` relativ zum Gelenk) nach der Drehung bei x-Abstand `xr` liegt:
    /// dx·cos θ − dy·sin θ = xr, Newton-Iteration ab 0.
    static func loese(dx: Double, dy: Double, xr: Double) -> Double {
        var theta = 0.0
        for _ in 0..<30 {
            let f = dx * cos(theta) - dy * sin(theta) - xr
            let df = -dx * sin(theta) - dy * cos(theta)
            theta -= f / df
        }
        return theta
    }

    static func glatt(_ u: Double) -> Double { u * u * (3 - 2 * u) }

    /// Ob das Bein bei dieser Phase (Zyklen seit Beginn, mit Startphase) am Boden steht.
    static func steht(_ bein: Bein, phase: Double) -> Bool {
        ((phase + paar[bein]!).truncatingRemainder(dividingBy: 1)) < stand
    }

    /// Das Bein im Trab bei `phase` (in Zyklen, inklusive Startphase).
    static func beinImTrab(_ bein: Bein, phase: Double) -> BeinZustand {
        let j = gelenk[bein]!, f = fuss[bein]!
        let dx = f.x - j.x, dy = f.y - j.y
        let fegen = stand * schritt                      // während des Stands zieht der Körper so weit weiter
        let p = (phase + paar[bein]!).truncatingRemainder(dividingBy: 1)
        if p < stand {                                   // Stand: Fuß bleibt in der Welt stehen
            let u = p / stand
            let theta = loese(dx: dx, dy: dy, xr: dx + fegen / 2 - u * fegen)
            return BeinZustand(winkel: theta * 180 / .pi, skala: 1)
        }
        let vorn = loese(dx: dx, dy: dy, xr: dx + fegen / 2)    // Fuß setzt vorn auf
        let hinten = loese(dx: dx, dy: dy, xr: dx - fegen / 2)  // Fuß hebt hinten ab
        let u = (p - stand) / (1 - stand)                // Schwung: nach vorn, dabei angehoben
        let theta = hinten + (vorn - hinten) * glatt(u)
        return BeinZustand(winkel: theta * 180 / .pi, skala: 1 - anheben * sin(.pi * u))
    }

    /// Der Körperversatz bei `t` (linear, kein Ease).
    static func koerperX(bei t: Double) -> Double {
        t < trab ? -weg * (1 - t / trab) : 0
    }

    /// Der ganze Zustand bei `t` Sekunden seit Start. Vor 0 und nach `dauer` gelten Anfangs- bzw. Endpose.
    static func zustand(bei zeit: Double) -> Zustand {
        let t = min(max(zeit, 0), dauer)
        var beine: [Bein: BeinZustand] = [:]
        for bein in Bein.allCases {
            if t <= trab {
                beine[bein] = beinImTrab(bein, phase: startphase + t / zyklus)
            } else if t <= trab + aufsetzen {
                // Aufsetzen: von der Pose am Ende des Trabs linear auf Logo-Stellung (0°, volle Länge)
                let ende = beinImTrab(bein, phase: startphase + trab / zyklus)
                let u = (t - trab) / aufsetzen
                beine[bein] = BeinZustand(winkel: ende.winkel * (1 - u), skala: ende.skala + (1 - ende.skala) * u)
            } else {
                beine[bein] = BeinZustand(winkel: 0, skala: 1)
            }
        }
        let wippt = t <= trab ? wippen * pow(sin(2 * .pi * t / zyklus), 2) : 0
        let drehStart = trab + aufsetzen + pause
        let skalaX = t <= drehStart ? -1.0 : -1 + 2 * glatt(min(1, (t - drehStart) / drehen))
        return Zustand(koerperX: koerperX(bei: t), beine: beine, kopfWinkel: wippt, kopfSkalaX: skalaX)
    }
}

// MARK: - Zeichnung

/// Die Ziege in einem Zustand. Das Raster ist 0…1000 = 22 pt; der Zeichenrahmen ragt links um den ganzen Weg (48 pt)
/// und oben/unten um 4 pt über den Platz des Logos hinaus (Kopf und Wippen), ohne Platz im Layout zu brauchen.
struct ZiegeEinlaufBild: View {
    typealias Rechnung = ZiegeEinlaufRechnung

    static let kante: CGFloat = 22
    static let einheit = kante / 1000
    static let randLinks = (Rechnung.weg * einheit).rounded(.up) + 2
    static let randOben: CGFloat = 4

    let zustand: Rechnung.Zustand

    /// Kopf des Logos, so wie `generate.py` ihn liefert (`HEAD_SRC`, schaut zurück).
    private static let kopf = SVGPathParser.path(from: "M666.219,430 L666.219,359.878 C666.219,331.736 657.099,305.731 641.663,284.674 L511.181,360.241 L378.054,282.599 L653.718,53.186 C690.091,20.134 738.348,0 791.292,0 C900.915,0 990.439,86.318 996,194.891 C990.825,129.472 936.261,78 869.712,78 C824.175,78 784.250,102.099 761.921,138.277 C835.037,264.281 871.595,354.283 871.595,408.283 L871.595,430 Z")

    private static func bein(_ bein: Rechnung.Bein) -> GoatPart {
        switch bein {
        case .fo: .foreNear
        case .fi: .foreFar
        case .ro: .hindNear
        case .ri: .hindFar
        }
    }

    /// Drehen und Längen um das Gelenk: erst `scaleY`, dann `rotate` (wie `rotate() scaleY()` in CSS).
    private static func umGelenk(_ gelenk: CGPoint, winkel: Double, skala: Double) -> CGAffineTransform {
        CGAffineTransform(translationX: -gelenk.x, y: -gelenk.y)
            .concatenating(CGAffineTransform(scaleX: 1, y: skala))
            .concatenating(CGAffineTransform(rotationAngle: winkel * .pi / 180))
            .concatenating(CGAffineTransform(translationX: gelenk.x, y: gelenk.y))
    }

    /// Kopf: erst spiegeln (`scaleX`), dann um dieselbe Achse drehen.
    private static func kopfTransform(winkel: Double, skalaX: Double) -> CGAffineTransform {
        let achse = Rechnung.kopfAchse
        return CGAffineTransform(translationX: -achse.x, y: -achse.y)
            .concatenating(CGAffineTransform(scaleX: skalaX, y: 1))
            .concatenating(CGAffineTransform(rotationAngle: winkel * .pi / 180))
            .concatenating(CGAffineTransform(translationX: achse.x, y: achse.y))
    }

    static var rahmen: CGSize {
        CGSize(width: randLinks + kante, height: kante + 2 * randOben)
    }

    var body: some View {
        Canvas { context, _ in
            context.translateBy(x: Self.randLinks, y: Self.randOben)
            context.scaleBy(x: Self.einheit, y: Self.einheit)
            context.translateBy(x: zustand.koerperX, y: 0)

            func beinZeichnen(_ bein: Rechnung.Bein) {
                let b = zustand.beine[bein] ?? .init(winkel: 0, skala: 1)
                let transform = Self.umGelenk(Rechnung.gelenk[bein]!, winkel: b.winkel, skala: b.skala)
                context.fill(Self.bein(bein).path.applying(transform), with: .foreground)
            }
            // Reihenfolge wie im SVG: hinten fern, vorn fern, Körper, Kopf, hinten nah, vorn nah.
            beinZeichnen(.ri)
            beinZeichnen(.fi)
            context.fill(GoatPart.body.path, with: .foreground)
            let kopf = Self.kopfTransform(winkel: zustand.kopfWinkel, skalaX: zustand.kopfSkalaX)
            context.fill(Self.kopf.applying(kopf), with: .foreground)
            beinZeichnen(.ro)
            beinZeichnen(.fo)
        }
        .frame(width: Self.rahmen.width, height: Self.rahmen.height)
    }
}

// MARK: - Einlauf

/// Das Logo (22 × 22 pt) im Kopf der Seitenleiste. Mit `start` trabt die Ziege von links hinein, sonst steht das Logo.
/// Die Farbe kommt vom umgebenden `foregroundStyle`. Layout und Platz bleiben gleich: Der Einlauf liegt als Overlay darüber.
///
/// Die `TimelineView` gibt es nur, solange der Einlauf läuft (3,36 s). Danach steht wieder das Logo-Asset, ohne Uhr.
/// Mit „Bewegung reduzieren“ steht das Logo sofort.
struct ZiegeEinlauf: View {
    /// Wann der Einlauf gestartet wurde; `nil` heißt: kein Einlauf (Seitenleiste zu).
    let start: Date?

    @Environment(\.accessibilityReduceMotion) private var bewegungReduziert
    /// Für welchen Start der Einlauf schon zu Ende ist.
    @State private var fertigFuer: Date?

    private var laeuft: Bool {
        start != nil && fertigFuer != start && !bewegungReduziert
    }

    var body: some View {
        Image("SymbolWhite")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: ZiegeEinlaufBild.kante, height: ZiegeEinlaufBild.kante)
            .opacity(laeuft ? 0 : 1)
            .overlay(alignment: .topLeading) {
                if laeuft, let start {
                    TimelineView(.animation) { zeit in
                        ZiegeEinlaufBild(zustand: .bei(zeit.date.timeIntervalSince(start)))
                    }
                    // Der Rahmen ragt nach links und oben/unten heraus; im Layout zählt nur der Platz des Logos.
                    .fixedSize()
                    .offset(x: -ZiegeEinlaufBild.randLinks, y: -ZiegeEinlaufBild.randOben)
                }
            }
            .task(id: start) {
                guard let start else { return }
                let rest = ZiegeEinlaufRechnung.dauer - Date.now.timeIntervalSince(start)
                try? await Task.sleep(for: .seconds(max(0, rest)))
                if !Task.isCancelled { fertigFuer = start }
            }
            .accessibilityHidden(true)
    }
}

extension ZiegeEinlaufRechnung.Zustand {
    static func bei(_ zeit: Double) -> Self { ZiegeEinlaufRechnung.zustand(bei: zeit) }
}
