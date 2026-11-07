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
        _model = State(initialValue: model ?? HeuteModel(widgetSync: .shared))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    kopf
                    if !model.hinweise.isEmpty { hinweiseAbschnitt }
                    jetztAbschnitt
                    // Ab 15:00 (nicht nachts) steht „Heute Abend“ vor „Als Nächstes“. Die Abschnitte behalten ihre
                    // Identität und gleiten an ihren Platz, ohne dass die Seite springt.
                    ForEach(unterteil, id: \.self) { abschnitt in
                        switch abschnitt {
                        case .alsNaechstes:
                            HeuteAlsNaechstesView(termine: model.alsNaechstes, onTermin: oeffne)
                        case .heuteAbend:
                            HeuteAbendKarte(
                                events: model.heuteAbend,
                                jetzt: model.jetzt,
                                onAlle: { router?.zeigeEventsHeuteAbend() },
                                onOeffne: { geoeffnetesEvent = $0 }
                            )
                        }
                    }
                }
                .animation(reduziereBewegung ? nil : .snappy, value: model.eventsZuerst)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.background))
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.laden() }
            .navigationDestination(isPresented: $zeigtMehr) { MehrView() }
            .navigationDestination(item: $geoeffnetesEvent) { event in
                EventDetailView(id: event.id, event: event)
            }
        }
        .sheet(isPresented: $zeigtMensaSheet) {
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
        .onAppear { model.mensaNeuLesen() }
        .onChange(of: scenePhase) { _, neu in
            guard neu == .active else { return }
            model.mensaNeuLesen()
            Task { await model.szeneWurdeAktiv() }
        }
    }

    // MARK: Kopf

    private var kopf: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.datumZeile)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.textSecondary))
                    .accessibilityLabel("\(model.datumZeile) Uhr")
                Text(model.begruessung.text)
                    .font(.display(size: 32, relativeTo: .largeTitle))
                    .tracking(-0.6)
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

    private var hinweiseAbschnitt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hinweise")
                .heuteAbschnittstitel()
            VStack(spacing: 10) {
                ForEach(model.hinweise) { hinweis in
                    HeuteHinweisKarte(hinweis: hinweis) {
                        withAnimation(.snappy) { model.blendeHinweisAus(hinweis.id) }
                    }
                }
            }
        }
    }

    // MARK: Jetzt

    private var jetztAbschnitt: some View {
        let karte = model.jetztKarte
        let zeigtWechsel = karte?.mensaAendernSichtbar ?? (model.phase != .nacht)
        return VStack(alignment: .leading, spacing: 10) {
            // Bei großer Schrift rutscht „Mensa ändern“ unter die Überschrift
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    Text(model.phase.ueberschrift).heuteAbschnittstitel()
                    Spacer(minLength: 8)
                    // Tippfläche 44 pt, ohne den Abstand zur Karte zu vergrößern
                    if zeigtWechsel { mensaAendernButton.padding(.vertical, -12) }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.phase.ueberschrift).heuteAbschnittstitel()
                    if zeigtWechsel { mensaAendernButton }
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

    private var mensaAendernButton: some View {
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
        .accessibilityElement(children: .contain)
    }

    private var kicker: String {
        [hinweis.kategorie, hinweis.zeitangabe].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
