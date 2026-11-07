import SwiftUI

/// Die Karte „Heute Abend“ im Zusammenhang einer Seite: davor und danach andere Inhalte, damit man sieht,
/// dass bei 0 Einträgen keine Lücke bleibt.
private struct HeuteAbendVorschau: View {
    @State private var model: HeuteAbendModel

    init(events: [CampusEvent], verhalten: EventsVorschauQuelle.Verhalten = .daten) {
        _model = State(initialValue: HeuteAbendModel(
            quelle: EventsVorschauQuelle(verhalten: verhalten, events: events),
            zeitlimit: .seconds(1),
            jetzt: { EventsVorschauQuelle.jetzt }
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Hallo!")
                    .display(size: 32)
                    .foregroundStyle(Color(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HeuteAbendKarte(events: model.events, jetzt: model.jetztZeit, onAlle: {}, onOeffne: { _ in })
                Card {
                    Text("Als Nächstes")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(.textSecondary))
                }
            }
            .padding(16)
        }
        .background(Color(.background))
        .task { await model.laden() }
    }
}

private func abend(_ id: String, _ uhr: String, _ titel: String, ort: String?, status: EventStatus = .findetStatt) -> CampusEvent {
    CampusEvent(id: id, titel: titel, beginn: EventsVorschauQuelle.zeit(0, uhr), status: status, ort: ort)
}

private let zweiEvents = [
    abend("1", "19:00", "Spieleabend", ort: "Studi-Club, Keller"),
    abend("2", "20:00", "Kneipenabend", ort: "Baracke5")
]

private let fuenfEvents = [
    abend("1", "17:30", "Offene Chorprobe", ort: "Audimax"),
    abend("2", "19:00", "Spieleabend", ort: "Studi-Club, Keller"),
    abend("3", "20:00", "Filmabend: Lieblingsfilme der Fachschaften mit anschließender Diskussion", ort: "Hans-Club"),
    abend("4", "21:00", "Rock-Nacht", ort: "BC-Club", status: .abgesagt),
    abend("5", "22:00", "Elektro-Abend", ort: nil)
]

#Preview("Heute Abend – 0 Einträge") {
    HeuteAbendVorschau(events: []).preferredColorScheme(.light)
}

#Preview("Heute Abend – 2 Einträge") {
    HeuteAbendVorschau(events: zweiEvents).preferredColorScheme(.light)
}

#Preview("Heute Abend – 5 Einträge (zeigt 3)") {
    HeuteAbendVorschau(events: fuenfEvents).preferredColorScheme(.light)
}

#Preview("Heute Abend – 5 Einträge – Dark") {
    HeuteAbendVorschau(events: fuenfEvents).preferredColorScheme(.dark)
}

#Preview("Heute Abend – Fehler (Karte fehlt)") {
    HeuteAbendVorschau(events: fuenfEvents, verhalten: .fehler).preferredColorScheme(.light)
}

#Preview("Heute Abend – Zeitablauf (Karte fehlt)") {
    HeuteAbendVorschau(events: fuenfEvents, verhalten: .laedt).preferredColorScheme(.light)
}

#Preview("Heute Abend – große Schrift") {
    HeuteAbendVorschau(events: fuenfEvents)
        .environment(\.dynamicTypeSize, .accessibility2)
        .preferredColorScheme(.light)
}
