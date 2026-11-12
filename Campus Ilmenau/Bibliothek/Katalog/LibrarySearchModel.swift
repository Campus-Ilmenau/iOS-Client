import SwiftUI
import Observation

/// Zustand und Ablauf der Katalogsuche. Hält Eingaben, Ergebnisse und die nachgeladenen Status.
/// Die Netzwerkarbeit steckt im `LibraryCatalogService`; hier steht, wann gesucht wird und was die Oberfläche zeigt.
@MainActor
@Observable
final class LibrarySearchModel {
    enum Phase: Equatable {
        /// Noch nichts gesucht.
        case start
        case loading
        case results
        /// Die Suche war erfolgreich, aber ohne Treffer.
        case empty
        /// 503 oder Netzwerkfehler. Der Text ist für die Anzeige gedacht.
        case failed(String)
    }

    /// Ein Block der Trefferliste. Bei gemischten Antworten gibt es zwei mit Überschrift.
    struct Section: Identifiable, Equatable {
        let id: String
        let title: String?
        let items: [LibraryMedia]
        /// Alle Treffer dieses Blocks kommen aus dem Gesamtkatalog (Chip „Gesamtkatalog“).
        let fromCatalog: Bool
    }

    struct PageState: Equatable {
        var query: LibrarySearchQuery
        var totalCount: Int
        var hasMore: Bool
    }

    /// Pause nach dem letzten Tippen, bevor gesucht wird.
    static let debounce: Duration = .milliseconds(700)
    /// Nach so langer Wartezeit erscheint der Hinweis auf den Gesamtkatalog.
    static let catalogHintDelay: Duration = .milliseconds(900)

    // MARK: - Eingaben

    var text = "" {
        didSet {
            if text.count > LibrarySearchQuery.maxTextLength {
                text = String(text.prefix(LibrarySearchQuery.maxTextLength))
            }
        }
    }
    /// Pills; „Gedruckt“ ist die Voreinstellung.
    var kind: LibraryMediaFilter = .printBook
    var advancedOpen = false
    var title = ""
    var author = ""
    var isbn = ""
    var subject = ""
    var yearFrom = "" { didSet { if yearFrom.count > 4 { yearFrom = String(yearFrom.prefix(4)) } } }
    var yearTo = "" { didSet { if yearTo.count > 4 { yearTo = String(yearTo.prefix(4)) } } }
    /// Fehler der erweiterten Suche (Jahre, fehlender Suchbegriff), rot unter den Feldern.
    var formError: String?

    // MARK: - Ergebnis

    var phase: Phase = .start
    /// Die zuletzt gesendete Suche, für Kopfzeile und „Weitere laden“.
    var executedQuery: LibrarySearchQuery?
    /// Antwort der ersten Seite (Metadaten wie `source`, `corrected_query`, `catalog_suggested`).
    var response: LibrarySearchResponse?
    var items: [LibraryMedia] = []
    var basePage: PageState?
    /// Fortsetzung im Gesamtkatalog („Im Gesamtkatalog weitersuchen“).
    var continuationItems: [LibraryMedia] = []
    var continuationPage: PageState?
    /// Die Fortsetzung im Gesamtkatalog lief schon (auch ohne Treffer).
    var catalogTried = false
    var isStale = false
    var staleSince: Date?
    var isLoadingMore = false
    var isContinuing = false
    var loadMoreError: String?
    var showsCatalogHint = false
    /// `/features` erlaubt Inhaltsverzeichnisse und Klappentexte.
    var contentsEnabled = false
    /// Verfügbarkeit je Titel, nachgeladen für die sichtbaren Karten.
    var availability: [String: LibraryAvailability] = [:]
    /// `search_id` je Titel: gilt nur bis zur nächsten Suche und geht beim Öffnen eines Titels mit.
    var searchIDs: [String: String] = [:]
    /// Für Previews: Status nicht nachladen.
    var loadsAvailability = true

    // MARK: - Intern

