import Foundation

// Modelle der Katalog-API `/v1/library/*` (hintergrundsystem). Ohne Anmeldung, nur lesend.
// Aufgebaut nach den echten Antworten der Dev-API (Stand 4.11.2026). Wo die API etwas nicht zeigte,
// steht es als Annahme dabei.

// MARK: - Codes mit Ersatzwert

/// Codes der API (`print_book`, `on_loan`, …). Unbekannte Werte brechen das Dekodieren nicht ab,
/// sondern landen im Fall `other`, damit eine neue Ausprägung der API die App nicht lahmlegt.
protocol LibraryCoded: Decodable {
    init(code: String)
}

extension LibraryCoded {
    init(from decoder: Decoder) throws {
        self.init(code: try decoder.singleValueContainer().decode(String.self))
    }
}

/// Medienart eines Titels.
enum LibraryMediaType: Equatable, LibraryCoded {
    case printBook
    case ebook
    case journal
    case other(String)

    init(code: String) {
        switch code {
        case "print_book": self = .printBook
        case "ebook": self = .ebook
        case "journal": self = .journal
        default: self = .other(code)
        }
    }

    var displayName: String {
        switch self {
        case .printBook: "Buch"
        case .ebook: "E-Book"
        case .journal: "Zeitschrift"
        case .other: "Medium"
        }
    }
}

/// Status eines Exemplars bzw. Gesamtstatus eines Titels. Die API liefert nur Codes,
/// die Texte stehen in `Uebergabe.md` (Abschnitt „Status-Badges“).
enum LibraryAvailabilityStatus: Equatable, LibraryCoded {
    case available
    case onLoan
    case referenceOnly
    case online
    case unknown

    init(code: String) {
        switch code {
        case "available": self = .available
        case "on_loan": self = .onLoan
        case "reference_only": self = .referenceOnly
        case "online": self = .online
        default: self = .unknown
        }
    }

    /// Text des Badges. `dueDate` ergänzt bei „ausgeliehen“ das Rückgabedatum.
    func displayText(dueDate: Date? = nil) -> String {
        switch self {
        case .available: "Ausleihbar"
        case .onLoan:
            if let dueDate { "Ausgeliehen bis \(BibliothekFormat.shortDate(dueDate))" } else { "Ausgeliehen" }
        case .referenceOnly: "Nur vor Ort"
        case .online: "Online lesen"
        case .unknown: "Status unbekannt"
        }
    }
}

/// Zustand des Covers.
enum LibraryCoverStatus: Equatable, LibraryCoded {
    case found
    case pending
    /// Kein Cover vorhanden (`none`).
    case absent
    case disabled
    case other(String)

    init(code: String) {
        switch code {
        case "found": self = .found
        case "pending": self = .pending
        case "none": self = .absent
        case "disabled": self = .disabled
        default: self = .other(code)
        }
    }
}

/// Woher die Treffer einer Suche stammen.
enum LibrarySearchSource: Equatable, LibraryCoded {
    /// Nur Bestand der UB Ilmenau.
    case local
    /// Wenig im Bestand, ergänzt aus dem Gesamtkatalog.
    case mixed
    /// Gesamtkatalog.
    case catalog
    case other(String)

    init(code: String) {
        switch code {
        case "local": self = .local
        case "mixed": self = .mixed
        case "catalog": self = .catalog
        default: self = .other(code)
        }
    }
}

/// Wie ein Treffer gefunden wurde (`match.stage`). Laut API-Team: `exact`, `corrected`, `relaxed`, `catalog`.
enum LibraryMatchStage: Equatable, LibraryCoded {
    case exact
    case corrected
    /// Gelockerte Suche (weniger strenge Treffer).
    case relaxed
    /// Der Treffer kommt aus dem Gesamtkatalog (Markierung bei `mixed`).
    case catalog
    case other(String)

    init(code: String) {
        switch code {
        case "exact": self = .exact
        case "corrected": self = .corrected
        case "relaxed": self = .relaxed
        case "catalog": self = .catalog
        default: self = .other(code)
        }
    }
}

/// Feld, in dem ein Treffer gefunden wurde (`match.fields`).
enum LibraryMatchField: Equatable, LibraryCoded {
    case title
    case author
    case subject
    case abstract
    case tableOfContents
    case blurb
    case other(String)

