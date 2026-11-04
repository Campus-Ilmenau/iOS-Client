import SwiftUI

/// Die Wand der Start-Animation mit der Ziege als Loch. Liegt als Overlay über der echten Startansicht.
///
/// `progress` (0…1 über `LaunchTimeline.duration`) ist animierbar, SwiftUI interpoliert ihn pro Bildschirmbild.
/// Die Ziege kommt als Vektor-Asset `GoatMask` (Goat Mask.pdf, Preserve Vector Data) und wird per
/// `.destinationOut` aus der Wand gestanzt.
struct LaunchWall: View, Animatable {
    var progress: Double

    @Environment(\.colorScheme) private var colorScheme

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let frame = LaunchFrame(progress: progress, size: size)
            let goat = context.resolve(Image(.goatMask))
            let goatRect = frame.maskRect
            let screen = Path(CGRect(origin: .zero, size: size))

            // Wand mit Loch
            context.drawLayer { layer in
                layer.fill(screen, with: wallShading(size: size, blend: frame.wallBlend))
                if colorScheme == .dark {
                    drawSun(in: &layer, frame: frame, size: size)
                }
                drawRings(in: &layer, frame: frame)
                layer.blendMode = .destinationOut
                layer.draw(goat, in: goatRect)
            }

            // Kantenlicht: weiche Zeichnung der Lochkante nach innen
            if frame.edgeOpacity > 0.001 {
                var edgeContext = context
                edgeContext.opacity = frame.edgeOpacity
                edgeContext.drawLayer { rim in
                    // Wand weichzeichnen, dann mit der Lochfläche beschneiden: bleibt ein Saum innen an der Kante.
                    rim.drawLayer { blurredWall in
                        blurredWall.addFilter(.blur(radius: LaunchTimeline.edgeBlur))
                        blurredWall.drawLayer { wall in
                            wall.fill(Path(CGRect(origin: .zero, size: size).insetBy(dx: -60, dy: -60)), with: .color(.black))
                            wall.blendMode = .destinationOut
                            wall.draw(goat, in: goatRect)
                        }
                    }
                    rim.blendMode = .sourceIn
                    rim.fill(screen, with: .color(Color(.launchEdge)))
                    rim.blendMode = .destinationIn
                    rim.draw(goat, in: goatRect)
                }
            }

            // Ziegenfüllung des ersten Frames, blendet aus: die Ziege wird zum Loch
            if frame.coverOpacity > 0.001 {
                var coverContext = context
                coverContext.opacity = frame.coverOpacity
                coverContext.drawLayer { cover in
                    cover.draw(goat, in: goatRect)
                    cover.blendMode = .sourceIn
                    cover.fill(screen, with: .color(Color(.launchGoatFill)))
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Hell: Diagonale von links oben nach rechts unten. Dunkel: vertikal.
    /// In der Haltephase geht die Vollfarbe des statischen Launch Screens in den Verlauf über.
    private func wallShading(size: CGSize, blend: Double) -> GraphicsContext.Shading {
        let solid = Color(.launchWall)
        let start = Color(.launchWallStart).mix(with: solid, by: 1 - blend)
        let end = Color(.launchWallEnd).mix(with: solid, by: 1 - blend)
        let endPoint = colorScheme == .dark
            ? CGPoint(x: 0, y: size.height)
            : CGPoint(x: size.width, y: size.height)
        return .linearGradient(Gradient(colors: [start, end]), startPoint: .zero, endPoint: endPoint)
    }

    /// Abendsonne hinter der Ziege, Horizont an den Hufen. Gehört zur Wand und wird mit ausgestanzt.
    private func drawSun(in layer: inout GraphicsContext, frame: LaunchFrame, size: CGSize) {
        let k = frame.unit * frame.scale
        let origin = frame.maskOrigin
        let center = CGPoint(
            x: origin.x + LaunchTimeline.sunCenter.x * k,
            y: origin.y + LaunchTimeline.sunCenter.y * k
        )
        let radius = LaunchTimeline.sunRadius * k
        layer.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .linearGradient(
                Gradient(colors: [Color(.brandOrange), Color(.brandYellow)]),
                startPoint: CGPoint(x: center.x, y: center.y - radius),
                endPoint: CGPoint(x: center.x, y: center.y + radius)
            )
        )
        let horizonY = origin.y + LaunchTimeline.sunHorizon * k
        layer.fill(
            Path(CGRect(x: -1, y: horizonY, width: size.width + 2, height: max(0, size.height - horizonY + 1))),
            with: .color(Color(.launchWallStart))
        )
    }

    /// Zwei Ringe um den Anker, wachsen langsamer als das Loch (Parallaxe).
    private func drawRings(in layer: inout GraphicsContext, frame: LaunchFrame) {
        let colors = [Color(.launchRingInner), Color(.launchRingOuter)]
        for (radiusUnits, color) in zip(LaunchTimeline.ringRadii, colors) {
            let radius = radiusUnits * frame.unit * frame.ringScale
            layer.stroke(
                Path(ellipseIn: CGRect(
                    x: frame.center.x - radius,
                    y: frame.center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .color(color.opacity(frame.wallBlend)),
                lineWidth: LaunchTimeline.ringLineWidth
            )
        }
    }
}
