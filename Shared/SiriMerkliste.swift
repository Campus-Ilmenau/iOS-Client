import Foundation

// „Was steht auf meiner Merkliste?“ für Siri: gesprochener Satz und Karte, als reine Logik ohne SwiftUI und ohne
// Katalog-API. Die Merkliste und der frische Stand aus `/availability` kommen als einfache Werte herein
// (`SiriMerklisteEintrag`); wer sie lädt, steht im App-Target (`SiriKatalogDaten`). Ohne Anmeldung, ohne Bibliotheks-Token.
// Gesprochen werden nur Anzahl und Standorte, nie Signaturen.
// Die Sätze folgen `Uebergabe.md`, Kapitel „Siri & Kurzbefehle“ → „Merkliste“.

/// Wo ein gemerkter Titel gerade ist.
nonisolated enum SiriMerklisteStand: Equatable, Sendable {
    /// Ausleihbar oder nur vor Ort, mit Standort („60 ELT“) und Signatur.
    case imRegal(standort: String, signatur: String?)
    case ausgeliehen
    case online
    /// Kein Status, kein Standort oder nicht abrufbar.
    case unbekannt
}

nonisolated struct SiriMerklisteEintrag: Equatable, Sendable, Identifiable {
    let id: String
    let titel: String
    var stand: SiriMerklisteStand
    /// Am Regal abgehakt („Gefunden“). Gefundene Titel zählen weder „im Regal“ noch „nicht im Regal“; sie stehen
    /// im Fuß („· Gefunden: n“) und am Ende des gesprochenen Satzes.
    var gefunden = false
}

nonisolated struct SiriMerklisteKarte: Equatable, Sendable {
    struct Standort: Equatable, Sendable, Identifiable {
        /// „60 ELT“
        let name: String
        /// Alle Titel an diesem Standort, auch die, die wegen der Zeilengrenze nicht auf der Karte stehen.
        let anzahl: Int
        /// Die gezeigten Titel mit Signatur.
        let titel: [Zeile]

        var id: String { name }
    }

    struct Zeile: Equatable, Sendable, Identifiable {
        let id: String
        let titel: String
        let signatur: String?
    }

    /// „3 Titel im Regal“
    var titel: String
    /// „Nach Standort, so läufst du einmal durch.“
    var untertitel: String
    var standorte: [Standort]
    /// „+2 weitere · Nicht im Regal: 1“
    var fuss: String
    /// `campusilmenau://bibliothek/merkliste`
    var link: URL
}

nonisolated struct SiriMerklisteAntwort: Equatable, Sendable {
    var sagt: String
    var karte: SiriMerklisteKarte?
}