    init(code: String) {
        switch code {
        case "title": self = .title
        case "author": self = .author
        case "subject": self = .subject
        case "abstract": self = .abstract
        case "toc": self = .tableOfContents
        case "blurb": self = .blurb
        default: self = .other(code)
        }
    }
}

/// Stand der Inhaltsangaben (Inhaltsverzeichnis, Klappentext) eines Titels.
/// Bei `disabled` fehlt `contents` ganz.
enum LibraryContentsStatus: Equatable, LibraryCoded {
    case available
    case pending
    case unavailable
    case disabled
    case other(String)

    init(code: String) {
        switch code {
        case "available": self = .available
        case "pending": self = .pending
        case "unavailable": self = .unavailable
        case "disabled": self = .disabled
        default: self = .other(code)
        }
    }
}

// MARK: - Titel

/// Cover eines Titels. `url` ist ein Pfad relativ zur Basis-URL, siehe `LibraryCatalogService.coverURL(for:)`.
struct LibraryCover: Decodable, Equatable {
    let status: LibraryCoverStatus
    let url: String?
    let width: Int?
    let height: Int?

    static let missing = LibraryCover(status: .absent, url: nil, width: nil, height: nil)
}

/// Zusätzlicher Link zu einem Titel (`table_of_contents`, `excerpt`, `blurb`, `other`).
struct LibraryLink: Decodable, Equatable {
    let kind: String
    let url: URL?
    let mimeType: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(String.self, forKey: .kind)
        url = container.lenientURL(forKey: .url)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
    }

    private enum CodingKeys: String, CodingKey { case kind, url, mimeType }
}

/// Warum ein Treffer passt (`match`). Gibt es nur bei `in=local` (und ohne `in`, wenn der Bestand durchsucht wird);
/// Antworten mit `in=catalog` haben kein `match`, dort stammt jeder Treffer aus dem Katalog.
struct LibraryMatch: Decodable, Equatable {
    /// Felder mit Treffer. Bei `stage == .catalog` leer.
    let fields: [LibraryMatchField]
    let stage: LibraryMatchStage?
    /// Textausschnitt (etwa 80 Zeichen vor und nach dem ersten Treffer, mit „…“ an den Rändern).
    /// Nur bei `in=content`, sonst `nil`. Eine Seitenzahl gibt es dort nicht als eigenes Feld.
    let snippet: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fields = try container.decodeIfPresent([LibraryMatchField].self, forKey: .fields) ?? []
        stage = try container.decodeIfPresent(LibraryMatchStage.self, forKey: .stage)
        snippet = try container.decodeIfPresent(String.self, forKey: .snippet)
    }

    private enum CodingKeys: String, CodingKey { case fields, stage, snippet }

    /// Der Treffer steht im Inhaltsverzeichnis.
    var isInTableOfContents: Bool { fields.contains(.tableOfContents) }

    /// Der Treffer steht im Klappentext.
    var isInBlurb: Bool { fields.contains(.blurb) }
}

