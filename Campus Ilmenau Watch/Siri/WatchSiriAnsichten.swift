import AppIntents
import SwiftUI

// Die kleinen Ansichten unter den Siri-Antworten auf der Uhr (`ShowsSnippetView`) nach `WatchSiri.dc.html`: eine Karte im
// Stil der Watch-Karten mit Kicker, Kopf, höchstens 3 Zeilen und Fuß in `watchAccent`, darunter der Button „In der App
// öffnen“. Die Texte kommen fertig aus `Shared/` (`SiriMensa`, `SiriOffen`, `SiriAbend`, `SiriMerkliste`) und sind
// dieselben wie auf der iPhone-Karte. Farben aus der Asset-Gruppe „Uhr“, Schrift mit Dynamic Type (`uhrSchrift`).

// MARK: - Bausteine

/// „In der App öffnen“: neutraler Button (`watchButton`, 44 pt) wie `WatchButton`, aber ein Intent, weil Snippets keine
/// Closures kennen. Der Intent öffnet die Watch-App am Ziel (`UhrOeffneZielIntent`).
struct UhrSiriOeffnenButton: View {
    let ziel: URL

    var body: some View {
        Button(intent: UhrOeffneZielIntent(url: ziel)) {
            Text("In der App öffnen")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color(.onWatchButton))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.watchButton), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Der Rahmen aller Siri-Ansichten: die Karte, darunter der Button.
private struct UhrSiriRahmen<Inhalt: View>: View {
    let ziel: URL
    @ViewBuilder let inhalt: Inhalt

    var body: some View {
        VStack(spacing: 6) {
            WatchKarte {
                VStack(alignment: .leading, spacing: 2) { inhalt }
            }
            UhrSiriOeffnenButton(ziel: ziel)
        }
    }
}

private struct UhrSiriKicker: View {
    let text: String

    var body: some View {
        Text(text.replacingOccurrences(of: " · ", with: "\u{00A0}· "))
            .uhrSchrift(13, .semibold)
            .foregroundStyle(Color(.watchAccent))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Der Fuß „+3 weitere Gerichte ›“: `watchAccent`, ein Link und kein Button.
private struct UhrSiriFuss: View {
    let text: String

    var body: some View {
        if !text.isEmpty {
            // Der Punkt bleibt am Wort davor, damit keine Zeile mit „·“ endet oder beginnt.
            Text("\(text.replacingOccurrences(of: " · ", with: "\u{00A0}· ")) ›")
                .uhrSchrift(12)
                .foregroundStyle(Color(.watchAccent))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
    }
}

/// Eine Zeile der Karte: links der Text, rechts Chip und/oder Wert. Passt beides in eine Zeile, bleibt es dabei; sonst
/// steht das Rechte unter dem Linken, statt dass ein Chip („Läuft gerade“) in drei Zeilen zerreißt.
private struct UhrSiriZeile<Links: View, Rechts: View>: View {
    /// Der Wert rechts ist kurz (Anzahl) und der Text links ein Standort („60 ELT“): Er bleibt rechts, links darf an einer
    /// Wortgrenze umbrechen.
    var wertRechts = false
    @ViewBuilder let links: Links
    @ViewBuilder let rechts: Rechts

    var body: some View {
        if wertRechts {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                links
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                rechts.fixedSize()
            }
            .padding(.top, 4)
            .uhrSchrift(13)
            .foregroundStyle(Color(.watchText))
        } else {
            wechselnd
        }
    }

    private var wechselnd: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                links.lineLimit(1)
                Spacer(minLength: 4)
                HStack(spacing: 4) { rechts }.lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 2) {
                links.fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) { rechts }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
        .uhrSchrift(13)
        .foregroundStyle(Color(.watchText))
    }
}

// MARK: - Mensa heute und Abendessen

/// „Geöffnet bis 14:00“, Mensa, 3 Gerichte mit Kurzname und Preis, Fuß „+3 weitere Gerichte ›“.
struct UhrSiriMensaAnsicht: View {
    let karte: SiriMensaKarte?
    let ziel: URL

    var body: some View {
        if let karte {
            UhrSiriRahmen(ziel: ziel) {
                UhrSiriKicker(text: karte.kicker)
                Text(MensaVenue(mensaKarte: karte)?.shortName ?? karte.titel)
                    .uhrSchrift(15, .semibold)
                    .fixedSize(horizontal: false, vertical: true)
                if let filter = karte.filterzeile {
                    Text(filter)
                        .uhrSchrift(13)
                        .foregroundStyle(Color(.watchText2))
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(UhrSiriGerichtZeile.zeilen(karte)) { zeile in
                    // Passt Name und Preis nicht in eine Zeile, steht der Preis darunter; nie ein Wort mitten durch.
                    UhrSiriZeile {
                        Text(zeile.name).fixedSize(horizontal: false, vertical: true)
                    } rechts: {
                        if !zeile.preis.isEmpty {
                            Text(zeile.preis).uhrSchrift(13, .semibold, monospaced: false).monospacedDigit()
                        }
                    }
                }
                UhrSiriFuss(text: karte.fuss)
            }
            .accessibilityElement(children: .contain)
        }
    }
}

private extension MensaVenue {
    /// Die Mensa einer Karte, aus ihrem Link (`campusilmenau://mensa?mensa=<id>`).
    init?(mensaKarte karte: SiriMensaKarte) {
        guard case .mensa(let id?)? = DeepLink(url: karte.kopfLink), let venue = MensaVenue(rawValue: id) else { return nil }
        self = venue
    }
}

// MARK: - Mensa offen?

/// Antwort groß (Jakarta): „Ja, bis 14:00“, darunter der Satz zur nächsten offenen; Liste aller Mensen, offene zuerst,
/// grüner Chip „noch 25 Min.“ unter 60 Minuten.
struct UhrSiriOffenAnsicht: View {
    let karte: SiriOffenKarte?
    let ziel: URL

