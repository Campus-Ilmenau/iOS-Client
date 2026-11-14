import SwiftUI

/// Das Raster der iPad-Ansichten: Ränder, Titelgröße, Textbreite und Spaltenanordnung. Entscheidend ist die **Breite, die
/// die Ansicht tatsächlich hat** (mit offener Seitenleiste, im Split View, im Stage-Manager-Fenster), nicht das Gerät:
///
/// | Breite der Ansicht | Anordnung |
/// |---|---|
/// | ab 900 pt | volle Anordnung (`.voll`) |
/// | 700 bis unter 900 pt | weiterhin zwei Spalten (`.zweiSpalten`) |
/// | unter 700 pt | die iPhone-Anordnung untereinander (`.untereinander`) |
///
/// Auf dem iPhone (auch quer) und überall unter 700 pt gelten die bisherigen Werte unverändert.
/// Werte nach `Uebergabe.md`, „iPad“ → „Raster auf dem iPad“.
struct PadRaster: Equatable {
    enum Anordnung: Equatable {
        case untereinander
        case zweiSpalten
        case voll
    }

    /// Ab dieser Breite stehen die Inhalte in zwei Spalten.
    static let zweiSpaltenAb: CGFloat = 700
    /// Ab dieser Breite gilt die volle Anordnung.
    static let vollAb: CGFloat = 900
    /// Fließtext ist höchstens so breit.
    static let textBreite: CGFloat = 680
    /// Abstand der Spalten und Verhältnis links : rechts bei „Heute“.
    static let spaltenAbstand: CGFloat = 24
    static let spaltenVerhaeltnis: CGFloat = 1.45
    /// Abstand der Hinweise nebeneinander.
    static let kartenAbstand: CGFloat = 16

    /// Breite der Ansicht in pt, 0 solange unbekannt.
    var breite: CGFloat = 0
    /// Nur ein iPad bekommt die iPad-Anordnung. Ein iPhone im Querformat bleibt bei der iPhone-Anordnung.
    var geraetIstPad = true

    var anordnung: Anordnung {
        guard geraetIstPad else { return .untereinander }
        if breite >= Self.vollAb { return .voll }
        if breite >= Self.zweiSpaltenAb { return .zweiSpalten }
        return .untereinander
    }

    /// Gilt die iPad-Anordnung (zwei Spalten oder mehr)?
    var istPad: Bool { anordnung != .untereinander }

    /// Bildschirmrand: 32 pt auf dem iPad, sonst 16 pt.
    var rand: CGFloat { istPad ? 32 : 16 }

    /// Größe des Seitentitels in Plus Jakarta Sans: 38 pt auf dem iPad, sonst der Wert des iPhones (`telefon`).
    func seitentitel(telefon: CGFloat) -> CGFloat { istPad ? 38 : telefon }

    /// Breite der linken Spalte bei zwei Spalten im Verhältnis 1,45 : 1 (nach Abzug der Ränder).
    var linkeSpalte: CGFloat {
        let nutz = max(0, breite - 2 * rand - Self.spaltenAbstand)
        return nutz * Self.spaltenVerhaeltnis / (Self.spaltenVerhaeltnis + 1)
    }
}

extension EnvironmentValues {
    /// Das Raster der umgebenden Ansicht (siehe `PadRasterMessung`).
    @Entry var padRaster = PadRaster()
}

/// Misst die Breite, die die Ansicht hat, und gibt das Raster an den Inhalt und per Umgebung an alles darunter.
/// Der `GeometryReader` kennt die Breite schon im ersten Durchlauf, die Ansicht springt also nicht von einer
/// Anordnung in die andere.
struct PadRasterMessung<Inhalt: View>: View {
    @ViewBuilder let inhalt: (PadRaster) -> Inhalt

    var body: some View {
        GeometryReader { proxy in
            let raster = PadRaster(breite: proxy.size.width, geraetIstPad: UIDevice.current.userInterfaceIdiom == .pad)
            inhalt(raster).environment(\.padRaster, raster)
        }
    }
}

/// Zwei Spalten im Verhältnis `verhaeltnis` : 1, oben ausgerichtet, so hoch wie die höhere.
struct VerhaeltnisSpalten: Layout {
    var verhaeltnis: CGFloat = PadRaster.spaltenVerhaeltnis
    var abstand: CGFloat = PadRaster.spaltenAbstand

    private func breiten(_ gesamt: CGFloat) -> (links: CGFloat, rechts: CGFloat) {
        let nutz = max(0, gesamt - abstand)
        let links = nutz * verhaeltnis / (verhaeltnis + 1)
        return (links, nutz - links)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let gesamt = proposal.width ?? 800
        let (links, rechts) = breiten(gesamt)
        let hoeheLinks = subviews[0].sizeThatFits(ProposedViewSize(width: links, height: nil)).height
        let hoeheRechts = subviews[1].sizeThatFits(ProposedViewSize(width: rechts, height: nil)).height
        return CGSize(width: gesamt, height: max(hoeheLinks, hoeheRechts))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let (links, rechts) = breiten(bounds.width)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: links, height: nil))
        subviews[1].place(at: CGPoint(x: bounds.minX + links + abstand, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: rechts, height: nil))
    }
}
