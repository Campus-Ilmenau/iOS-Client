import SwiftUI

// Previews der Katalog-Ansicht: ein Fall je Eintrag des Tweaks `ergebnis` in `BibSuche.dc.html`.
// Die Daten sind Beispiele aus dem Mockup; das Modell wird direkt gefüllt, es gibt keine Netzwerkanfragen.

private enum CatalogSamples {
    /// Baut einen Titel über denselben Decoder wie die echte Antwort.
    static func media(
        _ number: Int,
        _ title: String,
        subtitle: String? = nil,
        authors: [String] = [],
        year: String? = nil,
        type: String = "print_book",
        match: [String: Any]? = nil
    ) -> LibraryMedia {
        var json: [String: Any] = [
            "id": "med_\(number)",
            "ppn": "\(number)",
            "mediaType": type,
            "title": title,
            "authors": authors,
            "isbns": [String](),
            "subjects": [String](),
            "rvk": [String](),
            "links": [[String: Any]](),
            "cover": ["status": "none"]
        ]
        if let subtitle { json["subtitle"] = subtitle }
        if let year { json["year"] = year }
        if let match { json["match"] = match }
        // Eine fehlgeschlagene Umwandlung soll in der Preview auffallen, deshalb kein Ersatzwert.
        let data = try! JSONSerialization.data(withJSONObject: json) // swiftlint:disable:this force_try
        return try! LibraryCatalogService.decoder.decode(LibraryMedia.self, from: data) // swiftlint:disable:this force_try
    }

    static let local: [LibraryMedia] = [
        media(1, "Regelungstechnik für Ingenieure", subtitle: "Analyse, Simulation und Entwurf von Regelkreisen",
              authors: ["Reuter, Manfred", "Zacher, Serge"], year: "2022"),
        media(2, "Regelungstechnik 1", subtitle: "Systemtheoretische Grundlagen, Analyse und Entwurf einschleifiger Regelungen",
              authors: ["Lunze, Jan"], year: "2020"),
        media(3, "Regelungstechnik", subtitle: "Eine Einführung für Ingenieure und Naturwissenschaftler",
              authors: ["Schulz, Gerd"], year: "2015"),
        media(4, "Einführung in die Regelungstechnik", authors: ["Mann, Heinz", "Schiffelgen, Horst"], year: "2018", type: "ebook"),
        media(5, "Grundkurs der Regelungstechnik", subtitle: "Einführung in die praktischen und theoretischen Methoden",
              authors: ["Merz, Ludwig", "Jaschek, Holger"], year: "2016"),
        media(6, "at – Automatisierungstechnik", subtitle: "Methoden und Anwendungen der Steuerungs-, Regelungs- und Informationstechnik",
              year: "2024", type: "journal")
    ]

    static let catalog: [LibraryMedia] = [
        media(11, "Praxishandbuch Regelungstechnik für Ingenieure", authors: ["Fischer, Uwe"], year: "2021",
              match: ["fields": [String](), "stage": "catalog"]),
        media(12, "Regelungstechnik für Maschinenbauer", subtitle: "Mit Übungsaufgaben", authors: ["Schneider, Wolfgang"], year: "2019",
              match: ["fields": [String](), "stage": "catalog"])
    ]

    static let field: [LibraryMedia] = [
        media(21, "Regelungstechnik für Ingenieure", subtitle: "Analyse, Simulation und Entwurf von Regelkreisen",
              authors: ["Reuter, Manfred", "Zacher, Serge"], year: "2024", type: "ebook"),
        media(22, "Übungsbuch Regelungstechnik", subtitle: "Klassische, modell- und wissensbasierte Verfahren",
              authors: ["Zacher, Serge"], year: "2021", type: "ebook"),
        media(23, "Automatisierungstechnik kompakt", authors: ["Zacher, Serge"], year: "2015", type: "ebook")
    ]