    var body: some View {
        if let karte {
            UhrSiriRahmen(ziel: ziel) {
                UhrSiriKicker(text: "Mensa offen?")
                Text(karte.gross)
                    .jakartaSeitentitel()
                    .foregroundStyle(Color(.watchText))
                    .fixedSize(horizontal: false, vertical: true)
                Text(karte.klein)
                    .uhrSchrift(13)
                    .foregroundStyle(Color(.watchText2))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(karte.zeilen) { zeile in
                    UhrSiriOffenZeile(zeile: zeile)
                }
            }
        }
    }
}

/// Eine Mensa in der Liste: Punkt und Name, rechts der Status. Passt alles in eine Zeile, bleibt es dabei; sonst steht der
/// Status mit dem Chip „noch 25 Min.“ unter dem Namen (nie eine Zeile mit zerrissenem Chip).
private struct UhrSiriOffenZeile: View {
    let zeile: SiriOffenKarte.Zeile

    private var name: String { MensaVenue(rawValue: zeile.id)?.shortName ?? zeile.name }

    private var punkt: some View {
        Circle()
            .fill(zeile.offen ? Color(.green) : Color(.watchText3))
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }

    private var status: some View {
        HStack(spacing: 4) {
            if let chip = zeile.chip { WatchChip(LocalizedStringKey(chip), variante: .green) }
            Text(zeile.stat).foregroundStyle(Color(.watchText2))
        }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                punkt
                Text(name).lineLimit(1)
                Spacer(minLength: 4)
                status.lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    punkt
                    Text(name).fixedSize(horizontal: false, vertical: true)
                }
                status
                    .padding(.leading, 13)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
        .uhrSchrift(13)
        .foregroundStyle(Color(.watchText))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(zeile.offen ? "offen" : "zu"), \(zeile.stat)" + (zeile.chip.map { ", \($0)" } ?? ""))
    }
}

// MARK: - Heute Abend

/// „Heute Abend · Do 29. Okt.“, bis zu 3 Zeilen mit „Läuft gerade“, Uhrzeit oder „Fällt aus“, Stern für Gemerktes,
/// Fuß „+1 weitere heute ›“.
struct UhrSiriAbendAnsicht: View {
    let karte: SiriAbendKarte?
    let ziel: URL

    var body: some View {
        if let karte {
            UhrSiriRahmen(ziel: ziel) {
                UhrSiriKicker(text: "\(karte.titel) · \(karte.datum)")
                if let leer = karte.leerText {
                    Text(leer)
                        .uhrSchrift(15, .semibold)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(karte.zeilen) { zeile in
                    UhrSiriZeile {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(zeile.titel)
                                .strikethrough(zeile.abgesagt)
                                .foregroundStyle(zeile.abgesagt ? Color(.watchText2) : Color(.watchText))
                                .fixedSize(horizontal: false, vertical: true)
                            if zeile.gemerkt {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(.watchAccent))
                                    .accessibilityLabel("gemerkt")
                            }
                        }
                    } rechts: {
                        if zeile.abgesagt {
                            WatchChip("Fällt aus", variante: .danger)
                        } else if zeile.laeuft {
                            WatchChip("Läuft gerade", variante: .green)
                        } else {
                            Text(zeile.zeit).uhrSchrift(13, .semibold).monospacedDigit()
                        }
                    }
                }
                UhrSiriFuss(text: karte.fuss)
            }
        }
    }
}

// MARK: - Merkliste

/// „3 Titel im Regal“, Standorte mit Anzahl, Fuß „Nicht im Regal: n · Gefunden: n ›“.
struct UhrSiriMerklisteAnsicht: View {
    let karte: SiriMerklisteKarte?
    let ziel: URL

    var body: some View {
        if let karte {
            UhrSiriRahmen(ziel: ziel) {
                UhrSiriKicker(text: "Merkliste")
                Text(karte.titel)
                    .uhrSchrift(15, .semibold)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(karte.standorte) { standort in
                    UhrSiriZeile(wertRechts: true) {
                        Text(standort.name).fixedSize(horizontal: false, vertical: true)
                    } rechts: {
                        Text("\(standort.anzahl)").uhrSchrift(13, .semibold).monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(standort.name), \(standort.anzahl)")
                }
                UhrSiriFuss(text: karte.fuss)
            }
        }
    }
}
