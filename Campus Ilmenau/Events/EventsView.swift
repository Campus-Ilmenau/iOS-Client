import SwiftUI
import AppIntents

/// Der Tab „Events“: Kopf, Tagesleiste, Chipleiste und die nach Tagen gruppierte Liste.
/// Nach `Events.dc.html` und `EventsAbend.dc.html`.
struct EventsView: View {
    @State private var model: EventsModel
    @State private var pfad: [EventsRoute] = []
    @State private var zeigtFilter = false
    /// Der Siri-Tipp in „Heute Abend“ ist gerade zu sehen, und ob er schon einmal erschienen ist.
    @State private var zeigtAbendTipp = false
    @AppStorage(SiriTipp.abendGezeigt) private var abendTippGezeigt = false
    /// Wunsch von der Heute-Seite („Alle“ bei „Heute Abend“).
    @Environment(AppRouter.self) private var router: AppRouter?

    init(model: EventsModel? = nil) {
        _model = State(initialValue: model ?? EventsModel(widgetSync: .shared))
    }

    var body: some View {
        NavigationStack(path: $pfad) {
            VStack(spacing: 0) {
                EventsKopf(
                    titel: "Veranstaltungen",
                    unterzeile: model.unterzeile,
                    filterAnzahl: model.auswahl.sheetAnzahl,
                    onFilter: { zeigtFilter = true }
                )
                EventsTagesleiste(
                    tage: model.tage,
                    gewaehlterTag: model.auswahl.tag,
                    tageMitEvents: model.tageMitEvents,
                    jetzt: model.jetztZeit,
                    onWahl: { model.auswahl.waehleTag($0) }
                )
                .padding(.bottom, 2)
                EventsChipleiste(
                    auswahl: model.auswahl,
                    veranstalter: model.veranstalter,
                    onHeuteAbend: {
                        model.schalteHeuteAbend()
                        if model.auswahl.heuteAbend { SiriMelder.gemeinsam.melde(.heuteAbend, in: .events, router: router) }
                    },
                    onGemerkt: { model.auswahl.nurGemerkt.toggle() },
                    onVeranstalter: { model.auswahl.schalteVeranstalter($0.name, id: $0.id) }
                )
                .padding(.bottom, 4)
                if zeigtAbendTipp, model.auswahl.heuteAbend {
                    SiriTipView(intent: HeuteAbendIntent(), isVisible: $zeigtAbendTipp)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                EventsListe(model: model, onVergangene: { pfad.append(.vergangene) })
            }
            .background(Color(.background))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: EventsRoute.self) { route in
                switch route {
                case .detail(let event):
                    EventDetailView(
                        model: EventDetailModel(id: event.id, event: event, quelle: model.quelle),
                        anzahlKommende: event.veranstalter.flatMap { name in
                            model.veranstalter.first { $0.name == name }?.anzahlKommende
                        },
                        onAlleVonVeranstalter: { name in
                            // Die API filtert nach der ID: aus dem Event, sonst über die Veranstalterliste
                            let id = event.veranstalterID ?? model.veranstalter.first { $0.name == name }?.id
                            if let id { model.auswahl.waehleVeranstalter(name, id: id) }
                            pfad = []
                        }
                    )
                case .detailID(let id):
                    EventDetailView(
                        model: EventDetailModel(id: id, quelle: model.quelle),
                        onAlleVonVeranstalter: { name in
                            if let veranstalter = model.veranstalter.first(where: { $0.name == name }) {
                                model.auswahl.waehleVeranstalter(name, id: veranstalter.id)
                            }
                            pfad = []
                        }
                    )
                case .vergangene:
                    EventsVergangeneView(
                        quelle: model.quelle,
                        merkStore: model.merkStore,
                        auswahl: model.auswahl
                    )
                }
            }
        }
        .environment(\.eventsMerkStore, model.merkStore)
        .onAppear {
            uebernehmeAlleWunsch()
            uebernehmeHeuteAbendWunsch()
            uebernehmeEventWunsch()
            pruefeAbendTipp()
        }
        .onChange(of: model.auswahl.heuteAbend) { _, _ in pruefeAbendTipp() }
        .onChange(of: router?.tab) { _, neu in
            if neu == .events { SiriMelder.gemeinsam.neueOeffnung(.events) }
        }
        .onChange(of: router?.eventsAlle) { _, _ in uebernehmeAlleWunsch() }
        .onChange(of: router?.eventsHeuteAbend) { _, _ in uebernehmeHeuteAbendWunsch() }
        .onChange(of: router?.eventWunsch) { _, _ in uebernehmeEventWunsch() }
        .sheet(isPresented: $zeigtFilter) {
            EventsFilterSheet(auswahl: $model.auswahl)
        }
        // Am Stapel statt an der Liste: Die Aufgaben laufen weiter, wenn ein Detail geöffnet ist.
        .task(id: model.ladeSchluessel) { await model.ladenWennNoetig() }
        .task { await model.ladeBeiwerk() }
        .task(id: model.auswahl.nurGemerkt) {
            if model.auswahl.nurGemerkt { await model.ladeRest() }
        }
    }

