import SwiftUI

#if DEBUG

// Vorschauen der Merkliste auf dem iPad (iPad Pro 13″, Beispieldaten ohne Netz): quer ohne und mit Seitenleiste,
// hochkant, mit Gefunden-Abschnitt, leer, Titel nicht gefunden. Light und Dark über „Color Scheme“ der Vorschau, hochkant
// über „Orientation“. Die Breite kommt vom Rahmen. Toast, Alert und die Wischtasten zeigen nur das Gerät bzw. der Simulator.

@MainActor
private struct MerklistePadVorschau: View {
    let store: BibMerklisteStore
    let breite: CGFloat?
    let titel: @MainActor (GemerkterTitel) -> LibraryTitleModel

    init(
        gefunden: [Int] = [],
        leer: Bool = false,
        breite: CGFloat? = 1376,
        titel: @escaping @MainActor (GemerkterTitel) -> LibraryTitleModel = { _ in .preview(.ausleihbar) }
    ) {
        store = MerklisteBeispiele.store(filled: !leer, gefunden: gefunden)
        self.breite = breite
        self.titel = titel
    }

    var body: some View {
        let service = LibraryCatalogService()
        NavigationStack {
            BibMerklisteView(
                service: service,
                coverLoader: LibraryCoverLoader(service: service),
                mitZurueck: false,
                status: leerStatus,
                loadsStatus: false,
                vorschauTitel: titel
            )
        }
        .environment(\.merkliste, store)
        .frame(width: breite)
        .frame(maxWidth: breite == nil ? .infinity : nil, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.surfaceSecondary))
    }

    private var leerStatus: BibMerklisteStatus { store.anzahl == 0 ? BibMerklisteStatus() : MerklisteBeispiele.status }
}

#Preview("Quer ohne Seitenleiste") { MerklistePadVorschau() }

#Preview("Quer mit Seitenleiste") { MerklistePadVorschau(breite: 1096) }

#Preview("Hochkant") { MerklistePadVorschau(breite: nil) }

#Preview("Mit Gefunden") { MerklistePadVorschau(gefunden: [3, 5]) }

#Preview("Leer") { MerklistePadVorschau(leer: true) }

#Preview("Titel nicht gefunden") {
    MerklistePadVorschau(titel: { _ in .previewWithoutDetail(.notFound) })
}
#endif
