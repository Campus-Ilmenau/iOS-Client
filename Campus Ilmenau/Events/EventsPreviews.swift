import SwiftUI

/// Beispieldaten und eine Datenquelle ohne Netz für die Previews und Tests der Ansichten.
/// Die Beispiele folgen `Events.dc.html`; „jetzt“ ist Donnerstag, der 29. Oktober 2026, 12:00 Uhr (Berlin).
@MainActor
final class EventsVorschauQuelle: EventsDatenquelle {
    enum Verhalten {
        case daten
        case leer
        /// Antwortet nie, die Ansicht bleibt im Laden-Zustand.
        case laedt
        case fehler
    }

    static var jetzt: Date { zeit(0, "12:00") }

    let verhalten: Verhalten
    let events: [CampusEvent]

    init(verhalten: Verhalten = .daten, events: [CampusEvent] = EventsVorschauQuelle.beispiele) {
        self.verhalten = verhalten
        self.events = events
    }

    func liste(filter: EventFilter, seite: Int, jetzt: Date) async throws -> EventSeite {
        switch verhalten {
        case .laedt:
            try await Task.sleep(for: .seconds(3600))
        case .fehler:
            throw EventsAPIError.networkError(URLError(.notConnectedToInternet))
        case .leer:
            return EventSeite(events: [], seite: seite, hatWeitere: false, gesamt: 0)
        case .daten:
            break
        }
        let treffer = events.filter { passt($0, filter: filter, jetzt: jetzt) }
        return EventSeite(events: treffer, seite: seite, hatWeitere: false, gesamt: treffer.count)
    }

    func detail(id: String) async throws -> CampusEvent {
        switch verhalten {
        case .laedt: try await Task.sleep(for: .seconds(3600))
        case .fehler: throw EventsAPIError.networkError(URLError(.notConnectedToInternet))
        case .leer: throw EventsAPIError.notFound
        case .daten: break
        }
        guard let event = events.first(where: { $0.id == id }) else { throw EventsAPIError.notFound }
        return event
    }

