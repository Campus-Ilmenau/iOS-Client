import SwiftUI
import Observation

// MARK: - Anzeigetexte

/// Große Fläche mit dem Gesamtstatus eines Titels.
struct LibraryStatusBlock: Equatable {
    enum Tone: Equatable {
        /// `green` mit `onGreen`.
        case green
        /// `blue` mit `onBlue`.
        case blue
        /// `surface` mit `textPrimary`.
        case neutral
    }

    let title: String
    let subtitle: String
    let tone: Tone
}

/// Die Aktion unter der Statusfläche. Beides öffnet eine Seite der Bibliothek im Browser.
enum LibraryPrimaryAction: Equatable {
    case reserve(URL)
    case readOnline(URL)

    var title: String {
        switch self {
        case .reserve: "Vormerken"
        case .readOnline: "Online lesen"
        }
    }

    var url: URL {
        switch self {
        case .reserve(let url), .readOnline(let url): url
        }
    }
}

/// Zeile der Liste „Exemplare“.
struct LibraryItemRow: Equatable {
    let place: String
    let signature: String
    let chipText: String
    let status: LibraryAvailabilityStatus
    /// „Zurück bis 12. Nov. · 2 Vormerkungen“ bzw. ein Hinweis zur Nutzung.
    let extra: String?
    let floorPlanURL: URL?
}

/// „Weitere Angaben“: nur Felder mit Daten.
struct LibraryTitleFacts: Equatable {
    var isbn: String?
    var language: String?
    var publisher: String?
    var rvk: String?
    var subjects: [String] = []
    var abstract: String?

    var isEmpty: Bool {
        isbn == nil && language == nil && publisher == nil && rvk == nil && subjects.isEmpty && abstract == nil
    }
}

