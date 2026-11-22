import SwiftUI

/// Merkt, ob an der Zeile gerade gezogen wurde. Ein Tippen, das auf einen Zug folgt (auch einen zu kurzen für die
/// Aktion), soll die Zeile nicht auswählen oder öffnen.
@MainActor
final class WischMerker {
    private(set) var hatGezogen = false
    private var zuruecksetzen: Task<Void, Never>?

    func zug() {
        zuruecksetzen?.cancel()
        hatGezogen = true
    }

    /// Das Tippen nach dem Loslassen kommt im selben Moment; danach gilt die Zeile wieder als ruhig.
    func zugBeendet() {
        zuruecksetzen?.cancel()
        zuruecksetzen = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.hatGezogen = false
        }
    }
}

extension EnvironmentValues {
    @Entry var wischMerker: WischMerker?
}

extension View {
    /// Tippen innerhalb einer `WischZeile`: Nach einem Wisch passiert nichts. Außerhalb einer `WischZeile` ein normales Tippen.
    func wischTipp(_ aktion: @escaping () -> Void) -> some View {
        modifier(WischTipp(aktion: aktion))
    }
}

private struct WischTipp: ViewModifier {
    let aktion: () -> Void
    @Environment(\.wischMerker) private var merker

    func body(content: Content) -> some View {
        content.onTapGesture {
            guard merker?.hatGezogen != true else { return }
            aktion()
        }
    }
}

/// Eine Aktion hinter einer `WischZeile`: Fläche in der Höhe der Zeile, Symbol und Beschriftung in `onSwipe` (Weiß).
struct WischAktion {
    let titel: LocalizedStringKey
    let symbol: String
    /// Die Flächen `swipeDelete`, `swipeFound`, `swipeNeutral` (in Light und Dark gleich, ≥ 4,5 : 1 mit Weiß).
    let flaeche: Color
    let handler: () -> Void
}

/// Maße der Wischgeste (außerhalb von `WischZeile`: In generischen Typen gibt es keine statischen Konstanten).
private enum Maße {
    static let aktionsbreite: CGFloat = 100
    static let ausloeseSchwelle: CGFloat = 220
    static let hoechstzug: CGFloat = 320
}

/// Eine Zeile, die sich nach rechts und links wischen lässt. Hinter ihr erscheint die Fläche der Aktion, so hoch wie die
/// Zeile (wie „Verlängern“ in der Leihliste), nicht als runde Taste des Systems.
///
/// - Nach rechts wischen zeigt `links`, nach links wischen zeigt `rechts`.
/// - Ab 50 pt bleibt die Fläche offen (leichte Haptik), ab 220 pt löst Loslassen die Aktion aus (starke Haptik). Die
///   Aktion wird erst beim Loslassen ausgewertet: Wer über die Schwelle zieht und zurückschiebt, löst nichts aus.
/// - Tippen auf die Zeile schließt eine offene Fläche nur wieder.
/// - Für VoiceOver gibt es beide Aktionen als Aktionen der Zeile; die Flächen sind dort versteckt.
struct WischZeile<Inhalt: View>: View {
    var links: WischAktion?
    var rechts: WischAktion?
    /// Rundung der Zeile (die Fläche dahinter bekommt dieselbe), 0 bei Zeilen einer Liste.
    var eckenradius: CGFloat = 0
    @ViewBuilder var inhalt: Inhalt

    @State private var festerOffset: CGFloat = 0
    @State private var zug: CGFloat = 0
    @State private var istUeberAktionsbreite = false
    @State private var istUeberSchwelle = false
    @State private var merker = WischMerker()
    @State private var leichterImpuls = false
    @State private var starkerImpuls = false

    private var offset: CGFloat { begrenzt(festerOffset + zug) }

    var body: some View {
        ZStack {
            flaeche
                .opacity(offset == 0 ? 0 : 1)

            inhalt
                .accessibilityActions {
                    if let links { Button(links.titel, action: links.handler) }
                    if let rechts { Button(rechts.titel, action: rechts.handler) }
                }
                .overlay {
                    // Offen: Tippen schließt nur, die Zeile selbst reagiert nicht.
                    if festerOffset != 0 {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { schliessen() }
                            .accessibilityHidden(true)
                    }
                }
                .offset(x: offset)
                .gesture(wischgeste)
        }
        .environment(\.wischMerker, merker)
        .clipShape(RoundedRectangle(cornerRadius: eckenradius, style: .continuous))
        .sensoryFeedback(.impact(weight: .light), trigger: leichterImpuls)
        .sensoryFeedback(.impact(weight: .heavy), trigger: starkerImpuls)
    }

