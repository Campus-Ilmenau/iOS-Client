import SwiftUI
import WidgetKit

/// Der Inhalt des Widgets „Heute Abend“ nach `WidgetEvents.dc.html`: klein immer nachtblau mit großer Uhrzeit,
/// mittel und groß als Liste mit Kopf. Keine Bilder, keine Logos. Texte und Regeln stehen in `AbendWidgetPhasen`.
///
/// Die Schrift folgt Dynamic Type bis `xLarge`; bei großer Schrift steht lieber eine Zeile weniger da als
/// abgeschnittener Text.
struct AbendWidgetView: View {
    let anzeige: AbendWidgetAnzeige
    let groesse: WidgetGroesse
    /// „Getönt / Klar“ (iOS 18): keine Nachtfläche und keine Chip-Flächen.
    var getoent = false

    var body: some View {
        Group {
            if groesse == .klein {
                // Immer nachtblau: Alle Farben nehmen ihre Dunkel-Werte.
                AbendWidgetKlein(klein: anzeige.klein, getoent: getoent)
                    .environment(\.colorScheme, .dark)
                    .widgetURL(anzeige.klein.link)
            } else {
                AbendWidgetListe(anzeige: anzeige, groesse: groesse, getoent: getoent)
                    .widgetURL(anzeige.kopfLink)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

// MARK: - Klein

private struct AbendWidgetKlein: View {
    let klein: AbendWidgetAnzeige.Klein
    let getoent: Bool

    @Environment(\.dynamicTypeSize) private var schriftgroesse
    // Ein Faktor für alle Texte, damit die Größen zueinander so bleiben wie im Artboard (Titel größer als Ort).
    // Basis 100: `ScaledMetric` rundet auf ganze Zahlen, ein Wert von 1 würde nie größer.
    @ScaledMetric(relativeTo: .body) private var skala100: CGFloat = 100
    private var skala: CGFloat { skala100 / 100 }
    private var skalaKicker: CGFloat { skala }
    private var skalaZeit: CGFloat { skala }
    private var skalaTitel: CGFloat { skala }
    private var skalaOrt: CGFloat { skala }

    private var grosseSchrift: Bool { schriftgroesse >= .xLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            kicker
            if klein.hatEvent { event } else { leer }
            Spacer(minLength: 0)
            if klein.hatEvent, !klein.fuss.isEmpty {
                Text(klein.fuss)
                    .font(.system(size: 11.5 * skalaKicker, weight: .semibold))
                    .opacity(0.75)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Color(.textPrimary))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private var kicker: some View {
        HStack(spacing: 5) {
            Image(systemName: "moon.fill")
                .font(.system(size: 12 * skalaKicker))
                .foregroundStyle(Color(.accent))
                .widgetAccentable()
            Text(klein.kicker)
                .font(.system(size: 11 * skalaKicker, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.03 * 11 * skalaKicker)
                .opacity(0.9)
                .lineLimit(1)
                .widgetAccentable()
        }
    }

    private var event: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if klein.laeuft {
                    Text("bis")
                        .font(.system(size: 15 * skalaZeit, weight: .bold))
                        .opacity(0.8)
                }
                Text(klein.zeit ?? "")
                    .font(.custom("PlusJakartaSans-ExtraBold", size: 30 * skalaZeit))
                    .tracking(-0.02 * 30 * skalaZeit)
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .widgetAccentable()
            .padding(.top, 10)

            Text(klein.titel)
                .font(.system(size: 14 * skalaTitel, weight: .semibold))
                .lineLimit(grosseSchrift ? 1 : 2)
                .padding(.top, 6)
            if !klein.ort.isEmpty {
                Text(klein.ort)
                    .font(.system(size: 12 * skalaOrt))
                    .opacity(0.7)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
    }

    private var leer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nichts eingetragen")
                .font(.system(size: 14 * skalaTitel, weight: .bold))
            Text(klein.leerText)
                .font(.system(size: 12 * skalaOrt))
                .opacity(0.7)
                .lineLimit(grosseSchrift ? 2 : 3)
        }
        .padding(.top, 12)
    }
}

// MARK: - Mittel und groß

private struct AbendWidgetListe: View {
    let anzeige: AbendWidgetAnzeige
    let groesse: WidgetGroesse
    let getoent: Bool

    @Environment(\.dynamicTypeSize) private var schriftgroesse
    // Ein Faktor für alle Texte, damit die Größen zueinander so bleiben wie im Artboard (Titel größer als Ort).
    // Basis 100: `ScaledMetric` rundet auf ganze Zahlen, ein Wert von 1 würde nie größer.
    @ScaledMetric(relativeTo: .body) private var skala100: CGFloat = 100
    private var skala: CGFloat { skala100 / 100 }
    private var skalaKicker: CGFloat { skala }
    private var skalaKopf: CGFloat { skala }
    private var skalaOrt: CGFloat { skala }
    private var skalaZeile: CGFloat { skala }

    private var grosseSchrift: Bool { schriftgroesse >= .xLarge }
    private var kopfSchrift: CGFloat { groesse == .gross ? 17 : 15 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            kopf
            if groesse == .mittel { mittel } else { gross }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Kopf

    /// Mond und „Heute Abend“, rechts das Datum; tippen öffnet „Heute Abend“ in der App.
    private var kopf: some View {
        Link(destination: anzeige.kopfLink) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: kopfSchrift * skalaKopf))
                        .foregroundStyle(Color(.accent))
                    Text(anzeige.titel)
                        .font(.custom("PlusJakartaSans-ExtraBold", size: kopfSchrift * skalaKopf))
                        .tracking(-0.02 * kopfSchrift * skalaKopf)
                        .foregroundStyle(Color(.textPrimary))
                        .lineLimit(1)
                }
                .widgetAccentable()
                Spacer(minLength: 0)
                Text(anzeige.datum)
                    .font(.system(size: 12 * skalaOrt, weight: .semibold))
                    .foregroundStyle(Color(.textSecondary))
                    .lineLimit(1)
            }
            .padding(.bottom, 2)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Mittel

    @ViewBuilder
    private var mittel: some View {
        let inhalt = anzeige.mittel(maxZeilen: grosseSchrift ? 2 : AbendWidgetPhasen.maxMittel)
        if anzeige.leer {
            leerBlock(hinweis: anzeige.leerHinweis)
        } else {
            zeilen(inhalt.zeilen, abstand: 3)
            if let tail = inhalt.tail {
                Spacer(minLength: 0)
                Link(destination: anzeige.listeLink) {
                    Text(tail)
                        .font(.system(size: 12 * skalaOrt, weight: .semibold))
                        .foregroundStyle(Color(.textSecondary))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                        .overlay(alignment: .top) { trennlinie }
                }
            }
        }
    }

    // MARK: Groß

    @ViewBuilder
    private var gross: some View {
        let inhalt = anzeige.gross(
            maxHeute: grosseSchrift ? AbendWidgetPhasen.maxGrossHeute - 1 : AbendWidgetPhasen.maxGrossHeute,
            gesamt: grosseSchrift ? AbendWidgetPhasen.maxGrossGesamt - 1 : AbendWidgetPhasen.maxGrossGesamt
        )
        if anzeige.leer && !anzeige.zeigtMorgen {
            leerBlock(hinweis: "Schau, was morgen los ist.")
        } else if anzeige.leer {
            leerBlock(hinweis: anzeige.leerHinweis)
        } else {
            zeilen(inhalt.zeilen, abstand: 6)
        }
        if !inhalt.morgenZeilen.isEmpty {
            morgenAbschnitt
            zeilen(inhalt.morgenZeilen, abstand: 6)
        }
        Spacer(minLength: 0)
        fuss(inhalt.fuss)
    }

    private var morgenAbschnitt: some View {
        Link(destination: anzeige.listeLink) {
            HStack(alignment: .firstTextBaseline) {
                Text(anzeige.morgenKopf)
                    .font(.system(size: 11 * skalaKicker, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.03 * 11 * skalaKicker)
                Spacer(minLength: 0)
                Text(anzeige.morgenDatum)
                    .font(.system(size: 12 * skalaOrt, weight: .semibold))
            }
            .foregroundStyle(Color(.textSecondary))
            .padding(.top, 8)
            .padding(.bottom, 1)
            .overlay(alignment: .top) { trennlinie }
            .padding(.top, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func fuss(_ text: String) -> some View {
        Link(destination: anzeige.listeLink) {
            HStack {
                Text(text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("Alle ›")
                    .foregroundStyle(Color(.textPrimary))
            }
            .font(.system(size: 12.5 * skalaOrt, weight: .semibold))
            .foregroundStyle(Color(.textSecondary))
            .padding(.top, 8)
            .overlay(alignment: .top) { trennlinie }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Bausteine

    private var trennlinie: some View {
        Rectangle().fill(Color(.separator)).frame(height: 1)
    }

    private func leerBlock(hinweis: String) -> some View {
        Link(destination: anzeige.listeLink) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Heute Abend ist nichts eingetragen")
                    .font(.system(size: 14 * skalaZeile, weight: .bold))
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(2)
                Text(hinweis)
                    .font(.system(size: 13 * skalaOrt))
                    .foregroundStyle(Color(.textSecondary))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: groesse == .mittel ? .infinity : nil, alignment: .leading)
            .padding(.vertical, 6)
        }
        .accessibilityElement(children: .combine)
    }

    private func zeilen(_ liste: [AbendWidgetAnzeige.Zeile], abstand: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(liste.enumerated()), id: \.element.id) { index, zeile in
                AbendWidgetZeile(zeile: zeile, abstand: abstand, getoent: getoent, skalaZeile: skalaZeile, skalaOrt: skalaOrt, skalaChip: skalaKicker)
                    .overlay(alignment: .top) { if index > 0 { trennlinie } }
            }
        }
    }
}

// MARK: - Zeile

/// Beginn, Titel (mit Stern, wenn gemerkt), darunter Ort; rechts ein Chip nur bei Abweichung.
private struct AbendWidgetZeile: View {
    let zeile: AbendWidgetAnzeige.Zeile
    let abstand: CGFloat
    let getoent: Bool
    let skalaZeile: CGFloat
    let skalaOrt: CGFloat
    let skalaChip: CGFloat

    var body: some View {
        Link(destination: zeile.link) {
            HStack(spacing: 10) {
                Text(zeile.zeit)
                    .font(.system(size: 14 * skalaZeile, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(zeile.abgesagt ? Color(.textTertiary) : Color(.textPrimary))
                    .widgetAccentable()
                    .frame(width: 42 * skalaZeile, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(zeile.titel)
                            .font(.system(size: 14 * skalaZeile, weight: .semibold))
                            .strikethrough(zeile.abgesagt)
                            .foregroundStyle(zeile.abgesagt ? Color(.textTertiary) : Color(.textPrimary))
                            .lineLimit(1)
                        if zeile.gemerkt {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11 * skalaZeile))
                                .foregroundStyle(Color(.accent))
                                .widgetAccentable()
                                .accessibilityLabel("gemerkt")
                        }
                    }
                    if !zeile.ort.isEmpty {
                        Text(zeile.ort)
                            .font(.system(size: 12 * skalaOrt))
                            .foregroundStyle(Color(.textSecondary))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if zeile.abgesagt {
                    AbendWidgetChip(art: .faelltAus, getoent: getoent, skala: skalaChip)
                } else if zeile.laeuft {
                    AbendWidgetChip(art: .laeuft, getoent: getoent, skala: skalaChip)
                }
            }
            .padding(.vertical, abstand)
        }
        .accessibilityElement(children: .combine)
    }
}

/// „Läuft gerade“ (grüne Fläche) und „Fällt aus“ (`dangerSoft`/`danger`); getönt nur umrandeter Text.
private struct AbendWidgetChip: View {
    enum Art { case laeuft, faelltAus }

    let art: Art
    let getoent: Bool
    let skala: CGFloat

    var body: some View {
        Text(art == .laeuft ? "Läuft gerade" : "Fällt aus")
            .font(.system(size: 10.5 * skala, weight: .semibold))
            .foregroundStyle(getoent ? Color(.textSecondary) : vordergrund)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background { if !getoent { Capsule().fill(hintergrund) } }
            .overlay { if getoent { Capsule().strokeBorder(Color(.textSecondary).opacity(0.4), lineWidth: 1) } }
            .fixedSize()
    }

    private var hintergrund: Color {
        art == .laeuft ? Color(.green) : Color(.dangerSoft)
    }

    private var vordergrund: Color {
        art == .laeuft ? Color(.onGreen) : Color(.danger)
    }
}
