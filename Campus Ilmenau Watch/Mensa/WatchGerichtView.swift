import SwiftUI

/// Gericht auf der Uhr nach `WatchGericht.dc.html`: Name, Preis der eigenen Preisgruppe groß, die anderen Preise in einer
/// Zeile, Chips, Allergene und Zusatzstoffe (nur wenn vorhanden).
struct WatchGerichtView: View {
    @Environment(UhrDaten.self) private var daten
    @Environment(UhrVerbindung.self) private var verbindung
    let id: String

    var body: some View {
        ScrollView {
            if let gericht = daten.gericht(id: id) {
                inhalt(gericht)
            } else {
                WatchKarte {
                    Text("Das Gericht ist nicht mehr da.")
                        .font(.footnote)
                        .foregroundStyle(Color(.watchText2))
                }
            }
        }
        .navigationTitle(mensaName)
        .containerBackground(Color(.watchBackground), for: .navigation)
    }

    private var mensaName: String {
        daten.mensa(einstellungen: verbindung.einstellungen, jetzt: .now).shortName
    }

    private func inhalt(_ gericht: WidgetGericht) -> some View {
        let gruppe = verbindung.einstellungen.preisgruppe
        let andere = MensaPriceGroup.allCases.filter { $0 != gruppe }
            .map { "\($0.title) \(MensaWidgetPhasen.preis(gericht, $0))" }
        let stoffe = gericht.zusatzstoffe

        return VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(gericht.name)
                    .jakartaGerichtname()
                    .foregroundStyle(Color(.watchText))
                    .fixedSize(horizontal: false, vertical: true)
                // Preis und Preisgruppe nebeneinander; bei großer Schrift untereinander statt „2,90 / €“.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        preisText(gericht, gruppe)
                        gruppeText(gruppe)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        preisText(gericht, gruppe)
                        gruppeText(gruppe)
                    }
                }
                .padding(.top, 6)
                // Eine Zeile, wenn sie passt; sonst je Preisgruppe eine Zeile, ohne hängenden Punkt.
                ViewThatFits(in: .horizontal) {
                    andereZeilen(andere, getrennt: false)
                    andereZeilen(andere, getrennt: true)
                }
                .padding(.top, 2)
                if !gericht.chips.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(gericht.chips, id: \.self) { chip in
                            WatchChip(LocalizedStringKey(chip.titel), variante: chip.variante, systemImage: chip.symbol)
                        }
                    }
                    .padding(.top, 7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .accessibilityElement(children: .combine)

            if !gericht.allergene.isEmpty {
                infoKarte("Allergene", gericht.allergene.joined(separator: ", "))
            }
            if !stoffe.isEmpty {
                infoKarte("Zusatzstoffe", "Mit " + stoffe.joined(separator: ", "))
            }

            Text("Angaben des Studierendenwerks. Alles Weitere in der App auf dem iPhone.")
                .uhrSchrift(12)
                .foregroundStyle(Color(.watchText3))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
                .padding(.top, 4)
        }
    }

    private func preisText(_ gericht: WidgetGericht, _ gruppe: MensaPriceGroup) -> some View {
        Text(MensaWidgetPhasen.preis(gericht, gruppe))
            .jakartaPreis()
            .monospacedDigit()
            .foregroundStyle(Color(.watchText))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func gruppeText(_ gruppe: MensaPriceGroup) -> some View {
        Text(gruppe.title)
            .uhrSchrift(13)
            .foregroundStyle(Color(.watchText2))
            .lineLimit(1)
    }

    private func andereZeilen(_ preise: [String], getrennt: Bool) -> some View {
        Group {
            if getrennt {
                VStack(alignment: .leading, spacing: 0) { ForEach(preise, id: \.self) { Text($0) } }
            } else {
                Text(preise.joined(separator: " · "))
            }
        }
        .uhrSchrift(13)
        .foregroundStyle(Color(.watchText2))
        .lineLimit(getrennt ? nil : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoKarte(_ titel: LocalizedStringKey, _ text: String) -> some View {
        WatchKarte {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                    .uhrSchrift(13, .semibold)
                    .foregroundStyle(Color(.watchText2))
                Text(text)
                    .uhrSchrift(15, .medium)
                    .foregroundStyle(Color(.watchText))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
