import Foundation

// „Suche im Katalog“ für Siri: gesprochener Satz und Karte, als reine Logik ohne SwiftUI und ohne die Katalog-API.
// Die Suche und der Status der ersten Treffer kommen als einfache Werte herein (`SiriKatalogErgebnis`); wer sie lädt,
// steht im App-Target (`SiriKatalogDaten`). Ohne Anmeldung, ohne Bibliotheks-Token.
// Die Sätze folgen `Uebergabe.md`, Kapitel „Siri & Kurzbefehle“ → „Katalogsuche“.

/// Status eines Treffers, wie die Suche ihn als Chip zeigt.
nonisolated struct SiriKatalogStatus: Equatable, Sendable {
    enum Art: Equatable, Sendable {
        /// „Ausleihbar“ (grün)
        case ausleihbar
        /// „Nur vor Ort“ (blau)
        case nurVorOrt
        /// „Ausgeliehen bis 17. Nov.“ (neutral)
        case ausgeliehen
        /// „Online lesen“ (grün)
        case online
    }

    var art: Art
    /// Text des Chips, genau wie in der Suche.
    var chipText: String
    /// Frühestens zurück am (nur bei `ausgeliehen`).
    var rueckgabe: Date?

    /// Gesprochen: „ausleihbar“, „ausgeliehen bis zum 17. November“.
    var sagt: String {
        switch art {
        case .ausleihbar: "ausleihbar"
        case .nurVorOrt: "nur vor Ort nutzbar"
        case .online: "online lesbar"
        case .ausgeliehen:
            rueckgabe.map { "ausgeliehen bis zum \(EventKalender.format($0, "d. MMMM"))" } ?? "ausgeliehen"
        }
    }
}

nonisolated struct SiriKatalogTreffer: Equatable, Sendable, Identifiable {
    /// `med_<PPN>`
    let id: String
    let titel: String
    /// „Autor · Jahr · Art“, wie die Suche es zeigt.
    let meta: String
    /// `nil`, wenn der Status zu langsam kam oder unbekannt ist: Der Treffer erscheint ohne Chip.
    var status: SiriKatalogStatus?

    /// `campusilmenau://katalog/titel/<id>`
    var link: URL { DeepLink.katalogTitel(id: id).url }
}

/// Was die Suche im Bestand der UB ergeben hat.
nonisolated struct SiriKatalogErgebnis: Equatable, Sendable {
    /// Was gesagt wurde.
    var begriff: String
    /// Hat die API den Begriff korrigiert (`corrected_query`), steht hier, wonach sie gesucht hat.
    var korrigiert: String?
    var gesamt: Int
    /// Die ersten Treffer, höchstens `SiriKatalog.maxTreffer`.
    var treffer: [SiriKatalogTreffer]
}

nonisolated struct SiriKatalogKarte: Equatable, Sendable {
    /// „Katalog der UB“
    var kicker: String
    /// „128 Treffer“
    var titel: String
    /// „für „Regelungstechnik““
    var untertitel: String
    var treffer: [SiriKatalogTreffer]
    /// „Ohne Anmeldung“
    var fuss: String
    /// `campusilmenau://katalog/suche?q=<begriff>`: Fuß „Alle Treffer ›“.
    var alleLink: URL
}

nonisolated struct SiriKatalogAntwort: Equatable, Sendable {
    var sagt: String
    var karte: SiriKatalogKarte?
}

nonisolated enum SiriKatalog {
    /// So viele Treffer nennt Siri, zeigt die Karte und lädt den Status.
    static let maxTreffer = 3

    static let nichtErreichbar = SiriKatalogAntwort(
        sagt: "Ich komme gerade nicht an den Katalog. Versuch es gleich noch mal.", karte: nil
    )

    /// Leerer oder zu langer Begriff (mehr als 200 Zeichen).
    static let ungueltig = SiriKatalogAntwort(
        sagt: "Dein Suchbegriff passt nicht. Versuch es mit ein paar Stichworten.", karte: nil
    )

    static func antwort(_ ergebnis: SiriKatalogErgebnis) -> SiriKatalogAntwort {
        let treffer = Array(ergebnis.treffer.prefix(maxTreffer))
        let begriff = "„\(ergebnis.begriff)“"
        let gesucht = ergebnis.korrigiert.map { "Ich habe nach „\($0)“ gesucht. " } ?? ""
        let alleLink = DeepLink.katalogSuchen(begriff: ergebnis.begriff).url

        guard ergebnis.gesamt > 0, let erster = treffer.first else {
            return SiriKatalogAntwort(
                sagt: "\(gesucht)Für \(begriff) habe ich nichts gefunden.",
                karte: SiriKatalogKarte(
                    kicker: "Katalog der UB", titel: "Keine Treffer", untertitel: untertitel(ergebnis), treffer: [],
                    fuss: "Ohne Anmeldung", alleLink: alleLink
                )
            )
        }

        // Hat die API korrigiert, sagt Siri zuerst, wonach sie gesucht hat.
        let einleitung: String
        if ergebnis.korrigiert == nil {
            einleitung = "Ich habe \(ergebnis.gesamt == 1 ? "einen Treffer" : "\(zahl(ergebnis.gesamt)) Treffer") für \(begriff)."
        } else {
            einleitung = "\(gesucht)Das \(ergebnis.gesamt == 1 ? "ist ein Treffer" : "sind \(zahl(ergebnis.gesamt)) Treffer")."
        }
        let titel = "„\(erster.titel)“"
        let satz: String
        if ergebnis.gesamt == 1 {
            satz = einleitung.dropLast() + ": \(titel)." + (erster.status.map { " Er ist \($0.sagt)." } ?? "")
        } else {
            satz = einleitung + (erster.status.map { " Der erste, \(titel), ist \($0.sagt)." } ?? " Der erste ist \(titel).")
        }

        return SiriKatalogAntwort(
            sagt: satz,
            karte: SiriKatalogKarte(
                kicker: "Katalog der UB",
                titel: ergebnis.gesamt == 1 ? "1 Treffer" : "\(zahl(ergebnis.gesamt)) Treffer",
                untertitel: untertitel(ergebnis), treffer: treffer, fuss: "Ohne Anmeldung", alleLink: alleLink
            )
        )
    }

    /// „für „Regelungstechnik““, bei einer Korrektur „für „Regelungstechnik“ statt „Regelungstechnk““.
    private static func untertitel(_ ergebnis: SiriKatalogErgebnis) -> String {
        guard let korrigiert = ergebnis.korrigiert else { return "für „\(ergebnis.begriff)“" }
        return "für „\(korrigiert)“ statt „\(ergebnis.begriff)“"
    }

    /// 1280 → „1.280“
    private static func zahl(_ n: Int) -> String {
        n.formatted(.number.locale(Locale(identifier: "de_DE")))
    }
}