/// Ein Titel aus Suche oder Detail. IDs haben die Form `med_<PPN>`.
struct LibraryMedia: Decodable, Identifiable, Equatable {
    let id: String
    let ppn: String?
    let mediaType: LibraryMediaType
    let title: String
    let subtitle: String?
    let authors: [String]
    let edition: String?
    let year: String?
    let publisher: String?
    let isbns: [String]
    /// Sprachcode (MARC), z. B. `ger`. Den Namen liefert `languageName`.
    let language: String?
    let subjects: [String]
    let rvk: [String]
    let onlineUrl: URL?
    let catalogUrl: URL?
    /// Kurzbeschreibung.
    let abstract: String?
    let links: [LibraryLink]
    let fetchedAt: Date?
    let cover: LibraryCover
    let match: LibraryMatch?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ppn = try container.decodeIfPresent(String.self, forKey: .ppn)
        mediaType = try container.decodeIfPresent(LibraryMediaType.self, forKey: .mediaType) ?? .other("")
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        authors = try container.decodeIfPresent([String].self, forKey: .authors) ?? []
        edition = try container.decodeIfPresent(String.self, forKey: .edition)
        year = try container.decodeIfPresent(String.self, forKey: .year)
        publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        isbns = try container.decodeIfPresent([String].self, forKey: .isbns) ?? []
        language = try container.decodeIfPresent(String.self, forKey: .language)
        subjects = try container.decodeIfPresent([String].self, forKey: .subjects) ?? []
        rvk = try container.decodeIfPresent([String].self, forKey: .rvk) ?? []
        onlineUrl = container.lenientURL(forKey: .onlineUrl)
        catalogUrl = container.lenientURL(forKey: .catalogUrl)
        abstract = try container.decodeIfPresent(String.self, forKey: .abstract)
        links = try container.decodeIfPresent([LibraryLink].self, forKey: .links) ?? []
        fetchedAt = try container.decodeIfPresent(Date.self, forKey: .fetchedAt)
        cover = try container.decodeIfPresent(LibraryCover.self, forKey: .cover) ?? .missing
        match = try container.decodeIfPresent(LibraryMatch.self, forKey: .match)
    }

    private enum CodingKeys: String, CodingKey {
        case id, ppn, mediaType, title, subtitle, authors, edition, year, publisher, isbns, language
        case subjects, rvk, onlineUrl, catalogUrl, abstract, links, fetchedAt, cover, match
    }

    /// Sprache als Name („ger“ → „Deutsch“).
    var languageName: String? { language.map(LibraryLanguage.name(forCode:)) }

    /// Ein Titel nur mit ID und Titel, etwa aus einem Eintrag der Ausleihliste. Das Detail ergänzt den Rest beim Laden.
    init(id: String, ppn: String?, title: String, subtitle: String? = nil, mediaType: LibraryMediaType = .printBook) {
        self.id = id
        self.ppn = ppn
        self.mediaType = mediaType
        self.title = title
        self.subtitle = subtitle
        authors = []
        edition = nil
        year = nil
        publisher = nil
        isbns = []
        language = nil
        subjects = []
        rvk = []
        onlineUrl = nil
        catalogUrl = nil
        abstract = nil
        links = []
        fetchedAt = nil
        cover = .missing
        match = nil
    }

    /// Der Treffer stammt aus dem Gesamtkatalog (`match.stage == catalog`, nur bei gemischten Antworten).
    /// Bei `in=catalog` und Feldsuche gibt es kein `match`, dort gilt `LibrarySearchResponse.isFromCatalog(_:)`.
    var isMarkedAsCatalogHit: Bool { match?.stage == .catalog }
}

// MARK: - Suche

/// Antwort von `/v1/library/search`.
struct LibrarySearchResponse: Decodable, Equatable {
    let items: [LibraryMedia]
    let totalCount: Int
    let page: Int
    let perPage: Int
    let hasMore: Bool
    /// Herkunft der Treffer. Fehlt bei der Feldsuche – sie läuft immer im Gesamtkatalog.
    let source: LibrarySearchSource?
    let correctedQuery: String?
    /// Der Verbund hat nicht rechtzeitig geantwortet und wird zum Weitersuchen angeboten.
    let catalogSuggested: Bool
    let catalogChecked: Bool
    let catalogTotal: Int?
    /// Nur bis zur nächsten Suche aufheben und beim Öffnen eines Titels mitgeben.
    let searchId: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([LibraryMedia].self, forKey: .data) ?? []
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? items.count
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        perPage = try container.decodeIfPresent(Int.self, forKey: .perPage) ?? items.count
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        source = try container.decodeIfPresent(LibrarySearchSource.self, forKey: .source)
        correctedQuery = try container.decodeIfPresent(String.self, forKey: .correctedQuery)
        catalogSuggested = try container.decodeIfPresent(Bool.self, forKey: .catalogSuggested) ?? false
        catalogChecked = try container.decodeIfPresent(Bool.self, forKey: .catalogChecked) ?? false
        catalogTotal = try container.decodeIfPresent(Int.self, forKey: .catalogTotal)
        searchId = try container.decodeIfPresent(String.self, forKey: .searchId)
    }

    private enum CodingKeys: String, CodingKey {
        case data, totalCount, page, perPage, hasMore, source, correctedQuery
        case catalogSuggested, catalogChecked, catalogTotal, searchId
    }

    /// Kommt dieser Treffer aus dem Gesamtkatalog? Bei `source == catalog` alle, bei `mixed` die mit
    /// `match.stage == catalog`. Bei der Feldsuche (ohne `source`) kennt nur der Aufrufer die Antwort: dort ist es immer der Katalog.
    func isFromCatalog(_ media: LibraryMedia) -> Bool {
        source == .catalog || media.isMarkedAsCatalogHit
    }

    /// Älteste Abrufzeit (`fetchedAt`) der Treffer. Für den Hinweis „Stand von 10:12“ bei veralteten Antworten,
    /// weil es keinen Zeitstempel für die ganze Liste gibt.
    var oldestFetchedAt: Date? { items.compactMap(\.fetchedAt).min() }

    /// Treffer ohne die schon gezeigten. Nötig nach „Im Gesamtkatalog suchen“: Die Katalog-Liste enthält die
    /// vorher gezeigten Katalog-Treffer noch einmal.
    func items(excluding shownIDs: Set<String>) -> [LibraryMedia] {
        items.filter { !shownIDs.contains($0.id) }
    }
}

