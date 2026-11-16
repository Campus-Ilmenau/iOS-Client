import SwiftUI
import AppIntents

// Veranstaltungen auf dem iPad (ab 700 pt Breite der Ansicht): Liste links, Detail rechts, kein Push.
// Nach `PadEvents.dc.html` und `PadEventsAbend.dc.html`; Daten, Filterregeln, Sortierung und Texte wie auf dem iPhone.

/// Wohin die Liste scrollen soll. `mitte`: mittig (Link), sonst nur so weit, dass die Karte sichtbar wird (Pfeiltasten).
struct EventsScrollZiel: Equatable {
    let id: String
    var mitte = true
}

/// Was die Liste für die iPad-Anordnung braucht: gewählte Karte, Auswahl, Pfeiltasten und das Scrollziel.
struct EventsPadAuswahl {
    var gewaehlteID: String?
    var scrollZiel: EventsScrollZiel?
    var rand = EventsRand.pad
    let onWahl: (CampusEvent) -> Void
    /// −1 für ↑, +1 für ↓.
    let onPfeil: (Int) -> Void
    let fokus: FocusState<Bool>.Binding
    let onGescrollt: () -> Void
}

/// Pfeiltasten ↑/↓ wechseln die Auswahl, solange die Liste den Tastaturfokus hat. Ohne iPad-Auswahl tut der Modifier nichts.
struct EventsPadTasten: ViewModifier {
    let pad: EventsPadAuswahl?

    func body(content: Content) -> some View {
        if let pad {
            content
                .focusable()
                .focused(pad.fokus)
                .focusEffectDisabled()
                .onKeyPress(.upArrow) { pad.onPfeil(-1); return .handled }
                .onKeyPress(.downArrow) { pad.onPfeil(1); return .handled }
        } else {
            content
        }
    }
}

/// Zustand der iPad-Anordnung. Er liegt im Inhalt des Tabs, damit er beim Drehen und bei der Seitenleiste erhalten bleibt.
struct EventsPadZustand {
    struct Wahl: Equatable {
        let id: String
        /// Die Veranstaltung aus der Liste; bei einem Link nur mit ID zunächst `nil` (das Detail lädt sie selbst).
        var event: CampusEvent?
    }

    var wahl: Wahl?
    /// „Vergangene Veranstaltungen“ ersetzt nur die linke Spalte.
    var zeigtVergangene = false
    var vergangene: EventsModel?
    var scrollZiel: EventsScrollZiel?
    /// Die ID eines Links, die gerade in die Liste nachgeladen wird.
    var suchtID: String?
    /// Gewählt, steht aber nicht in der Liste (Link auf eine Veranstaltung außerhalb der Auswahl). Bleibt, bis sich die Auswahl ändert.
    var fremdeID: String?

    /// „Alle Veranstaltungen“, „Heute Abend“: Auswahl zurückgesetzt, die erste der Liste wird gewählt.
    mutating func zuruecksetzen() {
        wahl = nil
        zeigtVergangene = false
        vergangene = nil
        scrollZiel = nil
        suchtID = nil
        fremdeID = nil
    }

    /// Beim Öffnen und wenn die gewählte durch einen Filter verschwindet: die erste der Liste. Bleibt die Liste leer, ist
    /// nichts gewählt. Ein Link-Ziel, das noch gesucht wird oder außerhalb der Liste liegt, bleibt stehen.
    mutating func korrigiere(liste: [CampusEvent]) {
        if let wahl {
            if let gefunden = liste.first(where: { $0.id == wahl.id }) {
                if wahl.event == nil { self.wahl?.event = gefunden }
                fremdeID = nil
                return
            }
            if suchtID == wahl.id || fremdeID == wahl.id { return }
        }
        wahl = liste.first.map { .init(id: $0.id, event: $0) }
    }

    /// Link `events/<id>`: wählen, in der Liste suchen (auch in späteren Seiten) und dorthin scrollen.
    mutating func waehleVonAussen(id: String, aus model: EventsModel) {
        zeigtVergangene = false
        vergangene = nil
        fremdeID = nil
        let event = model.abschnitte.flatMap(\.events).first { $0.id == id }
        wahl = Wahl(id: id, event: event)
        scrollZiel = EventsScrollZiel(id: id)
        suchtID = event == nil ? id : nil
    }
}

