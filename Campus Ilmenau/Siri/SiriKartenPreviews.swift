import SwiftUI

// Previews der Siri-Karten in Light und Dark, mit den Beispielen aus `Siri.dc.html` (Tweak `frage`):
// „Mensa heute“, „Mensa heute gefiltert“, „Vegetarisch abends“, „Mensa offen“, „Abendessen“, „Heute Abend“, „Katalog Treffer“, „Merkliste“.
// Das System zeichnet um die Karte die Fläche und den Leuchtrand; hier steht nur eine Platte dahinter.

private enum SiriBeispiele {
    private static let vegan = WidgetChip(titel: "Vegan", art: .gruen)
    private static let regional = WidgetChip(titel: "Regional", art: .blau)
    private static let vegetarisch = WidgetChip(titel: "Vegetarisch", art: .neutral)

    private static func zeile(_ name: String, _ preis: String, _ chips: [WidgetChip] = []) -> MensaWidgetAnzeige.Zeile {
        .init(id: name, name: name, preis: preis, chips: chips, link: DeepLink.mensa(id: "mensaEhrenberg").url)
    }

    private static let ehrenberg = DeepLink.mensa(id: "mensaEhrenberg").url
    private static let cafeteria = DeepLink.mensa(id: "cafeteriaEhrenberg").url

    static let mittag = SiriMensaKarte(
        kicker: "Geöffnet bis 14:00", titel: "Mensa Ehrenberg", filterzeile: nil,
        gerichte: [
            zeile("Linsen-Dal mit Basmatireis", "2,90 €", [vegan, regional]),
            zeile("Hähnchenschnitzel, Kartoffelsalat", "3,80 €"),
            zeile("Pasta Arrabbiata", "2,60 €", [vegan])
        ],
        fuss: "+3 weitere Gerichte", kopfLink: ehrenberg
    )

    static let gefiltert = SiriMensaKarte(
        kicker: "Geöffnet bis 14:00", titel: "Mensa Ehrenberg", filterzeile: "Gefiltert: Vegan · ohne Milch",
        gerichte: [zeile("Linsen-Dal mit Basmatireis", "2,90 €", [vegan, regional]), zeile("Pasta Arrabbiata", "2,60 €", [vegan])],
        fuss: "6 Gerichte ohne Filter", kopfLink: ehrenberg
    )

    static let vegetarischAbends = SiriMensaKarte(
        kicker: "Abendessen · bis 19:30", titel: "Cafeteria Ehrenberg", filterzeile: "Vegetarisch – aus deiner Frage",
        gerichte: [zeile("Gemüse-Bowl mit Erdnusssoße", "3,00 €", [vegan]), zeile("Ofenkartoffel mit Quark", "2,50 €", [vegetarisch])],
        fuss: "Ohne Filter: 3 Gerichte", kopfLink: cafeteria
    )

    static let abendessen = SiriMensaKarte(
        kicker: "Abendessen · 16:30–19:30", titel: "Cafeteria Ehrenberg", filterzeile: nil,
        gerichte: [
            zeile("Flammkuchen mit Lauch und Speck", "3,20 €"),
            zeile("Gemüse-Bowl mit Erdnusssoße", "3,00 €", [vegan]),
            zeile("Ofenkartoffel mit Quark", "2,50 €", [vegetarisch])
        ],
        fuss: "Abendangebot", kopfLink: cafeteria
    )

    static let nichtsPasst = SiriMensaKarte(
        kicker: "Geöffnet bis 14:00", titel: "Mensa Ehrenberg", filterzeile: "Gefiltert: Vegan",
        gerichte: [], fuss: "2 Gerichte ohne Filter", kopfLink: ehrenberg
    )

    static let offen = SiriOffenKarte(
        gross: "Nein, seit 14:00 zu", klein: "Mensa Ehrenberg · die Nanoteria hat noch offen.",
        zeilen: [
            .init(id: "n", name: "Cafeteria Nanoteria", stat: "bis 15:00", offen: true, chip: "noch 25 Min."),
            .init(id: "c", name: "Cafeteria Ehrenberg", stat: "Abendessen ab 16:30", offen: false, chip: nil),
            .init(id: "m", name: "Mensa Ehrenberg", stat: "zu · morgen 11:00", offen: false, chip: nil),
            .init(id: "r", name: "Cafeteria Röntgenbau", stat: "zu · morgen 10:30", offen: false, chip: nil)
        ],
        link: DeepLink.mensaZeiten.url
    )
}

/// Die Platte des Systems: App-Zeile, gesprochener Satz, Karte.
private struct SiriPlatte<Inhalt: View>: View {
    let sagt: String
    @ViewBuilder let inhalt: Inhalt

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Campus Ilmenau", systemImage: "app.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
            Text(sagt)
                .font(.body.weight(.medium))
                .foregroundStyle(Color(.textPrimary))
                .padding(.bottom, 4)
            inhalt
        }
        .padding(14)
        .background(Color(.surface), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.background))
    }
}

private struct MensaKartenVorschau: View {
    let sagt: String
    let karte: SiriMensaKarte

