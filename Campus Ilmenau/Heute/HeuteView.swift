import SwiftUI

/// Die Startseite „Heute“: Kopf, Hinweise, Jetzt-Karte, dann „Als Nächstes“ und „Heute Abend“ (ab 15:00 getauscht).
/// Nach `Heute.dc.html`.
struct HeuteView: View {
    @State private var model: HeuteModel
    @State private var zeigtMensaSheet = false
    @State private var zeigtMehr = false
    @State private var geoeffnetesEvent: CampusEvent?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduziereBewegung
    /// In Previews ohne Hülle fehlt der Router; Links tun dann nichts.
    @Environment(AppRouter.self) private var router: AppRouter?

    init(model: HeuteModel? = nil) {
        _model = State(initialValue: model ?? HeuteModel(now: HeuteUhrUeberschreibung.jetzt, widgetSync: .shared))
    }

    var body: some View {
        // Die Breite der Ansicht entscheidet über die Anordnung (siehe `PadRaster`): untereinander wie auf dem iPhone,
        // ab 700 pt in zwei Spalten.
        PadRasterMessung { raster in
            seite(raster)
        }
    }

    private func seite(_ raster: PadRaster) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    kopf(raster)
                    if !model.hinweise.isEmpty { hinweiseAbschnitt(raster) }
                    if raster.istPad {
                        VerhaeltnisSpalten {
                            jetztAbschnitt(raster)
                            VStack(alignment: .leading, spacing: 22) {
                                ForEach(unterteil, id: \.self) { unterabschnitt($0, raster: raster) }
                            }
                        }
                    } else {
                        jetztAbschnitt(raster)
                        // Ab 15:00 (nicht nachts) steht „Heute Abend“ vor „Als Nächstes“. Die Abschnitte behalten ihre
                        // Identität und gleiten an ihren Platz, ohne dass die Seite springt.
                        ForEach(unterteil, id: \.self) { unterabschnitt($0, raster: raster) }
                    }
                }
                .animation(reduziereBewegung ? nil : .snappy, value: model.eventsZuerst)
                .padding(.horizontal, raster.rand)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.background))
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.laden() }
            .navigationDestination(isPresented: $zeigtMehr) { MehrView(zurueckTitel: "Heute") }
            .navigationDestination(item: $geoeffnetesEvent) { event in
                EventDetailView(id: event.id, event: event)
            }
        }
        // iPhone und schmale Fenster: Sheet wie bisher. Zwei Spalten: Popover am Link (siehe `mensaAendernButton`).
        .sheet(isPresented: Binding(get: { zeigtMensaSheet && !raster.istPad }, set: { zeigtMensaSheet = $0 })) {
            HeuteMensaSheet(
                optionen: model.mensaOptionen,
                gewaehlt: model.mensa,
                onWahl: { model.waehleMensa($0) }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            await model.laden()
            await model.beobachten()
        }
        .onAppear {
            model.mensaNeuLesen()
            oeffneMehrAufWunsch()
        }
        // ⌘, und der Link `mehr` bei geschlossener Seitenleiste: dieselbe Seite wie der Personen-Button.
        .onChange(of: router?.mehrOeffnen) { _, _ in oeffneMehrAufWunsch() }
        // „Mensa auf der Startseite“ und der Filter ändern sich unter „Mehr“: Beim Zurück bzw. beim Wechsel zu Heute gelten sie sofort.
        .onChange(of: zeigtMehr) { _, offen in
            if !offen { model.mensaNeuLesen() }
        }
        .onChange(of: router?.ziel) { _, neu in
            if neu == .heute { model.mensaNeuLesen() }
        }
        .onChange(of: scenePhase) { _, neu in
            guard neu == .active else { return }
            model.mensaNeuLesen()
            Task { await model.szeneWurdeAktiv() }
        }
        // ⌘R („Neu laden“ im Menü): lädt neu, wenn „Heute“ gerade offen ist.
        .onChange(of: router?.neuLadenZaehler) { _, _ in
            guard router?.tab == .heute else { return }
            Task { await model.laden() }
        }
    }

    private func oeffneMehrAufWunsch() {
        guard router?.mehrOeffnen == true else { return }
        router?.mehrOeffnen = false
        zeigtMehr = true
    }

    @ViewBuilder
    private func unterabschnitt(_ abschnitt: Unterabschnitt, raster: PadRaster) -> some View {
        switch abschnitt {
        case .alsNaechstes:
            HeuteAlsNaechstesView(termine: model.alsNaechstes, onTermin: oeffne)
        case .heuteAbend:
            HeuteAbendKarte(
                events: model.heuteAbend,
                jetzt: model.jetzt,
                onAlle: { router?.zeigeEventsHeuteAbend() },
                onOeffne: { geoeffnetesEvent = $0 },
                darstellung: raster.istPad ? .liste : .karten
            )
        }
    }

    // MARK: Kopf

    private func kopf(_ raster: PadRaster) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.datumZeile)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.textSecondary))
                    .accessibilityLabel("\(model.datumZeile) Uhr")
                Text(model.begruessung.text)
                    .font(.display(size: raster.seitentitel(telefon: 32), relativeTo: .largeTitle))
                    .tracking(raster.istPad ? -0.76 : -0.6)
                    .foregroundStyle(Color(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            Button {
                zeigtMehr = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(.textPrimary))
                    .frame(width: 44, height: 44)
                    .background(Color(.surfaceSecondary), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mehr und Einstellungen")
        }
    }

    // MARK: Hinweise

    @ViewBuilder
    private func hinweiseAbschnitt(_ raster: PadRaster) -> some View {
        if raster.istPad {
            // iPad: nebeneinander in zwei Spalten, ohne Überschrift
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: PadRaster.kartenAbstand, alignment: .top),
                    GridItem(.flexible(), alignment: .top),
                ],
                alignment: .leading,
                spacing: PadRaster.kartenAbstand
            ) {
                hinweisKarten
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Hinweise")
                    .heuteAbschnittstitel()
                VStack(spacing: 10) {
                    hinweisKarten
                }
            }
        }
    }

    private var hinweisKarten: some View {
        ForEach(model.hinweise) { hinweis in
            HeuteHinweisKarte(hinweis: hinweis) {
                withAnimation(.snappy) { model.blendeHinweisAus(hinweis.id) }
            }
        }
    }

    // MARK: Jetzt

    private func jetztAbschnitt(_ raster: PadRaster) -> some View {
        let karte = model.jetztKarte
        let zeigtWechsel = karte?.mensaAendernSichtbar ?? (model.phase != .nacht)
        return VStack(alignment: .leading, spacing: 10) {
            // Bei großer Schrift rutscht „Mensa ändern“ unter die Überschrift
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    Text(model.phase.ueberschrift).heuteAbschnittstitel()
                    Spacer(minLength: 8)
                    // Tippfläche 44 pt, ohne den Abstand zur Karte zu vergrößern
                    if zeigtWechsel { mensaAendernButton(raster).padding(.vertical, -12) }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.phase.ueberschrift).heuteAbschnittstitel()
                    if zeigtWechsel { mensaAendernButton(raster) }
                }
            }

            if !model.istGeladen {
                HeuteJetztKarteView(karte: .platzhalter, onLink: { _ in })
                    .redacted(reason: .placeholder)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Wird geladen")
            } else {
                HeuteJetztKarteView(karte: karte ?? model.fehlerKarte, onLink: oeffne)
            }
        }
    }

    private func mensaAendernButton(_ raster: PadRaster) -> some View {
        Button {
            zeigtMensaSheet = true
        } label: {
            HStack(spacing: 4) {
                Text("Mensa ändern")
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(.accent))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        // iPad (zwei Spalten): Popover am Link, 360 breit. Auf dem iPhone bleibt es beim Sheet oben.
        .popover(isPresented: Binding(get: { zeigtMensaSheet && raster.istPad }, set: { zeigtMensaSheet = $0 })) {
            HeuteMensaPopover(
                optionen: model.mensaOptionen,
                gewaehlt: model.mensa,
                onWahl: { model.waehleMensa($0) }
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private enum Unterabschnitt: Hashable {
        case alsNaechstes
        case heuteAbend
    }

    private var unterteil: [Unterabschnitt] {
        model.eventsZuerst ? [.heuteAbend, .alsNaechstes] : [.alsNaechstes, .heuteAbend]
    }

    private func oeffne(_ ziel: HeuteZiel) {
        switch ziel {
        case .speiseplan(let venue): router?.zeigeMensa(venue)
        case .oeffnungszeiten(let venue): router?.zeigeOeffnungszeiten(venue)
        case .gericht(let id, let tag): router?.zeigeGericht(id: id, tag: tag)
        case .event(let event): geoeffnetesEvent = event
        case .alleEvents: router?.zeigeEvents()
        }
    }
}

extension View {
    /// Überschrift eines Abschnitts: 13 pt Semibold, `textSecondary`, Versalien.
    func heuteAbschnittstitel() -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Color(.textSecondary))
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Hinweis-Karte

/// Redaktioneller Hinweis: Icon-Fläche, Kategorie und Zeit in `accent`, Titel, eine Zeile, ✕ zum dauerhaften Ausblenden.
private struct HeuteHinweisKarte: View {
    let hinweis: Hinweis
    let onAusblenden: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: hinweis.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(hinweis.farbe == .blau ? Color(.onBlue) : Color(.onGreen))
                .frame(width: 36, height: 36)
                .background(
                    hinweis.farbe == .blau ? Color(.blue) : Color(.green),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(kicker)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.accent))
                Text(hinweis.titel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                if !hinweis.text.isEmpty {
                    Text(hinweis.text)
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(action: onAusblenden) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.textTertiary))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -8)
            .padding(.vertical, -6)
            .accessibilityLabel("Hinweis ausblenden")
        }
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .hoverEffect()
        .accessibilityElement(children: .contain)
    }

    private var kicker: String {
        [hinweis.kategorie, hinweis.zeitangabe].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}


/// Nur Debug-Builds: Das Startargument `-HeuteUhr 11:45` stellt die Uhr der Seite „Heute“ (Phase, Jetzt-Karte,
/// „Heute Abend“) auf diese Uhrzeit heute. Mit Tagesversatz geht auch ein anderer Tag: `-HeuteUhr "+1 11:45"` ist
/// morgen um 11:45, `"-1 11:45"` gestern. Damit lassen sich Mittag, Abend und andere Tage im Simulator zeigen.
/// Sonst gilt die Systemuhr.
enum HeuteUhrUeberschreibung {
    static func jetzt() -> Date {
        #if DEBUG
        if let text = UserDefaults.standard.string(forKey: "HeuteUhr") {
            var teile = text.split(separator: " ").map(String.init)
            let versatz = teile.count == 2 ? Int(teile.removeFirst()) : 0
            let zeit = teile.first?.split(separator: ":").compactMap { Int($0) } ?? []
            if zeit.count == 2, let versatz,
               let tag = Calendar.current.date(byAdding: .day, value: versatz, to: .now),
               let datum = Calendar.current.date(bySettingHour: zeit[0], minute: zeit[1], second: 0, of: tag) {
                return datum
            }
        }
        #endif
        return .now
    }
}