    func veranstalter() async throws -> [Veranstalter] {
        switch verhalten {
        case .laedt: try await Task.sleep(for: .seconds(3600))
        case .fehler: throw EventsAPIError.invalidResponse
        case .leer: return []
        case .daten: break
        }
        let heute = EventKalender.tagesbeginn(Self.jetzt)
        let kommende = events.filter { $0.letzterTag >= heute }
        let gruppen = Dictionary(grouping: kommende.compactMap { $0.veranstalter }, by: { $0 })
        return gruppen
            .map { Veranstalter(name: $0.key, anzahlKommende: $0.value.count) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Nachbau der Server-Regeln für Zeit, Veranstalter, Art und Abgesagte.
    private func passt(_ event: CampusEvent, filter: EventFilter, jetzt: Date) -> Bool {
        if filter.abgesagteAusblenden, event.status == .abgesagt { return false }
        if let veranstalter = filter.veranstalter, (event.veranstalterID ?? event.veranstalter)?.lowercased() != veranstalter.lowercased() { return false }
        if let kategorie = filter.kategorie,
           (event.kategorie ?? "Veranstaltung").caseInsensitiveCompare(kategorie) != .orderedSame { return false }
        switch filter.zeitfilter(jetzt: jetzt) {
        case .abend(let tag):
            let stunde = Int(EventKalender.format(event.beginn, "H")) ?? 0
            return event.laeuftAm(tag) && !event.ganztaegig && stunde >= 17
        case .tag(let tag):
            return event.laeuftAm(tag)
        case .zeitraum(let von, let bis):
            return event.letzterTag >= von && (bis.map { event.beginn < $0 } ?? true)
        }
    }

    // MARK: Beispieldaten

    /// Berliner Zeit: `tag` Tage nach heute, `uhr` als „HH:mm“.
    static func zeit(_ tag: Int, _ uhr: String) -> Date {
        let teile = uhr.split(separator: ":").compactMap { Int($0) }
        let heute = EventKalender.tagesbeginn(EventKalender.kalender.date(
            from: DateComponents(timeZone: EventKalender.zeitzone, year: 2026, month: 10, day: 29, hour: 12)
        ) ?? .now)
        let tagesbeginn = EventKalender.tag(heute, plus: tag)
        return EventKalender.kalender.date(
            bySettingHour: teile.first ?? 0, minute: teile.last ?? 0, second: 0, of: tagesbeginn
        ) ?? tagesbeginn
    }

    private static func ganztaegig(_ id: String, von: Int, bis: Int, titel: String, ort: String?, veranstalter: String,
                                   kategorie: String? = nil) -> CampusEvent {
        CampusEvent(
            id: id, titel: titel, beginn: zeit(von, "00:00"), ende: zeit(bis + 1, "00:00"), ganztaegig: true,
            ort: ort, veranstalter: veranstalter, kategorie: kategorie
        )
    }

    static let beispiele: [CampusEvent] = [
        CampusEvent(id: "1", titel: "Spieleabend", beginn: zeit(0, "19:00"), ende: zeit(0, "23:00"),
                    ort: "Studi-Club, Keller", veranstalter: "Studi-Club"),
        CampusEvent(id: "2", titel: "Kneipenabend", beginn: zeit(0, "20:00"), status: .unbestaetigt,
                    ort: "Baracke5", veranstalter: "Baracke5"),
        ganztaegig("3", von: -1, bis: 3, titel: "Fotoausstellung „Licht über Ilmenau“",
                   ort: "Humboldtbau, Foyer", veranstalter: "Fotoverein"),
        CampusEvent(id: "4", titel: "Halloween-Party", beginn: zeit(1, "21:00"), ende: zeit(2, "03:00"),
                    ort: "Studi-Club", veranstalter: "Studi-Club"),
        CampusEvent(id: "5", titel: "Rock-Nacht", beginn: zeit(1, "22:00"), status: .abgesagt,
                    ort: "BC-Club", veranstalter: "BC-Club"),
        CampusEvent(id: "6", titel: "Fotowalk durch Ilmenau", beginn: zeit(2, "14:00"), ende: zeit(2, "16:00"),
                    ort: "Treffpunkt Markt", veranstalter: "Fotoverein"),
        ganztaegig("7", von: 4, bis: 4, titel: "Rückmeldung zum Sommersemester", ort: nil,
                   veranstalter: "TU Ilmenau", kategorie: "Frist"),
        CampusEvent(id: "8", titel: "Filmabend: Lieblingsfilme der Fachschaften", beginn: zeit(4, "20:00"),
                    ende: zeit(4, "23:30"), ort: "Hans-Club", veranstalter: "Hans-Club"),
        CampusEvent(id: "9", titel: "Pub-Quiz", beginn: zeit(5, "20:00"), ort: "Baracke5", veranstalter: "Baracke5"),
        CampusEvent(id: "10", titel: "Offene Chorprobe", beginn: zeit(6, "19:30"), ende: zeit(6, "21:00"),
                    ort: "Audimax", veranstalter: "Uni-Chor"),
        CampusEvent(id: "11", titel: "Elektro-Abend", beginn: zeit(8, "21:00"), status: .unbestaetigt,
                    ort: "Baracke5", veranstalter: "Baracke5"),
        // Vergangene
        CampusEvent(id: "21", titel: "Karaoke", beginn: zeit(-1, "20:00"), ende: zeit(-1, "23:00"),
                    ort: "BC-Club", veranstalter: "BC-Club"),
        CampusEvent(id: "22", titel: "Erstsemester-Grillen", beginn: zeit(-3, "19:00"),
                    ort: "Campus, Wiese am Ehrenberg", veranstalter: "StuRa"),
        CampusEvent(id: "23", titel: "Semesterstart-Party", beginn: zeit(-6, "21:00"), status: .abgesagt,
                    ort: "Hans-Club", veranstalter: "Hans-Club")
    ]
}

/// Eine Ansicht mit festem „jetzt“, Beispieldaten und einem Merk-Speicher nur im Speicher (Stern bei „4“).
@MainActor
private func vorschauModell(
    verhalten: EventsVorschauQuelle.Verhalten = .daten,
    auswahl: EventsAuswahl = EventsAuswahl(),
    gemerkt: Set<String> = ["4"]
) -> EventsModel {
    let speicher = EventsMerkStore(fileURL: nil)
    for id in gemerkt { speicher.umschalten(id) }
    return EventsModel(
        auswahl: auswahl,
        quelle: EventsVorschauQuelle(verhalten: verhalten),
        merkStore: speicher,
        jetzt: { EventsVorschauQuelle.jetzt }
    )
}

#Preview("Events – Liste – Light") {
    EventsView(model: vorschauModell())
        .preferredColorScheme(.light)
}

#Preview("Events – Liste – Dark") {
    EventsView(model: vorschauModell())
        .preferredColorScheme(.dark)
}

#Preview("Events – Heute Abend + Baracke5") {
    var auswahl = EventsAuswahl()
    auswahl.schalteHeuteAbend(jetzt: EventsVorschauQuelle.jetzt)
    auswahl.veranstalter = "Baracke5"
    return EventsView(model: vorschauModell(auswahl: auswahl))
        .preferredColorScheme(.light)
}

#Preview("Events – Heute Abend + Baracke5 – Dark") {
    var auswahl = EventsAuswahl()
    auswahl.schalteHeuteAbend(jetzt: EventsVorschauQuelle.jetzt)
    auswahl.veranstalter = "Baracke5"
    auswahl.art = .veranstaltung
    return EventsView(model: vorschauModell(auswahl: auswahl))
        .preferredColorScheme(.dark)
}

#Preview("Events – Filter-Sheet – Light") {
    EventsFilterSheet(auswahl: .constant(EventsAuswahl(art: .frist, abgesagteAusblenden: true)))
        .preferredColorScheme(.light)
}

