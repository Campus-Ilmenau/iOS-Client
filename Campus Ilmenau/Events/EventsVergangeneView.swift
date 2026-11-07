import SwiftUI

/// „Vergangene“: der letzte Monat bis gestern, neueste zuerst. Ohne Tages- und Chipleiste.
/// Die Einstellungen aus dem Filter-Sheet (Art, Abgesagte) gelten auch hier.
struct EventsVergangeneView: View {
    @State private var model: EventsModel
    @State private var zeigtFilter = false

    @Environment(\.dismiss) private var dismiss

    init(quelle: any EventsDatenquelle, merkStore: EventsMerkStore, auswahl: EventsAuswahl) {
        // Nur die Einstellungen aus dem Sheet gelten; Tag, „Heute Abend“, Veranstalter und „Gemerkt“ gibt es hier nicht.
        var uebernommen = EventsAuswahl()
        uebernommen.art = auswahl.art
        uebernommen.abgesagteAusblenden = auswahl.abgesagteAusblenden
        _model = State(initialValue: EventsModel(
            modus: .vergangene,
            auswahl: uebernommen,
            quelle: quelle,
            merkStore: merkStore
        ))
    }

    /// Für Previews mit fertigem Modell.
    init(model: EventsModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            EventsKopf(
                titel: "Vergangene",
                unterzeile: model.unterzeile,
                filterAnzahl: model.auswahl.sheetAnzahl,
                zurueckTitel: "Kommende",
                onZurueck: { dismiss() },
                onFilter: { zeigtFilter = true }
            )
            EventsListe(model: model)
        }
        .background(Color(.background))
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.eventsMerkStore, model.merkStore)
        .sheet(isPresented: $zeigtFilter) {
            EventsFilterSheet(auswahl: $model.auswahl)
        }
        .task(id: model.ladeSchluessel) { await model.ladenWennNoetig() }
    }
}
