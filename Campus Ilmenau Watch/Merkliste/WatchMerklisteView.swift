import SwiftUI
import WatchKit

/// Die Merkliste am Regal nach `WatchMerkliste.dc.html`: „Im Regal · n“ nach Standort, „Nicht im Regal“, „Gefunden · n“.
/// Die ganze Zeile tippen hakt ab oder nimmt den Haken zurück. Kein Wischen, kein Entfernen auf der Uhr.
struct WatchMerklisteView: View {
    @Environment(UhrVerbindung.self) private var verbindung
    @Environment(\.dynamicTypeSize) private var schriftgroesse

    private var merkliste: UhrMerkliste { verbindung.merkliste }

    var body: some View {
        let anzeige = merkliste.anzeige
        ScrollView {
            VStack(spacing: 6) {
                if !verbindung.iPhoneErreichbar {
                    offlineZeile
                }
                if anzeige.istLeer {
                    leer
                } else {
                    Text(anzeige.zusammenfassung)
                        .uhrSchrift(13)
                        .foregroundStyle(Color(.watchText2))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 2)
                    ForEach(anzeige.abschnitte) { abschnitt in
                        Text(abschnitt.titel)
                            .uhrSchrift(12, .bold)
                            .textCase(.uppercase)
                            .foregroundStyle(Color(.watchText2))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.top, 8)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(abschnitt.zeilen) { zeile in
                            zeileKarte(zeile)
                        }
                    }
                    Text("Tippen hakt ab. Entfernen geht auf dem iPhone.")
                        .uhrSchrift(12)
                        .foregroundStyle(Color(.watchText3))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.top, 4)
                }
            }
        }
        .navigationTitle("Merkliste")
        .containerBackground(Color(.watchBackground), for: .navigation)
        .task {
            // Beim Öffnen: Stand vom iPhone erfragen (wenn erreichbar) und Standort und Signatur frisch laden.
            verbindung.frageNachMerkliste()
            await merkliste.ladeStaende()
        }
    }

    // MARK: Teile

    private var offlineZeile: some View {
        Label {
            Text("iPhone nicht erreichbar · Haken werden später übertragen")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "iphone").accessibilityHidden(true)
        }
        .uhrSchrift(13)
        .foregroundStyle(Color(.watchText2))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private var leer: some View {
        WatchKarte {
            VStack(spacing: 2) {
                Image(systemName: "bookmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(.watchText3))
                    .accessibilityHidden(true)
                Text("Noch nichts gemerkt")
                    .uhrSchrift(15, .semibold)
                    .foregroundStyle(Color(.watchText))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
                Text("Titel merkst du im Katalog auf dem iPhone.")
                    .uhrSchrift(13)
                    .foregroundStyle(Color(.watchText2))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Die ganze Zeile ist ein Schalter: Kreis links (24 pt), Titel, Standort und Signatur, Chip.
    private func zeileKarte(_ zeile: UhrMerklisteAnzeige.Zeile) -> some View {
        Button {
            WKInterfaceDevice.current().play(.success)
            withAnimation(.easeInOut(duration: 0.25)) {
                merkliste.setzeGefunden(!zeile.gefunden, fuer: zeile.id)
            }
        } label: {
            WatchKarte {
                HStack(alignment: .top, spacing: 9) {
                    kreis(gefunden: zeile.gefunden)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(zeile.titel)
                            .uhrSchrift(15, zeile.gefunden ? .medium : .semibold)
                            .strikethrough(zeile.gefunden)
                            .foregroundStyle(Color(zeile.gefunden ? .watchText2 : .watchText))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let standort = zeile.standort {
                            Text(standort)
                                .uhrSchrift(14, .bold)
                                .foregroundStyle(Color(.watchText))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let signatur = zeile.signatur, !signatur.isEmpty {
                            Text(signatur)
                                .uhrSchrift(13, monospaced: true)
                                .foregroundStyle(Color(.watchText2))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let chip = zeile.chip {
                            WatchChip(LocalizedStringKey(chip), variante: zeile.chipArt == .blau ? .blue : .neutral)
                                .padding(.top, 3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minHeight: 44)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(zeile.beschriftung)
        .accessibilityAddTraits(zeile.gefunden ? [.isToggle, .isSelected] : .isToggle)
    }

    /// 24 pt: leer mit Rand in `watchText3`, abgehakt `green` mit Häkchen in `onGreen`.
    private func kreis(gefunden: Bool) -> some View {
        ZStack {
            if gefunden {
                Circle().fill(Color(.green))
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color(.onGreen))
            } else {
                Circle().strokeBorder(Color(.watchText3), lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
