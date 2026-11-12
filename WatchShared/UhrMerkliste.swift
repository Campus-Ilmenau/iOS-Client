import Foundation

// Die Merkliste der Bibliothek auf der Apple Watch: Datentypen, Abgleich mit dem iPhone und die Aufteilung in
// Abschnitte. Reine Logik ohne UI und ohne Netz, damit sie sich testen lässt.
// Diese Datei gehört zu iPhone-App und Watch-App, ihre Typen sind darum ausdrücklich `nonisolated`.

// MARK: - Daten

/// Ein Titel der Merkliste, wie ihn die Uhr kennt: ID, Titel, wann gefunden und die Zeit der letzten Aktion.
nonisolated struct UhrMerklisteEintrag: Equatable, Sendable, Identifiable {
    let id: String
    var titel: String
    /// `nil`: noch offen.
    var foundAt: Date?
    /// Zeitpunkt der letzten Aktion an diesem Eintrag (nicht der Übertragung).
    var changedAt: Date

    var istGefunden: Bool { foundAt != nil }

    /// Für `updateApplicationContext`: nur Property-List-Typen (Daten als Sekunden seit 2001).
    var kontext: [String: Any] {
        var kontext: [String: Any] = ["id": id, "titel": titel, "changedAt": changedAt.timeIntervalSinceReferenceDate]
        if let foundAt { kontext["foundAt"] = foundAt.timeIntervalSinceReferenceDate }
        return kontext
    }

    init(id: String, titel: String, foundAt: Date? = nil, changedAt: Date) {
        self.id = id
        self.titel = titel
        self.foundAt = foundAt
        self.changedAt = changedAt
    }

    init?(kontext: [String: Any]) {
        guard let id = kontext["id"] as? String, let titel = kontext["titel"] as? String,
              let geaendert = kontext["changedAt"] as? Double else { return nil }
        self.id = id
        self.titel = titel
        changedAt = Date(timeIntervalSinceReferenceDate: geaendert)
        foundAt = (kontext["foundAt"] as? Double).map { Date(timeIntervalSinceReferenceDate: $0) }
    }
}

/// Was die Uhr dem iPhone meldet: `{id, found, changedAt}`, per `transferUserInfo`.
nonisolated struct UhrAenderung: Equatable, Sendable {
    let id: String
    let found: Bool
    let changedAt: Date

    var kontext: [String: Any] {
        ["id": id, "found": found, "changedAt": changedAt.timeIntervalSinceReferenceDate]
    }

    init(id: String, found: Bool, changedAt: Date) {
        self.id = id
        self.found = found
        self.changedAt = changedAt
    }

    init?(kontext: [String: Any]) {
        guard let id = kontext["id"] as? String, let found = kontext["found"] as? Bool,
              let geaendert = kontext["changedAt"] as? Double else { return nil }
        self.id = id
        self.found = found
        changedAt = Date(timeIntervalSinceReferenceDate: geaendert)
    }
}

/// Alles, was das iPhone der Uhr als `applicationContext` schickt: Einstellungen und die ganze Merkliste. Ein
/// Kontext ersetzt den vorigen ganz, darum steht beides in einem Wörterbuch.
nonisolated struct UhrKontext: Equatable, Sendable {
    var einstellungen: UhrEinstellungen
    /// `nil`: nicht mitgeschickt (ältere iPhone-App), die Uhr behält ihre Liste.
    var merkliste: [UhrMerklisteEintrag]?

    init(einstellungen: UhrEinstellungen, merkliste: [UhrMerklisteEintrag]?) {
        self.einstellungen = einstellungen
        self.merkliste = merkliste
    }

    var kontext: [String: Any] {
        var kontext = einstellungen.kontext
        if let merkliste { kontext["merkliste"] = merkliste.map(\.kontext) }
        return kontext
    }

    /// `nil`, wenn das Wörterbuch leer ist.
    init?(kontext: [String: Any]) {
        guard let einstellungen = UhrEinstellungen(kontext: kontext) else { return nil }
        self.einstellungen = einstellungen
        merkliste = (kontext["merkliste"] as? [[String: Any]]).map { $0.compactMap(UhrMerklisteEintrag.init(kontext:)) }
    }
}

// MARK: - Konfliktregel

