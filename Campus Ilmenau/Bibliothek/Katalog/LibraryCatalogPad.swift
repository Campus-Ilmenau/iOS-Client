import SwiftUI

// Katalog auf dem iPad (ab 700 pt Breite der Ansicht): Treffer links, Titel rechts, kein Push.
// Nach `PadKatalog.dc.html` und `PadKatalogErweitert.dc.html`; Suche, Zusammenführung Bestand/Gesamtkatalog, Texte und
// Fehlerfälle wie `BibSuche` (`LibraryCatalogScreen`, `LibrarySearchModel`).

/// Was die Trefferliste für die iPad-Anordnung braucht: gewählter Treffer, Auswahl, Pfeiltasten, Fokus und Merkliste.
struct KatalogPadAuswahl {
    var gewaehlteID: String?
    /// Dorthin scrollt die Liste einmal (Pfeiltasten, Link).
    var scrollZiel: String?
    var rand = EventsRand.pad
    /// „‹ Bibliothek“ oben links, solange der Katalog im Navigationsstapel des Tabs liegt (Seitenleiste zu). Ohne Titel
    /// (Seitenleiste offen) gibt es kein Zurück.
    var zurueckTitel: String?
    /// Setzt den Cursor ins Suchfeld (⌘F, „Im Katalog suchen“, Link); die Liste setzt es danach zurück.
    var fokusAnfrage: Binding<Bool>
    let onWahl: (LibraryMedia) -> Void
    /// −1 für ↑, +1 für ↓.
    let onPfeil: (Int) -> Void
    let onMerkliste: () -> Void
    let onGescrollt: () -> Void
}

/// Pfeiltasten ↑/↓ wechseln die Auswahl, solange die Liste den Tastaturfokus hat.
struct PadListenTasten: ViewModifier {
    let aktiv: Bool
    var fokus: FocusState<Bool>.Binding
    let onPfeil: (Int) -> Void

    func body(content: Content) -> some View {
        if aktiv {
            content
                .focusable()
                .focused(fokus)
                .focusEffectDisabled()
                .onKeyPress(.upArrow) { onPfeil(-1); return .handled }
                .onKeyPress(.downArrow) { onPfeil(1); return .handled }
        } else {
            content
        }
    }
}

/// Zustand der iPad-Anordnung. Er liegt im `AppRouter`, damit Suche und Auswahl den Wechsel der Seitenleiste (Ausleihen,
/// Katalog, Merkliste, Seitenleiste auf oder zu) überleben.
struct KatalogPadZustand {
    var wahl: LibraryMedia?
    /// Gewählt, steht aber nicht in der Liste (Link `katalog/titel/<id>`). Bleibt, bis die nächste Suche Treffer bringt.
    var fremdeID: String?

    /// Nach jeder neuen Suche ist der erste Treffer gewählt; bei keinen Treffern oder ohne Suche ist nichts gewählt.
    mutating func neueSuche(treffer: [LibraryMedia]) {
        fremdeID = nil
        wahl = treffer.first
    }

    /// Wenn die gewählte aus der Liste verschwindet (zum Beispiel durch einen anderen Filter): der erste Treffer. Ein
    /// Titel aus einem Link bleibt gewählt, auch wenn er nicht in der Liste steht.
    mutating func korrigiere(treffer: [LibraryMedia]) {
        if let wahl {
            if treffer.contains(where: { $0.id == wahl.id }) {
                if fremdeID == wahl.id { fremdeID = nil }
                return
            }
            if fremdeID == wahl.id { return }
        }
        wahl = treffer.first
    }

    /// Link `katalog/titel/<id>`: rechts steht der Titel, die Liste markiert ihn, falls er darin vorkommt.
    mutating func waehleVonAussen(_ media: LibraryMedia, treffer: [LibraryMedia]) {
        if let gefunden = treffer.first(where: { $0.id == media.id }) {
            wahl = gefunden
            fremdeID = nil
        } else {
            wahl = media
            fremdeID = media.id
        }
    }

    /// Eine Suche ohne Treffer oder der Start: nichts gewählt.
    mutating func leeren() {
        wahl = nil
        fremdeID = nil
    }
}