// MARK: - Verfügbarkeit und Exemplare

/// Standort eines Exemplars.
struct LibraryLocation: Decodable, Equatable {
    let id: String?
    /// Nummer des Standorts (z. B. „53“).
    let code: String?
    let name: String
    /// Link zum Lageplan, wenn vorhanden.
    let floorPlanUrl: URL?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        floorPlanUrl = container.lenientURL(forKey: .floorPlanUrl)
    }

    private enum CodingKeys: String, CodingKey { case id, code, name, floorPlanUrl }
}

/// Ein Exemplar im Regal.
struct LibraryItem: Decodable, Equatable {
    /// Signatur.
    let label: String
    let location: LibraryLocation?
    let status: LibraryAvailabilityStatus
    /// Rückgabedatum bei „ausgeliehen“.
    let dueDate: Date?
    /// Link zum Vormerken im UB-Katalog, nur bei ausgeliehenen Exemplaren.
    let reserveUrl: URL?
    /// Anzahl Vormerkungen.
    let queue: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        location = try container.decodeIfPresent(LibraryLocation.self, forKey: .location)
        status = try container.decodeIfPresent(LibraryAvailabilityStatus.self, forKey: .status) ?? .unknown
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        reserveUrl = container.lenientURL(forKey: .reserveUrl)
        queue = try container.decodeIfPresent(Int.self, forKey: .queue)
    }

    private enum CodingKeys: String, CodingKey { case label, location, status, dueDate, reserveUrl, queue }

    /// Text des Status-Chips des Exemplars.
    var statusText: String { status.displayText(dueDate: dueDate) }
}

/// Verfügbarkeit eines Titels (`/library/availability` und Teil des Details).
struct LibraryAvailability: Decodable, Equatable {
    let id: String
    let status: LibraryAvailabilityStatus
    let items: [LibraryItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decodeIfPresent(LibraryAvailabilityStatus.self, forKey: .availabilityStatus) ?? .unknown
        items = try container.decodeIfPresent([LibraryItem].self, forKey: .items) ?? []
    }

    private enum CodingKeys: String, CodingKey { case id, availabilityStatus, items }

    /// Frühestes Rückgabedatum aller ausgeliehenen Exemplare.
    var earliestDueDate: Date? { items.compactMap(\.dueDate).min() }

    /// Summe der Vormerkungen über alle Exemplare.
    var totalQueue: Int { items.compactMap(\.queue).reduce(0, +) }

    /// Exemplare, die im Regal stehen.
    var availableCount: Int { items.filter { $0.status == .available }.count }
}

struct LibraryAvailabilityList: Decodable {
    let data: [LibraryAvailability]
}

