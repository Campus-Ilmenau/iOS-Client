import SwiftUI
import WidgetKit
import AppIntents

/// Die drei Größen der Widgets (Maße für 390-pt-Geräte: 158 × 158, 338 × 158, 338 × 354).
enum WidgetGroesse {
    case klein, mittel, gross

    init(_ family: WidgetFamily) {
        switch family {
        case .systemMedium: self = .mittel
        case .systemLarge, .systemExtraLarge: self = .gross
        default: self = .klein
        }
    }

    /// So viele Gerichte passen bei normaler Schrift hinein; bei großer Schrift eins weniger statt abgeschnittener Zeilen.
    func gerichte(grosseSchrift: Bool) -> Int {
        let normal = self == .gross ? 3 : 2
        return grosseSchrift ? normal - 1 : normal
    }
}

/// Der Inhalt des Widgets „Mensa heute“ nach `WidgetMensa.dc.html`: Kopf wie die Jetzt-Karte auf Heute (randlos),
/// darunter Gerichte, bei „groß“ zusätzlich „Als Nächstes“. Die Regeln für Texte und Phasen stehen in
/// `MensaWidgetPhasen`; diese Ansicht zeichnet nur.
///
/// Die Schrift folgt Dynamic Type bis `xLarge`. Darüber würde das feste Layout der Widgets überlaufen.
struct MensaWidgetView: View {
    let anzeige: MensaWidgetAnzeige
    let groesse: WidgetGroesse
    /// Knopf und Punkte im mittleren Widget; `nil` bei fester Mensa und in den anderen Größen.
    var wechsel: MensaWechsel?
    /// „Getönt / Klar“ (iOS 18): keine Bänder und Chip-Flächen, Chips als umrandeter Text.
    var getoent = false

    var body: some View {
        MensaWidgetInhalt(anzeige: anzeige, groesse: groesse, wechsel: wechsel, getoent: getoent)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .widgetURL(anzeige.kopfLink)
    }
}

private struct MensaWidgetInhalt: View {
    let anzeige: MensaWidgetAnzeige
    let groesse: WidgetGroesse
    let wechsel: MensaWechsel?
    let getoent: Bool

    @Environment(\.dynamicTypeSize) private var schriftgroesse

    // Die Größen aus dem Artboard (in pt) wachsen mit Dynamic Type, alle mit demselben Faktor, damit ihr Verhältnis
    // zueinander bleibt. Basis 100: `ScaledMetric` rundet auf ganze Zahlen, ein Wert von 1 würde nie größer.
    @ScaledMetric(relativeTo: .body) private var skala100: CGFloat = 100
    private var skala: CGFloat { skala100 / 100 }
    private var skalaKicker: CGFloat { skala }
    private var skalaTitel: CGFloat { skala }
    private var skalaUnterzeile: CGFloat { skala }
    private var skalaGericht: CGFloat { skala }
    private var skalaDetail: CGFloat { skala }

    /// Ab `xLarge` (dem gedeckelten Höchstwert) ist die Schrift groß genug, dass ein Gericht weniger gezeigt wird.
    private var grosseSchrift: Bool { schriftgroesse >= .xLarge }

