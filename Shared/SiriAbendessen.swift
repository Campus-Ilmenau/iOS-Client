import Foundation

// „Gibt es heute Abendessen?“ für Siri. Ort und Zeit kommen aus den Daten, nicht fest „Ehrenberg“. Die Karte ist
// dieselbe wie bei „Mensa heute“ (`SiriMensaKarte`), mit dem Kicker „Abendessen · 16:30–19:30“. Reine Logik ohne SwiftUI.
// Die Sätze folgen `Uebergabe.md`, Kapitel „Siri & Kurzbefehle“ → „Abendessen“.

nonisolated enum SiriAbendessen {
    typealias P = MensaWidgetPhasen

    static func antwort(snapshot: WidgetSnapshot, einstellungen: SiriMensaEinstellungen, jetzt: Date) -> SiriMensaAntwort {
        guard !snapshot.mensen.isEmpty else { return SiriMensaAntwort(sagt: SiriMensa.keineDaten, karte: nil) }
        let heute = EventKalender.berlinDatum(jetzt)
        guard MensaVenue.allCases.contains(where: { P.plan($0, tag: heute, in: snapshot) != nil }) else {
            return SiriMensaAntwort(sagt: "Für heute ist der Speiseplan noch nicht da.", karte: nil)
        }
        let minuten = HeuteUhr.minuten(jetzt)
        let beginn = SiriSprache.uhr(P.abendessenBeginn)
        let gruppe = einstellungen.preisgruppe

        if let ort = P.abendessenOrte(snapshot: snapshot, tag: heute).first, minuten < P.abendessenEnde {
            let gerichte = abendgerichte(ort, tag: heute, snapshot: snapshot)
            let karte = karte(ort: ort, tag: heute, wort: nil, gerichte: gerichte, gruppe: gruppe)
            let liste = SiriSprache.gerichte(karte.gerichte)
            let sagt = minuten < P.abendessenBeginn
                ? "Ja. Zum Abendessen gibt es ab \(beginn) \(ort.sprechOrt) \(liste)."
                : "Ja, noch bis \(SiriSprache.uhr(P.abendessenEnde)) gibt es zum Abendessen \(ort.sprechOrt) \(liste)."
            return SiriMensaAntwort(sagt: sagt, karte: karte)
        }

        // Vorbei oder heute keins: das nächste Abendessen, das der Speicher kennt.
        let vorbei = !P.abendessenOrte(snapshot: snapshot, tag: heute).isEmpty
        let naechstes = naechstesAbendessen(snapshot: snapshot, jetzt: jetzt)
        guard let (ort, tag, datum) = naechstes else {
            return SiriMensaAntwort(
                sagt: vorbei ? "Das Abendessen ist für heute vorbei." : "Heute gibt es kein Abendessen.", karte: nil
            )
        }
        let wort = SiriSprache.tagwort(datum, jetzt: jetzt)
        let karte = karte(ort: ort, tag: tag, wort: wort, gerichte: abendgerichte(ort, tag: tag, snapshot: snapshot), gruppe: gruppe)
        let sagt: String
        if vorbei {
            sagt = "Das Abendessen ist für heute vorbei. \(wort) ab \(HeuteUhr.uhrzeit(minuten: P.abendessenBeginn)) \(ort.sprechOrt)."
        } else {
            let wann = wort == "Morgen" ? "morgen" : "am \(wort)"
            sagt = "Heute gibt es kein Abendessen. Das nächste ist \(wann) ab \(HeuteUhr.uhrzeit(minuten: P.abendessenBeginn))."
        }
        return SiriMensaAntwort(sagt: sagt, karte: karte)
    }

    // MARK: Hilfen

    private static func abendgerichte(_ ort: MensaVenue, tag: String, snapshot: WidgetSnapshot) -> [WidgetGericht] {
        P.plan(ort, tag: tag, in: snapshot)?.gerichte.filter(\.abendessen) ?? []
    }

    /// Der früheste Tag nach heute, für den der Speicher ein Abendessen kennt, mit dem Ort (Cafeteria Ehrenberg zuerst).
    private static func naechstesAbendessen(snapshot: WidgetSnapshot, jetzt: Date) -> (MensaVenue, String, Date)? {
        let heute = EventKalender.berlinDatum(jetzt)
        let tage = Set(MensaVenue.allCases.compactMap { snapshot.mensa(id: $0.rawValue)?.naechsterOeffnungstag?.tag }.filter { $0 > heute })
        for tag in tage.sorted() {
            if let ort = P.abendessenOrte(snapshot: snapshot, tag: tag).first, let datum = P.datum(tag) {
                return (ort, tag, datum)
            }
        }
        return nil
    }

    /// `wort`: „Morgen“ oder „Montag“ für einen späteren Tag; `nil` für heute.
    private static func karte(
        ort: MensaVenue, tag: String, wort: String?, gerichte: [WidgetGericht], gruppe: MensaPriceGroup
    ) -> SiriMensaKarte {
        let zeiten = HeuteUhr.uhrzeit(minuten: P.abendessenBeginn) + "–" + HeuteUhr.uhrzeit(minuten: P.abendessenEnde)
        let zeilen = gerichte.prefix(P.maxZeilen).map { gericht in
            MensaWidgetAnzeige.Zeile(
                id: gericht.id, name: gericht.name, preis: P.preis(gericht, gruppe), chips: gericht.chips,
                link: DeepLink.gericht(id: gericht.id, tag: tag).url
            )
        }
        let mehr = gerichte.count - zeilen.count
        return SiriMensaKarte(
            kicker: "Abendessen" + (wort.map { " \($0 == "Morgen" ? "morgen" : $0)" } ?? "") + " · " + zeiten,
            titel: ort.displayName, filterzeile: nil, gerichte: zeilen,
            fuss: mehr > 0 ? "+\(mehr) weitere Gerichte" : "Abendangebot",
            kopfLink: DeepLink.mensa(id: ort.rawValue).url
        )
    }
}
