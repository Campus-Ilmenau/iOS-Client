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
        case .ausleihbar: siriText("siri.katalog.status.ausleihbar")
        case .nurVorOrt: siriText("siri.katalog.status.nurVorOrt")
        case .online: siriText("siri.katalog.status.online")
        case .ausgeliehen:
            rueckgabe.map { siriText("siri.katalog.status.ausgeliehenBis \(EventKalender.lokal($0) { $0.day().month(.wide) })") }
                ?? siriText("siri.katalog.status.ausgeliehen")
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

    static var nichtErreichbar: SiriKatalogAntwort {
        SiriKatalogAntwort(sagt: siriText("siri.katalog.nichtErreichbar"), karte: nil)
    }

    /// Leerer oder zu langer Begriff (mehr als 200 Zeichen).
    static var ungueltig: SiriKatalogAntwort {
        SiriKatalogAntwort(sagt: siriText("siri.katalog.ungueltig"), karte: nil)
    }

    static func antwort(_ ergebnis: SiriKatalogErgebnis) -> SiriKatalogAntwort {
        let treffer = Array(ergebnis.treffer.prefix(maxTreffer))
        let begriff = zitat(ergebnis.begriff)
        let gesucht = ergebnis.korrigiert.map { siriText("siri.katalog.gesucht \(zitat($0))") } ?? ""
        let alleLink = DeepLink.katalogSuchen(begriff: ergebnis.begriff).url

        guard ergebnis.gesamt > 0, let erster = treffer.first else {
            return SiriKatalogAntwort(
                sagt: siriText("siri.katalog.nichts \(gesucht) \(begriff)"),
                karte: SiriKatalogKarte(
                    kicker: siriText("siri.katalog.kicker"), titel: siriText("siri.katalog.keineTreffer"),
                    untertitel: untertitel(ergebnis), treffer: [],
                    fuss: siriText("siri.katalog.ohneAnmeldung"), alleLink: alleLink
                )
            )
        }

        // Hat die API korrigiert, sagt Siri zuerst, wonach sie gesucht hat.
        let einleitung: String
        if ergebnis.korrigiert == nil {
            einleitung = ergebnis.gesamt == 1
                ? siriText("siri.katalog.einl.eins \(begriff)")
                : siriText("siri.katalog.einl.mehr \(zahl(ergebnis.gesamt)) \(begriff)")
        } else {
            einleitung = ergebnis.gesamt == 1
                ? siriText("siri.katalog.korr.eins \(gesucht)")
                : siriText("siri.katalog.korr.mehr \(gesucht) \(zahl(ergebnis.gesamt))")
        }
        let titel = zitat(erster.titel)
        let satz: String
        if ergebnis.gesamt == 1 {
            satz = einleitung.dropLast() + ": \(titel)." + (erster.status.map { siriText("siri.katalog.erIst \($0.sagt)") } ?? "")
        } else {
            satz = einleitung + (erster.status.map { siriText("siri.katalog.derErsteIst \(titel) \($0.sagt)") }
                ?? siriText("siri.katalog.derErste \(titel)"))
        }

        return SiriKatalogAntwort(
            sagt: satz,
            karte: SiriKatalogKarte(
                kicker: siriText("siri.katalog.kicker"),
                titel: ergebnis.gesamt == 1 ? siriText("siri.katalog.karte.eins") : siriText("siri.katalog.karte.mehr \(zahl(ergebnis.gesamt))"),
                untertitel: untertitel(ergebnis), treffer: treffer, fuss: siriText("siri.katalog.ohneAnmeldung"), alleLink: alleLink
            )
        )
    }

    /// „für „Regelungstechnik““, bei einer Korrektur „für „Regelungstechnik“ statt „Regelungstechnk““.
    private static func untertitel(_ ergebnis: SiriKatalogErgebnis) -> String {
        guard let korrigiert = ergebnis.korrigiert else { return siriText("siri.katalog.fuer \(zitat(ergebnis.begriff))") }
        return siriText("siri.katalog.fuerStatt \(zitat(korrigiert)) \(zitat(ergebnis.begriff))")
    }

    /// „Regelungstechnik“ in den Anführungszeichen der Sprache.
    private static func zitat(_ text: String) -> String { siriText("siri.zitat \(text)") }

    /// 1280 → „1.280“
    private static func zahl(_ n: Int) -> String {
        n.formatted(.number.locale(AppLanguage.current.locale))
    }
}
