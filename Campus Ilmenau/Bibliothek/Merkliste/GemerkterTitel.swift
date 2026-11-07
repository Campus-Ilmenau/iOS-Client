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

    init(
        id: String,
        titel: String,
        personen: String = "",
        jahr: String? = nil,
        medientyp: String = "print_book",
        coverURL: URL? = nil,
        gemerktAm: Date = .now
    ) {
        self.id = id
        self.titel = titel
        self.personen = personen
        self.jahr = jahr
        self.medientyp = medientyp
        self.coverURL = coverURL
        self.gemerktAm = gemerktAm
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