/// Was mit einem Link auf eine Veranstaltung geschieht, sobald die Liste geladen ist (reine Entscheidung, damit sie testbar ist).
enum EventsLinkPlan: Equatable {
    /// Die Veranstaltung steht in der Liste: auswählen und hinscrollen.
    case inListe
    /// Sie steht nicht darin, und „Heute Abend“ ist als Ziel markiert: Das Ziel wechselt zu „Alle Veranstaltungen“, die
    /// Ansicht wird neu aufgebaut, und der Link kommt dort wieder an.
    case zuAlleVeranstaltungen
    /// Sie steht nicht darin, die Auswahl hat Filter: zurück auf „Ab heute“ ohne Filter und noch einmal suchen.
    case auswahlZuruecksetzen
    /// Sie steht auch in der ungefilterten Liste nicht: rechts nur das Detail, links nichts markiert.
    case nurDetail

    static func entscheide(steht: Bool, auswahlIstStandard: Bool, ziel: PadZiel?, padHuelleAktiv: Bool) -> EventsLinkPlan {
        if steht { return .inListe }
        if auswahlIstStandard { return .nurDetail }
        if ziel == .eventsAbend, padHuelleAktiv { return .zuAlleVeranstaltungen }
        return .auswahlZuruecksetzen
    }
}

/// Ein Link auf eine Veranstaltung wartet, bis die Ansicht ihre Breite kennt: Eine neu aufgebaute Ansicht (Wechsel des Ziels
/// in der Seitenleiste) hat beim ersten `onAppear` noch 0 pt, und der Link liefe sonst als iPhone-Push ins Leere.
struct EventsLinkPuffer: Equatable {
    private var offen: String?

    /// Der Link ist angekommen: mit bekannter Breite sofort nutzbar, sonst vorgemerkt.
    mutating func empfange(_ id: String, breite: CGFloat) -> String? {
        guard breite > 0 else {
            offen = id
            return nil
        }
        return id
    }

    /// Die Breite hat sich geändert: Ein vorgemerkter Link ist jetzt nutzbar (einmal).
    mutating func breiteGeaendert(_ breite: CGFloat) -> String? {
        guard breite > 0, let id = offen else { return nil }
        offen = nil
        return id
    }
}

/// Liste links, Detail rechts, getrennt durch `separator`. Jede Seite hat ihren eigenen Scrollbereich.
struct EventsPadAnsicht: View {
    @Bindable var model: EventsModel
    @Binding var zustand: EventsPadZustand
    let raster: PadRaster
    @Binding var zeigtAbendTipp: Bool
    let onHeuteAbend: () -> Void

    @State private var zeigtFilter = false
    @FocusState private var listeFokus: Bool
    @Environment(AppRouter.self) private var router: AppRouter?

    /// Das Modell der linken Spalte: kommende oder vergangene.
    private var aktiv: EventsModel {
        zustand.zeigtVergangene ? (zustand.vergangene ?? model) : model
    }

    private var events: [CampusEvent] { aktiv.abschnitte.flatMap(\.events) }

    var body: some View {
        HStack(spacing: 0) {
            linkeSpalte
                .frame(width: raster.listenbreite)
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
                .accessibilityHidden(true)
            rechteSeite
                .frame(maxWidth: .infinity)
        }
        .background(Color(.background))
        .onAppear { korrigiereAuswahl() }
        .onChange(of: events.map(\.id)) { _, _ in korrigiereAuswahl() }
        .onChange(of: aktiv.zustand) { _, _ in korrigiereAuswahl() }
        .onChange(of: model.auswahl) { _, _ in zustand.fremdeID = nil }
        .task(id: zustand.vergangene?.ladeSchluessel) { await zustand.vergangene?.ladenWennNoetig() }
        .task(id: zustand.suchtID) { await sucheLinkZiel() }
    }

    // MARK: Links

    private var linkeSpalte: some View {
        VStack(spacing: 0) {
            if zustand.zeigtVergangene {
                kopf(titel: "Vergangene", zurueck: true)
            } else {
                kopf(titel: "Veranstaltungen", zurueck: false)
                EventsTagesleiste(
                    tage: model.tage,
                    gewaehlterTag: model.auswahl.tag,
                    tageMitEvents: model.tageMitEvents,
                    jetzt: model.jetztZeit,
                    rand: .pad,
                    onWahl: { model.auswahl.waehleTag($0) }
                )
                .padding(.top, 2)
                .padding(.bottom, 2)
            }
            EventsListe(
                model: aktiv,
                onVergangene: zustand.zeigtVergangene ? nil : { oeffneVergangene() },
                pad: padAuswahl,
                vorspann: zustand.zeigtVergangene ? nil : AnyView(chips)
            )
        }
    }