    static let content: [LibraryMedia] = [
        media(2, "Regelungstechnik 1", subtitle: "Systemtheoretische Grundlagen, Analyse und Entwurf einschleifiger Regelungen",
              authors: ["Lunze, Jan"], year: "2020",
              match: ["fields": ["toc"], "stage": "exact", "snippet": "… 6.3 Zustandsbeobachter und Störgrößenaufschaltung … S. 120"]),
        media(1, "Regelungstechnik für Ingenieure", subtitle: "Analyse, Simulation und Entwurf von Regelkreisen",
              authors: ["Reuter, Manfred", "Zacher, Serge"], year: "2022",
              match: ["fields": ["toc"], "stage": "exact", "snippet": "… 8.2 Entwurf eines Zustandsbeobachters mit Polvorgabe …"])
    ]

    private static func item(_ status: String, due: String? = nil, queue: Int? = nil) -> [String: Any] {
        var item: [String: Any] = ["label": "INF 1", "status": status]
        if let due { item["dueDate"] = due }
        if let queue { item["queue"] = queue }
        return item
    }

    static func availability(id: String, status: String, due: String? = nil) -> LibraryAvailability {
        let json: [String: Any] = [
            "id": id,
            "availabilityStatus": status,
            "items": status == "unknown" ? [[String: Any]]() : [item(status, due: due)]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json) // swiftlint:disable:this force_try
        return try! LibraryCatalogService.decoder.decode(LibraryAvailability.self, from: data) // swiftlint:disable:this force_try
    }

    /// Status wie im Mockup: ausleihbar, ausgeliehen, nur vor Ort, online, unbekannt, online.
    static func availabilities(for media: [LibraryMedia]) -> [String: LibraryAvailability] {
        let statuses: [(String, String?)] = [
            ("available", nil), ("on_loan", "2026-11-12"), ("reference_only", nil),
            ("online", nil), ("unknown", nil), ("online", nil)
        ]
        var result: [String: LibraryAvailability] = [:]
        for (index, item) in media.enumerated() {
            let (status, due) = statuses[index % statuses.count]
            result[item.id] = availability(id: item.id, status: status, due: due)
        }
        return result
    }

    static func response(
        _ items: [LibraryMedia],
        total: Int,
        hasMore: Bool = false,
        source: String? = "local",
        corrected: String? = nil,
        suggested: Bool = false
    ) -> LibrarySearchResponse {
        var json: [String: Any] = [
            "object": "list",
            "data": items.map { ["id": $0.id, "title": $0.title] as [String: Any] },
            "total_count": total,
            "page": 1,
            "per_page": 20,
            "has_more": hasMore,
            "catalog_suggested": suggested,
            "catalog_checked": source == "mixed",
            "search_id": "srch_preview"
        ]
        if let source { json["source"] = source }
        if let corrected { json["corrected_query"] = corrected }
        let data = try! JSONSerialization.data(withJSONObject: json) // swiftlint:disable:this force_try
        return try! LibraryCatalogService.decoder.decode(LibrarySearchResponse.self, from: data) // swiftlint:disable:this force_try
    }
}

extension LibrarySearchModel {
    enum PreviewScenario {
        case bestand
        case gemischt
        case verbundZuLangsam
        case feldsuche
        case inhaltssuche
        case keineTreffer
        case veraltet
        case laedt
        case fehler
        case start
        case statusLaedt
        case jahrFehler
    }

