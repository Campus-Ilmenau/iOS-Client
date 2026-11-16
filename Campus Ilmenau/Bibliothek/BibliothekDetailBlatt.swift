import SwiftUI

/// Ziel des Details-Blatts der Bibliothek auf dem iPad: eine Ausleihe oder eine Vormerkung.
struct BibliothekDetailZiel: Identifiable, Equatable {
    let item: PAIALoanItem
    /// `true`: Kopf „Ausgeliehen“ mit „Deine Ausleihe“; `false`: Kopf „Vormerkung“ mit „Deine Vormerkung“.
    let ausleihe: Bool

    var id: String { (ausleihe ? "a-" : "v-") + (item.item ?? item.about ?? item.displayTitle) }
}

/// Form Sheet zu einer Ausleihe oder Vormerkung (640 breit): oben „Deine Ausleihe“ bzw. „Deine Vormerkung“, darunter der
/// Titel wie im Katalog (`TitelDetail`, Verfügbarkeit frisch aus dem Katalog). Ohne passende Katalog-ID oder ohne Antwort
/// bleibt nur der obere Teil stehen, darunter „Weitere Angaben gerade nicht abrufbar.“.
/// Die Werte aktualisieren sich: Nach dem Verlängern liest das Blatt den Eintrag neu aus `items`.
struct BibliothekDetailBlatt: View {
    let ziel: BibliothekDetailZiel
    let items: [PAIALoanItem]
    var now: Date = .now
    let catalogService: LibraryCatalogService
    let coverLoader: LibraryCoverLoader
    let onRenew: (PAIALoanItem) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var model: LibraryTitleModel?
    @State private var zeigtRueckfrage = false
    @State private var verlaengertGerade = false
    @State private var toast = ""
    @State private var zeigtToast = false

    init(
        ziel: BibliothekDetailZiel,
        items: [PAIALoanItem],
        now: Date = .now,
        catalogService: LibraryCatalogService,
        coverLoader: LibraryCoverLoader,
        vorschauModell: LibraryTitleModel? = nil,
        onRenew: @escaping (PAIALoanItem) async -> String?
    ) {
        self.ziel = ziel
        self.items = items
        self.now = now
        self.catalogService = catalogService
        self.coverLoader = coverLoader
        self.onRenew = onRenew
        // Nur für Vorschauen: ein fertig gefülltes Modell, ohne Netzwerk.
        self._model = State(initialValue: vorschauModell)
    }

