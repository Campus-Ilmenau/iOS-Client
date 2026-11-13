import SwiftUI

/// Ziele innerhalb der Mensa-Ansichten.
struct UhrGerichtZiel: Hashable {
    let id: String
}

struct UhrMensaWahlZiel: Hashable {}

extension WidgetChip {
    var variante: WatchChip.Variante {
        switch art {
        case .gruen: .green
        case .blau: .blue
        case .neutral: .neutral
        }
    }

    /// „Vegan“ trägt das Blatt wie im Mockup.
    var symbol: String? { titel == "Vegan" ? "leaf" : nil }
}

/// „Mensa heute“ auf der Uhr nach `WatchMensa.dc.html`: Kopf mit Kicker und Mensa, eine Karte je Gericht, „Andere Mensa“.
struct WatchMensaView: View {
    @Environment(UhrDaten.self) private var daten
    @Environment(UhrVerbindung.self) private var verbindung
    /// Previews legen die Uhrzeit fest.
    var jetzt: Date?

    var body: some View {
        UhrZeitgeber(festgelegt: jetzt) { jetzt in
            let anzeige = UhrMensaAnzeige.erstelle(
                snapshot: daten.snapshot, mensa: daten.mensa(einstellungen: verbindung.einstellungen, jetzt: jetzt),
                einstellungen: verbindung.einstellungen, jetzt: jetzt, aufDerUhrGewaehlt: daten.andereMensa?.mensa(jetzt: jetzt) != nil
            )
            ScrollView {
                VStack(spacing: 6) {
                    inhalt(anzeige)
                }
            }
            .navigationTitle("Mensa")
            .containerBackground(Color(.watchBackground), for: .navigation)
            .onAppear {
                UhrSiriMelder.neueOeffnung(.mensa)
                UhrSiriMelder.neueOeffnung(.mensaAbendessen)
                meldeAnSiri(anzeige)
            }
            .onChange(of: anzeige.mensa) { meldeAnSiri(anzeige) }
            .onChange(of: anzeige.kicker) { meldeAnSiri(anzeige) }
        }
    }

    /// Siri-Vorschläge: Mensa geöffnet oder gewechselt → „Mensa heute“ mit der gezeigten Mensa; läuft die Phase
    /// Abendessen → „Abendessen“. Höchstens einmal pro Öffnen, nichts, was ein Link von außen geöffnet hat.
    private func meldeAnSiri(_ anzeige: UhrMensaAnzeige) {
        guard anzeige.zustand == .plan else { return }
        UhrSiriMelder.melde(.mensaHeute(mensa: MensaOrt(anzeige.mensa), ernaehrung: nil), in: .mensa)
        if anzeige.kicker.hasPrefix("Abendessen") {
            UhrSiriMelder.melde(.abendessen, in: .mensaAbendessen)
        }
    }

