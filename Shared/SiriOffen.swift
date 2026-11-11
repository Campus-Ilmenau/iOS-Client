import Foundation

// „Hat die Mensa offen?“ für Siri: Antwort vorn, Liste aller vier Mensen, gesprochener Satz. Reine Logik ohne SwiftUI.
// Öffnungszeiten und Abendessen kommen aus `MensaWidgetPhasen` (Speicher der App Group), nichts davon ist neu gerechnet.
// Die Sätze folgen `Uebergabe.md`, Kapitel „Siri & Kurzbefehle“ → „Mensa offen?“.

nonisolated struct SiriOffenKarte: Equatable, Sendable {
    struct Zeile: Equatable, Sendable, Identifiable {
        let id: String
        let name: String
        /// „bis 15:00“, „Abendessen ab 16:30“, „zu · morgen 11:00“
        let stat: String
        /// Grüner Punkt, sonst grau.
        let offen: Bool
        /// „noch 25 Min.“, wenn die Mensa in weniger als 60 Minuten schließt.
        let chip: String?
    }

    /// „Ja, bis 14:00“, „Nein, seit 14:00 zu“, „Öffnet um 11:00“
    var gross: String
    /// „Mensa Ehrenberg · die Nanoteria hat noch offen.“
    var klein: String
    /// Offene zuerst.
    var zeilen: [Zeile]
    /// `campusilmenau://mensa/zeiten`
    var link: URL
}

nonisolated struct SiriOffenAntwort: Equatable, Sendable {
    var sagt: String
    var karte: SiriOffenKarte?
}