/// Treffer links (440 bzw. 360 pt), Titel rechts (max. 640, zentriert), getrennt durch `separator`.
struct KatalogPadAnsicht: View {
    @Bindable var model: LibrarySearchModel
    @Binding var zustand: KatalogPadZustand
    let raster: PadRaster
    /// „Bibliothek“ im Push (Seitenleiste zu), sonst `nil`.
    var zurueckTitel: String?
    @Binding var fokusAnfrage: Bool
    let onMerkliste: () -> Void
    /// Vorschauen setzen hier fertige Titel-Modelle ein (ohne Netz); sonst entsteht das Modell aus dem Treffer.
    var vorschauTitel: (@MainActor (LibraryMedia) -> LibraryTitleModel)?

    @State private var scrollZiel: String?

    private var treffer: [LibraryMedia] { model.sections.flatMap(\.items) }

    var body: some View {
        HStack(spacing: 0) {
            LibraryCatalogScreen(model: model, pad: padAuswahl)
                .frame(width: raster.listenbreite)
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
                .accessibilityHidden(true)
            rechteSeite
                .frame(maxWidth: .infinity)
        }
        .background(Color(.background))
        .onAppear { zustand.korrigiere(treffer: treffer) }
        .onChange(of: model.phase) { alt, neu in
            switch neu {
            case .results:
                if alt != .results { zustand.neueSuche(treffer: treffer) }
            case .empty, .start:
                zustand.leeren()
            case .loading, .failed:
                break
            }
        }
        .onChange(of: treffer.map(\.id)) { _, _ in
            guard model.phase == .results else { return }
            zustand.korrigiere(treffer: treffer)
        }
    }

    private var padAuswahl: KatalogPadAuswahl {
        KatalogPadAuswahl(
            gewaehlteID: zustand.wahl?.id,
            scrollZiel: scrollZiel,
            zurueckTitel: zurueckTitel,
            fokusAnfrage: $fokusAnfrage,
            onWahl: { media in
                zustand.wahl = media
                zustand.fremdeID = nil
            },
            onPfeil: { schritt in pfeil(schritt) },
            onMerkliste: onMerkliste,
            onGescrollt: { scrollZiel = nil }
        )
    }

    private func pfeil(_ schritt: Int) {
        let liste = treffer
        guard !liste.isEmpty else { return }
        let aktuell = zustand.wahl.flatMap { wahl in liste.firstIndex { $0.id == wahl.id } }
        let neu = aktuell.map { min(max($0 + schritt, 0), liste.count - 1) } ?? (schritt > 0 ? 0 : liste.count - 1)
        zustand.wahl = liste[neu]
        zustand.fremdeID = nil
        scrollZiel = liste[neu].id
    }

    // MARK: Rechts

    @ViewBuilder
    private var rechteSeite: some View {
        if let wahl = zustand.wahl {
            // Steht der Titel in einem Abschnitt „Gesamtkatalog“ der Trefferliste?
            let ausGesamtkatalog = model.sections.first { $0.items.contains { $0.id == wahl.id } }?.fromCatalog ?? false
            Group {
                if let vorschauTitel {
                    KatalogTitelPadDetail(
                        model: vorschauTitel(wahl), onMerkliste: onMerkliste, ladet: false, gesamtkatalog: ausGesamtkatalog
                    )
                } else {
                    KatalogTitelPadDetail(
                        media: wahl,
                        searchId: model.searchID(for: wahl),
                        service: model.service,
                        coverLoader: model.coverLoader,
                        onMerkliste: onMerkliste,
                        gesamtkatalog: ausGesamtkatalog
                    )
                }
            }
            .id(wahl.id)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "book")
                    .font(.system(size: 44, weight: .light))
                    .accessibilityHidden(true)
                Text(model.phase == .start ? "Suche nach einem Titel" : "Kein Titel gewählt")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Color(.textSecondary))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Der Titel rechts: oben rechts Teilen und Lesezeichen (44), darunter der gemeinsame `TitelDetail` in der breiten Form.
struct KatalogTitelPadDetail: View {
    @State private var model: LibraryTitleModel
    let onMerkliste: () -> Void
    private let ladet: Bool
    private let gesamtkatalog: Bool
    private let origin: LibraryTitleOrigin
    /// Merkliste: Das gefüllte Lesezeichen und „Von der Merkliste entfernen“ laufen über die Liste (nächster Titel,
    /// „Widerrufen“).
    private let onEntfernen: (() -> Void)?

