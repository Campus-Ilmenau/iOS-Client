import SwiftUI

/// Beispiele für die Previews der Detailansicht, nach den Tweaks in `EventDetail.dc.html`.
@MainActor
enum EventDetailVorschau {
    /// Ein Plakat aus Farbverlauf als Datei, damit `AsyncImage` ohne Netz etwas lädt.
    static let plakat: URL? = {
        let inhalt = LinearGradient(
            colors: [Color(.brandOrange), Color(.brandDusk), Color(.brandNight)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: 390, height: 280)
        let renderer = ImageRenderer(content: inhalt)
        renderer.scale = 2
        guard let daten = renderer.uiImage?.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("EventPlakatVorschau.png")
        try? daten.write(to: url)
        return url
    }()

    static let beschreibung = """
    Kürbisse, Kunstblut und DJs bis zum Morgengrauen. Das beste Kostüm gewinnt einen Monat freien Eintritt.

    Einlass ab 20:30 Uhr. Bitte Studierendenausweis mitbringen – Gäste nur in Begleitung.

    Garderobe vorhanden, Getränke zu Club-Preisen.
    """

    static func vollstaendig(
        status: EventStatus = .findetStatt,
        mitBild: Bool = true,
        titel: String = "Halloween-Party",
        tickets: Bool = true
    ) -> CampusEvent {
        CampusEvent(
            id: "4", titel: titel,
            beginn: EventsVorschauQuelle.zeit(1, "21:00"), ende: EventsVorschauQuelle.zeit(2, "03:00"),
            status: status, ort: "Studi-Club", adresse: "Max-Planck-Ring 6, 98693 Ilmenau",
            veranstalter: "Studi-Club", beschreibung: beschreibung,
            bildURL: mitBild ? plakat : nil,
            infoURL: URL(string: "https://studi-club.example/halloween"),
            ticketURL: tickets ? URL(string: "https://tickets.example/halloween") : nil
        )
    }

    static let mehrtaegig = CampusEvent(
        id: "3", titel: "Fotoausstellung „Licht über Ilmenau“",
        beginn: EventsVorschauQuelle.zeit(-1, "00:00"), ende: EventsVorschauQuelle.zeit(4, "00:00"), ganztaegig: true,
        ort: "Humboldtbau, Foyer", adresse: "Max-Planck-Ring 12, 98693 Ilmenau", veranstalter: "Fotoverein",
        beschreibung: "Fotos aus zehn Jahren Ilmenau, ausgewählt vom Fotoverein.",
        infoURL: URL(string: "https://fotoverein.example")
    )

    static let knapp = CampusEvent(
        id: "9", titel: "Pub-Quiz", beginn: EventsVorschauQuelle.zeit(1, "21:00")
    )

    static func modell(_ event: CampusEvent?, verhalten: EventsVorschauQuelle.Verhalten = .daten) -> EventDetailModel {
        EventDetailModel(
            id: event?.id ?? "4",
            event: event,
            quelle: EventsVorschauQuelle(verhalten: verhalten, events: event.map { [$0] } ?? []),
            kalender: VorschauKalender()
        )
    }
}

/// Schreibt nirgends hin und meldet Erfolg.
@MainActor
struct VorschauKalender: EventKalenderSchreiber {
    var ergebnis: KalenderErgebnis = .eingetragen

    func eintragen(_ eintrag: KalenderEintrag) async -> KalenderErgebnis { ergebnis }
}

@MainActor
private func vorschau(
    _ event: CampusEvent?,
    verhalten: EventsVorschauQuelle.Verhalten = .daten,
    anzahl: Int? = 3
) -> some View {
    NavigationStack {
        EventDetailView(
            model: EventDetailVorschau.modell(event, verhalten: verhalten),
            anzahlKommende: anzahl,
            onAlleVonVeranstalter: { _ in }
        )
    }
    .environment(\.eventsMerkStore, EventsMerkStore(fileURL: nil))
}

#Preview("Detail – vollständig – Light") {
    vorschau(EventDetailVorschau.vollstaendig()).preferredColorScheme(.light)
}

#Preview("Detail – vollständig – Dark") {
    vorschau(EventDetailVorschau.vollstaendig()).preferredColorScheme(.dark)
}

#Preview("Detail – ohne Bild") {
    vorschau(EventDetailVorschau.vollstaendig(mitBild: false)).preferredColorScheme(.light)
}

#Preview("Detail – ohne Bild – Dark") {
    vorschau(EventDetailVorschau.vollstaendig(mitBild: false)).preferredColorScheme(.dark)
}

#Preview("Detail – abgesagt") {
    vorschau(EventDetailVorschau.vollstaendig(status: .abgesagt)).preferredColorScheme(.light)
}

#Preview("Detail – abgesagt – Dark") {
    vorschau(EventDetailVorschau.vollstaendig(status: .abgesagt, mitBild: false)).preferredColorScheme(.dark)
}

#Preview("Detail – unbestätigt") {
    vorschau(EventDetailVorschau.vollstaendig(status: .unbestaetigt)).preferredColorScheme(.light)
}

#Preview("Detail – ganztägig, mehrtägig") {
    vorschau(EventDetailVorschau.mehrtaegig, anzahl: 2).preferredColorScheme(.light)
}

#Preview("Detail – knapp") {
    vorschau(EventDetailVorschau.knapp).preferredColorScheme(.light)
}

#Preview("Detail – knapp – Dark") {
    vorschau(EventDetailVorschau.knapp).preferredColorScheme(.dark)
}

#Preview("Detail – langer Titel") {
    vorschau(EventDetailVorschau.vollstaendig(
        titel: "Filmabend: Lieblingsfilme der Fachschaften mit anschließender Diskussion"
    ))
    .preferredColorScheme(.light)
}

#Preview("Detail – große Schrift") {
    vorschau(EventDetailVorschau.vollstaendig(status: .unbestaetigt))
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.light)
}

#Preview("Detail – nicht gefunden") {
    vorschau(nil, verhalten: .leer).preferredColorScheme(.light)
}

#Preview("Detail – Fehler – Dark") {
    vorschau(nil, verhalten: .fehler).preferredColorScheme(.dark)
}

#Preview("Detail – lädt") {
    vorschau(nil, verhalten: .laedt).preferredColorScheme(.light)
}
