import SwiftUI

/// Push-Ansicht „Katalog“ aus der Bibliothek: Suche in der Bibliotheks-API, ohne Anmeldung, nur lesend.
/// Das Feld ist beim Öffnen fokussiert, sofern `autofocus` gesetzt ist.
///
/// Mit `suchbegriff` (Link `campusilmenau://katalog/suche?q=<begriff>`, von Siri) steht der Begriff im Feld und die Treffer
/// laden sofort; die Tastatur bleibt zu.
struct LibraryCatalogView: View {
    var autofocus = true
    var suchbegriff: String?
    @State private var model: LibrarySearchModel

    init(autofocus: Bool = true, suchbegriff: String? = nil) {
        self.autofocus = autofocus
        self.suchbegriff = suchbegriff
        _model = State(initialValue: LibrarySearchModel.fuerSuchbegriff(suchbegriff))
    }

    var body: some View {
        LibraryCatalogScreen(model: model, autofocus: autofocus && suchbegriff == nil)
            .task {
                guard suchbegriff != nil else { return }
                model.submit()
            }
    }
}

/// Oberfläche nach `BibSuche.dc.html`. Zustand und Ablauf liegen im `LibrarySearchModel`.
struct LibraryCatalogScreen: View {
    @Bindable var model: LibrarySearchModel
    var autofocus = false

