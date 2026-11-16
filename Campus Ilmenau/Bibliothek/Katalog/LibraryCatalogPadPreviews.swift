import SwiftUI

// Vorschauen des Katalogs auf dem iPad (iPad Pro 13″, Beispieldaten ohne Netz): quer ohne und mit Seitenleiste, hochkant,
// erweiterte Suche mit Fehler, Titel aus dem Gesamtkatalog, keine Treffer, Start ohne Suche.
// Light und Dark über „Color Scheme“ der Vorschau, hochkant über „Orientation“. Die Breite kommt vom Rahmen.

@MainActor
private struct KatalogPadVorschau: View {
    @State private var model: LibrarySearchModel
    @State private var zustand = KatalogPadZustand()
    @State private var fokus = false
    let breite: CGFloat?
    let titel: (@MainActor (LibraryMedia) -> LibraryTitleModel)?

    init(
        _ szenario: LibrarySearchModel.PreviewScenario,
        breite: CGFloat? = 1376,
        auswahl: Int? = 0,
        titel: (@MainActor (LibraryMedia) -> LibraryTitleModel)? = { _ in .preview(.ausleihbar) }
    ) {
        let modell = LibrarySearchModel.preview(szenario)
        _model = State(initialValue: modell)
        var start = KatalogPadZustand()
        if let auswahl, modell.phase == .results {
            start.wahl = modell.sections.flatMap(\.items)[safe: auswahl]
        }
        _zustand = State(initialValue: start)
        self.breite = breite
        self.titel = titel
    }

    var body: some View {
        PadRasterMessung { raster in
            KatalogPadAnsicht(
                model: model, zustand: $zustand, raster: raster, zurueckTitel: nil, fokusAnfrage: $fokus,
                onMerkliste: {}, vorschauTitel: titel
            )
        }
        .environment(\.merkliste, BibMerklisteStore(fileURL: nil, legacyDefaults: nil))
        .frame(width: breite)
        .frame(maxWidth: breite == nil ? .infinity : nil, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.surfaceSecondary))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

#Preview("Quer ohne Seitenleiste") { KatalogPadVorschau(.bestand) }

#Preview("Quer mit Seitenleiste") { KatalogPadVorschau(.bestand, breite: 1096) }

#Preview("Hochkant") { KatalogPadVorschau(.bestand, breite: nil) }

#Preview("Gesamtkatalog-Titel") {
    KatalogPadVorschau(.gemischt, auswahl: 3, titel: { _ in .preview(.unbekannt, cover: false) })
}

#Preview("Erweiterte Suche mit Fehler") { KatalogPadVorschau(.jahrFehler, auswahl: nil, titel: nil) }

#Preview("Keine Treffer") { KatalogPadVorschau(.keineTreffer, auswahl: nil, titel: nil) }

#Preview("Start") { KatalogPadVorschau(.start, auswahl: nil, titel: nil) }
