import Foundation

// Modelle der Events-API `/v1/events` (hintergrundsystem). Lesend, ohne Anmeldung.
// Aufgebaut nach den echten Antworten der Dev-API (Stand 5.11.2026).

// MARK: - Kalender

/// Alle Tage und Uhrzeiten der Veranstaltungen laufen in der Zeitzone Europe/Berlin, nicht in der des Geräts.
enum EventKalender {
    static let zeitzone = TimeZone(identifier: "Europe/Berlin") ?? .gmt

    static let kalender: Calendar = {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zeitzone
        kalender.locale = Locale(identifier: "de_DE")
        return kalender
    }()

    /// Beginn des Berliner Tages.
    static func tagesbeginn(_ datum: Date) -> Date {
        kalender.startOfDay(for: datum)
    }

    static func tag(_ datum: Date, plus tage: Int) -> Date {
        kalender.date(byAdding: .day, value: tage, to: tagesbeginn(datum)) ?? datum
    }

    /// `YYYY-MM-DD` des Berliner Tages (so erwartet es `date`).
    static func berlinDatum(_ datum: Date) -> String {
        format(datum, "yyyy-MM-dd", zeitzone: zeitzone)
    }

    /// `YYYY-MM-DD` des UTC-Tages (so zählen `from` und `to`).
    static func utcDatum(_ datum: Date) -> String {
        format(datum, "yyyy-MM-dd", zeitzone: .gmt)
    }

    static func format(_ datum: Date, _ muster: String, zeitzone: TimeZone = EventKalender.zeitzone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = zeitzone
        formatter.dateFormat = muster
        return formatter.string(from: datum)
    }
}

// MARK: - Status

/// Zustand einer Veranstaltung. Unbekannte Werte der API gelten als „findet statt“.
enum EventStatus: String, Hashable, Sendable {
    case findetStatt
    case unbestaetigt
    case abgesagt

    /// `scheduled`, `tentative`, `cancelled`; alles andere (und fehlend) ist „findet statt“.
    init(apiWert: String?) {
        switch (apiWert ?? "").trimmingCharacters(in: .whitespaces).lowercased() {
        case "tentative", "unconfirmed": self = .unbestaetigt
        case "cancelled", "canceled": self = .abgesagt
        default: self = .findetStatt
        }
    }

    var apiWert: String {
        switch self {
        case .findetStatt: "scheduled"
        case .unbestaetigt: "tentative"
        case .abgesagt: "cancelled"
        }
    }
}

// MARK: - Veranstaltung