    @ObservationIgnored let service: LibraryCatalogService
    /// Wird an die Titel-Ansicht weitergegeben, damit schon geladene Cover nicht noch einmal geholt werden.
    @ObservationIgnored let coverLoader: LibraryCoverLoader
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var hintTask: Task<Void, Never>?
    @ObservationIgnored private var availabilityTask: Task<Void, Never>?
    /// Die zuletzt gestartete Suche, auch wenn sie noch läuft oder fehlschlug (für „Erneut versuchen“).
    @ObservationIgnored private var lastStartedQuery: LibrarySearchQuery?
    @ObservationIgnored private var searchGeneration = 0
    @ObservationIgnored private var pendingAvailability: [String] = []
    @ObservationIgnored private var requestedAvailability = Set<String>()
    @ObservationIgnored private var didLoadFeatures = false
    @ObservationIgnored private let clock: any Clock<Duration>

    /// - Parameter clock: Die Uhr für Pause nach dem Tippen, Katalog-Hinweis und Sammeln der Status-Abfragen. Tests geben
    ///   eine, die nur vorläuft, wenn sie es sagen.
    init(service: LibraryCatalogService? = nil, clock: any Clock<Duration> = ContinuousClock()) {
        let service = service ?? LibraryCatalogService()
        self.service = service
        self.clock = clock
        self.coverLoader = LibraryCoverLoader(service: service)
    }

    /// Ein Modell mit gefülltem Suchfeld, wenn die Suche von außen kommt (Siri-Link mit `?q=`). Leer oder `nil`: wie sonst.
    /// Die Treffer lädt erst `submit()`, denn eine Änderung vor dem Erscheinen löst `textChanged()` nicht aus.
    static func fuerSuchbegriff(_ begriff: String?) -> LibrarySearchModel {
        let model = LibrarySearchModel()
        if let begriff = begriff?.trimmingCharacters(in: .whitespacesAndNewlines), !begriff.isEmpty {
            model.text = begriff
        }
        return model
    }

    // MARK: - Aktionen der Oberfläche

    /// Beim Erscheinen: einmal abfragen, ob Inhaltsangaben erlaubt sind. Wird nicht gespeichert.
    func onAppear() async {
        guard !didLoadFeatures else { return }
        didLoadFeatures = true
        contentsEnabled = (try? await service.features().value.contents) ?? false
    }

