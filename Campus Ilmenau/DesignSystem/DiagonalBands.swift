import SwiftUI

/// Vieleck aus Punkten in Einheitskoordinaten (0…1), damit die Flächen mit der Größe mitwachsen.
struct UnitPolygon: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}

/// Kopfbereich mit zwei diagonalen Flächen (Blau vorne, Grün dahinter) und weichem Schatten an der Kante.
/// Inhalt liegt darüber, unten links ausgerichtet; Schrift auf Blau ist `onBlue`.
struct DiagonalBands<Content: View>: View {
    /// Die drei Anordnungen aus dem Mockup.
    enum Style {
        /// Gericht-Detail: zwei Bänder von links oben nach rechts unten auf `background`.
        case header
        /// Veranstaltung: blaue Fläche, grünes Band rechts, am Rand läuft es in `background` aus.
        /// Text gehört in die linke Hälfte (im Mockup rechts 140 pt Abstand), sonst liegt er auf Grün.
        case event
        /// „Heute“-Karte: blaue Fläche mit schmalem grünem Band rechts.
        case hero
    }

    /// Welche Ebenen gezeichnet werden. Nur `.header` kennt zwei Ebenen: Mit `.behind` (Hintergrund und grünes Band)
    /// und `.front` (blaues Band mit Schatten) lässt sich Inhalt zwischen die beiden legen, sodass er über dem
    /// Grünen liegt und genau an der blauen Schräge endet.
    enum Layer {
        case all
        case behind
        case front
    }

    private let style: Style
    private let layer: Layer
    private let height: CGFloat?
    private let content: Content

    init(_ style: Style = .header, layer: Layer = .all, height: CGFloat? = 250, @ViewBuilder content: () -> Content) {
        self.style = style
        self.layer = layer
        self.height = height
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            bands
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    @ViewBuilder
    private var bands: some View {
        switch style {
        case .header:
            ZStack {
                if layer != .front {
                    Color(.background)
                    band([(0, 0), (1, 0), (1, 0.46), (0, 1)], color: Color(.green))
                }
                if layer != .behind {
                    band([(0, 0), (1, 0), (1, 0.22), (0, 0.76)], color: Color(.blue), shadow: true)
                }
            }
        case .event:
            ZStack {
                Color(.blue)
                band([(0.58, 0), (1, 0), (1, 1), (0.30, 1)], color: Color(.green), shadow: true)
                band([(0.84, 0), (1, 0), (1, 1), (0.56, 1)], color: Color(.background))
            }
        case .hero:
            ZStack {
                Color(.blue)
                band([(0.78, 0), (1, 0), (1, 1), (0.62, 1)], color: Color(.green), shadow: true)
            }
        }
    }

    private func band(_ points: [(CGFloat, CGFloat)], color: Color, shadow: Bool = false) -> some View {
        UnitPolygon(points: points.map { CGPoint(x: $0.0, y: $0.1) })
            .fill(color)
            .shadow(color: shadow ? Color(.brandNight).opacity(0.25) : .clear, radius: 8, x: 0, y: 4)
    }
}

private struct DiagonalBandsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                DiagonalBands(.header, height: 250) {
                    Text("MENSA EHRENBERG · ESSEN 1 · HEUTE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(.onBlue))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 54)
                }

                DiagonalBands(.event, height: 270) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STUDI-CLUB")
                            .font(.caption.weight(.bold))
                        Text("Halloween-Party")
                            .display(size: 32, relativeTo: .largeTitle)
                    }
                    .foregroundStyle(Color(.onBlue))
                    .padding(.leading, 20)
                    .padding(.trailing, 140)
                    .padding(.bottom, 28)
                }

                DiagonalBands(.hero, height: 110) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("JETZT GEÖFFNET · BIS 14:00")
                            .font(.caption.weight(.bold))
                        Text("Mensa Ehrenberg")
                            .display(size: 24, relativeTo: .title)
                    }
                    .foregroundStyle(Color(.onBlue))
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.background))
    }
}

#Preview("DiagonalBands – Light") {
    DiagonalBandsPreview().preferredColorScheme(.light)
}

#Preview("DiagonalBands – Dark") {
    DiagonalBandsPreview().preferredColorScheme(.dark)
}