nonisolated enum SiriOffen {
    typealias P = MensaWidgetPhasen

    static let keineDaten = "Ich komme gerade nicht an die Öffnungszeiten. Versuch es gleich noch mal."

    /// So weit vor der Schließzeit steht „noch 25 Min.“.
    static let bald = 60

    // MARK: Stand je Mensa

    private nonisolated struct Stand {
        let venue: MensaVenue
        let zeiten: (oeffnet: Int, schliesst: Int)?
        let offen: Bool
        /// Wann sie schließt, wenn sie offen ist; läuft das Abendessen, ist es dessen Ende.
        let schliesst: Int?
        /// Zu, aber das Abendessen kommt heute noch.
        let abendessenKommt: Bool
    }

    private static func stand(_ venue: MensaVenue, snapshot: WidgetSnapshot, jetzt: Date) -> Stand {
        let minuten = HeuteUhr.minuten(jetzt)
        let zeiten = P.zeiten(venue, am: jetzt, in: snapshot)
        let abendHeute = P.abendessenOrte(snapshot: snapshot, tag: EventKalender.berlinDatum(jetzt)).contains(venue)
        var offen = zeiten.map { $0.oeffnet <= minuten && minuten < $0.schliesst } ?? false
        var schliesst = offen ? zeiten?.schliesst : nil
        if !offen, abendHeute, minuten >= P.abendessenBeginn, minuten < P.abendessenEnde {
            offen = true
            schliesst = P.abendessenEnde
        }
        return Stand(
            venue: venue, zeiten: zeiten, offen: offen, schliesst: schliesst,
            abendessenKommt: !offen && abendHeute && minuten < P.abendessenBeginn
        )
    }

    private static func naechster(_ venues: [MensaVenue], snapshot: WidgetSnapshot, jetzt: Date) -> (venue: MensaVenue, datum: Date, oeffnet: Int?)? {
        venues
            .map { venue -> (MensaVenue, String, Date, Int?) in
                let tag = P.naechsterOeffnungstag(snapshot: snapshot, mensaID: venue.rawValue, jetzt: jetzt)
                return (venue, tag.tag, tag.datum, tag.oeffnet)
            }
            .min { ($0.1, $0.3 ?? 24 * 60) < ($1.1, $1.3 ?? 24 * 60) }
            .map { ($0.0, $0.2, $0.3) }
    }

    /// „Morgen ab 11 Uhr.“ oder „Montag ab 11 Uhr.“
    private static func abSatz(_ naechster: (venue: MensaVenue, datum: Date, oeffnet: Int?)?, jetzt: Date) -> String {
        guard let naechster else { return "" }
        let wort = SiriSprache.tagwort(naechster.datum, jetzt: jetzt)
        return naechster.oeffnet.map { " \(wort) ab \(SiriSprache.uhr($0))." } ?? ""
    }

    // MARK: Karte

    private static func zeile(_ stand: Stand, snapshot: WidgetSnapshot, jetzt: Date) -> SiriOffenKarte.Zeile {
        let minuten = HeuteUhr.minuten(jetzt)
        let venue = stand.venue
        func zeile(_ text: String, chip: String? = nil) -> SiriOffenKarte.Zeile {
            .init(id: venue.rawValue, name: venue.displayName, stat: text, offen: stand.offen, chip: chip)
        }

        if stand.offen, let schliesst = stand.schliesst {
            let rest = schliesst - minuten
            return zeile("bis " + HeuteUhr.uhrzeit(minuten: schliesst), chip: rest < bald ? "noch \(rest) Min." : nil)
        }
        if stand.abendessenKommt { return zeile("Abendessen ab " + HeuteUhr.uhrzeit(minuten: P.abendessenBeginn)) }
        if let zeiten = stand.zeiten, minuten < zeiten.oeffnet { return zeile("öffnet " + HeuteUhr.uhrzeit(minuten: zeiten.oeffnet)) }

        let tag = P.naechsterOeffnungstag(snapshot: snapshot, mensaID: venue.rawValue, jetzt: jetzt)
        guard let oeffnet = tag.oeffnet else { return zeile("zu") }
        let wort = HeuteUhr.istGleicherTag(tag.datum, EventKalender.tag(jetzt, plus: 1)) ? "morgen" : HeuteUhr.wochentagKurz(tag.datum)
        return zeile("zu · \(wort) \(HeuteUhr.uhrzeit(minuten: oeffnet))")
    }

    // MARK: Antwort

    static func antwort(mensa: MensaOrt?, snapshot: WidgetSnapshot, einstellungen: SiriMensaEinstellungen, jetzt: Date) -> SiriOffenAntwort {
        guard snapshot.mensen.contains(where: { !$0.oeffnungszeiten.isEmpty }) else {
            return SiriOffenAntwort(sagt: keineDaten, karte: nil)
        }
        let minuten = HeuteUhr.minuten(jetzt)
        let staende = MensaVenue.allCases.map { stand($0, snapshot: snapshot, jetzt: jetzt) }
        let zeilen = staende
            .enumerated()
            .sorted { rang($0.element, $0.offset) < rang($1.element, $1.offset) }
            .map { zeile($0.element, snapshot: snapshot, jetzt: jetzt) }

        func karte(_ gross: String, _ klein: String) -> SiriOffenKarte {
            SiriOffenKarte(gross: gross, klein: klein, zeilen: zeilen, link: DeepLink.mensaZeiten.url)
        }
        func antwort(_ sagt: String, _ gross: String, _ klein: String) -> SiriOffenAntwort {
            SiriOffenAntwort(sagt: sagt, karte: karte(gross, klein))
        }

        let cafeteria = mensa == .cafeteria
        let ziel = cafeteria ? SiriMensa.cafeterien : [mensa?.venue ?? einstellungen.startseite]

        // Wochenende und Feiertage: keine Mensa hat heute Öffnungszeiten.
        if staende.allSatisfy({ $0.zeiten == nil && !$0.offen }) {
            let weiter = abSatz(naechster(ziel, snapshot: snapshot, jetzt: jetzt), jetzt: jetzt)
            return antwort("Heute haben alle Mensen zu.\(weiter)", "Heute zu", "Alle Mensen haben heute zu.")
        }
        return cafeteria
            ? cafeterienAntwort(staende, snapshot: snapshot, jetzt: jetzt, minuten: minuten, antwort: antwort)
            : einzelneAntwort(staende.first { $0.venue == ziel[0] }, staende, snapshot: snapshot, jetzt: jetzt, minuten: minuten, antwort: antwort)
    }

    /// Offene zuerst, dann die mit Abendessen heute, dann der Rest in der Reihenfolge der App.
    private static func rang(_ stand: Stand, _ index: Int) -> (Int, Int) {
        (stand.offen ? 0 : (stand.abendessenKommt ? 1 : 2), index)
    }

    private typealias Baue = (String, String, String) -> SiriOffenAntwort

    // MARK: Eine Mensa

    private static func einzelneAntwort(
        _ ziel: Stand?, _ alle: [Stand], snapshot: WidgetSnapshot, jetzt: Date, minuten: Int, antwort: Baue
    ) -> SiriOffenAntwort {
        guard let ziel else { return SiriOffenAntwort(sagt: keineDaten, karte: nil) }
        let venue = ziel.venue
        let name = venue.displayName
        let subjekt = SiriSprache.satzanfang(venue.sprechSubjekt)
        // Die andere Mensa, die am längsten offen hat.
        let andere = alle.filter { $0.venue != venue && $0.offen }.sorted { ($0.schliesst ?? 0) > ($1.schliesst ?? 0) }.first
        let andereSatz: String = andere.flatMap { stand in
            stand.schliesst.map { schliesst in
                let rest = schliesst - minuten
                let wer = SiriSprache.satzanfang(stand.venue.sprechSubjekt)
                return rest < bald
                    ? "\(wer) hat noch \(rest) Minuten offen, bis \(SiriSprache.uhr(schliesst))."
                    : "\(wer) hat bis \(SiriSprache.uhr(schliesst)) offen."
            }
        } ?? ""
        let andereKlein = andere.map { "\($0.venue.sprechSubjekt) hat noch offen." } ?? "keine andere Mensa hat offen."
        let danach = { (leer: String) in andereSatz.isEmpty ? leer : " " + andereSatz }

        if ziel.offen, let schliesst = ziel.schliesst {
            let rest = schliesst - minuten
            let sagt = rest < bald
                ? "Ja, \(venue.sprechSubjekt) hat noch \(rest) Minuten offen, bis \(SiriSprache.uhr(schliesst))."
                : "Ja, \(venue.sprechSubjekt) hat bis \(SiriSprache.uhr(schliesst)) offen."
            return antwort(sagt, "Ja, bis " + HeuteUhr.uhrzeit(minuten: schliesst), rest < bald ? "\(name) · schließt in \(rest) Min." : name)
        }

        let zu = ziel.zeiten.map { minuten >= $0.schliesst } ?? false
        let vorOeffnung = ziel.zeiten.map { minuten < $0.oeffnet } ?? false
        let naechster = naechster([venue], snapshot: snapshot, jetzt: jetzt)

        if ziel.abendessenKommt {
            let beginn = HeuteUhr.uhrzeit(minuten: P.abendessenBeginn)
            let mittag = vorOeffnung ? "\(subjekt) öffnet um \(SiriSprache.uhr(ziel.zeiten?.oeffnet ?? 0))." : "Zum Mittag hat \(venue.sprechSubjekt) zu."
            return antwort(
                "\(mittag) Das Abendessen gibt es ab \(SiriSprache.uhr(P.abendessenBeginn)).\(danach(""))",
                "Abendessen ab \(beginn)", "\(name) · \(andereKlein)"
            )
        }
        if zu, let zeiten = ziel.zeiten {
            let ohneAndere = "Heute hat keine Mensa mehr offen.\(abSatz(naechster, jetzt: jetzt))"
            return antwort(
                "\(subjekt) hat seit \(SiriSprache.uhr(zeiten.schliesst)) zu. \(andereSatz.isEmpty ? ohneAndere : andereSatz)",
                "Nein, seit \(HeuteUhr.uhrzeit(minuten: zeiten.schliesst)) zu", "\(name) · \(andereKlein)"
            )
        }
        if vorOeffnung, let zeiten = ziel.zeiten {
            return antwort(
                "\(subjekt) öffnet um \(SiriSprache.uhr(zeiten.oeffnet)).\(danach(""))",
                "Öffnet um \(HeuteUhr.uhrzeit(minuten: zeiten.oeffnet))", "\(name) · \(andereKlein)"
            )
        }
        return antwort(
            "\(subjekt) hat heute zu.\(abSatz(naechster, jetzt: jetzt))\(danach(""))",
            "Nein, heute zu", "\(name) · \(andereKlein)"
        )
    }

    // MARK: „Cafeteria“ ohne Ort: keine Rückfrage, die Antwort gilt für alle Cafeterien zusammen

    private static func cafeterienAntwort(
        _ alle: [Stand], snapshot: WidgetSnapshot, jetzt: Date, minuten: Int, antwort: Baue
    ) -> SiriOffenAntwort {
        let cafeterien = alle.filter { SiriMensa.cafeterien.contains($0.venue) }
        let offen = cafeterien.filter(\.offen)

        if let spaetestens = offen.compactMap(\.schliesst).max() {
            // Gleiche Schließzeit zusammenfassen, die späteste zuerst: „die Nanoteria hat bis 15 Uhr offen, Ehrenberg und
            // Röntgenbau bis 14 Uhr.“
            let gruppen = Dictionary(grouping: offen) { $0.schliesst ?? 0 }.sorted { $0.key > $1.key }
            let namen = { (stands: [Stand]) in SiriSprache.aufzaehlung(stands.map { $0.venue.sprechInGruppe }) }
            let sagt: String
            if gruppen.count == 1 {
                let verb = offen.count == 1 ? "hat" : "haben"
                sagt = "Ja, \(namen(offen)) \(verb) bis \(SiriSprache.uhr(spaetestens)) offen."
            } else {
                let erste = gruppen[0]
                let rest = gruppen.dropFirst().map { "\(namen($0.value)) bis \(SiriSprache.uhr($0.key))" }
                let verb = erste.value.count == 1 ? "hat" : "haben"
                sagt = "Ja, \(namen(erste.value)) \(verb) bis \(SiriSprache.uhr(erste.key)) offen, "
                    + SiriSprache.aufzaehlung(rest) + "."
            }
            return antwort(sagt, "Ja, bis " + HeuteUhr.uhrzeit(minuten: spaetestens), "Cafeterien · \(offen.count) von \(cafeterien.count) offen")
        }

        let spaeter = cafeterien.compactMap { stand in stand.zeiten.flatMap { $0.oeffnet > minuten ? (stand.venue, $0.oeffnet) : nil } }
        if let (venue, oeffnet) = spaeter.min(by: { $0.1 < $1.1 }) {
            return antwort(
                "Die Cafeterien haben noch zu. \(SiriSprache.satzanfang(venue.sprechSubjekt)) öffnet um \(SiriSprache.uhr(oeffnet)).",
                "Öffnet um " + HeuteUhr.uhrzeit(minuten: oeffnet), "Cafeterien · noch zu"
            )
        }
        if let abend = cafeterien.first(where: \.abendessenKommt) {
            return antwort(
                "Die Cafeterien haben zu. Das Abendessen gibt es ab \(SiriSprache.uhr(P.abendessenBeginn)) \(abend.venue.sprechOrt).",
                "Abendessen ab " + HeuteUhr.uhrzeit(minuten: P.abendessenBeginn), "Cafeterien · Abendessen \(abend.venue.shortName)"
            )
        }
        guard let naechster = naechster(SiriMensa.cafeterien, snapshot: snapshot, jetzt: jetzt), let oeffnet = naechster.oeffnet else {
            return antwort("Die Cafeterien haben zu.", "Nein, zu", "Cafeterien · zu")
        }
        let wort = SiriSprache.tagwort(naechster.datum, jetzt: jetzt)
        return antwort(
            "Die Cafeterien haben zu. \(wort) öffnet \(naechster.venue.sprechSubjekt) um \(SiriSprache.uhr(oeffnet)).",
            "Nein, zu", "Cafeterien · zu"
        )
    }
}
