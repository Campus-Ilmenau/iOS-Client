import SwiftUI
import WidgetKit

/// Beispieldaten für Platzhalter und Previews, mit den Gerichten aus `WidgetMensa.dc.html`.
/// Donnerstag, 29. Oktober 2026 (Berlin); der nächste Öffnungstag ist Freitag, der 30.
enum MensaWidgetVorschau {
    enum Szenario: CaseIterable {
        /// 08:15, Mensa Ehrenberg
        case morgen
        /// 11:45, Mensa Ehrenberg
        case mittag
        /// 15:10, Nanoteria (hat seit 15:00 zu)
        case nachmittag
        /// 17:40, Mensa Ehrenberg (Abendessen in der Cafeteria)
        case abend
        /// 21:30, Mensa Ehrenberg
        case nacht
        /// Samstag, Mensa Ehrenberg
        case wochenende
        /// Speicher leer, 11:45
        case kein

        var uhr: String {
            switch self {
            case .morgen: "08:15"
            case .mittag, .kein: "11:45"
            case .nachmittag: "15:10"
            case .abend: "17:40"
            case .nacht: "21:30"
            case .wochenende: "11:45"
            }
        }

        var mensa: MensaVenue { self == .nachmittag ? .nanoteria : .mensaEhrenberg }
        var tag: String { self == .wochenende ? "2026-10-31" : "2026-10-29" }
    }

    static func anzeige(_ szenario: Szenario, preisgruppe: MensaPriceGroup = .studierende) -> MensaWidgetAnzeige {
        MensaWidgetPhasen.anzeige(
            snapshot: snapshot(szenario),
            mensaID: szenario.mensa.rawValue,
            preisgruppe: preisgruppe,
            jetzt: zeit(szenario.tag, szenario.uhr)
        )
    }

    static func zeit(_ tag: String, _ uhr: String) -> Date {
        let datum = tag.split(separator: "-").compactMap { Int($0) }
        let teile = uhr.split(separator: ":").compactMap { Int($0) }
        return EventKalender.kalender.date(from: DateComponents(
            year: datum[0], month: datum[1], day: datum[2], hour: teile[0], minute: teile[1]
        )) ?? .now
    }

    // MARK: Speicher

    static func snapshot(_ szenario: Szenario) -> WidgetSnapshot {
        if szenario == .kein { return WidgetSnapshot() }
        let wochenende = szenario == .wochenende
        let heute = szenario.tag
        let naechster = wochenende ? "2026-11-02" : "2026-10-30"

        func mensa(_ venue: MensaVenue, von: String, bis: String, mittag: [WidgetGericht], abend: [WidgetGericht] = [], morgen: [WidgetGericht]) -> WidgetMensa {
            WidgetMensa(
                id: venue.rawValue, name: venue.displayName, kurzname: venue.shortName,
                oeffnungszeiten: ["mon", "tue", "wed", "thu", "fri"].map { WidgetOeffnung(wochentag: $0, oeffnet: von, schliesst: bis) },
                heute: WidgetSpeiseplan(tag: heute, gerichte: wochenende ? [] : mittag + abend),
                naechsterOeffnungstag: WidgetSpeiseplan(tag: naechster, gerichte: morgen)
            )
        }

        return WidgetSnapshot(mensen: [
            mensa(.mensaEhrenberg, von: "11:00", bis: "14:00", mittag: [
                gericht("Linsen-Dal mit Basmatireis", 2.90, [.vegan, .regional]),
                gericht("Hähnchenschnitzel, Kartoffelsalat", 3.80),
                gericht("Pasta Arrabbiata", 2.60, [.vegan])
            ], morgen: [
                gericht("Kartoffelsuppe mit Bockwurst", 2.40, [.regional]),
                gericht("Gemüselasagne", 3.20, [.vegetarisch]),
                gericht("Falafel-Teller mit Hummus", 3.10, [.vegan])
            ]),
            mensa(.cafeteriaEhrenberg, von: "08:00", bis: "15:00", mittag: [], abend: [
                gericht("Flammkuchen mit Lauch und Speck", 3.20, abend: true),
                gericht("Gemüse-Bowl mit Erdnusssoße", 3.00, [.vegan], abend: true),
                gericht("Ofenkartoffel mit Quark", 2.50, [.vegetarisch], abend: true)
            ], morgen: [
                gericht("Abendessen-Platzhalter", 3.00, abend: true)
            ]),
            mensa(.nanoteria, von: "08:00", bis: "15:00", mittag: [
                gericht("Gemüse-Curry mit Kokos und Reis", 2.80, [.vegan]),
                gericht("Käsespätzle mit Röstzwiebeln", 3.10, [.vegetarisch]),
                gericht("Chili sin Carne", 2.70, [.vegan])
            ], morgen: [
                gericht("Ofenkartoffel mit Kräuterquark", 2.50, [.vegetarisch]),
                gericht("Putengeschnetzeltes, Reis", 3.60)
            ]),
            mensa(.roentgenbau, von: "08:00", bis: "14:00", mittag: [
                gericht("Ofengemüse mit Feta und Couscous", 3.00, [.vegetarisch]),
                gericht("Seelachs, Dillkartoffeln", 4.20)
            ], morgen: [
                gericht("Tomatensuppe mit Brot", 2.20, [.vegan]),
                gericht("Wiener Würstchen, Kartoffelsalat", 3.30)
            ])
        ])
    }

