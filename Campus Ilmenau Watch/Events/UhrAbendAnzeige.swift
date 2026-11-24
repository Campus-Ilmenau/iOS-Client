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
        if hatKeineDaten { return UhrStartZeile(String(localized: "Noch keine Daten", table: "Shared")) }
        let anzeige = AbendWidgetPhasen.anzeige(
            events: snapshot.events, gemerkteIDs: Set(snapshot.gemerkteEventIDs), woche: snapshot.woche, jetzt: jetzt
        )
        guard !anzeige.zeilen.isEmpty else {
            guard !anzeige.morgenZeilen.isEmpty else { return UhrStartZeile(String(localized: "Heute nichts eingetragen", table: "Shared")) }
            let n = anzeige.morgenZeilen.count
            return UhrStartZeile(String(localized: "Heute nichts · morgen \(anzahl(n))", table: "Shared"), kurz: String(localized: "Heute nichts · morgen \(kurzAnzahl(n))", table: "Shared"))
        }
        let n = anzeige.zeilen.count
        let wann = anzeige.zeigtMorgen ? String(localized: " morgen", table: "Shared") : ""
        // „ab 19:00“: Beginn der ersten, die nicht ausfällt (die laufende steht zuerst); fallen alle aus, steht das da.
        let ab = anzeige.zeilen.first { !$0.abgesagt }.map { String(localized: " · ab \($0.zeit)", table: "Shared") } ?? String(localized: " · fällt aus", table: "Shared")
        return UhrStartZeile(anzahl(n) + wann + ab, kurz: kurzAnzahl(n) + wann + ab)
    }

    static func anzahl(_ n: Int) -> String { String(localized: "\(n) Veranstaltungen", table: "Shared") }
    static func kurzAnzahl(_ n: Int) -> String { String(localized: "\(n) Termine", table: "Shared") }
}