    /// Ein Modell im gewünschten Zustand, ohne Netzwerk.
    static func preview(_ scenario: PreviewScenario) -> LibrarySearchModel {
        let model = LibrarySearchModel()
        model.loadsAvailability = false
        let samples = CatalogSamples.self

        func fill(
            items: [LibraryMedia],
            response: LibrarySearchResponse,
            query: LibrarySearchQuery,
            ready: Bool = true
        ) {
            model.response = response
            model.executedQuery = query
            model.items = items
            model.basePage = PageState(query: query, totalCount: response.totalCount, hasMore: response.hasMore)
            model.phase = .results
            model.searchIDs = Dictionary(uniqueKeysWithValues: items.map { ($0.id, "srch_preview") })
            if ready { model.availability = samples.availabilities(for: items) }
        }

        switch scenario {
        case .bestand, .veraltet, .statusLaedt:
            model.text = "regelungstechnik ingeneure"
            let query = LibrarySearchQuery(text: model.text, mediaType: .all)
            fill(
                items: samples.local,
                response: samples.response(samples.local, total: 14, hasMore: true, corrected: "regelungstechnik ingenieure"),
                query: query,
                ready: scenario != .statusLaedt
            )
            if scenario == .veraltet {
                model.isStale = true
                var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                components.hour = 10
                components.minute = 12
                model.staleSince = Calendar.current.date(from: components)
            }
            model.kind = .all

        case .gemischt:
            model.text = "regelungstechnik ingenieure praxis"
            let items = Array(samples.local.prefix(3)) + samples.catalog
            fill(
                items: items,
                response: samples.response(items, total: 5, source: "mixed"),
                query: LibrarySearchQuery(text: model.text, mediaType: .all)
            )
            model.kind = .all

        case .verbundZuLangsam:
            model.text = "regelungstechnik ingenieure praxis"
            let items = Array(samples.local.prefix(3))
            fill(
                items: items,
                response: samples.response(items, total: 3, suggested: true),
                query: LibrarySearchQuery(text: model.text, mediaType: .all)
            )
            model.kind = .all

        case .feldsuche:
            // Wie im Mockup: Bei der Feldsuche ist der Klappbereich offen.
            model.advancedOpen = true
            model.author = "Zacher"
            model.yearFrom = "2015"
            model.yearTo = "2024"
            model.kind = .ebook
            let query = LibrarySearchQuery(author: "Zacher", mediaType: .ebook, yearFrom: "2015", yearTo: "2024")
            fill(
                items: samples.field,
                response: samples.response(samples.field, total: 23, hasMore: true, source: nil),
                query: query
            )

        case .inhaltssuche:
            model.text = "zustandsbeobachter"
            model.contentsEnabled = true
            model.kind = .all
            fill(
                items: samples.content,
                response: samples.response(samples.content, total: 2),
                query: LibrarySearchQuery(text: model.text, mediaType: .all)
            )

        case .keineTreffer:
            model.text = "quantenregelung"
            model.kind = .all
            model.executedQuery = LibrarySearchQuery(text: model.text, mediaType: .all)
            model.phase = .empty

        case .laedt:
            model.text = "regelungstechnik"
            model.phase = .loading
            model.showsCatalogHint = true

        case .fehler:
            model.text = "regelungstechnik ingenieure"
            model.phase = .failed("Katalog gerade nicht erreichbar")

        case .start:
            break

        case .jahrFehler:
            model.advancedOpen = true
            model.text = "regelung"
            model.author = "Zacher"
            model.yearFrom = "2030"
            model.yearTo = "2020"
            model.formError = "„von“ darf nicht nach „bis“ liegen."
        }
        return model
    }
}

private struct CatalogPreview: View {
    @State private var model: LibrarySearchModel

    init(_ scenario: LibrarySearchModel.PreviewScenario) {
        _model = State(initialValue: .preview(scenario))
    }

    var body: some View {
        NavigationStack {
            LibraryCatalogScreen(model: model)
        }
    }
}

// MARK: - Bestand (local)

#Preview("Bestand – Light") { CatalogPreview(.bestand).preferredColorScheme(.light) }
#Preview("Bestand – Dark") { CatalogPreview(.bestand).preferredColorScheme(.dark) }
#Preview("Bestand – xxxLarge") { CatalogPreview(.bestand).dynamicTypeSize(.xxxLarge) }

// MARK: - Gemischt (mixed)