    /// Der Siri-Tipp erscheint einmal, beim ersten Mal, dass „Heute Abend“ aktiv ist. Nach dem × oder dem Wechsel der
    /// Auswahl kommt er nie wieder (`@AppStorage`).
    private func pruefeAbendTipp() {
        guard SiriTipp.zeigtAbendErstmals(heuteAbendAktiv: model.auswahl.heuteAbend, schonGezeigt: abendTippGezeigt) else { return }
        abendTippGezeigt = true
        zeigtAbendTipp = true
    }

    private func uebernehmeHeuteAbendWunsch() {
        guard router?.eventsHeuteAbend == true else { return }
        router?.eventsHeuteAbend = false
        pfad = []
        model.auswahl = EventsAuswahl.heuteAbend(jetzt: model.jetztZeit)
        // Kam die Wahl von der Startseite („Alle ›“), ist es eine Handlung in der App; ein Link von außen zählt iOS selbst.
        SiriMelder.gemeinsam.melde(.heuteAbend, in: .events, router: router)
    }

    /// Link `campusilmenau://events`: die Liste ab heute, ohne die Filter vom letzten Besuch.
    private func uebernehmeAlleWunsch() {
        guard router?.eventsAlle == true else { return }
        router?.eventsAlle = false
        pfad = []
        model.auswahl = EventsAuswahl()
    }

    /// Link `campusilmenau://events/<id>`: öffnet das Detail über der Liste.
    private func uebernehmeEventWunsch() {
        guard let id = router?.eventWunsch else { return }
        router?.eventWunsch = nil
        pfad = [.detailID(id)]
    }
}

