import SwiftUI

// Previews der Titel-Ansicht: ein Fall je Eintrag der Tweaks `status`, `cover` und `inhalte` in `BibTitel.dc.html`.
// Die Daten sind Beispiele aus dem Mockup; das Modell wird direkt gefüllt, es gibt keine Netzwerkanfragen.

extension LibraryTitleModel {
    enum PreviewStatus {
        case ausleihbar
        case ausgeliehen
        case nurVorOrt
        case online
        case unbekannt
    }

    /// Titel „Regelungstechnik für Ingenieure“ mit den Exemplaren des gewünschten Status.
    static func preview(
        _ status: PreviewStatus,
        cover: Bool = true,
        contents: Bool = true,
        tocAsText: Bool = false,
        stale: Bool = false
    ) -> LibraryTitleModel {
        func item(_ place: String, _ signature: String, _ code: String, due: String? = nil, queue: Int? = nil, plan: Bool = true) -> [String: Any] {
            var item: [String: Any] = [
                "label": signature,
                "location": [
                    "id": "x", "code": "2", "name": place,
                    "floorPlanUrl": plan ? "https://example.org/lageplan.png" : NSNull()
                ] as [String: Any],
                "status": code
            ]
            if let due { item["dueDate"] = due }
            if let queue { item["queue"] = queue }
            if code == "on_loan" { item["reserveUrl"] = "https://opac.example/reserve" }
            return item
        }

        let items: [[String: Any]]
        let overall: String
        switch status {
        case .ausleihbar:
            overall = "available"
            items = [
                item("Lehrbuchsammlung, 2. OG", "ZQ 5000 R444(16)-1", "available"),
                item("Lehrbuchsammlung, 2. OG", "ZQ 5000 R444(16)-2", "available"),
                item("Freihand, 3. OG", "ZQ 5000 R444(16)-3", "on_loan", due: "2026-11-12")
            ]
        case .ausgeliehen:
            overall = "on_loan"
            items = [
                item("Lehrbuchsammlung, 2. OG", "ZQ 5000 R444(16)-1", "on_loan", due: "2026-11-12", queue: 2),
                item("Freihand, 3. OG", "ZQ 5000 R444(16)-2", "on_loan", due: "2026-11-26", queue: 1)
            ]
        case .nurVorOrt:
            overall = "reference_only"
            items = [item("Lesesaal, Präsenzbestand", "ZQ 5000 R444(16)", "reference_only")]
        case .online:
            overall = "online"
            items = [item("Online im Campusnetz", "E-Book", "online", plan: false)]
        case .unbekannt:
            overall = "unknown"
            items = []
        }

        let tocEntries: [[String: Any]] = [
            ["number": "1", "title": "Einführung", "page": "1", "level": 1],
            ["number": "2", "title": "Beschreibung von Regelkreisen", "page": "15", "level": 1],
            ["number": "2.1", "title": "Übertragungsglieder", "page": "17", "level": 2],
            ["number": "5", "title": "Stabilität", "page": "81", "level": 1],
            ["number": "6", "title": "Zustandsregelung", "page": "103", "level": 1],
            ["number": "6.3", "title": "Zustandsbeobachter und Störgrößenaufschaltung", "page": "120", "level": 2]
        ]
        var toc: [String: Any] = ["entries": tocAsText ? [[String: Any]]() : tocEntries]
        if tocAsText {
            toc["text"] = "Inhalt Vorwort V 1 Einführung 1 2 Beschreibung von Regelkreisen 15 2.1 Übertragungsglieder 17 5 Stabilität 81 6 Zustandsregelung 103 6.3 Zustandsbeobachter und Störgrößenaufschaltung 120"
        }

        var json: [String: Any] = [
            "id": "med_1234567890",
            "ppn": "1234567890",
            "mediaType": "print_book",
            "title": "Regelungstechnik für Ingenieure",
            "subtitle": "Analyse, Simulation und Entwurf von Regelkreisen",
            "authors": ["Reuter, Manfred", "Zacher, Serge"],
            "edition": "16. Auflage",
            "year": "2022",
            "publisher": "Springer Vieweg",
            "isbns": ["978-3-658-36406-9"],
            "language": "ger",
            "subjects": ["Regelungstechnik", "Regelkreis", "Simulation", "Lehrbuch"],
            "rvk": ["ZQ 5000"],
            "catalogUrl": "https://opac.example/PPN=1234567890",
            "links": [[String: Any]](),
            "items": items,
            "availabilityStatus": overall,
            "cover": ["status": cover ? "found" : "none", "url": "/v1/library/media/med_1234567890/cover"] as [String: Any]
        ]
        if status == .online { json["onlineUrl"] = "https://example.org/lesen" }
        if stale { json["fetchedAt"] = "2026-11-04T10:12:00.000Z" }
        if contents {
            json["contentsStatus"] = "available"
            json["contents"] = [
                "tableOfContents": toc,
                "blurb": ["text": "Das Lehrbuch führt in die Analyse und den Entwurf von Regelkreisen ein – von linearen Grundlagen über Zustandsregelung bis zur Simulation. Mit zahlreichen Beispielen und Übungsaufgaben."]
            ] as [String: Any]
        } else {
            json["contentsStatus"] = "disabled"
        }

        // Eine fehlgeschlagene Umwandlung soll in der Preview auffallen, deshalb kein Ersatzwert.
        let data = try! JSONSerialization.data(withJSONObject: json) // swiftlint:disable:this force_try
        let detail = try! LibraryCatalogService.decoder.decode(LibraryMediaDetail.self, from: data) // swiftlint:disable:this force_try

        let model = LibraryTitleModel(media: detail.media, searchId: "srch_preview", merkliste: BibMerklisteStore(fileURL: nil, legacyDefaults: nil))
        model.detail = detail
        model.phase = .loaded
        model.contentsEnabled = contents
        model.isStale = stale
        model.previewCover = cover ? sampleCover() : nil
        return model
    }