#Preview("Gemischt – Light") { CatalogPreview(.gemischt).preferredColorScheme(.light) }
#Preview("Gemischt – Dark") { CatalogPreview(.gemischt).preferredColorScheme(.dark) }
#Preview("Gemischt – xxxLarge") { CatalogPreview(.gemischt).dynamicTypeSize(.xxxLarge) }

// MARK: - Verbund zu langsam (catalog_suggested)

#Preview("Verbund zu langsam – Light") { CatalogPreview(.verbundZuLangsam).preferredColorScheme(.light) }
#Preview("Verbund zu langsam – Dark") { CatalogPreview(.verbundZuLangsam).preferredColorScheme(.dark) }
#Preview("Verbund zu langsam – xxxLarge") { CatalogPreview(.verbundZuLangsam).dynamicTypeSize(.xxxLarge) }

// MARK: - Feldsuche

#Preview("Feldsuche – Light") { CatalogPreview(.feldsuche).preferredColorScheme(.light) }
#Preview("Feldsuche – Dark") { CatalogPreview(.feldsuche).preferredColorScheme(.dark) }
#Preview("Feldsuche – xxxLarge") { CatalogPreview(.feldsuche).dynamicTypeSize(.xxxLarge) }

// MARK: - Inhaltssuche

#Preview("Inhaltssuche – Light") { CatalogPreview(.inhaltssuche).preferredColorScheme(.light) }
#Preview("Inhaltssuche – Dark") { CatalogPreview(.inhaltssuche).preferredColorScheme(.dark) }
#Preview("Inhaltssuche – xxxLarge") { CatalogPreview(.inhaltssuche).dynamicTypeSize(.xxxLarge) }

// MARK: - Keine Treffer

#Preview("Keine Treffer – Light") { CatalogPreview(.keineTreffer).preferredColorScheme(.light) }
#Preview("Keine Treffer – Dark") { CatalogPreview(.keineTreffer).preferredColorScheme(.dark) }
#Preview("Keine Treffer – xxxLarge") { CatalogPreview(.keineTreffer).dynamicTypeSize(.xxxLarge) }

// MARK: - Veraltet (stale)

#Preview("Veraltet – Light") { CatalogPreview(.veraltet).preferredColorScheme(.light) }
#Preview("Veraltet – Dark") { CatalogPreview(.veraltet).preferredColorScheme(.dark) }
#Preview("Veraltet – xxxLarge") { CatalogPreview(.veraltet).dynamicTypeSize(.xxxLarge) }

// MARK: - Lädt

#Preview("Lädt – Light") { CatalogPreview(.laedt).preferredColorScheme(.light) }
#Preview("Lädt – Dark") { CatalogPreview(.laedt).preferredColorScheme(.dark) }
#Preview("Lädt – xxxLarge") { CatalogPreview(.laedt).dynamicTypeSize(.xxxLarge) }

// MARK: - Fehler (503)

#Preview("Fehler – Light") { CatalogPreview(.fehler).preferredColorScheme(.light) }
#Preview("Fehler – Dark") { CatalogPreview(.fehler).preferredColorScheme(.dark) }
#Preview("Fehler – xxxLarge") { CatalogPreview(.fehler).dynamicTypeSize(.xxxLarge) }

// MARK: - Start ohne Suche

#Preview("Start – Light") { CatalogPreview(.start).preferredColorScheme(.light) }
#Preview("Start – Dark") { CatalogPreview(.start).preferredColorScheme(.dark) }
#Preview("Start – xxxLarge") { CatalogPreview(.start).dynamicTypeSize(.xxxLarge) }

// MARK: - Zusätzlich: Status lädt noch, erweiterte Suche mit Jahresfehler

#Preview("Status lädt – Light") { CatalogPreview(.statusLaedt).preferredColorScheme(.light) }
#Preview("Erweiterte Suche mit Fehler – Light") { CatalogPreview(.jahrFehler).preferredColorScheme(.light) }
#Preview("Erweiterte Suche mit Fehler – xxxLarge") { CatalogPreview(.jahrFehler).dynamicTypeSize(.xxxLarge) }