    private enum Chip {
        case vegan, regional, vegetarisch

        var wert: WidgetChip {
            switch self {
            case .vegan: WidgetChip(titel: "Vegan", art: .gruen)
            case .regional: WidgetChip(titel: "Regional", art: .blau)
            case .vegetarisch: WidgetChip(titel: "Vegetarisch", art: .neutral)
            }
        }
    }

    private static func gericht(_ name: String, _ preis: Double, _ chips: [Chip] = [], abend: Bool = false) -> WidgetGericht {
        WidgetGericht(
            id: "meal_\(name)", name: name, gruppe: abend ? "Abendessen" : "Mittag", abendessen: abend,
            preisStudierende: preis, preisBedienstete: preis + 1, preisGaeste: preis + 2, waehrung: "EUR",
            chips: chips.map(\.wert)
        )
    }
}

// MARK: - Previews

extension MensaEintrag {
    /// Ein Eintrag der Vorschau; das mittlere Widget bekommt Knopf und Punkte, außer bei fester Mensa.
    fileprivate static func vorschau(_ szenario: MensaWidgetVorschau.Szenario, fest: Bool = false, getoent: Bool = false) -> MensaEintrag {
        MensaEintrag(
            date: .now,
            anzeige: MensaWidgetVorschau.anzeige(szenario),
            wechsel: fest ? nil : MensaWechsel(venue: szenario.mensa),
            getoentVorschau: getoent
        )
    }
}

// Die echten Widget-Previews: alle sieben Zustände als Zeitleiste. Hell und dunkel, Dynamic Type (auch „X Large“,
// wo ein Gericht weniger erscheint) und die Größe schaltet die Preview-Leiste (Varianten).

#Preview("Widget klein", as: .systemSmall) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario) }
}

#Preview("Widget mittel", as: .systemMedium) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario) }
}

#Preview("Widget groß", as: .systemLarge) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario) }
}

#Preview("Widget mittel, feste Mensa (ohne Knopf)", as: .systemMedium) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario, fest: true) }
}

// Getönt / Klar: Ohne Tönung des Systems zeigen diese Previews nur, was wegfällt (Bänder, Chip-Flächen).

#Preview("Getönt klein", as: .systemSmall) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario, getoent: true) }
}

#Preview("Getönt mittel", as: .systemMedium) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario, getoent: true) }
}

#Preview("Getönt groß", as: .systemLarge) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario, getoent: true) }
}