    @ViewBuilder
    private func inhalt(_ anzeige: UhrMensaAnzeige) -> some View {
        switch anzeige.zustand {
        case .keineDaten:
            WatchKarte {
                VStack(alignment: .leading, spacing: 8) {
                    Text(SiriMensa.keineDaten)
                        .font(.footnote)
                        .foregroundStyle(Color(.watchText2))
                        .fixedSize(horizontal: false, vertical: true)
                    WatchButton("Neu laden", systemImage: "arrow.clockwise") {
                        Task { await daten.laden(gemerkteEvents: verbindung.einstellungen.gemerkteEvents) }
                    }
                }
            }
        case .hinweis(let text):
            kopf(anzeige)
            WatchKarte {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(Color(.watchText2))
                    .fixedSize(horizontal: false, vertical: true)
            }
            andereMensa
            fussnote(anzeige)
        case .plan:
            kopf(anzeige)
            if let hinweis = anzeige.hinweis { hinweisKarte(hinweis) }
            if let leerText = anzeige.leerText {
                WatchKarte {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leerText)
                            .uhrSchrift(15, .semibold)
                            .foregroundStyle(Color(.watchText))
                        if let fuss = anzeige.leerFuss {
                            Text(fuss).font(.footnote).foregroundStyle(Color(.watchText2))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(anzeige.gerichte) { gericht in
                NavigationLink(value: UhrGerichtZiel(id: gericht.id)) {
                    gerichtKarte(gericht)
                }
                .buttonStyle(.plain)
            }
            andereMensa
            fussnote(anzeige)
        }
    }

    // MARK: Teile

    private func kopf(_ anzeige: UhrMensaAnzeige) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Circle()
                    .fill(anzeige.offen ? Color(.green) : Color(.watchText3))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(anzeige.kicker)
                    .uhrSchrift(13, .semibold)
                    .foregroundStyle(Color(.watchAccent))
            }
            Text(anzeige.titel)
                .jakartaSeitentitel()
                .foregroundStyle(Color(.watchText))
                .padding(.top, 2)
            if let notiz = anzeige.notiz {
                Text(notiz)
                    .uhrSchrift(13)
                    .foregroundStyle(Color(.watchText2))
                    .padding(.top, 3)
            }
            if let filter = anzeige.filterzeile {
                Label(filter, systemImage: "line.3.horizontal.decrease")
                    .uhrSchrift(13)
                    .foregroundStyle(Color(.watchText2))
                    .padding(.top, 2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// „Nanoteria hat noch bis 15:00 offen ›“: Tippen wechselt dorthin, bis Mitternacht.
    private func hinweisKarte(_ hinweis: UhrMensaAnzeige.Hinweis) -> some View {
        Button {
            daten.waehleAndereMensa(hinweis.mensa, jetzt: jetzt ?? .now)
        } label: {
            WatchKarte {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(.green))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(hinweis.text)
                        .uhrSchrift(14, .semibold)
                        .foregroundStyle(Color(.watchText))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(.watchText3))
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hinweis.text). Zur \(hinweis.mensa.shortName) wechseln")
    }

    private func gerichtKarte(_ gericht: UhrMensaAnzeige.Gericht) -> some View {
        WatchKarte {
            VStack(alignment: .leading, spacing: 4) {
                Text(gericht.name)
                    .uhrSchrift(15, .semibold)
                    .foregroundStyle(Color(.watchText))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(gericht.preis)
                        .uhrSchrift(13, .semibold)
                        .monospacedDigit()
                        .foregroundStyle(Color(.watchText))
                    if let chip = gericht.chips.first {
                        WatchChip(LocalizedStringKey(chip.titel), variante: chip.variante, systemImage: chip.symbol)
                    }
                }
            }
        }
        .frame(minHeight: 44)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            ([gericht.name, gericht.preis] + gericht.chips.map(\.titel)).joined(separator: ", ")
        )
    }

    private var andereMensa: some View {
        NavigationLink(value: UhrMensaWahlZiel()) {
            WatchKarte {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Andere Mensa")
                            .uhrSchrift(15, .semibold)
                            .foregroundStyle(Color(.watchText))
                        Text("Nanoteria, Röntgenbau …")
                            .uhrSchrift(13)
                            .foregroundStyle(Color(.watchText2))
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(.watchText3))
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func fussnote(_ anzeige: UhrMensaAnzeige) -> some View {
        Text(anzeige.fussnote)
            .uhrSchrift(12)
            .foregroundStyle(Color(.watchText3))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 4)
    }
}

/// „Andere Mensa“: die Mensen mit Öffnungsstatus. Die Auswahl gilt nur auf der Uhr und nur bis Mitternacht.
struct WatchMensaWahlView: View {
    @Environment(UhrDaten.self) private var daten
    @Environment(UhrVerbindung.self) private var verbindung
    @Environment(\.dismiss) private var dismiss
    var jetzt: Date?

    var body: some View {
        UhrZeitgeber(festgelegt: jetzt) { jetzt in
            let aktuell = daten.mensa(einstellungen: verbindung.einstellungen, jetzt: jetzt)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(UhrMensaStatus.alle(snapshot: daten.snapshot, jetzt: jetzt)) { zeile in
                        Button {
                            daten.waehleAndereMensa(zeile.mensa, jetzt: jetzt)
                            dismiss()
                        } label: {
                            WatchKarte {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                                            Circle()
                                                .fill(zeile.offen ? Color(.green) : Color(.watchText3))
                                                .frame(width: 8, height: 8)
                                                .accessibilityHidden(true)
                                            Text(zeile.mensa.shortName)
                                                .uhrSchrift(15, .semibold)
                                                .foregroundStyle(Color(.watchText))
                                        }
                                        Text(zeile.status)
                                            .uhrSchrift(13)
                                            .foregroundStyle(Color(.watchText2))
                                    }
                                    Spacer(minLength: 4)
                                    if zeile.mensa == aktuell {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color(.watchAccent))
                                            .accessibilityHidden(true)
                                    }
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(zeile.mensa.displayName), \(zeile.status)" + (zeile.mensa == aktuell ? ", ausgewählt" : ""))
                    }
                    Text("Gilt nur auf der Uhr und bis Mitternacht.")
                        .uhrSchrift(12)
                        .foregroundStyle(Color(.watchText3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.top, 4)
                }
            }
            .navigationTitle("Andere Mensa")
            .containerBackground(Color(.watchBackground), for: .navigation)
        }
    }
}
