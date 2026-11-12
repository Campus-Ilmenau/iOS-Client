import SwiftUI

/// Ziele der Karten auf dem Start.
enum WatchZiel: Hashable {
    case mensa
    case heuteAbend
    case merkliste

    var titel: LocalizedStringKey {
        switch self {
        case .mensa: "Mensa"
        case .heuteAbend: "Heute Abend"
        case .merkliste: "Merkliste"
        }
    }

    var symbol: String {
        switch self {
        case .mensa: "fork.knife"
        case .heuteAbend: "moon"
        case .merkliste: "bookmark"
        }
    }
}

/// Start der Uhr nach `WatchStart.dc.html`: drei Karten mit rundem Symbol und einer Zeile darunter. Mensa und Heute
/// Abend zeigen echte Werte, die Merkliste bleibt vorerst Platzhalter.
struct WatchStartView: View {
    @Environment(UhrDaten.self) private var daten
    @Environment(UhrVerbindung.self) private var verbindung
    @Environment(\.dynamicTypeSize) private var schriftgroesse
    /// Previews legen die Uhrzeit fest.
    var jetzt: Date?

    var body: some View {
        NavigationStack {
            UhrZeitgeber(festgelegt: jetzt) { jetzt in
                ScrollView {
                    VStack(spacing: 6) {
                        karte(.mensa, zeile: UhrStartZeile(mensaZeile(jetzt)))
                        karte(.heuteAbend, zeile: UhrAbendStart.zeile(
                            snapshot: daten.snapshot, hatKeineDaten: daten.hatKeineVeranstaltungen, jetzt: jetzt
                        ))
                        karte(.merkliste, zeile: UhrStartZeile(merklisteZeile))

                        Text("Mensa, Preise und Filter wie in der App auf dem iPhone.")
                            .uhrSchrift(12)
                            .foregroundStyle(Color(.watchText3))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Campus")
            .navigationDestination(for: WatchZiel.self) { ziel in
                switch ziel {
                case .mensa: WatchMensaView(jetzt: jetzt)
                case .heuteAbend: WatchEventsView(jetzt: jetzt)
                case .merkliste: WatchMerklisteView()
                }
            }
            .navigationDestination(for: UhrGerichtZiel.self) { WatchGerichtView(id: $0.id) }
            .navigationDestination(for: UhrMensaWahlZiel.self) { _ in WatchMensaWahlView(jetzt: jetzt) }
            .navigationDestination(for: UhrEventZiel.self) { WatchEventInfoView(id: $0.id) }
            .containerBackground(Color(.watchBackground), for: .navigation)
        }
        // Titel links oben in `watchAccent`.
        .tint(Color(.watchAccent))
    }

    /// „3 im Regal · 1 gefunden“; ohne Einträge „Noch nichts gemerkt“.
    private var merklisteZeile: String {
        let merkliste = verbindung.merkliste
        guard !merkliste.eintraege.isEmpty else { return "Noch nichts gemerkt" }
        return merkliste.anzeige.zusammenfassung
    }

    private func mensaZeile(_ jetzt: Date) -> String {
        guard !daten.hatKeinenSpeiseplan else { return "Noch keine Daten" }
        return UhrMensaAnzeige.erstelle(
            snapshot: daten.snapshot, mensa: daten.mensa(einstellungen: verbindung.einstellungen, jetzt: jetzt),
            einstellungen: verbindung.einstellungen, jetzt: jetzt
        ).startzeile
    }

    /// Die Zeile unter dem Titel: die lange Fassung, wenn sie in eine Zeile passt, sonst die kurze, die nur an Wortgrenzen
    /// umbricht.
    /// Der Punkt bleibt am Wort davor, damit keine Zeile mit „·“ beginnt.
    private func fest(_ text: String) -> String { text.replacingOccurrences(of: " · ", with: "\u{00A0}· ") }

    @ViewBuilder
    private func zeilenText(_ zeile: UhrStartZeile) -> some View {
        if let kurz = zeile.kurz {
            ViewThatFits(in: .horizontal) {
                Text(fest(zeile.lang)).fixedSize(horizontal: false, vertical: true)
                Text(fest(kurz)).fixedSize(horizontal: false, vertical: true)
                Text(fest(kurz)).fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(fest(zeile.lang))
        }
    }

    private func karte(_ ziel: WatchZiel, zeile: UhrStartZeile) -> some View {
        NavigationLink(value: ziel) {
            WatchKarte {
                // Rundes Symbol links wie im Artboard; bei großer Schrift darüber, damit der Text die ganze Breite hat.
                let symbol = Image(systemName: ziel.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.watchAccent))
                    .frame(width: 34, height: 34)
                    .background(Color(.watchSurface2), in: Circle())
                    .accessibilityHidden(true)
                let text = VStack(alignment: .leading, spacing: 2) {
                    Text(ziel.titel)
                        .uhrSchrift(15, .semibold)
                        .foregroundStyle(Color(.watchText))
                    zeilenText(zeile)
                        .uhrSchrift(13)
                        .foregroundStyle(Color(.watchText2))
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                if schriftgroesse >= .xxLarge {
                    VStack(alignment: .leading, spacing: 6) { symbol; text }
                } else {
                    HStack(spacing: 9) { symbol; text }
                }
            }
            .frame(minHeight: 44)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(ziel.titel) + Text(", \(zeile.lang)"))
    }
}