/// Die Konfliktregel zwischen iPhone und Uhr. Das iPhone hat die Datenhoheit; je Eintrag gewinnt die jüngere Aktion
/// (`changedAt`, Zeitpunkt der Aktion, nicht der Übertragung).
nonisolated enum MerklisteAbgleich {
    enum Grund: Equatable, Sendable {
        /// Der Eintrag wurde auf dem iPhone entfernt (Grabstein): Er bleibt gelöscht.
        case geloescht
        /// Die ID kennt das iPhone nicht (und hat auch keinen Grabstein).
        case unbekannt
        /// Das iPhone hat eine jüngere Aktion.
        case aelter
        /// Dieselbe Änderung ist schon angewendet (doppelte Zustellung).
        case duplikat
        /// Gleicher Zeitpunkt, aber anderer Zustand: Das iPhone gewinnt.
        case gleichzeitig
    }

    enum Entscheidung: Equatable, Sendable {
        /// Setze `foundAt` und `changedAt` des Eintrags.
        case uebernehmen(foundAt: Date?, changedAt: Date)
        case verwerfen(Grund)
    }

    /// Soll das iPhone eine Änderung der Uhr übernehmen?
    /// - Parameters:
    ///   - aktuell: Stand des Eintrags auf dem iPhone, `nil` ohne Eintrag.
    ///   - geloescht: Zu der ID gibt es einen Grabstein.
    static func entscheide(
        _ aenderung: UhrAenderung, aktuell: (foundAt: Date?, changedAt: Date)?, geloescht: Bool
    ) -> Entscheidung {
        if geloescht { return .verwerfen(.geloescht) }
        guard let aktuell else { return .verwerfen(.unbekannt) }
        if aenderung.changedAt < aktuell.changedAt { return .verwerfen(.aelter) }
        if aenderung.changedAt == aktuell.changedAt {
            return .verwerfen((aktuell.foundAt != nil) == aenderung.found ? .duplikat : .gleichzeitig)
        }
        // `foundAt` ist der Zeitpunkt der jüngsten „Gefunden“-Aktion. Das hängt nicht von der Reihenfolge ab, in der die
        // Änderungen ankommen: Am Ende steht immer die jüngste.
        return .uebernehmen(foundAt: aenderung.found ? aenderung.changedAt : nil, changedAt: aenderung.changedAt)
    }

    /// Die Uhr bekommt den Stand des iPhones: Reihenfolge, Titel und Auswahl der Einträge gelten vom iPhone. Hat die Uhr
    /// an einem Eintrag eine jüngere Aktion, die das iPhone noch nicht kennt, bleibt sie, bis es sie bestätigt.
    static func verschmelze(iPhone: [UhrMerklisteEintrag], lokal: [UhrMerklisteEintrag]) -> [UhrMerklisteEintrag] {
        let lokale = Dictionary(lokal.map { ($0.id, $0) }, uniquingKeysWith: { erstes, _ in erstes })
        return iPhone.map { eintrag in
            guard let eigener = lokale[eintrag.id], eigener.changedAt > eintrag.changedAt else { return eintrag }
            var neu = eintrag
            neu.foundAt = eigener.foundAt
            neu.changedAt = eigener.changedAt
            return neu
        }
    }
}

// MARK: - Standort und Signatur

/// Wo ein Titel steht, aus `/v1/library/availability`. Wird nicht auf dem iPhone gespeichert, die Uhr merkt sich den
/// letzten Stand nur zum Anzeigen.
nonisolated enum UhrRegalStand: Equatable, Sendable, Codable {
    /// Im Regal: ausleihbar oder nur vor Ort.
    case regal(standort: String, signatur: String, nurVorOrt: Bool)
    case ausgeliehen(bis: Date?)
    case online
    case unbekannt

    /// Ein Exemplar aus der Antwort der API.
    struct Exemplar: Equatable, Sendable {
        let signatur: String
        let standort: String?
        /// `available`, `on_loan`, `reference_only`, `online`
        let status: String
        let faellig: Date?

        init(signatur: String, standort: String?, status: String, faellig: Date? = nil) {
            self.signatur = signatur
            self.standort = standort
            self.status = status
            self.faellig = faellig
        }
    }

    /// Das erste Exemplar mit `available` bzw. `reference_only` und einem Standort gibt Standort und Signatur; sonst
    /// ausgeliehen (frühestes Rückgabedatum), online oder unbekannt.
    init(gesamtstatus: String?, exemplare: [Exemplar]) {
        func leer(_ text: String?) -> String? {
            let text = text?.trimmingCharacters(in: .whitespacesAndNewlines)
            return text?.isEmpty == false ? text : nil
        }
        if let regal = exemplare.first(where: { ($0.status == "available" || $0.status == "reference_only") && leer($0.standort) != nil }),
           let standort = leer(regal.standort) {
            self = .regal(standort: standort, signatur: leer(regal.signatur) ?? "", nurVorOrt: regal.status == "reference_only")
        } else if exemplare.contains(where: { $0.status == "on_loan" }) || gesamtstatus == "on_loan" {
            self = .ausgeliehen(bis: exemplare.filter { $0.status == "on_loan" }.compactMap(\.faellig).min())
        } else if gesamtstatus == "online" || exemplare.contains(where: { $0.status == "online" }) {
            self = .online
        } else {
            self = .unbekannt
        }
    }
}

// MARK: - Abschnitte

