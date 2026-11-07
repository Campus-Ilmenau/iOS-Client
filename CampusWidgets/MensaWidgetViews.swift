import SwiftUI
import WidgetKit

/// Die drei Größen des Widgets „Mensa heute“ (Maße für 390-pt-Geräte: 158 × 158, 338 × 158, 338 × 354).
enum MensaWidgetGroesse {
    case klein, mittel, gross

    init(_ family: WidgetFamily) {
        switch family {
        case .systemMedium: self = .mittel
        case .systemLarge, .systemExtraLarge: self = .gross
        default: self = .klein
        }
    }

    /// So viele Gerichte passen hinein.
    var gerichte: Int { self == .gross ? 3 : 2 }
}

/// Der Inhalt des Widgets „Mensa heute“ nach `WidgetMensa.dc.html`: Kopf wie die Jetzt-Karte auf Heute (randlos),
/// darunter Gerichte, bei „groß“ zusätzlich „Als Nächstes“. Die Regeln für Texte und Phasen stehen in
/// `MensaWidgetPhasen`; diese Ansicht zeichnet nur.
struct MensaWidgetView: View {
    let anzeige: MensaWidgetAnzeige
    let groesse: MensaWidgetGroesse

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
        .widgetURL(anzeige.kopfLink)
    }

    // MARK: Kopf

    private var kopf: some View {
        let kopf = VStack(alignment: .leading, spacing: 0) {
            Text(anzeige.kicker)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.33)
                .opacity(0.9)
                .lineLimit(1)
            Text(anzeige.titel)
                .font(.custom("PlusJakartaSans-ExtraBold", size: titelGroesse))
                .tracking(-0.02 * titelGroesse)
                .lineLimit(1)
                // Im kleinen Widget reicht der Platz knapp: lieber etwas kleiner als unter dem grünen Band.
                .minimumScaleFactor(groesse == .klein ? 0.85 : 1)
                .padding(.top, groesse == .gross ? 3 : 2)
                .padding(.trailing, groesse == .klein ? 6 : 0)
            if groesse == .gross {
                Text(anzeige.unterzeile)
                    .font(.system(size: 12.5))
                    .opacity(0.85)
                    .lineLimit(1)
                    .padding(.top, 1)
            }
        }
        .foregroundStyle(Color(.onBlue))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(kopfRand)
        .background {
            ZStack {
                Color(.blue)
                MensaWidgetBand(schmal: groesse == .klein).fill(Color(.green))
            }
        }
        .accessibilityElement(children: .combine)

        return Group {
            // Im kleinen Widget gibt es nur einen Link: das ganze Widget (`widgetURL`).
            if groesse == .klein {
                kopf
            } else {
                Link(destination: anzeige.kopfLink) { kopf }
            }
        }
    }

    private var titelGroesse: CGFloat {
        switch groesse {
        case .klein: 15
        case .mittel: 17
        case .gross: 21
        }
    }

    private var kopfRand: EdgeInsets {
        switch groesse {
        case .klein: EdgeInsets(top: 12, leading: 14, bottom: 10, trailing: 14)
        case .mittel: EdgeInsets(top: 10, leading: 16, bottom: 9, trailing: 16)
        case .gross: EdgeInsets(top: 14, leading: 16, bottom: 13, trailing: 16)
        }
    }

    // MARK: Gerichte

    private var zeilen: [MensaWidgetAnzeige.Zeile] {
        Array(anzeige.zeilen.prefix(groesse.gerichte))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(zeile.preis)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color(.textSecondary))
                    if let chip = zeile.chips.first { MensaWidgetChip(chip: chip, klein: true) }
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(.textPrimary))
                            .lineLimit(1)
                        if !zeile.chips.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(zeile.chips, id: \.self) { MensaWidgetChip(chip: $0, klein: false) }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Text(zeile.preis)
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color(.textPrimary))
                }
                .padding(.vertical, groesse == .gross ? 10 : 6)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Kein Plan

    private var leer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(groesse == .klein ? "Noch kein Plan" : "Der Speiseplan ist noch nicht da")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(.textPrimary))
            Text(leerText)
                .font(.system(size: 13))
                .foregroundStyle(Color(.textSecondary))
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var leerText: LocalizedStringKey {
        switch groesse {
        case .klein: "Tippen zum Laden"
        case .mittel: "Tippen, um ihn in der App zu laden."
        case .gross: "Tippen, um ihn in der App zu laden. Öffnungszeiten stehen trotzdem unten."
        }
    }

    // MARK: Als Nächstes

    private var naechstes: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(anzeige.termine.prefix(2).enumerated()), id: \.offset) { _, termin in
                HStack(spacing: 10) {
                    Text(termin.zeit)
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color(.textPrimary))
                        .frame(width: 44, alignment: .leading)
                    Circle().fill(Color(.brandOrange)).frame(width: 8, height: 8)
                    Text(termin.text)
                        .font(.system(size: 13))
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
struct MensaWidgetChip: View {
    let chip: WidgetChip
    let klein: Bool

    var body: some View {
        Text(chip.titel)
            .font(.system(size: klein ? 9.5 : 10.5, weight: .semibold))
            .foregroundStyle(vordergrund)
            .lineLimit(1)
            .padding(.horizontal, klein ? 6 : 7)
            .padding(.vertical, klein ? 0 : 1)
            .background(hintergrund, in: Capsule())
    }

    private var hintergrund: Color {
        switch chip.art {
        case .gruen: Color(.green)
        case .blau: Color(.blue)
        case .neutral: Color(.surfaceSecondary)
        }
    }

    private var vordergrund: Color {
        switch chip.art {
        case .gruen: Color(.onGreen)
        case .blau: Color(.onBlue)
        case .neutral: Color(.textSecondary)
        }
    }
}