    // MARK: Fläche hinter der Zeile

    @ViewBuilder
    private var flaeche: some View {
        if offset > 0, let links {
            aktionsflaeche(links, ausrichtung: .leading)
        } else if offset < 0, let rechts {
            aktionsflaeche(rechts, ausrichtung: .trailing)
        }
    }

    private func aktionsflaeche(_ aktion: WischAktion, ausrichtung: Alignment) -> some View {
        Button {
            schliessen()
            aktion.handler()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: aktion.symbol)
                    .font(.title3)
                Text(aktion.titel)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color(.onSwipe))
            .padding(.horizontal, 4)
            .frame(width: Maße.aktionsbreite)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: ausrichtung)
        .background(aktion.flaeche)
        .accessibilityHidden(true)
    }

    // MARK: Geste

    /// Nach rechts nur mit `links`, nach links nur mit `rechts`.
    private func begrenzt(_ wert: CGFloat) -> CGFloat {
        min(max(wert, rechts == nil ? 0 : -Maße.hoechstzug), links == nil ? 0 : Maße.hoechstzug)
    }

    /// Eine UIKit-Pan-Geste statt `DragGesture`: Sie beginnt nur bei überwiegend waagerechter Bewegung. Ein `DragGesture`
    /// in einer Liste nahm auch senkrechte Züge an, die Liste ließ sich dann nicht mehr scrollen, wenn der Finger auf
    /// einer Zeile begann.
    private var wischgeste: some UIGestureRecognizerRepresentable {
        WaagerechterZug(
            aenderung: { verschiebung in
                guard links != nil || rechts != nil else { return }
                zug = verschiebung
                merker.zug()
                aktualisiereHaptik()
            },
            ende: { verschiebung, abgebrochen in
                let animation = Animation.spring(response: 0.3, dampingFraction: 0.8)
                merker.zugBeendet()
                guard !abgebrochen, links != nil || rechts != nil else {
                    withAnimation(animation) { zug = 0 }
                    istUeberAktionsbreite = false
                    istUeberSchwelle = false
                    return
                }

                let ziel = begrenzt(festerOffset + verschiebung)
                let ausloesen = abs(ziel) >= Maße.ausloeseSchwelle
                let offenHalten = abs(ziel) >= Maße.aktionsbreite / 2 && !ausloesen
                let aktion = ziel > 0 ? links : rechts

                withAnimation(animation) {
                    zug = 0
                    festerOffset = offenHalten ? (ziel > 0 ? Maße.aktionsbreite : -Maße.aktionsbreite) : 0
                }
                istUeberAktionsbreite = false
                istUeberSchwelle = false

                if ausloesen { aktion?.handler() }
            }
        )
    }

    private func aktualisiereHaptik() {
        let weit = abs(offset) >= Maße.aktionsbreite
        let sehrWeit = abs(offset) >= Maße.ausloeseSchwelle
        if weit != istUeberAktionsbreite {
            istUeberAktionsbreite = weit
            leichterImpuls.toggle()
        }
        if sehrWeit != istUeberSchwelle {
            istUeberSchwelle = sehrWeit
            starkerImpuls.toggle()
        }
    }

    private func schliessen() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { festerOffset = 0 }
    }
}

/// Waagerechter Zug: `gestureRecognizerShouldBegin` lässt die Geste nur zu, wenn die Bewegung überwiegend waagerecht ist.
/// Senkrechte Züge gehören der Liste (Scrollen).
private struct WaagerechterZug: UIGestureRecognizerRepresentable {
    /// Verschiebung in x seit Beginn des Zugs.
    let aenderung: (CGFloat) -> Void
    /// Verschiebung beim Loslassen; `abgebrochen`, wenn das System den Zug abgebrochen hat.
    let ende: (CGFloat, _ abgebrochen: Bool) -> Void

    final class Koordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let tempo = pan.velocity(in: pan.view)
            return abs(tempo.x) > abs(tempo.y)
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Koordinator { Koordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let verschiebung = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began, .changed: aenderung(verschiebung)
        case .ended: ende(verschiebung, false)
        case .cancelled, .failed: ende(0, true)
        default: break
        }
    }
}
