import Foundation

// „Was ist heute Abend los?“ für Siri: gesprochener Satz und Karte, als reine Logik ohne SwiftUI. Die Daten und Regeln
// kommen aus `AbendWidgetPhasen` (dasselbe wie das Widget „Heute Abend“: heute ab 17 Uhr, ohne Ganztägige, Laufendes
// zuerst, mit Abgesagten, nach dem letzten Ende der nächste Abend). Die Sätze folgen `Uebergabe.md`, Kapitel
// „Siri & Kurzbefehle“ → „Heute Abend“.

/// Die Karte unter der Antwort. Sie ist immer nachtblau wie das kleine Abend-Widget.
nonisolated struct SiriAbendKarte: Equatable, Sendable {
    /// „Heute Abend“ oder „Morgen Abend“
    var titel: String
    /// „Do 29. Okt.“
    var datum: String
    /// Bis zu 3 Zeilen, Abgesagte eingeschlossen (durchgestrichen, mit „Fällt aus“).
    var zeilen: [AbendWidgetAnzeige.Zeile]
    /// „+1 weitere heute“; leer, wenn alle zu sehen sind.
    var fuss: String
    /// Ist nichts eingetragen: „Morgen · 21:00 Halloween-Party, Studi-Club“. Dann gibt es keine Zeilen.
    var leerText: String?
    /// `campusilmenau://events?filter=heute-abend`, für Kopf und Fuß.
    var kopfLink: URL
}

nonisolated struct SiriAbendAntwort: Equatable, Sendable {
    /// Der gesprochene Satz. Er muss allein reichen.
    var sagt: String
    var karte: SiriAbendKarte?
}

