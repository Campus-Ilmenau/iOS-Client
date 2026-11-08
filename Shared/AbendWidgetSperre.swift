import SwiftUI
import WidgetKit

/// „Heute Abend“ auf dem Sperrbildschirm: Zeile über der Uhr, Rechteck und Kreis. Das System färbt einfarbig,
/// darum gibt es hier keine eigenen Farben, nur Gewichte und Deckkraft. Der Mond und die Uhrzeiten sind
/// `.widgetAccentable()`. Dynamic Type übernimmt das System; Text läuft einzeilig, schrumpft zuerst und kürzt mit „…“.
struct AbendWidgetSperre: View {
    let sperre: AbendWidgetAnzeige.Sperrbildschirm
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            AbendSperreZeile(text: sperre.zeile)
                .widgetURL(sperre.link)
        case .accessoryRectangular:
            AbendSperreRechteck(rechteck: sperre.rechteck)
                .widgetURL(sperre.link)
        default:
            AbendSperreKreis(kreis: sperre.kreis)
                .widgetURL(sperre.kreisLink)
        }
    }
}

/// Mond und „19:00 Spieleabend · Studi-Club“.
private struct AbendSperreZeile: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } icon: {
            Image(systemName: "moon.fill")
                .widgetAccentable()
        }
    }
}

/// Kicker mit Mond, Titel mit Uhrzeit (15 Bold), darunter Ort und „dann …“.
private struct AbendSperreRechteck: View {
    let rechteck: AbendWidgetAnzeige.Sperrbildschirm.Rechteck

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 10))
                    .widgetAccentable()
                Text(rechteck.kicker)
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.33)
                    .opacity(0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 3) {
                titel
                if rechteck.gemerkt {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .widgetAccentable()
                        .accessibilityLabel("gemerkt")
                }
            }
            if !rechteck.unterzeile.isEmpty {
                Text(rechteck.unterzeile)
                    .font(.system(size: 13))
                    .opacity(0.75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Die Uhrzeit ist hervorgehoben (`widgetAccentable`), der Titel danach nur fett; Abgesagtes ist durchgestrichen.
    /// Passt der Titel nicht, wird er stufenweise kleiner (15, 13, 11 pt) und erst dann mit „…“ gekürzt. Zeit und Name
    /// schrumpfen dabei zusammen, was ein einzelnes `minimumScaleFactor` nicht leistet.
    private var titel: some View {
        ViewThatFits(in: .horizontal) {
            titelZeile(groesse: 15)
            titelZeile(groesse: 13)
            titelZeile(groesse: 11).lineLimit(1)
        }
    }

    private func titelZeile(groesse: CGFloat) -> some View {
        HStack(spacing: 4) {
            if let zeit = rechteck.zeit {
                Text(zeit)
                    .monospacedDigit()
                    .widgetAccentable()
            }
            Text(rechteck.name)
        }
        .font(.system(size: groesse, weight: .bold))
        .strikethrough(rechteck.abgesagt)
        .opacity(rechteck.abgesagt ? 0.7 : 1)
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Beginn der nächsten und „+2“; ohne Veranstaltung nur der Mond.
private struct AbendSperreKreis: View {
    let kreis: AbendWidgetAnzeige.Sperrbildschirm.Kreis

    var body: some View {
        Group {
            if kreis.gross.isEmpty {
                Image(systemName: "moon.fill")
                    .font(.system(size: 22))
                    .widgetAccentable()
            } else {
                VStack(spacing: 0) {
                    Text(kreis.gross)
                        .font(.system(size: 17, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                    if !kreis.klein.isEmpty {
                        Text(kreis.klein)
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0.75)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kreis.beschriftung)
    }
}