    /// Titel ohne geladene Details (lädt, 404, 503): nur die Daten aus der Trefferliste.
    static func previewWithoutDetail(_ phase: Phase) -> LibraryTitleModel {
        let model = preview(.ausleihbar, cover: false)
        let media = model.media
        let bare = LibraryTitleModel(media: media, searchId: "srch_preview", merkliste: BibMerklisteStore(fileURL: nil, legacyDefaults: nil))
        bare.phase = phase
        return bare
    }

    private static func sampleCover() -> UIImage {
        let size = CGSize(width: 96, height: 136)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor(Color(.blue)).cgColor, UIColor(Color(.brandNight)).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
    }
}

private struct TitlePreview: View {
    @State private var model: LibraryTitleModel

    init(_ model: @autoclosure () -> LibraryTitleModel) {
        _model = State(initialValue: model())
    }

    var body: some View {
        NavigationStack {
            LibraryTitleScreen(model: model)
        }
    }
}

// MARK: - Status ausleihbar (mit Cover, Inhalt an)

#Preview("Ausleihbar – Light") { TitlePreview(.preview(.ausleihbar)).preferredColorScheme(.light) }
#Preview("Ausleihbar – Dark") { TitlePreview(.preview(.ausleihbar)).preferredColorScheme(.dark) }
#Preview("Ausleihbar – xxxLarge") { TitlePreview(.preview(.ausleihbar)).dynamicTypeSize(.xxxLarge) }

// MARK: - Status ausgeliehen

#Preview("Ausgeliehen – Light") { TitlePreview(.preview(.ausgeliehen)).preferredColorScheme(.light) }
#Preview("Ausgeliehen – Dark") { TitlePreview(.preview(.ausgeliehen)).preferredColorScheme(.dark) }
#Preview("Ausgeliehen – xxxLarge") { TitlePreview(.preview(.ausgeliehen)).dynamicTypeSize(.xxxLarge) }