    /// Mit fertigem Modell (Vorschauen): kein Laden.
    init(
        model: LibraryTitleModel,
        onMerkliste: @escaping () -> Void,
        ladet: Bool = true,
        gesamtkatalog: Bool = false,
        origin: LibraryTitleOrigin = .catalog,
        onEntfernen: (() -> Void)? = nil
    ) {
        _model = State(initialValue: model)
        self.onMerkliste = onMerkliste
        self.ladet = ladet
        self.gesamtkatalog = gesamtkatalog
        self.origin = origin
        self.onEntfernen = onEntfernen
    }

    init(
        media: LibraryMedia,
        searchId: String?,
        service: LibraryCatalogService,
        coverLoader: LibraryCoverLoader,
        onMerkliste: @escaping () -> Void,
        gesamtkatalog: Bool = false,
        origin: LibraryTitleOrigin = .catalog,
        onEntfernen: (() -> Void)? = nil
    ) {
        _model = State(initialValue: LibraryTitleModel(
            media: media,
            searchId: searchId,
            service: service,
            coverLoader: coverLoader
        ))
        self.onMerkliste = onMerkliste
        ladet = true
        self.gesamtkatalog = gesamtkatalog
        self.origin = origin
        self.onEntfernen = onEntfernen
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    teilenKnopf
                    merkenKnopf
                }
                .padding(.bottom, 4)
                TitelDetail(model: model, origin: origin, breit: true, gesamtkatalog: gesamtkatalog, onEntfernen: onEntfernen)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 6)
            .padding(.bottom, 32)
        }
        .refreshable { await model.refresh() }
        .task {
            if ladet { await model.load() }
        }
        .toast(
            LocalizedStringKey(model.toastMessage),
            actionTitle: model.toastActionTitle.map { LocalizedStringKey($0) },
            action: { model.performToastAction() },
            isPresented: $model.showsToast,
            duration: .seconds(model.toastActionTitle == nil ? 2 : 4),
            token: model.toastToken
        )
        .sensoryFeedback(.selection, trigger: model.istGemerkt)
        .onChange(of: model.opensMerkliste) { _, oeffnet in
            // „Anzeigen“ im Toast: die Merkliste als Ziel der Seitenleiste bzw. im Stapel des Tabs.
            guard oeffnet else { return }
            model.opensMerkliste = false
            onMerkliste()
        }
        .sheet(item: $model.externalLink) { link in
            LibrarySafariView(url: link.url)
                .ignoresSafeArea()
        }
    }

    /// Das Teilen-Blatt hängt am Knopf (Popover) und enthält den Text mit dem Link zum UB-Katalog.
    private var teilenKnopf: some View {
        let share = LibraryMediaShare(media: model.media, detail: model.detail)
        return ShareLink(item: share.text, subject: Text(share.title)) {
            runderSymbol("square.and.arrow.up", farbe: Color(.textPrimary))
        }
        .hoverEffect()
        .accessibilityLabel("Titel teilen")
    }

    private var merkenKnopf: some View {
        Button {
            // Merkliste: Das gefüllte Lesezeichen entfernt den Titel über die Liste.
            if let onEntfernen, model.istGemerkt { onEntfernen() } else { model.toggleMerken() }
        } label: {
            runderSymbol(model.istGemerkt ? "bookmark.fill" : "bookmark", farbe: model.istGemerkt ? Color(.accent) : Color(.textPrimary))
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityLabel(model.istGemerkt ? "Von der Merkliste entfernen" : "Auf die Merkliste setzen")
        .accessibilityAddTraits(model.istGemerkt ? .isSelected : [])
    }

    private func runderSymbol(_ name: String, farbe: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(farbe)
            .frame(width: 44, height: 44)
            .background(Color(.surfaceSecondary), in: Circle())
            .contentShape(Circle())
    }
}
