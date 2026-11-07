import SwiftUI

/// Detail einer Veranstaltung nach `EventDetail.dc.html` und `EventKnapp.dc.html`.
/// Zeigt zuerst die Daten aus der Liste (falls übergeben), lädt dann `detail(id:)`.
struct EventDetailView: View {
    @State private var model: EventDetailModel
    /// Kommende Veranstaltungen dieses Veranstalters laut Veranstalter-Liste, falls bekannt.
    let anzahlKommende: Int?
    /// „Alle kommenden von …“: zurück zur Liste mit aktivem Veranstalter-Chip. Ohne Closure entfällt der Link.
    var onAlleVonVeranstalter: ((String) -> Void)?

    @Environment(\.eventsMerkStore) private var merkStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var heroHoehe: CGFloat = 280
    @State private var toastText = ""
    @State private var zeigtToast = false
    @State private var toastZaehler = 0
    @State private var kalenderEintrag: KalenderEintrag?

    init(
        id: String,
        event: CampusEvent? = nil,
        anzahlKommende: Int? = nil,
        onAlleVonVeranstalter: ((String) -> Void)? = nil
    ) {
        _model = State(initialValue: EventDetailModel(id: id, event: event))
        self.anzahlKommende = anzahlKommende
        self.onAlleVonVeranstalter = onAlleVonVeranstalter
    }