// MARK: - Status nur vor Ort

#Preview("Nur vor Ort – Light") { TitlePreview(.preview(.nurVorOrt)).preferredColorScheme(.light) }
#Preview("Nur vor Ort – Dark") { TitlePreview(.preview(.nurVorOrt)).preferredColorScheme(.dark) }
#Preview("Nur vor Ort – xxxLarge") { TitlePreview(.preview(.nurVorOrt)).dynamicTypeSize(.xxxLarge) }

// MARK: - Status online

#Preview("Online – Light") { TitlePreview(.preview(.online)).preferredColorScheme(.light) }
#Preview("Online – Dark") { TitlePreview(.preview(.online)).preferredColorScheme(.dark) }
#Preview("Online – xxxLarge") { TitlePreview(.preview(.online)).dynamicTypeSize(.xxxLarge) }

// MARK: - Status unbekannt (leere Exemplarliste)

#Preview("Unbekannt – Light") { TitlePreview(.preview(.unbekannt)).preferredColorScheme(.light) }
#Preview("Unbekannt – Dark") { TitlePreview(.preview(.unbekannt)).preferredColorScheme(.dark) }
#Preview("Unbekannt – xxxLarge") { TitlePreview(.preview(.unbekannt)).dynamicTypeSize(.xxxLarge) }

// MARK: - Ohne Cover, Inhalt aus (alle Status)

#Preview("Ohne Cover, ohne Inhalt – Ausleihbar – Light") {
    TitlePreview(.preview(.ausleihbar, cover: false, contents: false)).preferredColorScheme(.light)
}
#Preview("Ohne Cover, ohne Inhalt – Ausleihbar – Dark") {
    TitlePreview(.preview(.ausleihbar, cover: false, contents: false)).preferredColorScheme(.dark)
}
#Preview("Ohne Cover, ohne Inhalt – Ausleihbar – xxxLarge") {
    TitlePreview(.preview(.ausleihbar, cover: false, contents: false)).dynamicTypeSize(.xxxLarge)
}
#Preview("Ohne Cover, ohne Inhalt – Ausgeliehen – Light") {
    TitlePreview(.preview(.ausgeliehen, cover: false, contents: false)).preferredColorScheme(.light)
}
#Preview("Ohne Cover, ohne Inhalt – Nur vor Ort – Light") {
    TitlePreview(.preview(.nurVorOrt, cover: false, contents: false)).preferredColorScheme(.light)
}
#Preview("Ohne Cover, ohne Inhalt – Online – Light") {
    TitlePreview(.preview(.online, cover: false, contents: false)).preferredColorScheme(.light)
}
#Preview("Ohne Cover, ohne Inhalt – Unbekannt – Light") {
    TitlePreview(.preview(.unbekannt, cover: false, contents: false)).preferredColorScheme(.light)
}

// MARK: - Weitere Zustände

#Preview("Inhaltsverzeichnis als Text – Light") {
    TitlePreview(.preview(.ausleihbar, tocAsText: true)).preferredColorScheme(.light)
}
#Preview("Veraltet – Light") {
    TitlePreview(.preview(.ausgeliehen, stale: true)).preferredColorScheme(.light)
}
#Preview("Lädt – Light") {
    TitlePreview(.previewWithoutDetail(.loading)).preferredColorScheme(.light)
}
#Preview("Titel nicht gefunden – Light") {
    TitlePreview(.previewWithoutDetail(.notFound)).preferredColorScheme(.light)
}
#Preview("Katalog nicht erreichbar – Light") {
    TitlePreview(.previewWithoutDetail(.failed("Katalog gerade nicht erreichbar"))).preferredColorScheme(.light)
}
#Preview("Katalog nicht erreichbar – Dark") {
    TitlePreview(.previewWithoutDetail(.failed("Katalog gerade nicht erreichbar"))).preferredColorScheme(.dark)
}
