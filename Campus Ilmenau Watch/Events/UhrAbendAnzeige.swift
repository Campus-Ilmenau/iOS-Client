import Foundation

/// Die zweite Zeile einer Startkarte. Passt `lang` nicht in eine Zeile, zeigt die Karte `kurz`, damit kein Wort mitten
/// durchbricht („4 Veranstaltungen · ab 19:00“ → „4 Termine · ab 19:00“).
struct UhrStartZeile: Equatable {
    let lang: String
    var kurz: String?

    init(_ lang: String, kurz: String? = nil) {
        self.lang = lang
        self.kurz = kurz
    }
}

/// Die Zeile „Heute Abend“ auf dem Start. Die Zeitleiste selbst kommt aus `AbendWidgetPhasen` (Shared).
enum UhrAbendStart {
    static func zeile(snapshot: WidgetSnapshot, hatKeineDaten: Bool, jetzt: Date) -> UhrStartZeile {
        if hatKeineDaten { return UhrStartZeile("Noch keine Daten") }
        let anzeige = AbendWidgetPhasen.anzeige(
            events: snapshot.events, gemerkteIDs: Set(snapshot.gemerkteEventIDs), woche: snapshot.woche, jetzt: jetzt
        )
        guard !anzeige.zeilen.isEmpty else {
            guard !anzeige.morgenZeilen.isEmpty else { return UhrStartZeile("Heute nichts eingetragen") }
            let n = anzeige.morgenZeilen.count
            return UhrStartZeile("Heute nichts · morgen \(anzahl(n))", kurz: "Heute nichts · morgen \(kurzAnzahl(n))")
        }
        let n = anzeige.zeilen.count
        let wann = anzeige.zeigtMorgen ? " morgen" : ""
        // „ab 19:00“: Beginn der ersten, die nicht ausfällt (die laufende steht zuerst); fallen alle aus, steht das da.
        let ab = anzeige.zeilen.first { !$0.abgesagt }.map { " · ab \($0.zeit)" } ?? " · fällt aus"
        return UhrStartZeile(anzahl(n) + wann + ab, kurz: kurzAnzahl(n) + wann + ab)
    }

    static func anzahl(_ n: Int) -> String { n == 1 ? "1 Veranstaltung" : "\(n) Veranstaltungen" }
    static func kurzAnzahl(_ n: Int) -> String { n == 1 ? "1 Termin" : "\(n) Termine" }
}
