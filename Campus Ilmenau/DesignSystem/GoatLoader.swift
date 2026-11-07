import SwiftUI

/// Ladeanimation: die Logo-Ziege rennt auf der Stelle und schaut dabei nach vorn.
/// Breite = `size`, Höhe = `size` × 1100/1320. Geometrie und Bewegung nach `Laden/Ziege rennt.svg`
/// und `LadenZiege.dc.html`; Größen laut Design: 96 / 44 / 28 pt. Farbe überall `accent`.
/// Boden und Staub gibt es erst ab 60 pt Breite.
struct GoatLoader: View {
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.goatLoaderForcesReducedMotion) private var forcesReducedMotion

    private var reduceMotion: Bool { systemReduceMotion || forcesReducedMotion }

    private var height: CGFloat { size * GoatGeometry.viewBox.height / GoatGeometry.viewBox.width }

    var body: some View {
        Group {
            if reduceMotion {
                GoatReducedMotion(size: size)
            } else {
                TimelineView(.animation) { context in
                    GoatRunning(size: size, time: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(width: size, height: height)
        .accessibilityHidden(true)
    }
}

extension EnvironmentValues {
    /// Erzwingt die Variante „Bewegung reduzieren“, weil `accessibilityReduceMotion` nur lesbar ist (Previews, Tests).
    @Entry var goatLoaderForcesReducedMotion = false
}

// MARK: - Geometrie

/// Koordinatenraum des SVG (`viewBox -80 -40 1320 1100`) und Drehpunkte.
private enum GoatGeometry {
    static let viewBox = CGRect(x: -80, y: -40, width: 1320, height: 1100)

    /// Gelenk in viewBox-Koordinaten → `UnitPoint` im Rahmen der Ziege.
    static func anchor(_ x: CGFloat, _ y: CGFloat) -> UnitPoint {
        UnitPoint(x: (x - viewBox.minX) / viewBox.width, y: (y - viewBox.minY) / viewBox.height)
    }

    static let bodyCenter = anchor(450, 620)
    static let headJoint = anchor(768.9, 420)
}

/// Die sechs Teile der Ziege. Pfaddaten unverändert aus `Ziege rennt.svg`.
private enum GoatPart {
    case hindFar, foreFar, body, head, hindNear, foreNear

    var pathData: String {
        switch self {
        case .hindFar:
            "M104,790 L163.5,996 L224,996 L180,790 A38,38 0 0 0 104,790 Z"
        case .foreFar:
            "M595.9,753.7 L480,1000 L541.7,999.9 L660.1,786.3 A36,36 0 0 0 595.9,753.7 Z"
        case .body:
            "M171.612,741.601 L170.536,741.609 C131.224,742.198 113,756 110,775 A55,55 0 0 1 0,775 L0,741.355 L1.718,741.359 L2.519,741.027 C48.026,721.783 79.981,676.638 80.030,624.000 L80.274,624 L80.274,487.2 L539.654,487.2 L539.654,486.954 L541.627,486.938 C610.628,485.816 664.5,446 666.219,408.283 L871.595,408.283 C871.595,458.092 860.683,505.344 841.126,547.765 L842,690 A44,44 0 0 1 754,690 L753.771,662.597 C696.611,711.005 622.907,740.376 542.379,740.958 L171.612,741.601 Z M206.960354,360 C216.301884,360 225.407266,361.014198 234.173036,362.938812 C201.280723,372.246418 177.174691,402.568236 177.174691,438.53772 C177.174691,456.916579 183.468222,473.820961 194.011438,487.200704 L80.274179,487.199154 L80.274179,487.07772 C80.274179,416.894633 136.993511,360 206.960354,360 Z"
        case .head:
            "M871.595,430 L871.595,359.878 C871.595,331.736 880.715,305.731 896.151,284.674 L1026.633,360.241 L1159.760,282.599 L884.096,53.186 C847.723,20.134 799.466,0 746.522,0 C636.899,0 547.375,86.318 541.814,194.891 C546.989,129.472 601.553,78 668.102,78 C713.639,78 753.564,102.099 775.893,138.277 C702.777,264.281 666.219,354.283 666.219,408.283 L666.219,430 Z"
        case .hindNear:
            "M0,775 L0.12,996 L59.94,996 L110,775 A55,55 0 0 0 0,775 Z"
        case .foreNear:
            "M754,690 L781.18,996 L841.12,995.88 L842,690 A44,44 0 0 0 754,690 Z"
        }
    }

    /// Pfad einmal geparst, in viewBox-Koordinaten.
    var path: Path { Self.cache[self] ?? Path() }

    private static let cache: [GoatPart: Path] = Dictionary(
        uniqueKeysWithValues: [GoatPart.hindFar, .foreFar, .body, .head, .hindNear, .foreNear]
            .map { ($0, SVGPathParser.path(from: $0.pathData)) }
    )
}

extension GoatPart: Hashable {}

/// Zeichnet einen Teil im Rahmen der Ziege; jeder Teil füllt den ganzen Rahmen,
/// damit `UnitPoint`-Anker für alle Teile dasselbe Koordinatensystem haben.
private struct GoatShape: Shape {
    let part: GoatPart

    func path(in rect: CGRect) -> Path {
        let box = GoatGeometry.viewBox
        let transform = CGAffineTransform(translationX: -box.minX, y: -box.minY)
            .concatenating(CGAffineTransform(scaleX: rect.width / box.width, y: rect.height / box.height))
        return part.path.applying(transform)
    }
}

// MARK: - Pfad-Parser (M, L, C, A, Z)

/// Liest die SVG-Befehle, die `Ziege rennt.svg` verwendet. Nur absolute Koordinaten.
private enum SVGPathParser {
    static func path(from data: String) -> Path {
        var path = Path()
        var tokens = tokenize(data)[...]
        var current = CGPoint.zero
        var start = CGPoint.zero
        var command: Character = "M"

        func number() -> CGFloat {
            guard let token = tokens.popFirst(), let value = Double(token) else { return 0 }
            return CGFloat(value)
        }
        func point() -> CGPoint {
            let x = number()
            return CGPoint(x: x, y: number())
        }

        while let token = tokens.first {
            if let letter = token.first, letter.isLetter {
                command = letter
                tokens.removeFirst()
            }
            switch command {
            case "M":
                current = point()
                start = current
                path.move(to: current)
                command = "L"   // weitere Paare nach M sind Linien
            case "L":
                current = point()
                path.addLine(to: current)
            case "C":
                let c1 = point(), c2 = point(), end = point()
                path.addCurve(to: end, control1: c1, control2: c2)
                current = end
            case "A":
                let rx = number(), ry = number()
                _ = number()    // Drehung der Achsen: im SVG immer 0
                let large = number() != 0, sweep = number() != 0
                let end = point()
                addArc(to: &path, from: current, to: end, rx: rx, ry: ry, large: large, sweep: sweep)
                current = end
            case "Z":
                path.closeSubpath()
                current = start
            default:
                return path
            }
        }
        return path
    }

    /// Trennt „M104,790 L163.5,996“ in Befehlsbuchstaben und Zahlen.
    private static func tokenize(_ data: String) -> [String] {
        var tokens: [String] = []
        var number = ""
        func flush() {
            if !number.isEmpty { tokens.append(number); number = "" }
        }
        for character in data {
            if character.isLetter {
                flush()
                tokens.append(String(character))
            } else if character == "," || character == " " {
                flush()
            } else if character == "-" {
                flush()
                number = "-"
            } else {
                number.append(character)
            }
        }
        flush()
        return tokens
    }

    /// Bogen (Endpunkt-Form, Achsen nicht gedreht) als Kubische Kurven, höchstens 90° je Stück.
    private static func addArc(
        to path: inout Path, from p1: CGPoint, to p2: CGPoint,
        rx rxIn: CGFloat, ry ryIn: CGFloat, large: Bool, sweep: Bool
    ) {
        var rx = abs(rxIn), ry = abs(ryIn)
        guard rx > 0, ry > 0, p1 != p2 else { path.addLine(to: p2); return }

        let dx = (p1.x - p2.x) / 2, dy = (p1.y - p2.y) / 2
        let lambda = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }

        let numerator = rx * rx * ry * ry - rx * rx * dy * dy - ry * ry * dx * dx
        let denominator = rx * rx * dy * dy + ry * ry * dx * dx
        let factor = (large == sweep ? -1 : 1) * max(0, numerator / denominator).squareRoot()
        let cxp = factor * rx * dy / ry
        let cyp = -factor * ry * dx / rx
        let cx = cxp + (p1.x + p2.x) / 2
        let cy = cyp + (p1.y + p2.y) / 2

        let theta1 = atan2((dy - cyp) / ry, (dx - cxp) / rx)
        let theta2 = atan2((-dy - cyp) / ry, (-dx - cxp) / rx)
        var delta = theta2 - theta1
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / CGFloat(segments)
        let k = 4.0 / 3.0 * tan(step / 4)
        var angle = theta1
        for _ in 0..<segments {
            let next = angle + step
            let c1 = CGPoint(x: cx + rx * (cos(angle) - k * sin(angle)), y: cy + ry * (sin(angle) + k * cos(angle)))
            let c2 = CGPoint(x: cx + rx * (cos(next) + k * sin(next)), y: cy + ry * (sin(next) - k * cos(next)))
            path.addCurve(to: CGPoint(x: cx + rx * cos(next), y: cy + ry * sin(next)), control1: c1, control2: c2)
            angle = next
        }
    }
}

// MARK: - Keyframes

/// CSS-Kurven aus dem Mockup (`ease-in`, `ease-out`, `ease-in-out`).
private enum GoatEase {
    case linear, easeIn, easeOut, easeInOut

    func value(at t: Double) -> Double {
        switch self {
        case .linear: t
        case .easeIn: Self.easeInCurve.value(at: t)
        case .easeOut: Self.easeOutCurve.value(at: t)
        case .easeInOut: Self.easeInOutCurve.value(at: t)
        }
    }

    private static let easeInCurve = UnitCurve.bezier(startControlPoint: .init(x: 0.42, y: 0), endControlPoint: .init(x: 1, y: 1))
    private static let easeOutCurve = UnitCurve.bezier(startControlPoint: .init(x: 0, y: 0), endControlPoint: .init(x: 0.58, y: 1))
    private static let easeInOutCurve = UnitCurve.bezier(startControlPoint: .init(x: 0.42, y: 0), endControlPoint: .init(x: 0.58, y: 1))
}

/// Keyframe bei Phase `at`; `ease` gilt für das Stück bis zum nächsten Keyframe (wie `animation-timing-function` in CSS).
private struct GoatKey {
    let at: Double
    let value: Double
    var ease: GoatEase = .linear
}

private func interpolate(_ keys: [GoatKey], phase p: Double) -> Double {
    guard var previous = keys.first else { return 0 }
    for key in keys.dropFirst() {
        if p <= key.at {
            let span = key.at - previous.at
            let t = span > 0 ? (p - previous.at) / span : 1
            return previous.value + (key.value - previous.value) * previous.ease.value(at: t)
        }
        previous = key
    }
    return previous.value
}

// MARK: - Bewegung

private enum GoatMotion {
    /// Dauer eines Sprungs in Sekunden.
    static let jump = 0.56
    static let legSquash = 0.84

    /// Winkel a → b → m (Grad) und Phasenversatz je Bein.
    struct Leg {
        let part: GoatPart
        let joint: UnitPoint
        let a: Double, b: Double, m: Double
        let offset: Double
    }

    static let hindFar = Leg(part: .hindFar, joint: GoatGeometry.anchor(142, 790), a: -36, b: 16, m: -14, offset: 0.4)
    static let foreFar = Leg(part: .foreFar, joint: GoatGeometry.anchor(628, 770), a: -42, b: 10, m: -22, offset: 0.9)
    static let hindNear = Leg(part: .hindNear, joint: GoatGeometry.anchor(55, 775), a: -26, b: 28, m: 2, offset: 0.5)
    static let foreNear = Leg(part: .foreNear, joint: GoatGeometry.anchor(798, 690), a: -32, b: 22, m: -8, offset: 0)

    static func phase(time: TimeInterval, offset: Double = 0) -> Double {
        (time / jump + offset).truncatingRemainder(dividingBy: 1)
    }

    static func legAngle(_ leg: Leg, phase p: Double) -> Double {
        interpolate([
            GoatKey(at: 0, value: leg.a),
            GoatKey(at: 0.55, value: leg.b, ease: .easeIn),
            GoatKey(at: 0.78, value: leg.m, ease: .easeOut),
            GoatKey(at: 1, value: leg.a),
        ], phase: p)
    }

    /// Das Bein wird beim Anziehen am Gelenk gestaucht.
    static func legScale(phase p: Double) -> Double {
        interpolate([
            GoatKey(at: 0, value: 1),
            GoatKey(at: 0.55, value: 1, ease: .easeIn),
            GoatKey(at: 0.78, value: legSquash, ease: .easeOut),
            GoatKey(at: 1, value: 1),
        ], phase: p)
    }

    static func headAngle(phase p: Double) -> Double {
        interpolate([
            GoatKey(at: 0, value: 0, ease: .easeInOut),
            GoatKey(at: 0.3, value: 4, ease: .easeInOut),
            GoatKey(at: 0.55, value: -1, ease: .easeInOut),
            GoatKey(at: 0.8, value: 2, ease: .easeInOut),
            GoatKey(at: 1, value: 0),
        ], phase: p)
    }

    /// Hub in viewBox-Einheiten (negativ = nach oben).
    static func bobLift(phase p: Double) -> Double {
        interpolate([
            GoatKey(at: 0, value: 0, ease: .easeInOut),
            GoatKey(at: 0.3, value: -24, ease: .easeInOut),
            GoatKey(at: 0.55, value: 0, ease: .easeInOut),
            GoatKey(at: 0.8, value: -8, ease: .easeInOut),
            GoatKey(at: 1, value: 0),
        ], phase: p)
    }

    static func bobAngle(phase p: Double) -> Double {
        interpolate([
            GoatKey(at: 0, value: 0, ease: .easeInOut),
            GoatKey(at: 0.3, value: -2, ease: .easeInOut),
            GoatKey(at: 0.55, value: 0.5, ease: .easeInOut),
            GoatKey(at: 0.8, value: 1.5, ease: .easeInOut),
            GoatKey(at: 1, value: 0),
        ], phase: p)
    }
}

// MARK: - Rennende Ziege

private struct GoatRunning: View {
    let size: CGFloat
    let time: TimeInterval

    /// Ab dieser Breite gibt es Boden und Staub.
    private static let groundMinimumWidth: CGFloat = 60

    var body: some View {
        let height = size * GoatGeometry.viewBox.height / GoatGeometry.viewBox.width
        let jump = GoatMotion.phase(time: time)

        ZStack {
            if size >= Self.groundMinimumWidth {
                GoatGround(scale: size / GoatGeometry.viewBox.width, phase: jump)
                GoatDust(scale: size / GoatGeometry.viewBox.width, time: time)
            }
            figure(jumpPhase: jump)
        }
        .frame(width: size, height: height)
    }

    /// Körper, Kopf und alle Beine wippen gemeinsam um die Körpermitte.
    private func figure(jumpPhase p: Double) -> some View {
        let unit = size / GoatGeometry.viewBox.width
        return ZStack {
            leg(GoatMotion.hindFar)
            leg(GoatMotion.foreFar)
            GoatShape(part: .body).fill(Color(.accent))
            GoatShape(part: .head)
                .fill(Color(.accent))
                .rotationEffect(.degrees(GoatMotion.headAngle(phase: p)), anchor: GoatGeometry.headJoint)
            leg(GoatMotion.hindNear)
            leg(GoatMotion.foreNear)
        }
        .rotationEffect(.degrees(GoatMotion.bobAngle(phase: p)), anchor: GoatGeometry.bodyCenter)
        .offset(y: GoatMotion.bobLift(phase: p) * unit)
    }

    private func leg(_ leg: GoatMotion.Leg) -> some View {
        let p = GoatMotion.phase(time: time, offset: leg.offset)
        return GoatShape(part: leg.part)
            .fill(Color(.accent))
            .scaleEffect(x: 1, y: GoatMotion.legScale(phase: p), anchor: leg.joint)
            .rotationEffect(.degrees(GoatMotion.legAngle(leg, phase: p)), anchor: leg.joint)
    }
}

/// Strichlinie bei y = 1018, läuft nach links; an den Enden ausgeblendet.
private struct GoatGround: View {
    let scale: CGFloat
    let phase: Double

    var body: some View {
        GoatGroundLine()
            .stroke(
                Color(.accent),
                style: StrokeStyle(
                    lineWidth: 14 * scale,
                    lineCap: .round,
                    dash: [70 * scale, 46 * scale],
                    dashPhase: 232 * scale * phase
                )
            )
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black.opacity(0.38), location: 0.22),
                        .init(color: .black.opacity(0.38), location: 0.78),
                        .init(color: .black.opacity(0), location: 1),
                    ],
                    startPoint: GoatGeometry.anchor(-60, 0),
                    endPoint: GoatGeometry.anchor(1220, 0)
                )
            }
    }
}