    /// Die umbrechenden Chips (und der Siri-Tipp) stehen über den Karten und scrollen mit, ohne eigenen Seitenrand.
    private var chips: some View {
        VStack(alignment: .leading, spacing: 8) {
            EventsChipleiste(
                auswahl: model.auswahl,
                veranstalter: model.veranstalter,
                umbrechend: true,
                rand: EventsRand(links: 0, rechts: 0),
                onHeuteAbend: onHeuteAbend,
                onGemerkt: { model.auswahl.nurGemerkt.toggle() },
                onVeranstalter: { model.auswahl.schalteVeranstalter($0.name, id: $0.id) }
            )
            if zeigtAbendTipp, model.auswahl.heuteAbend {
                SiriTipView(intent: HeuteAbendIntent(), isVisible: $zeigtAbendTipp)
            }
        }
        .padding(.bottom, 2)
    }

    private var padAuswahl: EventsPadAuswahl {
        EventsPadAuswahl(
            gewaehlteID: zustand.wahl?.id,
            scrollZiel: zustand.scrollZiel,
            onWahl: { event in
                zustand.wahl = .init(id: event.id, event: event)
                zustand.fremdeID = nil
                listeFokus = true
            },
            onPfeil: { schritt in pfeil(schritt) },
            fokus: $listeFokus,
            onGescrollt: { zustand.scrollZiel = nil }
        )
    }

    private func kopf(titel: LocalizedStringKey, zurueck: Bool) -> some View {
        EventsKopf(
            titel: titel,
            unterzeile: aktiv.unterzeile,
            filterAnzahl: aktiv.auswahl.sheetAnzahl,
            zurueckTitel: zurueck ? "Kommende" : nil,
            onZurueck: zurueck ? { schliesseVergangene() } : nil,
            rand: .pad,
            filterPopover: (
                istOffen: $zeigtFilter,
                inhalt: AnyView(EventsFilterPopover(auswahl: Binding(get: { aktiv.auswahl }, set: { aktiv.auswahl = $0 })))
            ),
            onFilter: { zeigtFilter = true }
        )
    }

    // MARK: Rechts

