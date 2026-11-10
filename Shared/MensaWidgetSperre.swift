import SwiftUI
import WidgetKit

/// „Mensa heute“ auf dem Sperrbildschirm: Zeile über der Uhr, Rechteck und Kreis. Das System färbt einfarbig, darum
/// gibt es keine eigenen Farben, nur Gewichte und Deckkraft. Die Gabel (`fork.knife`) und die Uhrzeiten sind
/// `.widgetAccentable()`. Dynamic Type übernimmt das System; Text schrumpft zuerst und kürzt dann mit „…“.
struct MensaWidgetSperre: View {
    let sperre: MensaSperreAnzeige
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            MensaSperreZeile(text: sperre.zeile)
                .widgetURL(sperre.speiseplanLink)
        case .accessoryRectangular:
            MensaSperreRechteck(sperre: sperre)
                .widgetURL(sperre.rechteckLink)
        default:
            MensaSperreKreis(sperre: sperre)
                .widgetURL(sperre.speiseplanLink)
        }
    }
}

/// Gabel und „bis 14:00 · Linsen-Dal mit Basmatireis“.
private struct MensaSperreZeile: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } icon: {
            Image(systemName: "fork.knife")
                .widgetAccentable()
        }
    }
}

/// Kicker mit Gabel („EHRENBERG · BIS 14:00“, ggf. Filter-Symbol), Gericht in höchstens zwei Zeilen, darunter
/// Preis links und „1/3“ rechts.
private struct MensaSperreRechteck: View {
    let sperre: MensaSperreAnzeige

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            kicker
            Text(sperre.gericht?.name ?? sperre.leerTitel)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(2)
                // Zwei Zeilen Platz, auch wenn das System nur wenig Höhe anbietet.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(sperre.gericht?.preis ?? sperre.leerDetail)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(sperre.positionText)
                    .accessibilityLabel(sperre.anzahl > 1 ? "Gericht \(sperre.position) von \(sperre.anzahl)" : "")
            }
            .font(.system(size: 12))
            .monospacedDigit()
            .opacity(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var kicker: some View {
        HStack(spacing: 4) {
            Image(systemName: "fork.knife")
                .font(.system(size: 10, weight: .bold))
                .widgetAccentable()
            Text(sperre.kicker)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.22)
                .opacity(0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if sperre.filterung != nil {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(0.7)
                    .accessibilityLabel("Gefiltert")
            }
        }
    }
}

/// Gabel, Uhrzeit und ein kurzes Wort („14:00 bis“, „16:30 Abend“, „15:00 Nanoteria“). Rotiert nicht.
private struct MensaSperreKreis: View {
    let sperre: MensaSperreAnzeige

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "fork.knife")
                .font(.system(size: 14, weight: .semibold))
                .widgetAccentable()
            Text(sperre.kreisGross)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            if !sperre.kreisKlein.isEmpty {
                Text(sperre.kreisKlein)
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sperre.kreisBeschriftung)
    }
}