private struct GoatGroundLine: Shape {
    func path(in rect: CGRect) -> Path {
        let box = GoatGeometry.viewBox
        let sx = rect.width / box.width, sy = rect.height / box.height
        var path = Path()
        path.move(to: CGPoint(x: (-60 - box.minX) * sx, y: (1018 - box.minY) * sy))
        path.addLine(to: CGPoint(x: (1220 - box.minX) * sx, y: (1018 - box.minY) * sy))
        return path
    }
}

/// Drei Staubwolken am hinteren Huf, je ⅓ Takt versetzt.
private struct GoatDust: View {
    let scale: CGFloat
    let time: TimeInterval

    private static let period = GoatMotion.jump * 1.5
    private static let radii: [CGFloat] = [26, 20, 16]

    var body: some View {
        let box = GoatGeometry.viewBox
        Canvas { context, canvasSize in
            let sx = canvasSize.width / box.width
            for (index, radius) in Self.radii.enumerated() {
                let p = (time / Self.period + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                let travel = GoatEase.easeOut.value(at: p)
                let growth = 0.3 + (1.4 - 0.3) * travel
                // Deckkraft: 0 → 0,28 (bis 15 %), dann → 0; je Stück ease-out
                let opacity = p < 0.15
                    ? 0.28 * GoatEase.easeOut.value(at: p / 0.15)
                    : 0.28 * (1 - GoatEase.easeOut.value(at: (p - 0.15) / 0.85))
                let center = CGPoint(
                    x: (30 - 200 * travel - box.minX) * sx,
                    y: (990 - 46 * travel - box.minY) * sx
                )
                let r = radius * growth * sx
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                    with: .color(Color(.accent).opacity(opacity))
                )
            }
        }
        .frame(width: GoatGeometry.viewBox.width * scale, height: GoatGeometry.viewBox.height * scale)
    }
}

