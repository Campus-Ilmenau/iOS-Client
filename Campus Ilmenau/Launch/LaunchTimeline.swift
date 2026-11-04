import SwiftUI

/// Zeitachse und Geometrie der Start-Animation „Durch die Ziege“.
/// Werte stammen aus `Design/Logo 2026/Launch/Launch-Animation.md` und dem Skript in `Launch/index.html`.
/// Koordinaten der Ziege sind Pfad-Einheiten der Maske (viewBox 996 × 1000).
enum LaunchTimeline {
    /// Gesamtdauer in Sekunden.
    static let duration: Double = 1.1

    /// Breite der Ziege im ersten Frame (entspricht dem statischen Launch Screen und dem App-Icon).
    static let goatWidth: CGFloat = 180
    static let maskSize = CGSize(width: 996, height: 1000)

    /// Zoom-Anker: dickste Stelle der Silhouette, Übergang von Brust zu Hals.
    static let anchor = CGPoint(x: 602, y: 608)
    /// Radius des Innenkreises um den Anker; ab dort ist der Bildschirm sicher Loch.
    static let anchorInnerRadius: CGFloat = 129

    /// Der erste Frame sitzt 10 pt über der Bildschirmmitte, wie der statische Launch Screen.
    static let goatVerticalOffset: CGFloat = -10

    static let anticipationScale: CGFloat = 0.88
    static let minimumEndScale: CGFloat = 30

    /// Abendsonne im Dark Mode (wie App-Icon Dark), in Pfad-Einheiten.
    static let sunCenter = CGPoint(x: 527, y: 443)
    static let sunRadius: CGFloat = 587
    static let sunHorizon: CGFloat = 996

    static let ringRadii: [CGFloat] = [900, 1300]
    static let ringLineWidth: CGFloat = 3
    /// Kantenlicht: konstante Breite und Weichzeichnung, unabhängig vom Zoom.
    static let edgeBlur: CGFloat = 4

    /// Skalierung der Startansicht von 1,08 auf 1,0, solange die Wand wegfliegt.
    static func contentScale(at progress: Double) -> CGFloat {
        1.08 + (1 - 1.08) * CGFloat(Ease.outCubic(Ease.clamp(progress, 0.32, 1)))
    }
}

/// Alle Größen eines Frames für eine gegebene Bildschirmgröße.
struct LaunchFrame {
    /// Skalierung der Ziege relativ zur Startgröße.
    let scale: CGFloat
    /// Bildschirmposition des Zoom-Ankers.
    let center: CGPoint
    /// Pro Pfad-Einheit in pt.
    let unit: CGFloat
    /// Deckkraft der Ziegenfüllung: 1 beim Start, 0 sobald die Ziege zum Loch geworden ist.
    let coverOpacity: Double
    /// Deckkraft des Kantenlichts: ab 1,3× ein, ab 8–16× aus.
    let edgeOpacity: Double
    /// Skalierung der Ringe (wachsen langsamer als das Loch).
    let ringScale: CGFloat
    /// 0 → 1 in der Haltephase: Vollfarbe des Launch Screens geht in den Wandverlauf über.
    let wallBlend: Double

    /// Linke obere Ecke der Maske in Bildschirmkoordinaten.
    var maskOrigin: CGPoint {
        CGPoint(
            x: center.x - LaunchTimeline.anchor.x * unit * scale,
            y: center.y - LaunchTimeline.anchor.y * unit * scale
        )
    }

    var maskRect: CGRect {
        CGRect(
            origin: maskOrigin,
            size: CGSize(
                width: LaunchTimeline.maskSize.width * unit * scale,
                height: LaunchTimeline.maskSize.height * unit * scale
            )
        )
    }

    init(progress t: Double, size: CGSize) {
        let unit = LaunchTimeline.goatWidth / LaunchTimeline.maskSize.width
        let startOrigin = CGPoint(
            x: (size.width - LaunchTimeline.goatWidth) / 2,
            y: (size.height - LaunchTimeline.maskSize.height * unit) / 2 + LaunchTimeline.goatVerticalOffset
        )
        let startAnchor = CGPoint(
            x: startOrigin.x + LaunchTimeline.anchor.x * unit,
            y: startOrigin.y + LaunchTimeline.anchor.y * unit
        )
        let screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)

        // Am Ende muss der Innenkreis um den Anker die am weitesten entfernte Ecke abdecken.
        let farthestCorner = hypot(size.width / 2, size.height / 2)
        let endScale = max(
            LaunchTimeline.minimumEndScale,
            1.1 * farthestCorner / (LaunchTimeline.anchorInnerRadius * unit)
        )

        let anticipation = Ease.inOut(Ease.clamp(t, 0.10, 0.32))
        let fly = Ease.inCubic(Ease.clamp(t, 0.32, 1))
        let anticipationFactor = 1 + (LaunchTimeline.anticipationScale - 1) * CGFloat(anticipation)
        let scale = fly > 0
            ? anticipationFactor * exp(log(endScale / LaunchTimeline.anticipationScale) * CGFloat(fly))
            : anticipationFactor

        self.unit = unit
        self.scale = scale
        self.center = CGPoint(
            x: startAnchor.x + (screenCenter.x - startAnchor.x) * CGFloat(fly),
            y: startAnchor.y + (screenCenter.y - startAnchor.y) * CGFloat(fly)
        )
        self.coverOpacity = 1 - Ease.clamp(t, 0.26, 0.40)
        self.edgeOpacity = Ease.clamp(Double(scale), 1.3, 3) * (1 - Ease.clamp(Double(scale), 8, 16))
        self.ringScale = pow(scale, 0.6)
        self.wallBlend = Ease.clamp(t, 0, 0.10)
    }
}

enum Ease {
    /// Anteil von `t` zwischen `a` und `b`, begrenzt auf 0…1.
    static func clamp(_ t: Double, _ a: Double, _ b: Double) -> Double {
        min(1, max(0, (t - a) / (b - a)))
    }

    static func inOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    static func inCubic(_ t: Double) -> Double { t * t * t }

    static func outCubic(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
}