    @ViewBuilder
    private var rechteSeite: some View {
        if let wahl = zustand.wahl {
            EventDetailView(
                model: EventDetailModel(id: wahl.id, event: wahl.event, quelle: model.quelle),
                anzahlKommende: wahl.event?.veranstalter.flatMap { name in
                    model.veranstalter.first { $0.name == name }?.anzahlKommende
                },
                onAlleVonVeranstalter: { name in alleVon(name, event: wahl.event) },
                padStil: true
            )
            .id(wahl.id)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 44, weight: .light))
                    .accessibilityHidden(true)
                Text("Keine Veranstaltung gewählt")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Color(.textSecondary))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    /// „Alle n kommenden von …“: filtert die Liste links, ohne Push.
    private func alleVon(_ name: String, event: CampusEvent?) {
        let id = event?.veranstalterID ?? model.veranstalter.first { $0.name == name }?.id
        guard let id else { return }
        zustand.zeigtVergangene = false
        zustand.vergangene = nil
        model.auswahl.waehleVeranstalter(name, id: id)
    }

    // MARK: Vergangene

    private func oeffneVergangene() {
        // Nur Art und „Abgesagte ausblenden“ gelten dort, wie auf dem iPhone.
        var uebernommen = EventsAuswahl()
        uebernommen.art = model.auswahl.art
        uebernommen.abgesagteAusblenden = model.auswahl.abgesagteAusblenden
        zustand.vergangene = EventsModel(modus: .vergangene, auswahl: uebernommen, quelle: model.quelle, merkStore: model.merkStore)
        zustand.zeigtVergangene = true
        zustand.fremdeID = nil
    }

    private func schliesseVergangene() {
        zustand.zeigtVergangene = false
        zustand.vergangene = nil
        zustand.fremdeID = nil
    }

    // MARK: Auswahl

    /// Siehe `EventsPadZustand.korrigiere(liste:)`.
    private func korrigiereAuswahl() {
        guard aktiv.zustand == .geladen else { return }
        zustand.korrigiere(liste: events)
    }

    private func pfeil(_ schritt: Int) {
        let liste = events
        guard !liste.isEmpty else { return }
        let aktuell = zustand.wahl.flatMap { wahl in liste.firstIndex { $0.id == wahl.id } }
        let neu = aktuell.map { min(max($0 + schritt, 0), liste.count - 1) } ?? (schritt > 0 ? 0 : liste.count - 1)
        let event = liste[neu]
        zustand.wahl = .init(id: event.id, event: event)
        zustand.fremdeID = nil
        zustand.scrollZiel = EventsScrollZiel(id: event.id, mitte: false)
    }

    /// Ein Link auf eine Veranstaltung, die nicht auf der ersten Seite steht oder von einem Filter ausgeblendet ist: nachladen,
    /// bis sie da ist (höchstens bis zur Obergrenze des Modells); steht sie dann noch nicht in der Liste, gilt die Auswahl
    /// „Ab heute“ ohne Filter, und es wird noch einmal gesucht. Findet sie sich auch dort nicht (zum Beispiel, weil sie vorbei
    /// ist), zeigt rechts nur das Detail, und links ist nichts markiert.
    private func sucheLinkZiel() async {
        guard let id = zustand.suchtID else { return }
        func steht() -> Bool { model.abschnitte.contains { $0.events.contains { $0.id == id } } }
        func nachladen() async {
            // Auf die erste Seite warten (höchstens etwa 15 s).
            var versuche = 0
            while model.zustand == .laedt, versuche < 100, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                versuche += 1
            }
            var seiten = 0
            while !steht(), model.hatWeitere, seiten < EventsModel.maxSeiten, !Task.isCancelled {
                let vorher = model.events.count
                await model.weiterLaden()
                if model.events.count == vorher { break }
                seiten += 1
            }
        }

        // Eine Auswahl, die der Link gerade zurückgesetzt hat, löst erst im nächsten Durchlauf das Laden aus.
        try? await Task.sleep(for: .milliseconds(300))
        await nachladen()
        if !Task.isCancelled {
            switch EventsLinkPlan.entscheide(
                steht: steht(), auswahlIstStandard: model.auswahl == EventsAuswahl(),
                ziel: router?.ziel, padHuelleAktiv: router?.padHuelleAktiv ?? false
            ) {
            case .zuAlleVeranstaltungen:
                // Markiert die Seitenleiste „Heute Abend“, wechselt sie mit der Auswahl zu „Alle Veranstaltungen“ (das baut die
                // Ansicht neu auf, der Link kommt dort wieder an), damit Markierung und Liste zusammenpassen.
                if let router {
                    zustand.suchtID = nil
                    router.wechsle(zu: .eventsAlle) {
                        router.eventsAlle = true
                        router.eventWunsch = id
                    }
                }
                return
            case .auswahlZuruecksetzen:
                model.auswahl = EventsAuswahl()
                // Die Liste lädt für die neue Auswahl neu; kurz warten, bis die Aufgabe der Ansicht angelaufen ist.
                try? await Task.sleep(for: .milliseconds(300))
                await nachladen()
            case .inListe, .nurDetail:
                break
            }
        }
        guard !Task.isCancelled else { return }
        if steht() {
            zustand.fremdeID = nil
            zustand.scrollZiel = EventsScrollZiel(id: id)
        } else {
            zustand.fremdeID = id
            zustand.scrollZiel = nil
        }
        zustand.suchtID = nil
    }
}

/// Filter als Popover am Filter-Button (340 breit): Art und „Abgesagte ausblenden“, mit „Zurücksetzen“ und „Fertig“.
struct EventsFilterPopover: View {
    @Binding var auswahl: EventsAuswahl

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Zurücksetzen") { auswahl.sheetZuruecksetzen() }
                    .disabled(auswahl.sheetAnzahl == 0)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                Spacer(minLength: 8)
                Text("Filter")
                    .font(.headline)
                    .foregroundStyle(Color(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button("Fertig") { dismiss() }
                    .fontWeight(.semibold)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Art")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.textSecondary))
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.isHeader)
                    SegmentedControl(
                        selection: $auswahl.art,
                        options: [(.alle, "Alle"), (.veranstaltung, "Veranstaltungen"), (.frist, "Fristen")],
                        einzeilig: true
                    )
                    .accessibilityLabel("Art")
                }
                Toggle(isOn: $auswahl.abgesagteAusblenden) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Abgesagte ausblenden")
                            .foregroundStyle(Color(.textPrimary))
                        Text("Sonst erscheinen sie mit „Fällt aus“.")
                            .font(.footnote)
                            .foregroundStyle(Color(.textSecondary))
                    }
                }
                .toggleStyle(NeutralToggleStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 52)
                .background(Color(.background), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .frame(width: 340)
        .background(Color(.surface))
        .tint(Color(.accent))
        .presentationCompactAdaptation(.popover)
    }
}