#Preview("Events – Filter-Sheet – Dark") {
    EventsFilterSheet(auswahl: .constant(EventsAuswahl()))
        .preferredColorScheme(.dark)
}

#Preview("Events – Vergangene – Light") {
    NavigationStack {
        EventsVergangeneView(model: {
            let modell = vorschauModell(gemerkt: [])
            return EventsModel(
                modus: .vergangene,
                quelle: modell.quelle,
                merkStore: modell.merkStore,
                jetzt: { EventsVorschauQuelle.jetzt }
            )
        }())
        .navigationDestination(for: EventsRoute.self) { _ in EmptyView() }
    }
    .preferredColorScheme(.light)
}

#Preview("Events – Vergangene – Dark") {
    NavigationStack {
        EventsVergangeneView(model: {
            let modell = vorschauModell(gemerkt: [])
            return EventsModel(
                modus: .vergangene,
                quelle: modell.quelle,
                merkStore: modell.merkStore,
                jetzt: { EventsVorschauQuelle.jetzt }
            )
        }())
        .navigationDestination(for: EventsRoute.self) { _ in EmptyView() }
    }
    .preferredColorScheme(.dark)
}

#Preview("Events – Leer: Heute Abend") {
    var auswahl = EventsAuswahl()
    auswahl.schalteHeuteAbend(jetzt: EventsVorschauQuelle.jetzt)
    return EventsView(model: vorschauModell(verhalten: .leer, auswahl: auswahl))
        .preferredColorScheme(.light)
}

#Preview("Events – Leer: Gemerkt") {
    var auswahl = EventsAuswahl()
    auswahl.nurGemerkt = true
    return EventsView(model: vorschauModell(auswahl: auswahl, gemerkt: []))
        .preferredColorScheme(.light)
}

#Preview("Events – Leer: Auswahl – Dark") {
    EventsView(model: vorschauModell(verhalten: .leer))
        .preferredColorScheme(.dark)
}

#Preview("Events – Laden") {
    EventsView(model: vorschauModell(verhalten: .laedt))
        .preferredColorScheme(.light)
}

#Preview("Events – Laden – Dark") {
    EventsView(model: vorschauModell(verhalten: .laedt))
        .preferredColorScheme(.dark)
}

#Preview("Events – Fehler") {
    EventsView(model: vorschauModell(verhalten: .fehler))
        .preferredColorScheme(.light)
}

#Preview("Events – Fehler – Dark") {
    EventsView(model: vorschauModell(verhalten: .fehler))
        .preferredColorScheme(.dark)
}

#Preview("Events – Karten – Light") {
    EventKartenVorschau().preferredColorScheme(.light)
}

#Preview("Events – Karten – Dark") {
    EventKartenVorschau().preferredColorScheme(.dark)
}

/// Alle Zustände der Karte untereinander: normal, unbestätigt, abgesagt, Frist, mehrtägig, lang, gemerkt.
private struct EventKartenVorschau: View {
    @State private var speicher = EventsMerkStore(fileURL: nil)

    var body: some View {
        let jetzt = EventsVorschauQuelle.jetzt
        let heute = EventKalender.tagesbeginn(jetzt)
        let beispiele = EventsVorschauQuelle.beispiele
        let lang = CampusEvent(
            id: "99",
            titel: "Sehr langer Titel einer Veranstaltung, der sich über mehr als zwei Zeilen erstreckt und gekürzt wird",
            beginn: EventsVorschauQuelle.zeit(0, "18:30"), ort: "Mensa Ehrenberg, Obergeschoss, Raum 2",
            veranstalter: "Fachschaftsrat Elektrotechnik und Informationstechnik"
        )
        let liste = [beispiele[0], beispiele[1], beispiele[4], beispiele[6], beispiele[2], beispiele[3], lang]
        ScrollView {
            VStack(spacing: 10) {
                ForEach(liste) { event in
                    EventKarte(event: event, bezugstag: heute, jetzt: jetzt)
                }
            }
            .padding(16)
        }
        .background(Color(.background))
        .environment(\.eventsMerkStore, speicher)
        .onAppear { speicher.umschalten("4") }
    }
}

#Preview("Events – Chipleiste") {
    var auswahl = EventsAuswahl()
    auswahl.veranstalter = "Baracke5"
    return VStack(spacing: 12) {
        EventsChipleiste(
            auswahl: auswahl,
            veranstalter: [
                Veranstalter(name: "Baracke5", anzahlKommende: 4),
                Veranstalter(name: "BC-Club", anzahlKommende: 1),
                Veranstalter(name: "Studi-Club", anzahlKommende: 2)
            ],
            onHeuteAbend: {}, onGemerkt: {}, onVeranstalter: { _ in }
        )
        Spacer()
    }
    .padding(.top, 20)
    .background(Color(.background))
}