/// Liste der Veranstaltungen mit Laden, Fehler und Leer-Zustand. Gleich für „Kommende“ und „Vergangene“.
/// Mit `onVergangene` steht am Ende der Link „Vergangene Veranstaltungen“, und die Abschnitte zeigen ihre Anzahl.
struct EventsListe: View {
    let model: EventsModel
    var onVergangene: (() -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                switch model.zustand {
                case .laedt:
                    platzhalter
                case .fehler:
                    EventsMeldung(
                        titel: "Veranstaltungen konnten nicht geladen werden",
                        text: "Prüfe deine Verbindung und versuch es noch einmal.",
                        aktion: "Erneut versuchen",
                        hauptaktion: true,
                        onAktion: { model.nochmalVersuchen() }
                    )
                case .geladen:
                    if model.abschnitte.isEmpty {
                        leer
                    } else {
                        abschnitte
                        fuss
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable { await model.aktualisieren() }
    }

    // MARK: Abschnitte

    private var abschnitte: some View {
        let formatter = EventZeitFormatter(jetzt: model.jetztZeit)
        let letzte = model.abschnitte.last?.events.last?.id
        return ForEach(model.abschnitte) { abschnitt in
            HStack {
                Text(titel(abschnitt.tag, formatter))
                    .foregroundStyle(Color(.textSecondary))
                Spacer(minLength: 8)
                if onVergangene != nil {
                    Text(abschnitt.zaehler)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(.textTertiary))
                }
            }
            .font(.footnote.weight(.bold))
            .padding(.horizontal, 2)
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(abschnitt.events) { event in
                EventKarte(event: event, bezugstag: abschnitt.tag, jetzt: model.jetztZeit)
                    .onAppear {
                        if event.id == letzte { Task { await model.weiterLaden() } }
                    }
            }
        }
    }

    private func titel(_ tag: Date, _ formatter: EventZeitFormatter) -> String {
        model.modus == .vergangene
            ? formatter.vergangenerAbschnittstitel(fuer: tag)
            : formatter.abschnittstitel(fuer: tag)
    }

    /// Ende der Liste: Hinweis oder Ziege beim Nachladen, bei „Kommende“ der Link zu den vergangenen.
    @ViewBuilder
    private var fuss: some View {
        if model.laedtWeitere {
            GoatLoadingFooter()
                .padding(.top, 6)
        } else if model.hatWeitere, model.modus == .kommende {
            Text("Weitere laden beim Scrollen automatisch.")
                .font(.footnote)
                .foregroundStyle(Color(.textTertiary))
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
        }
        if let onVergangene {
            SecondaryButton("Vergangene Veranstaltungen", action: onVergangene)
                .padding(.top, 4)
        }
    }

    // MARK: Leer

    @ViewBuilder
    private var leer: some View {
        switch model.leerArt {
        case .gemerkt:
            EventsMeldung(
                titel: "Noch nichts gemerkt",
                text: "Tippe auf den Stern bei einer Veranstaltung. Gemerktes bleibt auf deinem iPhone.",
                aktion: "Alle anzeigen",
                onAktion: { model.zuruecksetzen() }
            )
        case .abend(let heute):
            EventsMeldung(
                titel: heute ? "Heute Abend ist nichts eingetragen" : "An diesem Abend ist nichts eingetragen",
                text: "Ab 17 Uhr findest du hier Partys, Kneipenabende und mehr.",
                aktion: "Alles ab heute zeigen",
                onAktion: { model.zuruecksetzen() }
            )
        case .allgemein:
            if model.modus == .vergangene {
                EventsMeldung(
                    titel: "Keine Veranstaltungen für diese Auswahl",
                    text: "Im letzten Monat gab es dazu nichts.",
                    aktion: model.auswahl.sheetAnzahl > 0 ? "Filter zurücksetzen" : nil,
                    onAktion: { model.zuruecksetzen() }
                )
            } else {
                EventsMeldung(
                    titel: "Keine Veranstaltungen für diese Auswahl",
                    text: "Wähle einen anderen Tag oder einen anderen Veranstalter.",
                    aktion: "Filter zurücksetzen",
                    onAktion: { model.zuruecksetzen() }
                )
            }
        }
    }

    // MARK: Laden

    /// Graue Platzhalter-Karten mit demselben Aufbau wie die echten.
    private var platzhalter: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                Card(verticalPadding: 12, horizontalPadding: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("19:00–23:00 Uhr")
                            .font(.footnote.weight(.semibold))
                        Text("Titel der Veranstaltung")
                            .font(.callout.weight(.semibold))
                        Text("Ort · Veranstalter")
                            .font(.footnote)
                    }
                    .foregroundStyle(Color(.textPrimary))
                    .padding(.trailing, 36)
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Veranstaltungen werden geladen")
    }
}

/// Mitteilung mitten in der Liste: Titel, Text und ein Button. Für Leer-Zustände und den Fehler.
struct EventsMeldung: View {
    let titel: LocalizedStringKey
    let text: LocalizedStringKey
    var aktion: LocalizedStringKey?
    /// `true` für den Hauptbutton (Fehler), sonst Nebenbutton.
    var hauptaktion = false
    let onAktion: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(titel)
                .font(.headline)
                .foregroundStyle(Color(.textPrimary))
                .multilineTextAlignment(.center)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
            if let aktion {
                Group {
                    if hauptaktion {
                        PrimaryButton(aktion, action: onAktion)
                    } else {
                        SecondaryButton(aktion, action: onAktion)
                    }
                }
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 40)
    }
}