extension LibraryAvailabilityList {
    var byID: [String: LibraryAvailability] {
        Dictionary(data.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

// MARK: - Detail

/// Eine Zeile des Inhaltsverzeichnisses.
struct LibraryTOCEntry: Decodable, Equatable {
    let number: String?
    let title: String
    let page: String?
    /// Ebene ab 1; Ebene 2 und tiefer werden eingerückt.
    let level: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decodeIfPresent(String.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        page = try container.decodeIfPresent(String.self, forKey: .page)
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
    }

    private enum CodingKeys: String, CodingKey { case number, title, page, level }
}

struct LibraryTableOfContents: Decodable, Equatable {
    /// Rohtext, wenn keine Gliederung erkannt wurde (kann Erkennungsfehler enthalten).
    let text: String?
    let entries: [LibraryTOCEntry]
    let sourceUrl: URL?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        entries = try container.decodeIfPresent([LibraryTOCEntry].self, forKey: .entries) ?? []
        sourceUrl = container.lenientURL(forKey: .sourceUrl)
    }

    private enum CodingKeys: String, CodingKey { case text, entries, sourceUrl }
}

struct LibraryBlurb: Decodable, Equatable {
    let text: String?
}

/// Inhaltsverzeichnis und Klappentext. Wird nicht dauerhaft gespeichert.
struct LibraryContents: Decodable, Equatable {
    let tableOfContents: LibraryTableOfContents?
    let blurb: LibraryBlurb?

    var hasTableOfContents: Bool {
        guard let toc = tableOfContents else { return false }
        return !toc.entries.isEmpty || !(toc.text ?? "").isEmpty
    }

    var hasBlurb: Bool { !(blurb?.text ?? "").isEmpty }
}

/// Antwort von `/v1/library/media/{id}`: die Felder des Titels plus Exemplare, Gesamtstatus und Inhalte.
struct LibraryMediaDetail: Decodable, Equatable {
    let media: LibraryMedia
    let items: [LibraryItem]
    /// Gesamtstatus. Ohne Exemplare (`items: []`) meist `unknown`.
    let availabilityStatus: LibraryAvailabilityStatus
    let contentsStatus: LibraryContentsStatus?
    let contents: LibraryContents?

    init(from decoder: Decoder) throws {
        media = try LibraryMedia(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([LibraryItem].self, forKey: .items) ?? []
        availabilityStatus = try container.decodeIfPresent(LibraryAvailabilityStatus.self, forKey: .availabilityStatus) ?? .unknown
        contentsStatus = try container.decodeIfPresent(LibraryContentsStatus.self, forKey: .contentsStatus)
        contents = try container.decodeIfPresent(LibraryContents.self, forKey: .contents)
    }

    private enum CodingKeys: String, CodingKey { case items, availabilityStatus, contentsStatus, contents }

    /// Inhaltsverzeichnis und Klappentext dürfen gezeigt werden: Status `available` und Inhalte vorhanden.
    var hasContents: Bool {
        contentsStatus == .available && contents != nil && (contents?.hasTableOfContents == true || contents?.hasBlurb == true)
    }

    /// Verfügbarkeit im Format der Listenansicht, z. B. für „2 von 3 Exemplaren stehen im Regal“.
    var availability: LibraryAvailability {
        LibraryAvailability(id: media.id, status: availabilityStatus, items: items)
    }
}

extension LibraryAvailability {
    init(id: String, status: LibraryAvailabilityStatus, items: [LibraryItem]) {
        self.id = id
        self.status = status
        self.items = items
    }
}

/// Antwort von `/v1/library/features`: was die API gerade anbietet.
struct LibraryFeatures: Decodable, Equatable {
    /// Inhaltsverzeichnis, Klappentext und Inhaltssuche sind verfügbar.
    let contents: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contents = try container.decodeIfPresent(Bool.self, forKey: .contents) ?? false
    }

    private enum CodingKeys: String, CodingKey { case contents }
}

// MARK: - Hilfen

/// Sprachcodes der Bibliothek (MARC, dreistellig) als deutscher Name.
enum LibraryLanguage {
    private static let names: [String: String] = [
        "ger": "Deutsch", "deu": "Deutsch", "eng": "Englisch", "fre": "Französisch", "fra": "Französisch",
        "spa": "Spanisch", "ita": "Italienisch", "rus": "Russisch", "lat": "Latein", "dut": "Niederländisch",
        "nld": "Niederländisch", "chi": "Chinesisch", "zho": "Chinesisch", "jpn": "Japanisch",
        "por": "Portugiesisch", "pol": "Polnisch", "cze": "Tschechisch", "ces": "Tschechisch", "tur": "Türkisch",
        "swe": "Schwedisch", "dan": "Dänisch", "nor": "Norwegisch", "fin": "Finnisch", "hun": "Ungarisch",
        "gre": "Griechisch", "ell": "Griechisch", "ara": "Arabisch", "heb": "Hebräisch", "kor": "Koreanisch",
        "ukr": "Ukrainisch", "rum": "Rumänisch", "ron": "Rumänisch", "slv": "Slowenisch", "hrv": "Kroatisch",
        "srp": "Serbisch", "bul": "Bulgarisch", "mul": "Mehrsprachig", "und": "Unbekannt"
    ]

    static func name(forCode code: String) -> String {
        let key = code.lowercased()
        if let name = names[key] { return name }
        if let name = Locale(identifier: "de").localizedString(forLanguageCode: key) { return name }
        return code.uppercased()
    }
}