nonisolated enum SiriMerkliste {
    /// Die Karte zeigt höchstens so viele Titel (3 Zeilen), darunter steht „+N weitere“.
    static let maxZeilen = 3
    /// Gesprochen werden höchstens so viele Standorte einzeln, der Rest heißt „an weiteren Standorten“.
    static let maxStandorte = 4

    static var leer: SiriMerklisteAntwort {
        SiriMerklisteAntwort(sagt: siriText("siri.merkliste.leer"), karte: nil)
    }

    static func antwort(_ eintraege: [SiriMerklisteEintrag]) -> SiriMerklisteAntwort {
        guard !eintraege.isEmpty else { return leer }

        let gefunden = eintraege.filter(\.gefunden).count
        let offene = eintraege.filter { !$0.gefunden }

        // Alles am Regal abgehakt: nichts mehr zu suchen.
        if offene.isEmpty {
            return SiriMerklisteAntwort(
                sagt: gefunden == 1 ? siriText("siri.merkliste.titelGefunden") : siriText("siri.merkliste.gefundenAlle \(gefunden)"), karte: nil
            )
        }

        // Ist nirgends etwas bekannt, kam `/availability` nicht an (offline, zu langsam).
        if offene.allSatisfy({ $0.stand == .unbekannt }) {
            return SiriMerklisteAntwort(
                sagt: eintraege.count == 1
                    ? siriText("siri.merkliste.unbekannt.eins")
                    : siriText("siri.merkliste.unbekannt.mehr \(eintraege.count)"),
                karte: nil
            )
        }

        let gruppen = standorte(offene)
        let imRegal = gruppen.reduce(0) { $0 + $1.eintraege.count }
        let ausgeliehen = offene.filter { $0.stand == .ausgeliehen }.count
        let online = offene.filter { $0.stand == .online }.count
        let unbekannt = offene.filter { $0.stand == .unbekannt }.count
        let nichtImRegal = offene.count - imRegal

        return SiriMerklisteAntwort(
            sagt: satz(
                gruppen: gruppen, imRegal: imRegal, gesamt: offene.count, ausgeliehen: ausgeliehen, online: online,
                unbekannt: unbekannt, gefunden: gefunden
            ),
            karte: karte(gruppen: gruppen, imRegal: imRegal, nichtImRegal: nichtImRegal, gefunden: gefunden)
        )
    }

    // MARK: Gruppen

    private struct Gruppe {
        let name: String
        let eintraege: [(eintrag: SiriMerklisteEintrag, signatur: String?)]
    }

    /// Die Titel im Regal nach Standort, natürlich sortiert („52/53 INF“ vor „60 ELT“, „9 X“ vor „60 ELT“).
    private static func standorte(_ eintraege: [SiriMerklisteEintrag]) -> [Gruppe] {
        var nachName: [String: [(SiriMerklisteEintrag, String?)]] = [:]
        for eintrag in eintraege {
            if case .imRegal(let standort, let signatur) = eintrag.stand {
                nachName[standort, default: []].append((eintrag, signatur))
            }
        }
        return nachName
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            .map { Gruppe(name: $0.key, eintraege: $0.value.map { (eintrag: $0.0, signatur: $0.1) }) }
    }

    // MARK: Satz

    /// „einer“, „zwei“, „drei“, sonst die Ziffer.
    private static func wort(_ n: Int) -> String {
        switch n {
        case 1: siriText("siri.merkliste.wort.1")
        case 2: siriText("siri.merkliste.wort.2")
        case 3: siriText("siri.merkliste.wort.3")
        default: String(n)
        }
    }

    private static func satz(
        gruppen: [Gruppe], imRegal: Int, gesamt: Int, ausgeliehen: Int, online: Int, unbekannt: Int, gefunden: Int
    ) -> String {
        var saetze: [String] = []

        if imRegal == 0 {
            saetze.append(gesamt == 1 ? siriText("siri.merkliste.keinerEins") : siriText("siri.merkliste.keinerMehr \(gesamt)"))
        } else {
            // „Ein Titel steht“, „Zwei Titel stehen“, „5 Titel stehen“
            let zahl = imRegal <= 3 ? SiriSprache.satzanfang(SiriSprache.zahl(imRegal)) : String(imRegal)
            if imRegal == 1 {
                saetze.append(siriText("siri.merkliste.regal.eins \(gruppen[0].name)"))
            } else if gruppen.count == 1 {
                saetze.append(siriText("siri.merkliste.regal.alle \(zahl) \(gruppen[0].name)"))
            } else {
                var teile = gruppen.prefix(maxStandorte).enumerated().map { index, gruppe in
                    index == 0
                        ? siriText("siri.merkliste.teil.erster \(wort(gruppe.eintraege.count)) \(gruppe.name)")
                        : siriText("siri.merkliste.teil.weiter \(wort(gruppe.eintraege.count)) \(gruppe.name)")
                }
                let uebrig = gruppen.dropFirst(maxStandorte).reduce(0) { $0 + $1.eintraege.count }
                if uebrig > 0 { teile.append(siriText("siri.merkliste.teil.uebrig \(wort(uebrig))")) }
                // Zwei Standorte stehen wie im Mockup nur mit Komma, ab drei mit „und“ vor dem letzten.
                let liste = teile.count >= 3 ? SiriSprache.aufzaehlung(teile) : teile.joined(separator: ", ")
                saetze.append(siriText("siri.merkliste.regal.liste \(zahl) \(liste)"))
            }
        }

        if ausgeliehen > 0 {
            let wer = SiriSprache.satzanfang(wort(ausgeliehen))
            saetze.append(ausgeliehen == 1 ? siriText("siri.merkliste.ausgeliehen.eins \(wer)") : siriText("siri.merkliste.ausgeliehen.mehr \(wer)"))
        }
        if online > 0 {
            let wer = SiriSprache.satzanfang(wort(online))
            saetze.append(online == 1 ? siriText("siri.merkliste.online.eins \(wer)") : siriText("siri.merkliste.online.mehr \(wer)"))
        }
        if unbekannt > 0 {
            saetze.append(unbekannt == 1 ? siriText("siri.merkliste.standortUnbekannt.eins") : siriText("siri.merkliste.standortUnbekannt.mehr \(unbekannt)"))
        }
        // Die Gefundenen kommen ans Ende, auch hinter den Standort-Satz: „Einen hast du schon gefunden.“, „Zwei hast du
        // schon gefunden.“ (Zahlwort bis drei, sonst die Ziffer).
        if gefunden > 0 {
            saetze.append(
                gefunden == 1
                    ? siriText("siri.merkliste.gefunden.eins")
                    : siriText("siri.merkliste.gefunden.mehr \(wort(gefunden)) \(SiriSprache.satzanfang(wort(gefunden)))")
            )
        }
        return saetze.joined(separator: " ")
    }

    // MARK: Karte

    private static func karte(gruppen: [Gruppe], imRegal: Int, nichtImRegal: Int, gefunden: Int) -> SiriMerklisteKarte? {
        var uebrig = maxZeilen
        var standorte: [SiriMerklisteKarte.Standort] = []
        for gruppe in gruppen where uebrig > 0 {
            let sichtbar = gruppe.eintraege.prefix(uebrig)
            uebrig -= sichtbar.count
            standorte.append(.init(
                name: gruppe.name, anzahl: gruppe.eintraege.count,
                titel: sichtbar.map { .init(id: $0.eintrag.id, titel: $0.eintrag.titel, signatur: $0.signatur) }
            ))
        }
        let weitere = imRegal - standorte.reduce(0) { $0 + $1.titel.count }
        let fussTeile = [
            weitere > 0 ? siriText("siri.merkliste.fuss.weitere \(weitere)") : nil,
            nichtImRegal > 0 ? siriText("siri.merkliste.fuss.nichtImRegal \(nichtImRegal)") : nil,
            gefunden > 0 ? siriText("siri.merkliste.fuss.gefunden \(gefunden)") : nil
        ].compactMap { $0 }
        return SiriMerklisteKarte(
            titel: imRegal == 0 ? siriText("siri.merkliste.karte.nichts") : siriText("siri.merkliste.karte.titel \(imRegal)"),
            untertitel: imRegal == 0 ? siriText("siri.merkliste.karte.alles") : siriText("siri.merkliste.karte.sortiert"),
            standorte: standorte, fuss: fussTeile.joined(separator: " · "), link: DeepLink.merkliste.url
        )
    }
}
