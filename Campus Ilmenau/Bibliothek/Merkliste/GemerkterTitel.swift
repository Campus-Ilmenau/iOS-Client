import Foundation

/// Ein Titel auf der Merkliste. Gespeichert wird nur, was man zum Anzeigen braucht; den Verfügbarkeitsstatus nicht,
/// der wird beim Öffnen der Liste frisch geladen.
struct GemerkterTitel: Codable, Identifiable, Equatable, Hashable {
    /// ID wie die Katalog-API sie liefert: `med_<PPN>`.
    let id: String
    var titel: String
    /// „Vorname Nachname, …“, schon so formatiert, wie die Zeile sie zeigt.
    var personen: String
    var jahr: String?
    /// Code der Medienart (`print_book`, `ebook`, `journal`, …).
    var medientyp: String
    var coverURL: URL?
    var gemerktAm: Date
    /// Wann der Titel am Regal als „Gefunden“ abgehakt wurde. `nil`: noch offen.
    var foundAt: Date?
    /// Zeitpunkt der letzten Aktion an diesem Eintrag (Merken, Abhaken, Zurücknehmen, Wiederherstellen). Beim
    /// Abgleich mit der Apple Watch gewinnt je Eintrag die jüngere Aktion.
    var changedAt: Date

    var istGefunden: Bool { foundAt != nil }

    init(
        id: String,
        titel: String,
        personen: String = "",
        jahr: String? = nil,
        medientyp: String = "print_book",
        coverURL: URL? = nil,
        gemerktAm: Date = .now,
        foundAt: Date? = nil,
        changedAt: Date? = nil
    ) {
        self.id = id
        self.titel = titel
        self.personen = personen
        self.jahr = jahr
        self.medientyp = medientyp
        self.coverURL = coverURL
        self.gemerktAm = gemerktAm
        self.foundAt = foundAt
        self.changedAt = changedAt ?? gemerktAm
    }

    private enum CodingKeys: String, CodingKey {
        case id, titel, personen, jahr, medientyp, coverURL, gemerktAm, foundAt, changedAt
    }

    /// Dateien aus früheren Versionen kennen `foundAt` und `changedAt` nicht: dann offen, und `changedAt` ist
    /// der Zeitpunkt des Merkens.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        titel = try container.decode(String.self, forKey: .titel)
        personen = try container.decode(String.self, forKey: .personen)
        jahr = try container.decodeIfPresent(String.self, forKey: .jahr)
        medientyp = try container.decode(String.self, forKey: .medientyp)
        coverURL = try container.decodeIfPresent(URL.self, forKey: .coverURL)
        gemerktAm = try container.decode(Date.self, forKey: .gemerktAm)
        foundAt = try container.decodeIfPresent(Date.self, forKey: .foundAt)
        changedAt = try container.decodeIfPresent(Date.self, forKey: .changedAt) ?? gemerktAm
    }

    /// Aus einem Titel des Katalogs. `coverURL` ist die absolute Adresse, wenn es ein Cover gibt.
    init(media: LibraryMedia, coverURL: URL?, gemerktAm: Date = .now) {
        self.init(
            id: media.id,
            titel: media.title,
            personen: media.personsLine,
            jahr: media.year,
            medientyp: media.mediaType.code,
            coverURL: coverURL,
            gemerktAm: gemerktAm
        )
    }

    /// Von einer früheren Version übernommen: nur die ID ist bekannt, die Daten kommen beim Öffnen der Merkliste nach.
    var istUnvollstaendig: Bool { titel.isEmpty }

    /// Titel für die Anzeige; solange er unbekannt ist, die Nummer.
    var anzeigeTitel: String {
        titel.isEmpty ? "Titel \(id.replacingOccurrences(of: "med_", with: ""))" : titel
    }

    var mediaType: LibraryMediaType { LibraryMediaType(code: medientyp) }

    /// „Personen · Jahr“, ohne Leeres.
    var untertitel: String {
        [personen, jahr ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Ein Titel für die Titel-Ansicht, bis das Detail geladen ist.
    var alsMedia: LibraryMedia {
        LibraryMedia(
            id: id,
            ppn: id.hasPrefix("med_") ? String(id.dropFirst(4)) : nil,
            title: anzeigeTitel,
            subtitle: nil,
            mediaType: mediaType
        )
    }
}

/// Grabstein eines entfernten Eintrags. Bleibt 30 Tage, damit eine verspätete Änderung von der Apple Watch
/// den Eintrag nicht zurückholt.
struct MerklisteGrabstein: Codable, Equatable {
    let id: String
    var deletedAt: Date
}

extension LibraryMediaType {
    /// Code der API (`print_book`, `ebook`, `journal`), bei Unbekanntem der Rohwert.
    var code: String {
        switch self {
        case .printBook: "print_book"
        case .ebook: "ebook"
        case .journal: "journal"
        case .other(let raw): raw
        }
    }
}