nonisolated enum SiriAbend {
    typealias Anzeige = AbendWidgetAnzeige

    /// So viele Veranstaltungen nennt Siri, und so viele Zeilen hat die Karte.
    static let maxGenannt = 3

    static let keineDaten = "Ich komme gerade nicht an die Veranstaltungen. Versuch es gleich noch mal."

    static func antwort(snapshot: WidgetSnapshot, jetzt: Date) -> SiriAbendAntwort {
        // Der Speicher wurde nie geschrieben und enthält nichts: Es hat sich nichts laden lassen.
        if snapshot.stand == nil, snapshot.events.isEmpty, snapshot.woche == nil {
            return SiriAbendAntwort(sagt: keineDaten, karte: nil)
        }
        let anzeige = AbendWidgetPhasen.anzeige(
            events: snapshot.events, gemerkteIDs: Set(snapshot.gemerkteEventIDs), woche: nil, jetzt: jetzt
        )
        let orte = Dictionary(snapshot.events.map { ($0.id, $0.ort) }, uniquingKeysWith: { erstes, _ in erstes })
        return SiriAbendAntwort(sagt: satz(anzeige, orte: orte), karte: karte(anzeige))
    }

    // MARK: Karte

    private static func karte(_ anzeige: Anzeige) -> SiriAbendKarte {
        let zeilen = Array(anzeige.zeilen.prefix(maxGenannt))
        let weitere = anzeige.zeilen.count - zeilen.count
        return SiriAbendKarte(
            titel: anzeige.titel, datum: anzeige.datum, zeilen: zeilen,
            fuss: weitere > 0 ? "+\(weitere) weitere \(anzeige.zeigtMorgen ? "morgen" : "heute")" : "",
            leerText: anzeige.zeilen.isEmpty ? anzeige.leerHinweis : nil,
            kopfLink: anzeige.kopfLink
        )
    }

    // MARK: Satz

    private static func satz(_ anzeige: Anzeige, orte: [String: String?]) -> String {
        let kopf = anzeige.titel
        let naechster = naechsterAbend(anzeige, orte: orte)

        if anzeige.leer {
            // Heute ist alles vorbei und morgen nichts da, oder heute war nichts eingetragen.
            return anzeige.zeigtMorgen
                ? "Heute Abend ist alles vorbei. Für morgen Abend ist nichts eingetragen."
                : "Heute Abend ist nichts eingetragen.\(naechster)"
        }

        let vorbei = anzeige.zeigtMorgen ? "Heute Abend ist alles vorbei. " : ""
        let aktiv = anzeige.zeilen.filter { !$0.abgesagt }
        let absagen = absagen(anzeige.zeilen.filter(\.abgesagt))

        // Nur noch Abgesagtes.
        guard !aktiv.isEmpty else {
            return "\(vorbei)\(kopf) ist nichts los. \(absagen)" + (anzeige.zeigtMorgen ? "" : naechster)
        }

        let genannt = Array(aktiv.prefix(maxGenannt))
        func eintrag(_ zeile: Anzeige.Zeile) -> String { zeile.titel + SiriSprache.ortsangabe(orte[zeile.id] ?? nil) }
        func uhr(_ zeile: Anzeige.Zeile) -> String { SiriSprache.uhr(HeuteUhr.minuten(aus: zeile.zeit) ?? 0) }
        /// „um 21 Uhr Open Stage im BC-Club, um 22 Uhr Karaoke“
        func folge(_ zeilen: [Anzeige.Zeile]) -> [String] {
            zeilen.map { "um \(uhr($0)) \(eintrag($0))" }
        }

        var saetze: [String] = []
        if let laeuft = genannt.first, laeuft.laeuft {
            saetze.append("Gerade läuft \(eintrag(laeuft)).")
            // „Um 21 Uhr ist Open Stage im BC-Club, um 22 Uhr Karaoke.“
            let weitere = Array(genannt.dropFirst())
            if let naechstes = weitere.first {
                let teile = ["Um \(uhr(naechstes)) ist \(eintrag(naechstes))"] + folge(Array(weitere.dropFirst()))
                saetze.append(aufzaehlung(teile) + ".")
            }
        } else {
            // „Heute Abend ist um 19 Uhr Spieleabend im Studi-Club, um 21 Uhr …“
            let liste = folge(genannt)
            saetze.append("\(kopf) ist " + aufzaehlung(liste) + ".")
        }
        if !absagen.isEmpty { saetze.append(absagen) }
        return vorbei + saetze.joined(separator: " ")
    }

    /// Mit „und“ vor dem letzten ab drei Teilen; zwei stehen wie im Mockup nur mit Komma: „um 21 Uhr ist …, um 22 Uhr …“.
    private static func aufzaehlung(_ teile: [String]) -> String {
        teile.count >= 3 ? SiriSprache.aufzaehlung(teile) : teile.joined(separator: ", ")
    }

    /// „Kneipenquiz fällt aus.“ oder „Kneipenquiz und Open Stage fallen aus.“ Das Geschlecht der Titel ist nicht
    /// bekannt, darum steht kein Artikel davor. Absagen stehen nur am Ende, in einem Satz.
    private static func absagen(_ zeilen: [Anzeige.Zeile]) -> String {
        guard !zeilen.isEmpty else { return "" }
        let namen = SiriSprache.aufzaehlung(zeilen.map(\.titel))
        return "\(namen) \(zeilen.count == 1 ? "fällt" : "fallen") aus."
    }

    /// „ Morgen um 21 Uhr: Halloween-Party im Studi-Club.“ (mit führendem Leerzeichen), das erste nicht abgesagte Event
    /// des nächsten Abends; leer, wenn es keins gibt.
    private static func naechsterAbend(_ anzeige: Anzeige, orte: [String: String?]) -> String {
        guard !anzeige.zeigtMorgen, let erstes = anzeige.morgenZeilen.first(where: { !$0.abgesagt }) else { return "" }
        let uhr = SiriSprache.uhr(HeuteUhr.minuten(aus: erstes.zeit) ?? 0)
        return " Morgen um \(uhr): \(erstes.titel)\(SiriSprache.ortsangabe(orte[erstes.id] ?? nil))."
    }
}

extension SiriSprache {
    /// „ im Studi-Club“, „ in der Baracke5“. Das Geschlecht eines Ortes lässt sich nur am Wortende erkennen
    /// („…club“, „…hörsaal“ → im; „…baracke“, „…mensa“ → in der). Bei einem unbekannten Ort steht er ohne Verhältniswort
    /// hinter einem Gedankenstrich, das ist nie falsch. Ohne Ort: leer.
    nonisolated static func ortsangabe(_ ort: String?) -> String {
        guard let ort = ort?.trimmingCharacters(in: .whitespacesAndNewlines), !ort.isEmpty else { return "" }
        let wort = ort.lowercased()
            .split(whereSeparator: { " -–/".contains($0) }).last
            .map { $0.filter { !$0.isNumber } } ?? ""
        let maennlichOderSaechlich = ["club", "hörsaal", "haus", "keller", "raum", "saal", "zentrum", "gebäude", "theater", "kino", "café", "foyer", "stadion"]
        let weiblich = ["baracke", "mensa", "bar", "halle", "kneipe", "cafeteria", "bibliothek", "aula", "kirche", "disco", "diskothek", "turnhalle", "sporthalle"]
        if maennlichOderSaechlich.contains(wort) { return " im \(ort)" }
        if weiblich.contains(wort) { return " in der \(ort)" }
        return " – \(ort)"
    }
}