    @FocusState private var searchFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var rowLabelWidth: CGFloat = 96

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            searchRow
            pills
            if model.advancedOpen {
                advancedPanel
            }
            results
        }
        .background(Color(.background))
        // Die Navigationsleiste bleibt vorerst für den Zurück-Pfeil, bis die TabBar die Navigation übernimmt.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: model.text) { model.textChanged() }
        .onChange(of: model.yearFrom) { model.formError = nil }
        .onChange(of: model.yearTo) { model.formError = nil }
        .task { await model.onAppear() }
        .task {
            guard autofocus else { return }
            // Erst nach dem Einblenden der Ansicht, sonst kommt die Tastatur zu früh.
            try? await Task.sleep(for: .milliseconds(350))
            searchFocused = true
        }
    }

    // MARK: - Kopf

    private var titleBar: some View {
        Text("Katalog")
            .display(size: 30, relativeTo: .largeTitle)
            .foregroundStyle(Color(.textPrimary))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(.textTertiary))
                    .accessibilityHidden(true)
                TextField("Titel, Person, Thema, ISBN", text: $model.text)
                    .font(.callout)
                    .foregroundStyle(Color(.textPrimary))
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { model.submit() }
                    .accessibilityLabel("Im Katalog suchen")
                if !model.text.isEmpty {
                    Button {
                        model.clearText()
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(.textTertiary))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Suchbegriff löschen")
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, model.text.isEmpty ? 12 : 0)
            .frame(minHeight: 44)
            .background(Color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                withAnimation(.snappy(duration: 0.2)) { model.toggleAdvanced() }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(model.advancedOpen ? Color(.onButtonPrimary) : Color(.textPrimary))
                    .frame(width: 44, height: 44)
                    .background(
                        model.advancedOpen ? Color(.buttonPrimary) : Color(.surfaceSecondary),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .accessibilityLabel("Erweiterte Suche")
            .accessibilityValue(model.advancedOpen ? "geöffnet" : "geschlossen")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var pills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryMediaFilter.allCases, id: \.self) { kind in
                    pill(kind)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Medienart")
    }

    private func pill(_ kind: LibraryMediaFilter) -> some View {
        let selected = model.kind == kind
        return Button {
            model.selectKind(kind)
        } label: {
            Text(kind.pillTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color(.onButtonPrimary) : Color(.textPrimary))
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(selected ? Color(.buttonPrimary) : Color(.surface), in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Color(.buttonPrimary) : Color(.separator), lineWidth: 1))
                .padding(.vertical, 5)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Erweiterte Suche

    private var advancedPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldRow("Titel", placeholder: "z. B. Technische Mechanik", text: $model.title)
            fieldRow("Person", placeholder: "Autor:in, Herausgeber:in", text: $model.author)
            fieldRow("ISBN", placeholder: "978-…", text: $model.isbn, keyboard: .numbersAndPunctuation)
            fieldRow("Schlagwort", placeholder: "z. B. Regelungstechnik", text: $model.subject)
            yearRow

            if let error = model.formError {
                Text(error)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.danger))
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isStaticText)
            }

            Text("Feldsuche läuft im Gesamtkatalog, neueste Titel zuerst.")
                .font(.caption)
                .foregroundStyle(Color(.textTertiary))
                .padding(.top, 8)
                .padding(.bottom, 12)

            PrimaryButton("Suchen") {
                searchFocused = false
                // Die Felder haben eigene Fokusse; die Tastatur schließt sich sicher über UIKit.
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation(.snappy(duration: 0.2)) { model.submitAdvanced() }
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 14)
        .padding(.horizontal, 16)
        .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .onChange(of: model.formError) { _, newValue in
            if let newValue { AccessibilityNotification.Announcement(newValue).post() }
        }
    }

    private func fieldRow(
        _ label: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        rowLayout(label: label) {
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { model.submit() }
        }
    }

    private var yearRow: some View {
        rowLayout(label: "Jahr", showsSeparator: false) {
            HStack(spacing: 8) {
                TextField("von", text: $model.yearFrom)
                    .keyboardType(.numberPad)
                    .accessibilityLabel("Jahr von")
                Text("–")
                    .foregroundStyle(Color(.textTertiary))
                    .accessibilityHidden(true)
                TextField("bis", text: $model.yearTo)
                    .keyboardType(.numberPad)
                    .accessibilityLabel("Jahr bis")
            }
        }
    }

    /// Zeile mit Beschriftung links und Eingabe rechts; bei großer Schrift steht die Beschriftung darüber.
    private func rowLayout<Field: View>(
        label: LocalizedStringKey,
        showsSeparator: Bool = true,
        @ViewBuilder field: () -> Field
    ) -> some View {
        let stacked = dynamicTypeSize >= .xxLarge
        return VStack(spacing: 0) {
            Group {
                if stacked {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(label).font(.subheadline).foregroundStyle(Color(.textSecondary)).padding(.top, 8)
                        field().frame(minHeight: 44)
                    }
                } else {
                    HStack(spacing: 12) {
                        Text(label)
                            .font(.subheadline)
                            .foregroundStyle(Color(.textSecondary))
                            .frame(width: rowLabelWidth, alignment: .leading)
                        field().frame(minHeight: 44)
                    }
                }
            }
            .font(.callout)
            .foregroundStyle(Color(.textPrimary))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

            if showsSeparator {
                Rectangle().fill(Color(.separator)).frame(height: 1)
            }
        }
    }

    // MARK: - Ergebnisse

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                switch model.phase {
                case .start: startBlock
                case .loading: loadingBlock
                case .failed: failedBlock
                case .empty: emptyBlock
                case .results: resultsBlock
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await model.refresh() }
    }

    @ViewBuilder
    private var resultsBlock: some View {
        if let header = model.header {
            VStack(alignment: .leading, spacing: 1) {
                Text(header.line1)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                if let line2 = header.line2 {
                    Text(line2)
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }

        if let notice = model.staleNotice {
            infoRow(notice, systemImage: "clock", warning: true)
        }

        ForEach(model.sections) { section in
            if let title = section.title {
                Text(title)
                    .font(.caption.weight(.bold))
                    .tracking(0.7)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(.textTertiary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                    .padding(.horizontal, 2)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(section.items) { media in
                NavigationLink {
                    LibraryTitleView(
                        media: media,
                        searchId: model.searchID(for: media),
                        service: model.service,
                        coverLoader: model.coverLoader
                    )
                } label: {
                    LibraryResultCard(
                        media: media,
                        availability: model.availability[media.id],
                        fromCatalog: section.fromCatalog,
                        searchText: model.text,
                        model: model
                    )
                }
                .buttonStyle(.plain)
                .onAppear { model.requestAvailability(for: media.id) }
            }
        }

        if let error = model.loadMoreError {
            Text(error)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.danger))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
        }

        if let count = model.loadMoreCount {
            loadMoreRow(count: count) { await model.loadMore() }
        }
        if model.offersCatalogContinuation {
            infoRow("Im Bestand der UB gibt es nur wenige Treffer. Der Gesamtkatalog hat vielleicht mehr.")
            SecondaryButton("Im Gesamtkatalog weitersuchen", isLoading: model.isContinuing) {
                Task { await model.continueInCatalog() }
            }
        }
        if model.offersMixedEnd {
            infoRow("Das sind alle Treffer dieser Suche. Für mehr Titel aus anderen Bibliotheken:")
            SecondaryButton("Im Gesamtkatalog suchen", isLoading: model.isContinuing) {
                Task { await model.continueInCatalog() }
            }
        }
        if let count = model.loadMoreCountInCatalog {
            loadMoreRow(count: count) { await model.loadMoreInCatalog() }
        }
    }

    /// „Weitere N Treffer laden“; beim Nachladen steht die kleine Ziege an der Stelle des Buttons.
    @ViewBuilder
    private func loadMoreRow(count: Int, load: @escaping () async -> Void) -> some View {
        if model.isLoadingMore {
            GoatLoadingFooter(minHeight: 50)
        } else {
            SecondaryButton("Weitere \(count) Treffer laden") {
                Task { await load() }
            }
        }
    }

    private var loadingBlock: some View {
        Group {
            HStack(alignment: .center, spacing: 10) {
                LibrarySkeletonPill(width: 18, height: 18)
                Text(model.showsCatalogHint ? "Wenig im Bestand – frage auch den Gesamtkatalog …" : "Suche läuft …")
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color(.surface), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .combine)

            ForEach(0..<4, id: \.self) { _ in LibrarySkeletonCard() }
        }
    }

    private var emptyBlock: some View {
        VStack(spacing: 6) {
            Text("Keine Treffer für „\(model.emptyQueryText)“")
                .font(.headline)
                .foregroundStyle(Color(.textPrimary))
            Text(model.catalogTried
                 ? "Auch im Gesamtkatalog gibt es keine Treffer. Prüfe die Schreibweise."
                 : "Prüfe die Schreibweise oder wähle bei Medienart „Alle“.")
                .foregroundStyle(Color(.textSecondary))
                .padding(.bottom, 12)
            if model.offersCatalogForEmpty {
                SecondaryButton("Im Gesamtkatalog suchen", isLoading: model.isContinuing) {
                    Task { await model.continueInCatalog() }
                }
            }
            if let error = model.loadMoreError {
                Text(error).font(.footnote.weight(.semibold)).foregroundStyle(Color(.danger))
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
    }

    private var failedBlock: some View {
        VStack(spacing: 6) {
            Text("Katalog gerade nicht erreichbar")
                .font(.headline)
                .foregroundStyle(Color(.textPrimary))
            Text("Die Bibliothek antwortet nicht. Versuch es gleich noch einmal.")
                .foregroundStyle(Color(.textSecondary))
                .padding(.bottom, 12)
            PrimaryButton("Erneut versuchen") { model.retry() }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
    }

    private var startBlock: some View {
        VStack(spacing: 6) {
            Text("Im Bestand der UB Ilmenau suchen")
                .font(.headline)
                .foregroundStyle(Color(.textPrimary))
            Text("Tippfehler sind kein Problem. Gibt es wenig Treffer, fragt die App auch den Gesamtkatalog. Keine Anmeldung nötig.")
                .foregroundStyle(Color(.textSecondary))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    private func infoRow(_ text: String, systemImage: String? = nil, warning: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.footnote.weight(warning ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(warning ? Color(.warning) : Color(.textSecondary))
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(warning ? Color(.warningSoft) : Color(.surface), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