// MARK: - Bewegung reduziert

/// Ziege steht (Logo-Stellung), nur die Deckkraft pulsiert 1 → 0,45 in 1,2 s, hin und her.
private struct GoatReducedMotion: View {
    let size: CGFloat

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate / 1.2
            let wave = t.truncatingRemainder(dividingBy: 2)
            let progress = GoatEase.easeInOut.value(at: wave <= 1 ? wave : 2 - wave)

            ZStack {
                ForEach([GoatPart.hindFar, .foreFar, .body, .head, .hindNear, .foreNear], id: \.self) { part in
                    GoatShape(part: part).fill(Color(.accent))
                }
            }
            .compositingGroup()   // sonst werden Überlappungen an den Gelenken dunkler
            .opacity(1 - 0.55 * progress)
        }
    }
}

// MARK: - Previews

private struct GoatLoaderPreview: View {
    var body: some View {
        VStack(spacing: 24) {
            GoatLoader(size: 96)
            GoatLoader(size: 44)
            GoatLoader(size: 28)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.background))
    }
}

#Preview("Hell") {
    GoatLoaderPreview().preferredColorScheme(.light)
}

#Preview("Dunkel") {
    GoatLoaderPreview().preferredColorScheme(.dark)
}

#Preview("Bewegung reduzieren") {
    GoatLoaderPreview()
        .environment(\.goatLoaderForcesReducedMotion, true)
}