extension LibraryMedia {
    /// „BUCH · DEUTSCH“ (die Großschreibung setzt die Ansicht).
    var kindLabel: String {
        [mediaType.displayName, languageName ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// „16. Auflage · 2022 · Springer Vieweg“.
    var editionLine: String {
        [edition ?? "", year ?? "", publisher ?? ""].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var personsLine: String {
        LibraryPersonName.list(authors, limit: 6)
    }

    var facts: LibraryTitleFacts {
        func text(_ value: String?) -> String? {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        func joined(_ values: [String], limit: Int = .max) -> String? {
            let clean = values.compactMap(text)
            return clean.isEmpty ? nil : clean.prefix(limit).joined(separator: ", ")
        }
        return LibraryTitleFacts(
            isbn: joined(isbns, limit: 2),
            language: languageName,
            publisher: text(publisher),
            rvk: joined(rvk),
            subjects: subjects.compactMap(text),
            abstract: text(abstract)
        )
    }

    /// Adresse zum Teilen: die Seite im UB-Katalog, sonst der Link zum Online-Zugang.
    var shareURL: URL? { catalogUrl ?? onlineUrl }
}

extension LibraryItem {
    var row: LibraryItemRow {
        let chip = status.chipText

        var extra: String?
        switch status {
        case .onLoan:
            var parts: [String] = []
            if let dueDate { parts.append("Zurück bis \(BibliothekFormat.shortDate(dueDate))") }
            if let queue, queue > 0 { parts.append(Self.queueText(queue)) }
            extra = parts.isEmpty ? nil : parts.joined(separator: " · ")
        case .referenceOnly:
            extra = "Nicht ausleihbar, im Lesesaal nutzbar"
        case .online:
            extra = "Außerhalb des Campus über VPN"
        case .available, .unknown:
            extra = nil
        }

        return LibraryItemRow(
            place: location?.name ?? "Exemplar",
            signature: label,
            chipText: chip,
            status: status,
            extra: extra,
            floorPlanURL: location?.floorPlanUrl
        )
    }

    static func queueText(_ count: Int) -> String {
        count == 1 ? "1 Vormerkung" : "\(count) Vormerkungen"
    }
}

extension LibraryMediaDetail {
    /// Gesamtstatus als große Fläche, Texte nach `BibTitel.dc.html`.
    var statusBlock: LibraryStatusBlock {
        let overview = availability
        switch availabilityStatus {
        case .available:
            let total = items.count
            let subtitle: String
            if total == 0 {
                subtitle = "Im UB-Katalog siehst du die Exemplare."
            } else if total == 1 {
                subtitle = "Das Exemplar steht im Regal"
            } else {
                subtitle = "\(overview.availableCount) von \(total) Exemplaren stehen im Regal"
            }
            return LibraryStatusBlock(title: "Ausleihbar", subtitle: subtitle, tone: .green)

        case .onLoan:
            var parts: [String] = []
            if let due = overview.earliestDueDate { parts.append("Frühestens zurück am \(BibliothekFormat.shortDate(due))") }
            if overview.totalQueue > 0 { parts.append(LibraryItem.queueText(overview.totalQueue)) }
            return LibraryStatusBlock(
                title: items.count > 1 ? "Alle Exemplare ausgeliehen" : "Ausgeliehen",
                subtitle: parts.isEmpty ? "Im UB-Katalog siehst du, wann es zurück ist." : parts.joined(separator: " · "),
                tone: .neutral
            )

        case .referenceOnly:
            return LibraryStatusBlock(title: "Nur vor Ort nutzbar", subtitle: "Im Lesesaal, nicht ausleihbar", tone: .blue)

        case .online:
            return LibraryStatusBlock(title: "Online verfügbar", subtitle: "Im Campusnetz oder über VPN lesen", tone: .green)

        case .unknown:
            return LibraryStatusBlock(
                title: "Verfügbarkeit gerade nicht abrufbar",
                subtitle: "Im UB-Katalog siehst du den aktuellen Stand.",
                tone: .neutral
            )
        }
    }

    /// „Vormerken“ nur bei ausgeliehenen Titeln mit `reserveUrl`, „Online lesen“ nur mit `onlineUrl`.
    var primaryAction: LibraryPrimaryAction? {
        switch availabilityStatus {
        case .onLoan:
            items.compactMap(\.reserveUrl).first.map(LibraryPrimaryAction.reserve)
        case .online:
            media.onlineUrl.map(LibraryPrimaryAction.readOnline)
        default:
            nil
        }
    }

    var rows: [LibraryItemRow] { items.map(\.row) }
}

extension LibraryTableOfContents {
    /// Längster Fließtext, den die Ansicht zeigt (der Rohtext eines ganzen Buches kann sehr lang sein).
    static let textLimit = 2000

    /// Rohtext ohne Gliederung, gekürzt. Nur ein Rückfall, wenn es keine `entries` gibt.
    var shortText: String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        guard text.count > Self.textLimit else { return text }
        return String(text.prefix(Self.textLimit)).trimmingCharacters(in: .whitespacesAndNewlines) + " …"
    }
}

// MARK: - Modell

/// Adresse, die im Browser-Fenster geöffnet wird.
struct LibraryExternalLink: Identifiable, Equatable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Zustand der Titel-Ansicht: lädt den Titel mit Exemplaren, verwaltet Merkliste, Aufklappbereiche und Hinweise.
@MainActor
@Observable
final class LibraryTitleModel {
    enum Phase: Equatable {
        case loading
        case loaded
        /// 404.
        case notFound
        /// 503 oder Netzwerkfehler.
        case failed(String)
    }

    /// Zuerst die Daten aus der Trefferliste, nach dem Laden die des Details.
    var media: LibraryMedia
    var detail: LibraryMediaDetail?
    var phase: Phase = .loading
    /// `/features` erlaubt Inhaltsverzeichnis und Klappentext.
    var contentsEnabled = false
    var isStale = false
    var tocOpen = true
    var blurbOpen = false
    var toastMessage = ""
    /// Aktion rechts im Toast, z. B. „Anzeigen“ nach dem Merken.
    var toastActionTitle: String?
    var showsToast = false
    /// Zählt neue Meldungen hoch, damit eine zweite Meldung die Anzeigedauer neu beginnt.
    var toastToken = 0
    /// Die Merkliste soll geöffnet werden („Anzeigen“ im Toast).
    var opensMerkliste = false
    var externalLink: LibraryExternalLink?
    /// Für Previews: fertiges Cover statt Netzwerk.
    var previewCover: UIImage?

    let searchId: String?
    @ObservationIgnored let coverLoader: LibraryCoverLoader
    @ObservationIgnored let service: LibraryCatalogService
    @ObservationIgnored let merkliste: BibMerklisteStore

    init(
        media: LibraryMedia,
        searchId: String?,
        service: LibraryCatalogService? = nil,
        coverLoader: LibraryCoverLoader? = nil,
        merkliste: BibMerklisteStore = .shared
    ) {
        let service = service ?? LibraryCatalogService()
        self.media = media
        self.searchId = searchId
        self.service = service
        self.coverLoader = coverLoader ?? LibraryCoverLoader(service: service)
        self.merkliste = merkliste
    }

    // MARK: Laden

    /// Lädt den Titel. Das erste Mal mit `search_id` und Zählung, beim Neuladen einer offenen Seite mit `track=false`.
    func load(track: Bool = true) async {
        if detail == nil { phase = .loading }
        async let contents = try? service.features().value.contents
        do {
            let result = try await service.media(id: media.id, searchId: searchId, track: track)
            detail = result.value
            media = result.value.media
            isStale = result.info.isStale
            phase = .loaded
            // Ist der Titel gemerkt, bekommt er die vollständigen Angaben des Details.
            if istGemerkt { merkliste.aktualisieren(gemerkterTitel()) }
        } catch is CancellationError {
            return
        } catch let error as LibraryAPIError {
            handle(error)
        } catch {
            handle(LibraryAPIError.networkError(error))
        }
        contentsEnabled = await contents ?? false
    }

    /// Ziehen zum Aktualisieren und „Erneut versuchen“: nicht noch einmal als Aufruf zählen.
    func refresh() async {
        await load(track: false)
    }

    private func handle(_ error: LibraryAPIError) {
        if detail != nil {
            // Die Seite zeigt schon Daten: behalten und nur melden.
            flash("Aktualisieren fehlgeschlagen")
            return
        }
        if case .notFound = error {
            phase = .notFound
        } else {
            phase = .failed(error.errorDescription ?? "Katalog gerade nicht erreichbar")
        }
    }

    // MARK: Aktionen

    /// Steht der Titel auf der Merkliste?
    var istGemerkt: Bool { merkliste.istGemerkt(media.id) }

    /// Der Titel in der Form, wie die Merkliste ihn speichert. Das Cover nur, wenn es eines gibt.
    func gemerkterTitel() -> GemerkterTitel {
        let coverURL = media.cover.status == .found ? service.coverURL(for: media.cover) : nil
        return GemerkterTitel(media: media, coverURL: coverURL)
    }

    /// Lesezeichen: auf die Merkliste setzen oder wieder entfernen, mit kurzem Hinweis.
    func toggleMerken() {
        if istGemerkt {
            merkliste.entfernen(media.id)
            flash("Von der Merkliste entfernt")
        } else {
            merkliste.merken(gemerkterTitel())
            flash("Auf die Merkliste gesetzt", actionTitle: "Anzeigen")
        }
    }

    /// „Von der Merkliste entfernen“, wenn es den Titel im Katalog nicht mehr gibt.
    func vonMerklisteEntfernen() {
        guard istGemerkt else { return }
        merkliste.entfernen(media.id)
        flash("Von der Merkliste entfernt")
    }

    /// Aktion des Toasts: die Merkliste öffnen.
    func performToastAction() {
        opensMerkliste = true
        showsToast = false
    }

    func copySignature(_ signature: String) {
        UIPasteboard.general.string = signature
        flash("Signatur kopiert")
    }

    /// Öffnet eine Seite der Bibliothek im Browser-Fenster. Nach dem Vormerken gibt es keine Erfolgsmeldung,
    /// die App erfährt nicht, ob es geklappt hat.
    func open(_ url: URL?) {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased()) else { return }
        externalLink = LibraryExternalLink(url: url)
    }

    private func flash(_ message: String, actionTitle: String? = nil) {
        toastMessage = message
        toastActionTitle = actionTitle
        toastToken += 1
        showsToast = true
    }

    // MARK: Anzeige

    /// Hinweis bei veralteten Daten, mit der Abrufzeit des Titels.
    var staleNotice: String? {
        guard isStale else { return nil }
        if let fetched = media.fetchedAt {
            return "Stand von \(LibrarySearchModel.timeText(fetched)) – der Katalog antwortet gerade langsam. Verfügbarkeit kann sich geändert haben."
        }
        return "Der Katalog antwortet gerade langsam. Verfügbarkeit kann sich geändert haben."
    }

    /// Inhaltsverzeichnis und Klappentext zeigen nur, wenn `/features` es erlaubt.
    var showsContents: Bool {
        contentsEnabled && detail?.hasContents == true
    }
}