    /// Nach jeder Änderung im Suchfeld: kurz warten, dann suchen. Bei geöffneter erweiterter Suche gilt nur „Suchen“.
    func textChanged() {
        debounceTask?.cancel()
        guard !advancedOpen else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            reset()
            return
        }
        debounceTask = Task { [weak self, clock] in
            try? await clock.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            self?.startSearch()
        }
    }

    /// Return-Taste oder „Suchen“: sofort suchen.
    func submit() {
        debounceTask?.cancel()
        startSearch()
    }

    func selectKind(_ newKind: LibraryMediaFilter) {
        guard kind != newKind else { return }
        kind = newKind
        // Nur neu suchen, wenn schon etwas gesucht wurde oder ein Begriff dasteht.
        if currentQuery() != nil { submit() }
    }

    func toggleAdvanced() {
        advancedOpen.toggle()
        formError = nil
    }

    func clearText() {
        text = ""
        debounceTask?.cancel()
        if !advancedOpen { reset() }
    }

    /// „Erneut versuchen“ nach einem Fehler.
    func retry() {
        // Dieselbe Anfrage, auch wenn die erweiterte Suche inzwischen zugeklappt ist.
        debounceTask?.cancel()
        startSearch(query: lastStartedQuery)
    }

    /// „Suchen“ in der erweiterten Suche: sofort suchen, dann Felder zuklappen und Tastatur schließen.
    /// Die Anfrage entsteht vor dem Zuklappen, denn zugeklappte Felder zählen nicht mehr.
    func submitAdvanced() {
        debounceTask?.cancel()
        startSearch()
        guard formError == nil else { return }
        advancedOpen = false
    }

    /// Pull to Refresh: dieselbe Suche noch einmal. Die alte Liste bleibt stehen, bis die neue da ist; bei einem
    /// Fehler bleibt sie erhalten. Ohne Treffer in der Anzeige (Fehler, leer) läuft die normale Suche.
    func refresh() async {
        guard phase == .results, let query = executedQuery else {
            guard phase != .start, phase != .loading else { return }
            debounceTask?.cancel()
            startSearch()
            await searchTask?.value
            return
        }
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        loadMoreError = nil
        // Eigene Task, damit das Ende der Geste die Anfrage nicht abbricht.
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.search(query)
                guard generation == searchGeneration else { return }
                resetForRefresh()
                apply(result, for: query)
            } catch is CancellationError {
                return
            } catch {
                guard generation == searchGeneration else { return }
                loadMoreError = Self.message(for: error)
            }
        }
        searchTask = task
        await task.value
    }

    /// Verfügbarkeit und Fortsetzung stammen von der alten Liste und werden neu geholt.
    private func resetForRefresh() {
        continuationItems = []
        continuationPage = nil
        catalogTried = false
        availability = [:]
        searchIDs = [:]
        pendingAvailability = []
        requestedAvailability = []
    }

    // MARK: - Suche

    /// Die Anfrage aus den Eingaben. Die Felder der erweiterten Suche zählen nur, solange der Bereich offen ist.
    func currentQuery(page: Int = 1) -> LibrarySearchQuery? {
        let fields = [title, author, isbn, subject, yearFrom, yearTo]
        let useFields = advancedOpen && fields.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var query = LibrarySearchQuery(text: text, mediaType: kind, page: page)
        if useFields {
            query.title = title
            query.author = author
            query.isbn = isbn
            query.subject = subject
            query.yearFrom = yearFrom
            query.yearTo = yearTo
        }
        return query.hasSearchTerm || useFields ? query : nil
    }

    private func startSearch(query override: LibrarySearchQuery? = nil) {
        guard let query = override ?? currentQuery() else {
            reset()
            return
        }
        let issues = query.validate()
        if let issue = issues.first {
            // Jahre und fehlende Begriffe der erweiterten Suche erscheinen unter den Feldern.
            formError = advancedOpen ? issue.message : nil
            if !advancedOpen { reset() }
            return
        }
        formError = nil
        lastStartedQuery = query

        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        beginLoading()
        searchTask = Task { [weak self] in
            await self?.run(query, generation: generation)
        }
    }

    private func beginLoading() {
        phase = .loading
        response = nil
        items = []
        basePage = nil
        continuationItems = []
        continuationPage = nil
        catalogTried = false
        isStale = false
        staleSince = nil
        loadMoreError = nil
        availability = [:]
        searchIDs = [:]
        pendingAvailability = []
        requestedAvailability = []
        showsCatalogHint = false
        hintTask?.cancel()
        hintTask = Task { [weak self, clock] in
            try? await clock.sleep(for: Self.catalogHintDelay)
            guard !Task.isCancelled else { return }
            self?.showsCatalogHint = true
        }
    }

    private func run(_ query: LibrarySearchQuery, generation: Int) async {
        do {
            let result = try await service.search(query)
            guard generation == searchGeneration else { return }
            apply(result, for: query)
        } catch is CancellationError {
            return
        } catch {
            guard generation == searchGeneration else { return }
            hintTask?.cancel()
            showsCatalogHint = false
            phase = .failed(Self.message(for: error))
        }
    }

    private func apply(_ result: LibraryResult<LibrarySearchResponse>, for query: LibrarySearchQuery) {
        hintTask?.cancel()
        showsCatalogHint = false
        let response = result.value
        self.response = response
        executedQuery = query
        items = Self.unique(response.items)
        for item in items { searchIDs[item.id] = response.searchId }
        basePage = PageState(query: query, totalCount: response.totalCount, hasMore: response.hasMore)
        isStale = result.info.isStale
        staleSince = response.oldestFetchedAt
        phase = items.isEmpty ? .empty : .results
    }

    /// Zurück zum Start, wenn das Feld leer ist.
    private func reset() {
        searchTask?.cancel()
        hintTask?.cancel()
        searchGeneration += 1
        phase = .start
        response = nil
        items = []
        basePage = nil
        continuationItems = []
        continuationPage = nil
        catalogTried = false
        isStale = false
        showsCatalogHint = false
        loadMoreError = nil
        availability = [:]
        searchIDs = [:]
        executedQuery = nil
    }

    // MARK: - Mehr laden

    /// „Weitere 20 Treffer laden“ für die Liste des Bestands bzw. der Feldsuche.
    func loadMore() async {
        guard let page = basePage, page.hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }
        let generation = searchGeneration
        let next = page.query.nextPage()
        do {
            let result = try await service.search(next)
            guard generation == searchGeneration else { return }
            let fresh = result.value.items(excluding: Set(items.map(\.id)))
            items += fresh
            for item in fresh { searchIDs[item.id] = result.value.searchId }
            basePage = PageState(query: next, totalCount: result.value.totalCount, hasMore: result.value.hasMore)
            if result.info.isStale { isStale = true }
        } catch is CancellationError {
            return
        } catch {
            guard generation == searchGeneration else { return }
            loadMoreError = Self.message(for: error)
        }
    }

    /// „Im Gesamtkatalog (weiter)suchen“: dieselbe Suche mit `in=catalog` ab Seite 1. Die Katalog-Liste enthält die
    /// schon gezeigten Titel noch einmal, deshalb kommen sie nach `id` nicht doppelt in die Anzeige.
    func continueInCatalog() async {
        guard let base = executedQuery, !isContinuing else { return }
        isContinuing = true
        loadMoreError = nil
        defer { isContinuing = false }
        let generation = searchGeneration
        let query = base.continuedInCatalog()
        do {
            let result = try await service.search(query)
            guard generation == searchGeneration else { return }
            let shown = Set(items.map(\.id))
            let fresh = Self.unique(result.value.items(excluding: shown))
            continuationItems = fresh
            for item in fresh { searchIDs[item.id] = result.value.searchId }
            continuationPage = PageState(query: query, totalCount: result.value.totalCount, hasMore: result.value.hasMore)
            catalogTried = true
            if result.info.isStale { isStale = true }
            if !fresh.isEmpty { phase = .results }
        } catch is CancellationError {
            return
        } catch {
            guard generation == searchGeneration else { return }
            loadMoreError = Self.message(for: error)
        }
    }

    /// „Weitere … Treffer laden“ in der Fortsetzung.
    func loadMoreInCatalog() async {
        guard let page = continuationPage, page.hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }
        let generation = searchGeneration
        let next = page.query.nextPage()
        do {
            let result = try await service.search(next)
            guard generation == searchGeneration else { return }
            let shown = Set(items.map(\.id) + continuationItems.map(\.id))
            let fresh = Self.unique(result.value.items(excluding: shown))
            continuationItems += fresh
            for item in fresh { searchIDs[item.id] = result.value.searchId }
            continuationPage = PageState(query: next, totalCount: result.value.totalCount, hasMore: result.value.hasMore)
            if result.info.isStale { isStale = true }
        } catch is CancellationError {
            return
        } catch {
            guard generation == searchGeneration else { return }
            loadMoreError = Self.message(for: error)
        }
    }

    // MARK: - Status der sichtbaren Treffer

    /// Eine Karte wird sichtbar: ihren Status zum nächsten Stapel (höchstens 20 IDs) hinzufügen.
    func requestAvailability(for id: String) {
        guard loadsAvailability, availability[id] == nil, requestedAvailability.insert(id).inserted else { return }
        pendingAvailability.append(id)
        guard availabilityTask == nil else { return }
        availabilityTask = Task { [weak self, clock] in
            try? await clock.sleep(for: .milliseconds(80))
            await self?.flushAvailability()
        }
    }

    private func flushAvailability() async {
        availabilityTask = nil
        while !pendingAvailability.isEmpty {
            let batch = Array(pendingAvailability.prefix(LibraryCatalogService.maxAvailabilityIDs))
            pendingAvailability.removeFirst(batch.count)
            let generation = searchGeneration
            do {
                let result = try await service.availability(ids: batch)
                guard generation == searchGeneration else { return }
                for id in batch {
                    availability[id] = result.value[id] ?? LibraryAvailability(id: id, status: .unknown, items: [])
                }
                if result.info.isStale { isStale = true }
            } catch is CancellationError {
                return
            } catch {
                guard generation == searchGeneration else { return }
                // Ohne Antwort bleibt „Status unbekannt“ statt eines endlosen Platzhalters.
                for id in batch { availability[id] = LibraryAvailability(id: id, status: .unknown, items: []) }
            }
        }
    }

    // MARK: - Cover

    /// Lädt das Cover über den gemeinsamen Lader (mit Zwischenspeicher für diese Sitzung).
    func coverImage(for media: LibraryMedia) async -> UIImage? {
        await coverLoader.image(for: media)
    }

    // MARK: - Anzeige

    /// Die Blöcke der Trefferliste.
    var sections: [Section] {
        var result: [Section] = []
        if let response {
            if response.source == .mixed {
                let local = items.filter { !response.isFromCatalog($0) }
                let catalog = items.filter { response.isFromCatalog($0) }
                if !local.isEmpty { result.append(Section(id: "local", title: "Bestand der UB Ilmenau", items: local, fromCatalog: false)) }
                if !catalog.isEmpty { result.append(Section(id: "catalog", title: "Aus dem Gesamtkatalog", items: catalog, fromCatalog: true)) }
            } else if !items.isEmpty {
                result.append(Section(id: "main", title: nil, items: items, fromCatalog: isCatalogOnlySearch))
            }
        }
        if !continuationItems.isEmpty {
            result.append(Section(
                id: "continued",
                title: items.isEmpty ? nil : "Weitere aus dem Gesamtkatalog",
                items: continuationItems,
                fromCatalog: true
            ))
        }
        return result
    }

    /// Feldsuche und `in=catalog` laufen im Gesamtkatalog; die Antwort der Feldsuche trägt kein `source`.
    var isCatalogOnlySearch: Bool {
        guard let response else { return false }
        if response.source == .catalog { return true }
        return response.source == nil && executedQuery?.isFieldSearch == true
    }

    /// Kopfzeile der Treffer nach der Tabelle in `Uebergabe.md`.
    var header: (line1: String, line2: String?)? {
        guard phase == .results, let response, let query = executedQuery else { return nil }

        // Nur Treffer aus der Fortsetzung (der Bestand hatte nichts).
        if items.isEmpty, let continuationPage {
            return ("\(continuationPage.totalCount) Treffer im Gesamtkatalog", nil)
        }

        var line1: String
        var line2: String?

        if isCatalogOnlySearch {
            line1 = "\(response.totalCount) Treffer im Gesamtkatalog"
            line2 = query.isFieldSearch ? Self.fieldSummary(query) : nil
        } else if response.source == .mixed {
            line1 = "\(response.totalCount) Treffer"
            line2 = "Wenig im Bestand der UB – ergänzt aus dem Gesamtkatalog"
        } else if response.catalogSuggested {
            line1 = "\(response.totalCount) Treffer im Bestand der UB Ilmenau"
            line2 = "Der Gesamtkatalog hat nicht rechtzeitig geantwortet."
        } else {
            line1 = response.correctedQuery.map { "Ergebnisse für „\($0)“" } ?? "\(response.totalCount) Treffer"
            line2 = searchedInContents
                ? "Auch in Inhaltsverzeichnissen und Klappentexten gesucht"
                : "\(response.totalCount) Treffer im Bestand der UB Ilmenau"
        }

        if let continuationPage {
            line2 = "Ergänzt um \(continuationPage.totalCount) Treffer aus dem Gesamtkatalog"
        }
        return (line1, line2)
    }

    /// Die Inhaltssuche hat gegriffen: `/features` erlaubt sie und mindestens ein Treffer steht im Inhaltsverzeichnis
    /// oder Klappentext.
    var searchedInContents: Bool {
        contentsEnabled && items.contains { $0.match?.isInTableOfContents == true || $0.match?.isInBlurb == true }
    }

    /// Hinweis bei veralteten Daten: „Stand von 10:12 – …“.
    var staleNotice: String? {
        guard isStale else { return nil }
        let base = "der Katalog antwortet gerade langsam. Verfügbarkeit kann sich geändert haben."
        if let staleSince {
            return "Stand von \(Self.timeText(staleSince)) – \(base)"
        }
        return "Der Katalog antwortet gerade langsam. Verfügbarkeit kann sich geändert haben."
    }

    /// Fortsetzung im Gesamtkatalog anbieten, weil der Verbund nicht rechtzeitig geantwortet hat.
    var offersCatalogContinuation: Bool {
        phase == .results && response?.catalogSuggested == true && !catalogTried && !isCatalogOnlySearch
    }

    /// Am Ende einer gemischten Liste: „Im Gesamtkatalog suchen“.
    var offersMixedEnd: Bool {
        phase == .results && response?.source == .mixed && !catalogTried
    }

    /// Bei „keine Treffer“ auch den Gesamtkatalog anbieten.
    var offersCatalogForEmpty: Bool {
        phase == .empty && !catalogTried && !isCatalogOnlySearch
    }

    /// „Weitere N Treffer laden“ für die Hauptliste.
    var loadMoreCount: Int? {
        guard let basePage, basePage.hasMore, response?.source != .mixed else { return nil }
        return min(LibrarySearchQuery.pageSize, max(1, basePage.totalCount - items.count))
    }

    var loadMoreCountInCatalog: Int? {
        guard let continuationPage, continuationPage.hasMore else { return nil }
        return min(LibrarySearchQuery.pageSize, max(1, continuationPage.totalCount - continuationItems.count - items.count))
    }

    /// Wie die Suche in „Keine Treffer für …“ genannt wird.
    var emptyQueryText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return executedQuery.map(Self.fieldSummary) ?? ""
    }

    func searchID(for media: LibraryMedia) -> String? { searchIDs[media.id] }

    // MARK: - Hilfen

    /// „Person „Zacher“ · E-Book · 2015–2024 · neueste zuerst“.
    static func fieldSummary(_ query: LibrarySearchQuery) -> String {
        func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
        var parts: [String] = []
        if !trimmed(query.text).isEmpty { parts.append("„\(trimmed(query.text))“") }
        if !trimmed(query.title).isEmpty { parts.append("Titel „\(trimmed(query.title))“") }
        if !trimmed(query.author).isEmpty { parts.append("Person „\(trimmed(query.author))“") }
        if !trimmed(query.isbn).isEmpty { parts.append("ISBN \(trimmed(query.isbn))") }
        if !trimmed(query.subject).isEmpty { parts.append("Schlagwort „\(trimmed(query.subject))“") }
        if let type = query.mediaType { parts.append(type.pillTitle) }
        let from = trimmed(query.yearFrom)
        let to = trimmed(query.yearTo)
        if !from.isEmpty, !to.isEmpty {
            parts.append("\(from)–\(to)")
        } else if !from.isEmpty {
            parts.append("ab \(from)")
        } else if !to.isEmpty {
            parts.append("bis \(to)")
        }
        parts.append("neueste zuerst")
        return parts.joined(separator: " · ")
    }

    /// Meldung für den Fehlerzustand.
    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    static func timeText(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "de_DE")))
    }

    private static func unique(_ media: [LibraryMedia]) -> [LibraryMedia] {
        var seen = Set<String>()
        return media.filter { seen.insert($0.id).inserted }
    }
}

// MARK: - Anzeigetexte

extension LibraryMediaFilter {
    /// Beschriftung der Pills.
    var pillTitle: String {
        switch self {
        case .printBook: "Gedruckt"
        case .ebook: "E-Book"
        case .journal: "Zeitschrift"
        case .all: "Alle"
        }
    }
}

/// Namen aus der Bibliothek stehen als „Nachname, Vorname“. Im Mockup stehen sie als „Vorname Nachname“.
enum LibraryPersonName {
    static func display(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return trimmed }
        return "\(parts[1]) \(parts[0])"
    }

    /// Bis zu `limit` Namen, danach „u. a.“.
    static func list(_ authors: [String], limit: Int = 3) -> String {
        let names = authors.map(display).filter { !$0.isEmpty }
        guard names.count > limit else { return names.joined(separator: ", ") }
        return names.prefix(limit).joined(separator: ", ") + " u. a."
    }
}

extension LibraryMedia {
    /// „Personen · Jahr · Medienart“.
    var metaLine: String {
        [LibraryPersonName.list(authors), year ?? "", mediaType.displayName]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var trimmedSubtitle: String? {
        let value = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }
}