    var body: some View {
        SiriPlatte(sagt: sagt) { SiriMensaAntwortView(karte: karte) }
    }
}

#Preview("Mensa heute · Light") {
    MensaKartenVorschau(
        sagt: "Zum Mittag gibt es in Ehrenberg Linsen-Dal für 2,90 €, Hähnchenschnitzel und Pasta Arrabbiata. Geöffnet bis 14 Uhr.",
        karte: SiriBeispiele.mittag
    )
    .preferredColorScheme(.light)
}

#Preview("Mensa heute · Dark") {
    MensaKartenVorschau(
        sagt: "Zum Mittag gibt es in Ehrenberg Linsen-Dal für 2,90 €, Hähnchenschnitzel und Pasta Arrabbiata. Geöffnet bis 14 Uhr.",
        karte: SiriBeispiele.mittag
    )
    .preferredColorScheme(.dark)
}

#Preview("Gefiltert · Light") {
    MensaKartenVorschau(
        sagt: "Zum Mittag passen in Ehrenberg zwei Gerichte zu deinem Filter: Linsen-Dal für 2,90 € und Pasta Arrabbiata.",
        karte: SiriBeispiele.gefiltert
    )
    .preferredColorScheme(.light)
}

#Preview("Gefiltert · Dark") {
    MensaKartenVorschau(
        sagt: "Zum Mittag passen in Ehrenberg zwei Gerichte zu deinem Filter: Linsen-Dal für 2,90 € und Pasta Arrabbiata.",
        karte: SiriBeispiele.gefiltert
    )
    .preferredColorScheme(.dark)
}

#Preview("Vegetarisch abends · Light") {
    MensaKartenVorschau(
        sagt: "Zum Abendessen gibt es bis 19:30 Uhr in der Cafeteria Ehrenberg zwei vegetarische Gerichte: Gemüse-Bowl für 3,00 € und Ofenkartoffel.",
        karte: SiriBeispiele.vegetarischAbends
    )
    .preferredColorScheme(.light)
}

#Preview("Vegetarisch abends · Dark") {
    MensaKartenVorschau(
        sagt: "Zum Abendessen gibt es bis 19:30 Uhr in der Cafeteria Ehrenberg zwei vegetarische Gerichte: Gemüse-Bowl für 3,00 € und Ofenkartoffel.",
        karte: SiriBeispiele.vegetarischAbends
    )
    .preferredColorScheme(.dark)
}

#Preview("Nichts passt · Light") {
    MensaKartenVorschau(
        sagt: "Zum Mittag passt heute nichts zu deinem Filter. Ohne Filter gibt es 2 Gerichte.",
        karte: SiriBeispiele.nichtsPasst
    )
    .preferredColorScheme(.light)
}

#Preview("Abendessen · Light") {
    MensaKartenVorschau(
        sagt: "Ja. Zum Abendessen gibt es ab 16:30 Uhr in der Cafeteria Ehrenberg Flammkuchen für 3,20 €, Gemüse-Bowl und Ofenkartoffel.",
        karte: SiriBeispiele.abendessen
    )
    .preferredColorScheme(.light)
}

#Preview("Abendessen · Dark") {
    MensaKartenVorschau(
        sagt: "Ja. Zum Abendessen gibt es ab 16:30 Uhr in der Cafeteria Ehrenberg Flammkuchen für 3,20 €, Gemüse-Bowl und Ofenkartoffel.",
        karte: SiriBeispiele.abendessen
    )
    .preferredColorScheme(.dark)
}

#Preview("Mensa offen · Light") {
    SiriPlatte(sagt: "Ehrenberg hat seit 14 Uhr zu. Die Nanoteria hat noch 25 Minuten offen, bis 15 Uhr.") {
        SiriOffenAntwortView(karte: SiriBeispiele.offen)
    }
    .preferredColorScheme(.light)
}

#Preview("Mensa offen · Dark") {
    SiriPlatte(sagt: "Ehrenberg hat seit 14 Uhr zu. Die Nanoteria hat noch 25 Minuten offen, bis 15 Uhr.") {
        SiriOffenAntwortView(karte: SiriBeispiele.offen)
    }
    .preferredColorScheme(.dark)
}

// MARK: - Heute Abend

private enum SiriAbendBeispiele {
    private static func zeile(
        _ id: String, _ zeit: String, _ titel: String, _ ort: String,
        laeuft: Bool = false, abgesagt: Bool = false, gemerkt: Bool = false
    ) -> AbendWidgetAnzeige.Zeile {
        .init(
            id: id, zeit: zeit, titel: titel, ort: ort, laeuft: laeuft, abgesagt: abgesagt, gemerkt: gemerkt,
            link: DeepLink.event(id: id).url
        )
    }

    static let laeuft = SiriAbendKarte(
        titel: "Heute Abend", datum: "Do 29. Okt.",
        zeilen: [
            zeile("spiel", "19:00", "Spieleabend", "Studi-Club · bis 23:00", laeuft: true),
            zeile("quiz", "20:00", "Kneipenquiz", "Baracke5", abgesagt: true),
            zeile("stage", "21:00", "Open Stage", "BC-Club", gemerkt: true)
        ],
        fuss: "+1 weitere heute", leerText: nil, kopfLink: DeepLink.eventsHeuteAbend.url
    )

