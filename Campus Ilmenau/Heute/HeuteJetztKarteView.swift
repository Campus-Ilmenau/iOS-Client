import SwiftUI

/// Die Jetzt-Karte: Kopf (Mensa: Blau mit grünem Band, Event: Nachtblau mit Abendsonne), Zeilen und Fußlink.
struct HeuteJetztKarteView: View {
    let karte: HeuteJetztKarte
    let onLink: (HeuteZiel) -> Void

    @Environment(\.dynamicTypeSize) private var schriftgroesse

    var body: some View {
        VStack(spacing: 0) {
            kopf
            ForEach(karte.zeilen) { zeile in
                trenner
                HeuteZeileView(zeile: zeile)
            }
            trenner
            Button { onLink(karte.ziel) } label: {
                Text(karte.linkText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.accent))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color(.surface))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var trenner: some View {
        Rectangle().fill(Color(.separator)).frame(height: 1)
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !karte.kicker.isEmpty {
                Text(karte.kicker)
                    .font(.system(size: 13, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .opacity(0.85)
                    // Oben beginnt das Band erst bei 78 % der Breite, der Kicker darf deshalb weiter nach rechts
                    .modifier(KopfTextbreite(anteil: 0.70, begrenzt: !schriftgroesse.isAccessibilitySize))
            }
            Text(karte.titel)
                .font(.display(size: 22, relativeTo: .title2))
                .tracking(-0.44)
                .padding(.top, 2)
                .modifier(KopfTextbreite(anteil: 0.58, begrenzt: !schriftgroesse.isAccessibilitySize))
            if !karte.unterzeile.isEmpty {
                Text(karte.unterzeile)
                    .font(.subheadline)
                    .opacity(0.85)
                    .modifier(KopfTextbreite(anteil: 0.58, begrenzt: !schriftgroesse.isAccessibilitySize))
            }
        }
        .foregroundStyle(Color(.onBlue))
        .padding(.leading, 18)
        .padding(.trailing, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { kopfFlaeche }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var kopfFlaeche: some View {
        switch karte.stil {
        case .mensa:
            // Bei sehr großer Schrift nimmt der Text die ganze Breite ein; dann entfällt das Band (Kontrast).
            if schriftgroesse.isAccessibilitySize {
                Color(.blue)
            } else {
                DiagonalBands(.hero, height: nil) { EmptyView() }
            }
        case .event:
            GeometryReader { geometrie in
                ZStack {
                    Color(.brandNight)
                    // Abendsonne: rechts unten angeschnitten, Mittelpunkt bei 92 % Breite und 120 % Höhe
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(.brandOrange), Color(.brandYellow)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 140, height: 140)
                        .position(x: geometrie.size.width * 0.92, y: geometrie.size.height * 1.2)
                }
            }
            .clipped()
        }
    }
}

/// Eine Zeile: Gericht (bis 2 Zeilen), Chips, rechts der Preis.
private struct HeuteZeileView: View {
    let zeile: HeuteZeile

    @Environment(\.dynamicTypeSize) private var schriftgroesse

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(zeile.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    // Zwei Zeilen; bei großer Schrift ohne Grenze, damit nichts abgeschnitten wird
                    .lineLimit(schriftgroesse.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)
                if !zeile.chips.isEmpty {
                    ChipFlowLayout(spacing: 5) {
                        ForEach(zeile.chips, id: \.self) { chip in
                            Chip(LocalizedStringKey(chip.title), variant: chip.variant)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let rechts = zeile.rechts {
                Text(rechts)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(.textPrimary))
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beschriftung)
    }

    private var beschriftung: String {
        ([zeile.name] + zeile.chips.map(\.title) + [zeile.rechts].compactMap { $0 }).joined(separator: ", ")
    }
}

extension HeuteJetztKarte {
    /// Beispielinhalt für die Platzhalter-Darstellung beim ersten Laden (`.redacted`).
    static let platzhalter = HeuteJetztKarte(
        ueberschrift: "Jetzt",
        kicker: "Jetzt geöffnet · bis 14:00",
        titel: "Mensa Ehrenberg",
        unterzeile: "Mittagsangebot",
        zeilen: (1...3).map {
            HeuteZeile(id: "platzhalter-\($0)", name: "Gericht des Tages mit Beilage", chips: [], rechts: "2,90 €")
        },
        linkText: "Ganzer Speiseplan",
        ziel: .alleEvents,
        mensaAendernSichtbar: true,
        stil: .mensa
    )
}

/// Hält den Kopftext links vom grünen Band bzw. von der Abendsonne (weißer Text auf Grün hätte zu wenig Kontrast).
/// Das Band beginnt unten bei 62 % der Kartenbreite; der Text endet knapp davor.
private struct KopfTextbreite: ViewModifier {
    /// Anteil der Kartenbreite, bis zu dem der Text reichen darf.
    let anteil: CGFloat
    let begrenzt: Bool

    func body(content: Content) -> some View {
        if begrenzt {
            // Container ist der ScrollView der Seite; die Karte ist 32 pt (2 × 16) schmaler.
            content.containerRelativeFrame(.horizontal, alignment: .leading) { breite, _ in
                max(120, (breite - 32) * anteil - 18)
            }
        } else {
            content
        }
    }
}