    var body: some View {
        VStack(spacing: 0) {
            kopf
            inhalt
            if groesse == .gross {
                Spacer(minLength: 0)
                naechstes
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Kopf

    private var kopf: some View {
        ZStack(alignment: .trailing) {
            kopfLink
            if let wechsel, groesse == .mittel { wechselBedienung(wechsel) }
        }
    }

    @ViewBuilder
    private var kopfLink: some View {
        // Im kleinen Widget gibt es nur einen Link: das ganze Widget (`widgetURL`).
        if groesse == .klein {
            kopfInhalt
        } else {
            Link(destination: anzeige.kopfLink) { kopfInhalt }
        }
    }

    private var kopfInhalt: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(anzeige.kicker)
                .font(.system(size: 11 * skalaKicker, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.03 * 11 * skalaKicker)
                .opacity(0.9)
                .lineLimit(1)
                .minimumScaleFactor(groesse == .klein ? 0.7 : 1)
                .padding(.trailing, kopfTextRand(kicker: true))
            HStack(spacing: 5) {
                Text(anzeige.titel)
                    .font(.custom("PlusJakartaSans-ExtraBold", size: titelGroesse * skalaTitel))
                    .tracking(-0.02 * titelGroesse * skalaTitel)
                    .lineLimit(1)
                    .minimumScaleFactor(groesse == .klein ? 0.7 : 1)
                // Filter der App ist angewendet.
                if anzeige.filterung != nil {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 13 * skalaTitel, weight: .semibold))
                        .opacity(0.85)
                        .accessibilityLabel("Gefiltert")
                }
            }
            .padding(.top, groesse == .gross ? 3 : 2)
            .padding(.trailing, kopfTextRand(kicker: false))
            if groesse == .gross {
                Text(anzeige.unterzeile)
                    .font(.system(size: 12.5 * skalaUnterzeile))
                    .opacity(0.85)
                    .lineLimit(1)
                    .padding(.top, 1)
            }
        }
        .foregroundStyle(getoent ? Color(.textPrimary) : Color(.onBlue))
        .widgetAccentable()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(kopfRand)
        // Rechts bleibt Platz für Punkte und Knopf.
        .padding(.trailing, wechsel != nil && groesse == .mittel ? 80 : 0)
        .background {
            if !getoent {
                ZStack {
                    Color(.blue)
                    MensaWidgetBand(schmal: groesse == .klein).fill(Color(.green))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Im kleinen Widget endet der Text links der grünen Schräge, denn Weiß auf Grün hätte zu wenig Kontrast.
    /// Die Schräge liegt oben weiter rechts, der Kicker darf also etwas weiter reichen als der Titel.
    private func kopfTextRand(kicker: Bool) -> CGFloat {
        guard groesse == .klein, !getoent else { return 0 }
        return kicker ? 20 : 24
    }

    private var titelGroesse: CGFloat {
        switch groesse {
        case .klein: 15
        case .mittel: 17
        case .gross: 21
        }
    }

    private var kopfRand: EdgeInsets {
        let unten: CGFloat = getoent ? 4 : 0
        switch groesse {
        case .klein: return EdgeInsets(top: 12, leading: 14, bottom: unten == 0 ? 10 : unten, trailing: 14)
        case .mittel: return EdgeInsets(top: 10, leading: 16, bottom: unten == 0 ? 9 : unten, trailing: 16)
        case .gross: return EdgeInsets(top: 14, leading: 16, bottom: unten == 0 ? 13 : unten, trailing: 16)
        }
    }

    // MARK: Wechsel-Knopf

    /// Vier Punkte (die gezeigte Mensa ist weiß) und der Knopf: ⇄, 44 pt Tippfläche, 32 pt Kreis.
    private func wechselBedienung(_ wechsel: MensaWechsel) -> some View {
        HStack(spacing: 2) {
            HStack(spacing: 4) {
                ForEach(0..<wechsel.anzahl, id: \.self) { index in
                    Circle()
                        .fill(index == wechsel.aktuell ? punktAn : punktAus)
                        .frame(width: 5, height: 5)
                }
            }
            .accessibilityHidden(true)

            Button(intent: MensaWechselnIntent()) {
                ZStack {
                    Circle().fill(knopfKreis).frame(width: 32, height: 32)
                    Image(systemName: "arrow.right.arrow.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(getoent ? Color(.textPrimary) : Color(.onBlue))
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .widgetAccentable()
            .accessibilityLabel("Mensa wechseln, als Nächstes \(wechsel.naechsterName)")
        }
        .padding(.trailing, 12)
    }

    private var punktAn: Color { getoent ? Color(.textPrimary) : Color(.onBlue) }
    private var punktAus: Color { (getoent ? Color(.textPrimary) : Color(.onBlue)).opacity(getoent ? 0.3 : 0.45) }
    private var knopfKreis: Color { (getoent ? Color(.textPrimary) : Color(.onBlue)).opacity(getoent ? 0.14 : 0.2) }

    // MARK: Gerichte

    private var zeilen: [MensaWidgetAnzeige.Zeile] {
        Array(anzeige.zeilen.prefix(groesse.gerichte(grosseSchrift: grosseSchrift)))
    }

    @ViewBuilder
    private var inhalt: some View {
        if zeilen.isEmpty {
            leer
        } else {
            VStack(spacing: 0) {
                ForEach(Array(zeilen.enumerated()), id: \.element.id) { index, zeile in
                    if index > 0 { Rectangle().fill(Color(.separator)).frame(height: 1) }
                    self.zeile(zeile)
                }
            }
            .padding(.horizontal, groesse == .klein ? 14 : 16)
            .padding(.top, groesse == .klein ? 6 : 2)
        }
    }

    @ViewBuilder
    private func zeile(_ zeile: MensaWidgetAnzeige.Zeile) -> some View {
        switch groesse {
        case .klein:
            // Name, darunter Preis und höchstens ein Chip. Tippen öffnet den Speiseplan (ganzes Widget).
            VStack(alignment: .leading, spacing: 2) {
                Text(zeile.name)
                    .font(.system(size: 13 * skalaDetail, weight: .semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(zeile.preis)
                        .font(.system(size: 12 * skalaUnterzeile, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color(.textSecondary))
                    if let chip = zeile.chips.first { MensaWidgetChip(chip: chip, klein: true, getoent: getoent, skala: skalaKicker) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .accessibilityElement(children: .combine)
        case .mittel, .gross:
            Link(destination: zeile.link) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(zeile.name)
                            .font(.system(size: 14 * skalaGericht, weight: .semibold))
                            .foregroundStyle(Color(.textPrimary))
                            .lineLimit(1)
                        if !zeile.chips.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(zeile.chips, id: \.self) {
                                    MensaWidgetChip(chip: $0, klein: false, getoent: getoent, skala: skalaKicker)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Text(zeile.preis)
                        .font(.system(size: 14 * skalaGericht, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color(.textPrimary))
                }
                .padding(.vertical, groesse == .gross ? 10 : 6)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Kein Plan, nichts passt

    private var leer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(leerTitel)
                .font(.system(size: 14 * skalaGericht, weight: .bold))
                .foregroundStyle(Color(.textPrimary))
            Text(leerText)
                .font(.system(size: 13 * skalaDetail))
                .foregroundStyle(Color(.textSecondary))
                .lineLimit(groesse == .klein ? 4 : nil)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var leerTitel: LocalizedStringKey {
        if anzeige.nichtsPasst { return groesse == .klein ? "Nichts passt" : "Nichts passt zu deinem Filter" }
        return groesse == .klein ? "Noch kein Plan" : "Der Speiseplan ist noch nicht da"
    }

    private var leerText: LocalizedStringKey {
        // Alle Gerichte stehen im Speiseplan: Tippen öffnet ihn (Kopf-Link, im kleinen Widget das ganze Widget).
        if let filterung = anzeige.filterung, anzeige.nichtsPasst {
            let text = "\(filterung.kurztext) · \(filterung.ohneFilterText)"
            switch groesse {
            case .klein: return "\(filterung.kurztext)"
            case .mittel: return "\(text)"
            case .gross: return "\(text). Tippen zeigt alle im Speiseplan."
            }
        }
        switch groesse {
        case .klein: return "Tippen zum Laden"
        case .mittel: return "Tippen, um ihn in der App zu laden."
        case .gross: return "Tippen, um ihn in der App zu laden. Öffnungszeiten stehen trotzdem unten."
        }
    }

    // MARK: Als Nächstes

    private var naechstes: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(anzeige.termine.prefix(2).enumerated()), id: \.offset) { _, termin in
                HStack(spacing: 10) {
                    Text(termin.zeit)
                        .font(.system(size: 13 * skalaDetail, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color(.textPrimary))
                        .widgetAccentable()
                        .frame(width: 44, alignment: .leading)
                    Circle().fill(Color(.brandOrange)).frame(width: 8, height: 8).widgetAccentable()
                    Text(termin.text)
                        .font(.system(size: 13 * skalaDetail))
                        .foregroundStyle(Color(.textSecondary))
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        .overlay(alignment: .top) { Rectangle().fill(Color(.separator)).frame(height: 1) }
    }
}

// MARK: - Bausteine

/// Das schmale grüne Band rechts im Kopf, wie in der Jetzt-Karte auf Heute (Diagonale).
struct MensaWidgetBand: Shape {
    let schmal: Bool

    func path(in rect: CGRect) -> Path {
        let oben = schmal ? 0.86 : 0.80
        let unten = schmal ? 0.74 : 0.66
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + oben * rect.width, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + unten * rect.width, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Kapsel für „Vegan“, „Vegetarisch“, „Regional“ …; Grün und Blau sind Flächen mit eigener Schriftfarbe.
/// Getönt gibt es keine Flächen: Der Chip ist dann Text mit dünnem Rand.
struct MensaWidgetChip: View {
    let chip: WidgetChip
    let klein: Bool
    var getoent = false
    /// Faktor aus Dynamic Type.
    var skala: CGFloat = 1

    var body: some View {
        Text(chip.titel)
            .font(.system(size: (klein ? 9.5 : 10.5) * skala, weight: .semibold))
            .foregroundStyle(vordergrund)
            .lineLimit(1)
            .padding(.horizontal, klein ? 6 : 7)
            .padding(.vertical, klein ? 0 : 1)
            .background { if !getoent { Capsule().fill(hintergrund) } }
            .overlay { if getoent { Capsule().strokeBorder(Color(.textSecondary).opacity(0.4), lineWidth: 1) } }
    }

    private var hintergrund: Color {
        switch chip.art {
        case .gruen: Color(.green)
        case .blau: Color(.blue)
        case .neutral: Color(.surfaceSecondary)
        }
    }

    private var vordergrund: Color {
        if getoent { return Color(.textSecondary) }
        switch chip.art {
        case .gruen: return Color(.onGreen)
        case .blau: return Color(.onBlue)
        case .neutral: return Color(.textSecondary)
        }
    }
}