    /// Der aktuelle Stand des Eintrags (nach dem Verlängern ein anderer als beim Öffnen).
    private var item: PAIALoanItem {
        items.first { $0.item != nil && $0.item == ziel.item.item } ?? ziel.item
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if ziel.ausleihe { deineAusleihe } else { deineVormerkung }
                    katalogteil
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(.background))
            .navigationTitle(ziel.ausleihe ? "Ausgeliehen" : "Vormerkung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
                if let model {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        teilenKnopf(model)
                        merkenKnopf(model)
                    }
                }
            }
            .tint(Color(.accent))
        }
        .task {
            guard model == nil, let route = ziel.item.catalogRoute else { return }
            let neu = LibraryTitleModel(media: route.media, searchId: nil, service: catalogService, coverLoader: coverLoader)
            model = neu
            // Die Verfügbarkeit kommt frisch aus dem Katalog (`/availability`), nicht aus dem Zwischenspeicher der Liste.
            await neu.load()
        }
        .toast(LocalizedStringKey(toast), isPresented: $zeigtToast)
        .alert("Leihfrist verlängern?", isPresented: $zeigtRueckfrage) {
            Button("Abbrechen", role: .cancel) {}
            Button("Verlängern") { verlaengern() }
        } message: {
            Text("Möchtest du die Leihfrist für „\(item.displayTitle)“ verlängern?")
        }
    }

    // MARK: - Deine Ausleihe

    private var deineAusleihe: some View {
        let info = BibliothekLoanInfo(item: item, now: now)
        return Card(verticalPadding: 18, horizontalPadding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Deine Ausleihe")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(.textPrimary))
                    .accessibilityAddTraits(.isHeader)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(rueckgabeText(info))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let text = info.dueText {
                        Chip(LocalizedStringKey(text), variant: chipVariant(info))
                    }
                }

                if info.days != nil {
                    PAIALoanTimelineView(info: info)
                }

                Text(metaText(info))
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))

                if info.canRenew {
                    SecondaryButton("Verlängern", compact: true) { zeigtRueckfrage = true }
                        .disabled(verlaengertGerade)
                } else if info.isOverdue {
                    Text("Nicht mehr verlängerbar. Bitte gib das Medium zurück.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.danger))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rueckgabeText(_ info: BibliothekLoanInfo) -> String {
        guard let due = info.dueDate else { return "Ohne Rückgabedatum" }
        let datum = BibliothekFormat.shortDate(due)
        return info.isOverdue ? "Rückgabe war am \(datum)" : "Rückgabe bis \(datum)"
    }

    private func chipVariant(_ info: BibliothekLoanInfo) -> Chip.Variant {
        switch info.urgency {
        case .normal: .neutral
        case .soon: .warning
        case .urgent: .dangerSoft
        }
    }

    /// „1× verlängert · Signatur …“, ohne Signatur nur der erste Teil.
    private func metaText(_ info: BibliothekLoanInfo) -> String {
        var teile = [info.renewals > 0 ? "\(info.renewals)× verlängert" : "Noch nicht verlängert"]
        if let signatur = item.signature { teile.append("Signatur \(signatur)") }
        return teile.joined(separator: " · ")
    }

    private func verlaengern() {
        verlaengertGerade = true
        Task {
            if let meldung = await onRenew(item) {
                toast = meldung
                zeigtToast = true
            }
            verlaengertGerade = false
        }
    }

    // MARK: - Deine Vormerkung

    /// Status-Chip, der Satz aus der Liste (sonst der Hinweis auf die Mitteilung) und die Signatur. Keine Aktionen.
    private var deineVormerkung: some View {
        let info = BibliothekHoldInfo(item: item)
        return Card(verticalPadding: 18, horizontalPadding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Deine Vormerkung")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                Chip(LocalizedStringKey(info.statusText), variant: info.variant)
                Text(info.detail ?? "Sobald es für dich bereitliegt, erscheint eine Mitteilung.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
                if let signatur = item.signature {
                    Text("Signatur \(signatur)")
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Katalogteil

    @ViewBuilder
    private var katalogteil: some View {
        if let model, !katalogFehlt(model) {
            TitelDetail(model: model)
        } else if model != nil || ziel.item.catalogRoute == nil {
            // Keine passende Titel-ID oder keine Antwort: nur „Deine Ausleihe“ bleibt.
            Text("Weitere Angaben gerade nicht abrufbar.")
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    /// Keine Antwort (Netzwerk, 503) oder Titel nicht gefunden: Der Katalogteil entfällt.
    private func katalogFehlt(_ model: LibraryTitleModel) -> Bool {
        switch model.phase {
        case .failed, .notFound: true
        case .loading, .loaded: false
        }
    }

    private func teilenKnopf(_ model: LibraryTitleModel) -> some View {
        let share = LibraryMediaShare(media: model.media, detail: model.detail)
        return ShareLink(item: share.text, subject: Text(share.title)) {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(Color(.textPrimary))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Titel teilen")
    }

    private func merkenKnopf(_ model: LibraryTitleModel) -> some View {
        Button { model.toggleMerken() } label: {
            Image(systemName: model.istGemerkt ? "bookmark.fill" : "bookmark")
                .foregroundStyle(model.istGemerkt ? Color(.accent) : Color(.textPrimary))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(model.istGemerkt ? "Von der Merkliste entfernen" : "Auf die Merkliste setzen")
    }
}