    static let leer = SiriAbendKarte(
        titel: "Heute Abend", datum: "Do 29. Okt.", zeilen: [], fuss: "",
        leerText: "Morgen · 21:00 Halloween-Party, Studi-Club", kopfLink: DeepLink.eventsHeuteAbend.url
    )
}

private let abendSatz = "Gerade läuft Spieleabend im Studi-Club. Um 21 Uhr ist Open Stage im BC-Club, um 22 Uhr Karaoke-Nacht in der Baracke5. Kneipenquiz fällt aus."

#Preview("Heute Abend · Light") {
    SiriPlatte(sagt: abendSatz) { SiriAbendAntwortView(karte: SiriAbendBeispiele.laeuft) }
        .preferredColorScheme(.light)
}

#Preview("Heute Abend · Dark") {
    SiriPlatte(sagt: abendSatz) { SiriAbendAntwortView(karte: SiriAbendBeispiele.laeuft) }
        .preferredColorScheme(.dark)
}

#Preview("Heute Abend leer · Light") {
    SiriPlatte(sagt: "Heute Abend ist nichts eingetragen. Morgen um 21 Uhr: Halloween-Party im Studi-Club.") {
        SiriAbendAntwortView(karte: SiriAbendBeispiele.leer)
    }
    .preferredColorScheme(.light)
}

// MARK: - Katalogsuche und Merkliste

private enum SiriBibliothekBeispiele {
    private static func treffer(_ nummer: Int, _ titel: String, _ meta: String, _ status: SiriKatalogStatus?) -> SiriKatalogTreffer {
        SiriKatalogTreffer(id: "med_\(nummer)", titel: titel, meta: meta, status: status)
    }

    static let katalog = SiriKatalogKarte(
        kicker: "Katalog der UB", titel: "128 Treffer", untertitel: "für „Regelungstechnik“",
        treffer: [
            treffer(1, "Regelungstechnik für Ingenieure", "Manfred Reuter, Serge Zacher · 2020 · Buch",
                    SiriKatalogStatus(art: .ausleihbar, chipText: "Ausleihbar", rueckgabe: nil)),
            treffer(2, "Regelungstechnik 1", "Jan Lunze · 2023 · Buch",
                    SiriKatalogStatus(art: .ausgeliehen, chipText: "Ausgeliehen bis 17. Nov.", rueckgabe: nil)),
            treffer(3, "Regelungstechnik", "Otto Föllinger · 2016 · Buch",
                    SiriKatalogStatus(art: .nurVorOrt, chipText: "Nur vor Ort", rueckgabe: nil))
        ],
        fuss: "Ohne Anmeldung", alleLink: DeepLink.katalogSuchen(begriff: "Regelungstechnik").url
    )

    static let merkliste = SiriMerklisteKarte(
        titel: "3 Titel im Regal", untertitel: "Nach Standort, so läufst du einmal durch.",
        standorte: [
            .init(name: "60 ELT", anzahl: 2, titel: [
                .init(id: "1", titel: "Regelungstechnik für Ingenieure", signatur: "ELT ZQ 5200 R447(10)"),
                .init(id: "2", titel: "Elektrische Maschinen", signatur: "ELT ZN 4000 F542(4)")
            ]),
            .init(name: "70 MB", anzahl: 1, titel: [
                .init(id: "3", titel: "Technische Mechanik 1: Statik", signatur: "MB UF 1000 G878(14)")
            ])
        ],
        fuss: "Nicht im Regal: 1", link: DeepLink.merkliste.url
    )
}

#Preview("Katalog Treffer · Light") {
    SiriPlatte(sagt: "Ich habe 128 Treffer für „Regelungstechnik“. Der erste, „Regelungstechnik für Ingenieure“, ist ausleihbar.") {
        SiriKatalogAntwortView(karte: SiriBibliothekBeispiele.katalog)
    }
    .preferredColorScheme(.light)
}

#Preview("Katalog Treffer · Dark") {
    SiriPlatte(sagt: "Ich habe 128 Treffer für „Regelungstechnik“. Der erste, „Regelungstechnik für Ingenieure“, ist ausleihbar.") {
        SiriKatalogAntwortView(karte: SiriBibliothekBeispiele.katalog)
    }
    .preferredColorScheme(.dark)
}

#Preview("Merkliste · Light") {
    SiriPlatte(sagt: "Drei Titel stehen im Regal: zwei im Bereich 60 ELT, einer in 70 MB. Einer ist ausgeliehen.") {
        SiriMerklisteAntwortView(karte: SiriBibliothekBeispiele.merkliste)
    }
    .preferredColorScheme(.light)
}

#Preview("Merkliste · Dark") {
    SiriPlatte(sagt: "Drei Titel stehen im Regal: zwei im Bereich 60 ELT, einer in 70 MB. Einer ist ausgeliehen.") {
        SiriMerklisteAntwortView(karte: SiriBibliothekBeispiele.merkliste)
    }
    .preferredColorScheme(.dark)
}
