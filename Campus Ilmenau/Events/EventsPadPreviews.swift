import SwiftUI

// Vorschauen der iPad-Anordnung der Veranstaltungen (iPad Pro 13″, Beispieldaten ohne Netz, keine echten Konten):
// quer ohne Seitenleiste (1376 pt), quer mit Seitenleiste (1096 pt), hochkant (1032 pt), „Heute Abend“, abgesagte Veranstaltung,
// Veranstaltung ohne Plakat, leere Liste, Filter-Popover. Light und Dark über „Color Scheme“ der Vorschau.
// Die Breite kommt vom Rahmen; „Hochkant“ über „Orientation“ der Vorschau.

@MainActor
private struct EventsPadVorschau: View {
    let model: EventsModel
    var breite: CGFloat?
    @State var zustand = EventsPadZustand()
    @State private var tipp = false

    var body: some View {
        PadRasterMessung { raster in
            EventsPadAnsicht(
                model: model, zustand: $zustand, raster: raster, zeigtAbendTipp: $tipp,
                onHeuteAbend: { model.schalteHeuteAbend() }
            )
        }
        .environment(\.eventsMerkStore, model.merkStore)
        .frame(width: breite)
        .frame(maxWidth: breite == nil ? .infinity : nil, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.surfaceSecondary))
        .task(id: model.ladeSchluessel) { await model.ladenWennNoetig() }
        .task { await model.ladeBeiwerk() }
    }
}

#Preview("Quer ohne Seitenleiste") {
    EventsPadVorschau(model: vorschauModell(), breite: 1376)
}

#Preview("Quer mit Seitenleiste") {
    EventsPadVorschau(model: vorschauModell(), breite: 1096)
}

#Preview("Hochkant") {
    EventsPadVorschau(model: vorschauModell())
}

#Preview("Heute Abend") {
    EventsPadVorschau(model: vorschauModell(auswahl: .heuteAbend(jetzt: EventsVorschauQuelle.jetzt)), breite: 1376)
}

#Preview("Abgesagte Veranstaltung") {
    EventsPadVorschau(model: vorschauModell(), breite: 1376, zustand: .init(wahl: .init(id: "5", event: nil)))
}

#Preview("Unbestätigte Veranstaltung") {
    EventsPadVorschau(model: vorschauModell(), breite: 1376, zustand: .init(wahl: .init(id: "2", event: nil)))
}

#Preview("Mit Plakat") {
    // Halloween-Party mit Plakat aus einer Datei (siehe `EventDetailVorschau`), damit `AsyncImage` ohne Netz etwas lädt.
    let beispiele = EventsVorschauQuelle.beispiele.map { $0.id == "4" ? EventDetailVorschau.vollstaendig() : $0 }
    let speicher = EventsMerkStore(fileURL: nil)
    let modell = EventsModel(
        quelle: EventsVorschauQuelle(events: beispiele), merkStore: speicher, jetzt: { EventsVorschauQuelle.jetzt }
    )
    return EventsPadVorschau(model: modell, breite: 1376, zustand: .init(wahl: .init(id: "4", event: nil)))
}

#Preview("Leere Liste") {
    EventsPadVorschau(model: vorschauModell(verhalten: .leer), breite: 1376)
}

#Preview("Filter-Popover") {
    EventsFilterPopover(auswahl: .constant(EventsAuswahl()))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(40)
        .background(Color(.surfaceSecondary))
}

#Preview("Filter-Popover mit Auswahl") {
    var auswahl = EventsAuswahl()
    auswahl.art = .veranstaltung
    auswahl.abgesagteAusblenden = true
    return EventsFilterPopover(auswahl: .constant(auswahl))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(40)
        .background(Color(.surfaceSecondary))
}
