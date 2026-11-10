import Foundation

// MARK: - Daten

/// Alles, was die Widgets aus der App bekommen. Nur Inhalte, die nicht veralten: Speiseplan (heute und nächster
/// Öffnungstag), Öffnungszeiten, Events der nächsten zwei Abende und die IDs gemerkter Events.
/// Nicht hier: Thoska-Guthaben, Ausleihen, Bibliotheks-Token oder andere Kontodaten.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// Immer alle vier Mensen, die sich laden ließen (Reihenfolge wie `MensaVenue.allCases`).
    var mensen: [WidgetMensa] = []
    /// Nicht abgesagte Events von heute und morgen, nach Beginn.
    var events: [WidgetEvent] = []
    var gemerkteEventIDs: [String] = []
    /// Wie viele Veranstaltungen in der Woche ab dem Abend-Bezugstag stehen („Diese Woche: 14 Veranstaltungen“).
    var woche: WidgetWoche?
    /// Wann die App den Speicher zuletzt geschrieben hat.
    var stand: Date?

    func mensa(id: String) -> WidgetMensa? {
        mensen.first { $0.id == id }
    }
}

nonisolated struct WidgetMensa: Codable, Equatable, Sendable, Identifiable {
    /// `MensaVenue.rawValue`, z. B. „mensaEhrenberg“. Dieselbe ID steht im Deeplink.
    var id: String
    /// „Mensa Ehrenberg“
    var name: String
    /// „Ehrenberg“
    var kurzname: String
    var oeffnungszeiten: [WidgetOeffnung] = []
    var heute: WidgetSpeiseplan?
    /// Der nächste Tag nach heute, an dem diese Mensa einen Speiseplan hat.
    var naechsterOeffnungstag: WidgetSpeiseplan?
}

/// Öffnungszeit an einem Wochentag, im Format der API.
nonisolated struct WidgetOeffnung: Codable, Equatable, Sendable {
    /// `mon` … `sun`
    var wochentag: String
    /// `11:00`
    var oeffnet: String
    var schliesst: String
}

nonisolated struct WidgetSpeiseplan: Codable, Equatable, Sendable {
    /// Berliner Tag als `yyyy-MM-dd`.
    var tag: String
    var gerichte: [WidgetGericht]
}

nonisolated struct WidgetGericht: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    /// Gruppe der API, z. B. „Abendessen“.
    var gruppe: String
    var abendessen: Bool
    var preisStudierende: Double?
    var preisBedienstete: Double?
    var preisGaeste: Double?
    var waehrung: String
    var chips: [WidgetChip]
    /// Allergene wie in der API; der Filter „Allergene ausschließen“ prüft sie.
    var allergene: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, name, gruppe, abendessen, preisStudierende, preisBedienstete, preisGaeste, waehrung, chips, allergene
    }
}

extension WidgetGericht {
    // Ältere Dateien kennen `allergene` noch nicht; sie werden beim nächsten Laden neu geschrieben.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        gruppe = try container.decode(String.self, forKey: .gruppe)
        abendessen = try container.decode(Bool.self, forKey: .abendessen)
        preisStudierende = try container.decodeIfPresent(Double.self, forKey: .preisStudierende)
        preisBedienstete = try container.decodeIfPresent(Double.self, forKey: .preisBedienstete)
        preisGaeste = try container.decodeIfPresent(Double.self, forKey: .preisGaeste)
        waehrung = try container.decode(String.self, forKey: .waehrung)
        chips = try container.decode([WidgetChip].self, forKey: .chips)
        allergene = try container.decodeIfPresent([String].self, forKey: .allergene) ?? []
    }
}

nonisolated struct WidgetChip: Codable, Equatable, Sendable, Hashable {
    enum Art: String, Codable, Sendable {
        case gruen, blau, neutral
    }

    var titel: String
    var art: Art
}

nonisolated struct WidgetEvent: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var titel: String
    var beginn: Date
    var ende: Date?
    var ganztaegig: Bool
    var ort: String?
    var veranstalter: String?
    /// Abgesagt: Das Widget zeigt „Fällt aus“ und streicht den Titel durch.
    var abgesagt = false

    init(
        id: String, titel: String, beginn: Date, ende: Date? = nil, ganztaegig: Bool = false,
        ort: String? = nil, veranstalter: String? = nil, abgesagt: Bool = false
    ) {
        self.id = id
        self.titel = titel
        self.beginn = beginn
        self.ende = ende
        self.ganztaegig = ganztaegig
        self.ort = ort
        self.veranstalter = veranstalter
        self.abgesagt = abgesagt
    }

    // Ältere Dateien kennen `abgesagt` noch nicht.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        titel = try container.decode(String.self, forKey: .titel)
        beginn = try container.decode(Date.self, forKey: .beginn)
        ende = try container.decodeIfPresent(Date.self, forKey: .ende)
        ganztaegig = try container.decode(Bool.self, forKey: .ganztaegig)
        ort = try container.decodeIfPresent(String.self, forKey: .ort)
        veranstalter = try container.decodeIfPresent(String.self, forKey: .veranstalter)
        abgesagt = try container.decodeIfPresent(Bool.self, forKey: .abgesagt) ?? false
    }
}

nonisolated struct WidgetWoche: Codable, Equatable, Sendable {
    /// Berliner Tag `yyyy-MM-dd`, ab dem gezählt wurde.
    var von: String
    var anzahl: Int
}

// MARK: - Speicher

/// Der gemeinsame Speicher: eine JSON-Datei im Ordner der App Group. Die App schreibt, die Widgets lesen.
/// Schreiben ersetzt die Datei atomar, damit ein Widget nie eine halbe Datei liest.
nonisolated struct WidgetStore: Sendable {
    private let dateiURL: URL?

    /// - Parameter dateiURL: Ort der Datei. Vorgabe ist die App Group; Tests und Previews geben einen eigenen Ort.
    init(dateiURL: URL? = WidgetStore.standardDatei) {
        self.dateiURL = dateiURL
    }

    static var standardDatei: URL? {
        AppGroup.ordner?.appendingPathComponent("WidgetStore.json")
    }

    /// Der gespeicherte Stand; leer, wenn nichts da ist oder die Datei sich nicht lesen lässt.
    func lesen() -> WidgetSnapshot {
        guard let dateiURL, let daten = try? Data(contentsOf: dateiURL),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: daten) else { return WidgetSnapshot() }
        return snapshot
    }

    /// Ändert den gespeicherten Stand und schreibt ihn. Gibt zurück, ob sich etwas geändert hat
    /// (nur dann lohnt sich ein Neuladen der Widgets).
    @discardableResult
    func aendern(_ aenderung: (inout WidgetSnapshot) -> Void) -> Bool {
        guard let dateiURL else { return false }
        let alt = lesen()
        var neu = alt
        aenderung(&neu)
        guard neu != alt else { return false }
        neu.stand = .now
        guard let daten = try? JSONEncoder().encode(neu) else { return false }
        do {
            try daten.write(to: dateiURL, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}