    /// Mit fertigem Modell (Previews, Tests).
    init(model: EventDetailModel, anzahlKommende: Int? = nil, onAlleVonVeranstalter: ((String) -> Void)? = nil) {
        _model = State(initialValue: model)
        self.anzahlKommende = anzahlKommende
        self.onAlleVonVeranstalter = onAlleVonVeranstalter
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                switch model.zustand {
                case .nichtGefunden:
                    fehler(
                        titel: "Veranstaltung nicht gefunden",
                        text: "Sie wurde vielleicht entfernt.",
                        aktion: "Zurück",
                        hauptaktion: true,
                        proxy: proxy
                    ) { dismiss() }
                case .fehler:
                    fehler(
                        titel: "Konnte nicht geladen werden",
                        text: "Prüfe deine Verbindung und versuch es noch einmal.",
                        aktion: "Erneut versuchen",
                        hauptaktion: true,
                        proxy: proxy
                    ) { Task { await model.nochmal() } }
                case .laedt, .geladen:
                    if let event = model.event {
                        inhalt(event, proxy: proxy)
                    } else {
                        platzhalter(proxy: proxy)
                    }
                }
            }
        }
        .background(Color(.background))
        .toolbar(.hidden, for: .navigationBar)
        .toast(LocalizedStringKey(toastText), actionTitle: nil, action: {}, isPresented: $zeigtToast, token: toastZaehler)
        .task(id: model.id) { await model.laden() }
        .sheet(isPresented: Binding(get: { kalenderEintrag != nil }, set: { if !$0 { kalenderEintrag = nil } })) {
            if let eintrag = kalenderEintrag {
                KalenderEditor(eintrag: eintrag) { gesichert in
                    kalenderEintrag = nil
                    if gesichert { zeigeToast("Im Kalender eingetragen") }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Inhalt

    private func inhalt(_ event: CampusEvent, proxy: GeometryProxy) -> some View {
        let anzeige = EventDetailAnzeige(event: event)
        return ScrollView {
            VStack(spacing: 0) {
                kopf(anzeige, proxy: proxy)
                VStack(alignment: .leading, spacing: 14) {
                    hinweis(anzeige)
                    infokarte(anzeige)
                    if let text = anzeige.beschreibung {
                        EventBeschreibung(text: text)
                    }
                    aktionen(anzeige)
                    Text("Angaben vom Veranstalter. Kurzfristige Änderungen sind möglich.")
                        .font(.caption)
                        .foregroundStyle(Color(.textTertiary))
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Kopf

    private func kopf(_ anzeige: EventDetailAnzeige, proxy: GeometryProxy) -> some View {
        let event = anzeige.event
        // Mindestens 280 pt; bei großer Schrift wächst der Kopf, damit der Text nicht unter die Tasten läuft.
        return kopfText(anzeige)
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
            .padding(.top, proxy.safeAreaInsets.top + 64)
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .bottomLeading)
            .background {
                ZStack(alignment: .bottom) {
                    plakat(event.bildURL, hoehe: heroHoehe)
                    LinearGradient(
                        colors: [Color(.brandNight).opacity(0), Color(.brandNight).opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heroHoehe = $0 }
            .clipped()
            .overlay(alignment: .top) {
                tasten(anzeige)
                    .padding(.horizontal, 16)
                    .padding(.top, proxy.safeAreaInsets.top + 8)
            }
    }

    /// Das Plakat; ohne Bild oder solange es lädt der `DiagonalBands`-Baustein.
    @ViewBuilder
    private func plakat(_ url: URL?, hoehe: CGFloat) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let bild):
                    Color(.blue)
                        .overlay { bild.resizable().scaledToFill() }
                        .clipped()
                default:
                    DiagonalBands(.event, height: hoehe) { EmptyView() }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: hoehe)
            .clipped()
            .accessibilityHidden(true)
        } else {
            DiagonalBands(.event, height: hoehe) { EmptyView() }
                .accessibilityHidden(true)
        }
    }

    private func kopfText(_ anzeige: EventDetailAnzeige) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if anzeige.abgesagt {
                Chip("Fällt aus", variant: .dangerSoft)
                    .padding(.bottom, 4)
            } else if anzeige.unbestaetigt {
                Text("Noch nicht bestätigt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.brandNight))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.92), in: Capsule())
                    .padding(.bottom, 4)
            }
            if let veranstalter = anzeige.veranstalter {
                Text(veranstalter)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            Text(anzeige.event.titel)
                .display(size: anzeige.titelGroesse, relativeTo: .largeTitle)
                .foregroundStyle(Color.white)
                .opacity(anzeige.abgesagt ? 0.85 : 1)
                .strikethrough(anzeige.abgesagt)
                .lineSpacing(0)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Auf dem Platzhalter liegt der Text links, rechts steht das grüne Band.
        .padding(.trailing, anzeige.event.bildURL == nil ? 60 : 0)
    }

    /// Runde weiße Tasten. Sie bleiben in beiden Modi weiß auf dem Bild, deshalb immer mit den hellen Farben.
    private func tasten(_ anzeige: EventDetailAnzeige) -> some View {
        let gemerkt = merkStore.istGemerkt(anzeige.event.id)
        return HStack(spacing: 8) {
            rundeTaste("chevron.left") { dismiss() }
                .accessibilityLabel("Zurück zu den Veranstaltungen")
            Spacer(minLength: 0)
            teilen(anzeige)
            rundeTaste(gemerkt ? "star.fill" : "star", farbe: gemerkt ? Color(.accent) : Color(.brandNight)) {
                let jetztGemerkt = merkStore.umschalten(anzeige.event.id)
                zeigeToast(jetztGemerkt ? "Gemerkt" : "Nicht mehr gemerkt")
            }
            .sensoryFeedback(.impact(weight: .light), trigger: gemerkt)
            .accessibilityLabel(gemerkt ? "Nicht mehr merken" : "Merken")
            .accessibilityAddTraits(.isToggle)
        }
        .environment(\.colorScheme, .light)
    }

    /// Runde Taste links vom Stern: Menü mit „Als Bild teilen“ und „Als Text teilen“. Der Text enthält den Tickets- oder
    /// Infos-Link der Veranstaltung.
    private func teilen(_ anzeige: EventDetailAnzeige) -> some View {
        let inhalt = EventShare(event: anzeige.event)
        return ShareMenuButton(content: inhalt, caption: inhalt.menuCaption) {
            rundesSymbol("square.and.arrow.up")
        }
        .accessibilityLabel("Veranstaltung teilen")
    }

    private func rundeTaste(_ symbol: String, farbe: Color = Color(.brandNight), action: @escaping () -> Void) -> some View {
        Button(action: action) { rundesSymbol(symbol, farbe: farbe) }
            .buttonStyle(.plain)
    }

    private func rundesSymbol(_ symbol: String, farbe: Color = Color(.brandNight)) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(farbe)
            .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.92), in: Circle())
            .contentShape(Circle())
    }

    // MARK: Hinweis

    @ViewBuilder
    private func hinweis(_ anzeige: EventDetailAnzeige) -> some View {
        if anzeige.abgesagt {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fällt aus").fontWeight(.semibold)
                    Text("Der Veranstalter hat diese Veranstaltung abgesagt.").fontWeight(.regular)
                }
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(.danger))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.dangerSoft), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
        } else if anzeige.unbestaetigt {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock")
                    .font(.title3)
                    .accessibilityHidden(true)
                Text("Der Termin ist noch nicht bestätigt. Schau kurz vorher noch einmal rein.")
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .foregroundStyle(Color(.textSecondary))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Infokarte

    private func infokarte(_ anzeige: EventDetailAnzeige) -> some View {
        let zeit = EventZeitFormatter().datumUndZeit(anzeige.event)
        return VStack(spacing: 0) {
            infoZeile("calendar") {
                Text(zeit.datum).fontWeight(.semibold).foregroundStyle(Color(.textPrimary))
                Text(zeit.zeit).font(.footnote).foregroundStyle(Color(.textSecondary))
            }
            .accessibilityElement(children: .combine)

            if let ort = anzeige.ort {
                trenner
                infoZeile("mappin.and.ellipse") {
                    Text(ort).fontWeight(.semibold).foregroundStyle(Color(.textPrimary))
                    if let adresse = anzeige.adresse {
                        Text(adresse).font(.footnote).foregroundStyle(Color(.textSecondary))
                        if let karten = anzeige.kartenURL {
                            link("In Karten öffnen", systemImage: "arrow.up.right") { openURL(karten) }
                        }
                    }
                }
            }

            if let veranstalter = anzeige.veranstalter {
                trenner
                infoZeile("person.2") {
                    Text(veranstalter).fontWeight(.semibold).foregroundStyle(Color(.textPrimary))
                    if let onAlleVonVeranstalter {
                        let titel: LocalizedStringKey = anzahlKommende.map { "Alle \($0) kommenden von \(veranstalter)" }
                            ?? "Alle kommenden von \(veranstalter)"
                        link(titel) { onAlleVonVeranstalter(veranstalter) }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var trenner: some View {
        Rectangle().fill(Color(.separator)).frame(height: 1)
    }

    private func infoZeile<Inhalt: View>(_ symbol: String, @ViewBuilder inhalt: () -> Inhalt) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(Color(.textSecondary))
                .frame(width: 24)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2, content: inhalt)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private func link(_ titel: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(titel)
                if let systemImage {
                    Image(systemName: systemImage).font(.caption.weight(.bold)).accessibilityHidden(true)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(.accent))
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Aktionen

    @ViewBuilder
    private func aktionen(_ anzeige: EventDetailAnzeige) -> some View {
        let event = anzeige.event
        VStack(spacing: 10) {
            if anzeige.zeigtTickets, let ticket = event.ticketURL {
                PrimaryButton("Tickets", trailingSystemImage: "arrow.up.right") { openURL(ticket) }
            }
            if anzeige.zeigtKalender {
                if anzeige.kalenderIstHauptbutton {
                    PrimaryButton("Zum Kalender hinzufügen", isLoading: model.traegtKalender) { eintragen() }
                } else {
                    SecondaryButton("Zum Kalender hinzufügen", isLoading: model.traegtKalender) { eintragen() }
                }
            }
            if let info = event.infoURL {
                SecondaryButton("Infoseite des Veranstalters", trailingSystemImage: "arrow.up.right") { openURL(info) }
            }
            if anzeige.zeigtExternHinweis {
                Text("↗ öffnet eine Seite außerhalb der App.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.textTertiary))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }

    /// Öffnet das Systemblatt, in dem man den Kalender wählt.
    private func eintragen() {
        guard let event = model.event else { return }
        kalenderEintrag = KalenderEintrag(event: event)
    }

    private func zeigeToast(_ text: String) {
        toastText = text
        toastZaehler += 1
        zeigtToast = true
    }

    // MARK: Fehler und Platzhalter

    private func fehler(
        titel: LocalizedStringKey,
        text: LocalizedStringKey,
        aktion: LocalizedStringKey,
        hauptaktion: Bool,
        proxy: GeometryProxy,
        onAktion: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                rundeTaste("chevron.left") { dismiss() }
                    .accessibilityLabel("Zurück zu den Veranstaltungen")
                Spacer()
            }
            .environment(\.colorScheme, .light)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
            EventsMeldung(titel: titel, text: text, aktion: aktion, hauptaktion: hauptaktion, onAktion: onAktion)
                .padding(.horizontal, 16)
            Spacer()
        }
    }

    /// Bis die Daten da sind und keine aus der Liste kommen: Kopf als Platzhalter und graue Blöcke.
    private func platzhalter(proxy: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                DiagonalBands(.event, height: 280) { EmptyView() }
                    .overlay(alignment: .top) {
                        HStack {
                            rundeTaste("chevron.left") { dismiss() }
                                .accessibilityLabel("Zurück zu den Veranstaltungen")
                            Spacer()
                        }
                        .environment(\.colorScheme, .light)
                        .padding(.horizontal, 16)
                        .padding(.top, proxy.safeAreaInsets.top + 8)
                    }
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Freitag, 30. Oktober").fontWeight(.semibold)
                        Text("21:00 – 03:00 Uhr").font(.footnote)
                        Text("Studi-Club").fontWeight(.semibold).padding(.top, 12)
                        Text("Max-Planck-Ring 6").font(.footnote)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .redacted(reason: .placeholder)
                }
                .padding(16)
            }
        }
        .ignoresSafeArea(edges: .top)
        .accessibilityLabel("Veranstaltung wird geladen")
    }
}

/// Beschreibung als reiner Text mit Absätzen: 4 Zeilen, dann „Mehr anzeigen“. Der Button erscheint nur,
/// wenn der Text mit 4 Zeilen wirklich abgeschnitten wäre.
struct EventBeschreibung: View {
    let text: String

    @State private var aufgeklappt = false
    @State private var vollHoehe: CGFloat = 0
    @State private var gekuerztHoehe: CGFloat = 0

    private var istGekuerzt: Bool { vollHoehe > gekuerztHoehe + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: text)
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(aufgeklappt ? nil : 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .background(messung)

            if istGekuerzt {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { aufgeklappt.toggle() }
                } label: {
                    Text(aufgeklappt ? "Weniger anzeigen" : "Mehr anzeigen")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.accent))
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 2)
            }
        }
    }

    /// Zwei unsichtbare Kopien: eine ohne Begrenzung, eine mit 4 Zeilen. Ist die erste höher, wird gekürzt.
    private var messung: some View {
        ZStack {
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { vollHoehe = $0 }
            Text(verbatim: text)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { gekuerztHoehe = $0 }
        }
        .padding(.horizontal, 2)
        .hidden()
        .accessibilityHidden(true)
    }
}