/// Eine Veranstaltung oder Frist. Alles außer Titel, Beginn und Status ist optional; fehlende Felder sind kein Fehler.
struct CampusEvent: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var titel: String
    var beginn: Date
    var ende: Date?
    var ganztaegig: Bool
    var status: EventStatus
    var ort: String?
    var adresse: String?
    var veranstalter: String?
    /// ID des Veranstalters laut API (zum Filtern, ohne den Namen zu kennen).
    var veranstalterID: String?
    /// Reiner Text, mit Absätzen.
    var beschreibung: String?
    var bildURL: URL?
    var infoURL: URL?
    var ticketURL: URL?
    /// „Veranstaltung“, „Frist“ …
    var kategorie: String?

    init(
        id: String,
        titel: String,
        beginn: Date,
        ende: Date? = nil,
        ganztaegig: Bool = false,
        status: EventStatus = .findetStatt,
        ort: String? = nil,
        adresse: String? = nil,
        veranstalter: String? = nil,
        veranstalterID: String? = nil,
        beschreibung: String? = nil,
        bildURL: URL? = nil,
        infoURL: URL? = nil,
        ticketURL: URL? = nil,
        kategorie: String? = nil
    ) {
        self.id = id
        self.titel = titel
        self.beginn = beginn
        self.ende = ende
        self.ganztaegig = ganztaegig
        self.status = status
        self.ort = ort
        self.adresse = adresse
        self.veranstalter = veranstalter
        self.veranstalterID = veranstalterID
        self.beschreibung = beschreibung
        self.bildURL = bildURL
        self.infoURL = infoURL
        self.ticketURL = ticketURL
        self.kategorie = kategorie
    }

    // MARK: Codable (im Format der API)

    private enum CodingKeys: String, CodingKey {
        case id, title, category, startAt, endAt, allDay, status, location, locationAddress
        case organizer, description, imageUrl, sourceUrl, ticketUrl
    }

    private struct Organizer: Codable {
        let id: String?
        let name: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        titel = try container.decode(String.self, forKey: .title)

        // Das Datum liest der Event selbst: die API schickt ISO 8601 mit Millisekunden.
        let startText = try container.decode(String.self, forKey: .startAt)
        guard let start = LibraryDateParsing.date(from: startText) else {
            throw DecodingError.dataCorruptedError(forKey: .startAt, in: container, debugDescription: "Ungültiges Datum: \(startText)")
        }
        beginn = start
        ende = (try? container.decodeIfPresent(String.self, forKey: .endAt)).flatMap { $0 }.flatMap(LibraryDateParsing.date(from:))

        ganztaegig = (try? container.decodeIfPresent(Bool.self, forKey: .allDay)) ?? false
        status = EventStatus(apiWert: (try? container.decodeIfPresent(String.self, forKey: .status)) ?? nil)
        ort = Self.text(container, .location)
        adresse = Self.text(container, .locationAddress)
        let organizer = (try? container.decodeIfPresent(Organizer.self, forKey: .organizer)) ?? nil
        veranstalter = organizer?.name.flatMap(Self.sauber)
        veranstalterID = organizer?.id.flatMap(Self.sauber)
        beschreibung = Self.text(container, .description)
        bildURL = Self.webURL(container, .imageUrl)
        infoURL = Self.webURL(container, .sourceUrl)
        ticketURL = Self.webURL(container, .ticketUrl)
        kategorie = Self.text(container, .category).map(Self.kategorieName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(titel, forKey: .title)
        try container.encode(Self.isoText(beginn), forKey: .startAt)
        try container.encodeIfPresent(ende.map(Self.isoText), forKey: .endAt)
        try container.encode(ganztaegig, forKey: .allDay)
        try container.encode(status.apiWert, forKey: .status)
        try container.encodeIfPresent(ort, forKey: .location)
        try container.encodeIfPresent(adresse, forKey: .locationAddress)
        if veranstalter != nil || veranstalterID != nil {
            try container.encode(Organizer(id: veranstalterID, name: veranstalter), forKey: .organizer)
        }
        try container.encodeIfPresent(beschreibung, forKey: .description)
        try container.encodeIfPresent(bildURL?.absoluteString, forKey: .imageUrl)
        try container.encodeIfPresent(infoURL?.absoluteString, forKey: .sourceUrl)
        try container.encodeIfPresent(ticketURL?.absoluteString, forKey: .ticketUrl)
        try container.encodeIfPresent(kategorie, forKey: .category)
    }

    private static func text(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        ((try? container.decodeIfPresent(String.self, forKey: key)) ?? nil).flatMap(sauber)
    }

    /// Nur Webadressen (http, https) sind brauchbare Links; alles andere, auch Text, den `URL` gutmütig übernimmt, entfällt.
    private static func webURL(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> URL? {
        guard let url = container.lenientURL(forKey: key),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else { return nil }
        return url
    }

    /// Entfernt Leerraum an den Rändern; Leeres wird zu `nil`.
    private static func sauber(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Die API schickt `VERANSTALTUNG` und `FRIST`; angezeigt wird „Veranstaltung“ und „Frist“.
    private static func kategorieName(_ roh: String) -> String {
        roh.prefix(1).uppercased() + roh.dropFirst().lowercased()
    }

    private static func isoText(_ datum: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: datum)
    }

    // MARK: Abgeleitet

    /// Erster Berliner Tag der Veranstaltung.
    var ersterTag: Date { EventKalender.tagesbeginn(beginn) }

    /// Letzter Berliner Tag. Das Ende ganztägiger Veranstaltungen ist exklusiv (Mitternacht), ein Ende genau um
    /// Mitternacht gehört zum Vortag, und eine Nachtveranstaltung, die bis 06:00 am Folgetag geht, zählt noch zum Starttag.
    var letzterTag: Date {
        guard let ende, ende > beginn else { return ersterTag }
        let endTag = EventKalender.tagesbeginn(ende)
        if ende == endTag {
            return max(ersterTag, EventKalender.tagesbeginn(ende.addingTimeInterval(-1)))
        }
        if endTag == ersterTag { return ersterTag }
        if endTag == EventKalender.tag(ersterTag, plus: 1), ende.timeIntervalSince(endTag) <= 6 * 3600 {
            return ersterTag
        }
        return endTag
    }

    var istMehrtaegig: Bool { letzterTag > ersterTag }

    /// Findet die Veranstaltung an diesem (Berliner) Tag statt? Mehrtägige zählen an jedem Tag dazwischen.
    func laeuftAm(_ tag: Date) -> Bool {
        let tagesbeginn = EventKalender.tagesbeginn(tag)
        return tagesbeginn >= ersterTag && tagesbeginn <= letzterTag
    }

    var istFrist: Bool { kategorie?.lowercased() == "frist" }

    /// Der Veranstalter für die Anzeige. `nil`, wenn er fehlt oder gleich dem Ort ist.
    var veranstalterAnzeigen: String? {
        guard let veranstalter else { return nil }
        let name = veranstalter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let ort, ort.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(name) == .orderedSame {
            return nil
        }
        return name
    }
}

// MARK: - Veranstalter

/// Ein Veranstalter mit der Zahl seiner kommenden Veranstaltungen.
struct Veranstalter: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let anzahlKommende: Int

    init(id: String = "", name: String, anzahlKommende: Int) {
        self.id = id.isEmpty ? name : id
        self.name = name
        self.anzahlKommende = anzahlKommende
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, upcomingEventCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        self.name = name
        id = (try? container.decodeIfPresent(String.self, forKey: .id)).flatMap { $0 } ?? name
        anzahlKommende = (try? container.decodeIfPresent(Int.self, forKey: .upcomingEventCount)).flatMap { $0 } ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(anzahlKommende, forKey: .upcomingEventCount)
    }
}

// MARK: - Seite

/// Eine Seite der Liste (bis zu 100 Veranstaltungen).
struct EventSeite: Equatable, Sendable {
    var events: [CampusEvent]
    var seite: Int
    var hatWeitere: Bool
    /// Gesamtzahl für die gesetzten Filter laut API.
    var gesamt: Int
}