/// Die Merkliste, wie die Uhr sie zeigt: „Im Regal · n“ (nach Standort), „Nicht im Regal“ und „Gefunden · n“.
nonisolated struct UhrMerklisteAnzeige: Equatable, Sendable {
    struct Zeile: Identifiable, Equatable, Sendable {
        enum ChipArt: Equatable, Sendable { case blau, neutral }

        let id: String
        let titel: String
        let gefunden: Bool
        /// Nur im Abschnitt „Im Regal“.
        let standort: String?
        let signatur: String?
        let chip: String?
        let chipArt: ChipArt

        /// VoiceOver wie im Artboard: „Titel, 60 ELT, Signatur ELT ZQ 5200“, „…, gefunden“, „…, Ausgeliehen bis 17. Nov.“.
        var beschriftung: String {
            if gefunden { return "\(titel), gefunden" }
            if let standort { return "\(titel), \(standort)" + (signatur.map { $0.isEmpty ? "" : ", Signatur \($0)" } ?? "") }
            if let chip { return "\(titel), \(chip)" }
            return titel
        }
    }

    struct Abschnitt: Identifiable, Equatable, Sendable {
        enum Art: Equatable, Sendable { case imRegal, nichtImRegal, gefunden }
        let art: Art
        /// „Im Regal · 2“, „Nicht im Regal“, „Gefunden · 1“
        let titel: String
        let zeilen: [Zeile]
        var id: Art { art }
    }

    var abschnitte: [Abschnitt]
    /// „3 im Regal · 1 gefunden“
    var zusammenfassung: String
    var istLeer: Bool { abschnitte.isEmpty }

    static func erstelle(eintraege: [UhrMerklisteEintrag], staende: [String: UhrRegalStand]) -> UhrMerklisteAnzeige {
        var regal: [(zeile: Zeile, standort: String, signatur: String)] = []
        var anderswo: [Zeile] = []
        var gefunden: [(zeile: Zeile, am: Date)] = []

        for eintrag in eintraege {
            if let am = eintrag.foundAt {
                gefunden.append((
                    Zeile(id: eintrag.id, titel: eintrag.titel, gefunden: true, standort: nil, signatur: nil, chip: nil, chipArt: .neutral), am
                ))
                continue
            }
            func ohneStandort(_ chip: String) -> Zeile {
                Zeile(id: eintrag.id, titel: eintrag.titel, gefunden: false, standort: nil, signatur: nil, chip: chip, chipArt: .neutral)
            }
            switch staende[eintrag.id] {
            case .regal(let standort, let signatur, let nurVorOrt)?:
                regal.append((
                    Zeile(
                        id: eintrag.id, titel: eintrag.titel, gefunden: false, standort: standort, signatur: signatur,
                        chip: nurVorOrt ? "Nur vor Ort" : nil, chipArt: nurVorOrt ? .blau : .neutral
                    ),
                    standort, signatur
                ))
            case .ausgeliehen(let bis)?:
                anderswo.append(ohneStandort(bis.map { "Ausgeliehen bis \(kurzesDatum($0))" } ?? "Ausgeliehen"))
            case .online?:
                anderswo.append(ohneStandort("Online"))
            case .unbekannt?:
                anderswo.append(ohneStandort("Standort unbekannt"))
            case nil:
                // Der Stand lädt noch.
                anderswo.append(ohneStandort("…"))
            }
        }

        // Natürliche Sortierung nach Standort („60 ELT“ vor „70 MB“, „9 X“ vor „40 PHY“), dann Signatur und Titel.
        regal.sort { a, b in
            for (x, y) in [(a.standort, b.standort), (a.signatur, b.signatur), (a.zeile.titel, b.zeile.titel)] {
                let ergebnis = x.compare(y, options: [.numeric, .caseInsensitive], locale: Locale(identifier: "de_DE"))
                if ergebnis != .orderedSame { return ergebnis == .orderedAscending }
            }
            return false
        }
        // Zuletzt gefunden zuerst.
        gefunden.sort { $0.am > $1.am }

        var abschnitte: [Abschnitt] = []
        if !regal.isEmpty {
            abschnitte.append(Abschnitt(art: .imRegal, titel: "Im Regal · \(regal.count)", zeilen: regal.map(\.zeile)))
        }
        if !anderswo.isEmpty {
            abschnitte.append(Abschnitt(art: .nichtImRegal, titel: "Nicht im Regal", zeilen: anderswo))
        }
        if !gefunden.isEmpty {
            abschnitte.append(Abschnitt(art: .gefunden, titel: "Gefunden · \(gefunden.count)", zeilen: gefunden.map(\.zeile)))
        }
        return UhrMerklisteAnzeige(
            abschnitte: abschnitte, zusammenfassung: "\(regal.count) im Regal · \(gefunden.count) gefunden"
        )
    }

    /// „17. Nov.“
    static func kurzesDatum(_ datum: Date) -> String {
        EventKalender.format(datum, "d. MMM")
    }
}
