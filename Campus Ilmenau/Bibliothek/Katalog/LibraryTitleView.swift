import SwiftUI
import SafariServices

/// Woher man in die Titel-Ansicht kam; bestimmt die Beschriftung des Zurück-Knopfs.
enum LibraryTitleOrigin {
    case catalog
    case library
    case merkliste

    var backTitle: String {
        switch self {
        case .catalog: "Katalog"
        case .library: "Bibliothek"
        case .merkliste: "Merkliste"
        }
    }

    var backToTitle: String {
        switch self {
        case .catalog: "Zurück zum Katalog"
        case .library: "Zurück zur Bibliothek"
        case .merkliste: "Zurück zur Merkliste"
        }
    }
}

/// Push-Ansicht eines Titels aus dem Katalog nach `BibTitel.dc.html`. Lädt den Titel erst beim Öffnen, nichts wird vorgeladen.
struct LibraryTitleView: View {
    @State private var model: LibraryTitleModel

    private let origin: LibraryTitleOrigin

    init(
        media: LibraryMedia,
        searchId: String?,
        service: LibraryCatalogService,
        coverLoader: LibraryCoverLoader,
        origin: LibraryTitleOrigin = .catalog
    ) {
        self.origin = origin
        _model = State(initialValue: LibraryTitleModel(
            media: media,
            searchId: searchId,
            service: service,
            coverLoader: coverLoader
        ))
    }

    var body: some View {
        LibraryTitleScreen(model: model, origin: origin)
            .task { await model.load() }
    }
}

/// Oberfläche der Titel-Ansicht. Zustand und Laden liegen im `LibraryTitleModel`.
struct LibraryTitleScreen: View {
    @Bindable var model: LibraryTitleModel
    var origin: LibraryTitleOrigin = .catalog

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch model.phase {
                case .notFound:
                    notFoundBlock
                default:
                    content
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .refreshable { await model.refresh() }
        .background(Color(.background))
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { toolbarContent }
        .toast(
            LocalizedStringKey(model.toastMessage),
            actionTitle: model.toastActionTitle.map { LocalizedStringKey($0) },
            action: { model.performToastAction() },
            isPresented: $model.showsToast,
            duration: .seconds(model.toastActionTitle == nil ? 2 : 4),
            token: model.toastToken
        )
        .sensoryFeedback(.selection, trigger: model.istGemerkt)
        .navigationDestination(isPresented: Binding(
            get: { model.opensMerkliste && origin != .merkliste },
            set: { model.opensMerkliste = $0 }
        )) {
            BibMerklisteView(service: model.service, coverLoader: model.coverLoader, backTitle: "Titel")
        }
        .onChange(of: model.opensMerkliste) { _, opens in
            // Kam man aus der Merkliste, führt „Anzeigen“ einfach dorthin zurück.
            if opens && origin == .merkliste {
                model.opensMerkliste = false
                dismiss()
            }
        }
        .sheet(item: $model.externalLink) { link in
            LibrarySafariView(url: link.url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Navigationszeile

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    Text(origin.backTitle)
                }
                .foregroundStyle(Color(.accent))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(origin.backToTitle)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            shareButton
            Button {
                model.toggleMerken()
            } label: {
                Image(systemName: model.istGemerkt ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(model.istGemerkt ? Color(.accent) : Color(.textPrimary))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(model.istGemerkt ? "Von der Merkliste entfernen" : "Auf die Merkliste setzen")
            .accessibilityAddTraits(model.istGemerkt ? .isSelected : [])
        }
    }

    /// Nur der Text, kein Menü und kein Bild: Das Wichtigste ist der Link zum UB-Katalog, und den muss man antippen können.
    private var shareButton: some View {
        let share = LibraryMediaShare(media: model.media, detail: model.detail)
        // Ohne `SharePreview`: Mit Vorschau bietet das Blatt für Text kein „Kopieren“ an.
        return ShareLink(item: share.text, subject: Text(share.title)) {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(Color(.textPrimary))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Titel teilen")
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var content: some View {
        header

        if let notice = model.staleNotice {
            infoRow(notice)
                .padding(.top, 16)
        }

        statusArea
            .padding(.top, 16)

        // Auch nach einem Fehler bleibt der UB-Katalog über den Link aus der Trefferliste erreichbar.
        actions
            .padding(.top, 12)

        if let detail = model.detail, !detail.items.isEmpty {
            itemsSection(detail)
        } else if model.phase == .loading {
            skeletonItems
        }

        if model.showsContents, let contents = model.detail?.contents {
            contentsSection(contents)
        }

        factsSection

        Text("Angaben aus dem Katalog der Universitätsbibliothek Ilmenau. Die Verfügbarkeit kann bis zu 5 Minuten alt sein.")
            .font(.caption)
            .foregroundStyle(Color(.textTertiary))
            .padding(.top, 18)
            .padding(.horizontal, 4)
    }

    // MARK: Kopf

    private var header: some View {
        let media = model.media
        let titleBlock = VStack(alignment: .leading, spacing: 4) {
            Text(media.kindLabel)
                .font(.caption.weight(.bold))
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundStyle(Color(.textTertiary))
            Text(media.title)
                .display(size: 23, relativeTo: .title2)
                .foregroundStyle(Color(.textPrimary))
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        return VStack(alignment: .leading, spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    LibraryTitleCover(model: model)
                    titleBlock
                }
            } else {
                HStack(alignment: .bottom, spacing: 16) {
                    LibraryTitleCover(model: model)
                    titleBlock.padding(.bottom, 2)
                }
            }

            if let subtitle = media.trimmedSubtitle {
                Text(subtitle)
                    .foregroundStyle(Color(.textSecondary))
                    .padding(.top, 12)
            }
            if !media.personsLine.isEmpty {
                Text(media.personsLine)
                    .foregroundStyle(Color(.textPrimary))
                    .padding(.top, 6)
            }
            if !media.editionLine.isEmpty {
                Text(media.editionLine)
                    .font(.footnote)
                    .foregroundStyle(Color(.textTertiary))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: Gesamtstatus

    @ViewBuilder
    private var statusArea: some View {
        switch model.phase {
        case .loading:
            VStack(alignment: .leading, spacing: 8) {
                LibrarySkeletonPill(width: 180, height: 20)
                LibrarySkeletonPill(width: 240, height: 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Verfügbarkeit wird geladen")

        case .failed:
            VStack(spacing: 6) {
                Text("Katalog gerade nicht erreichbar")
                    .font(.headline)
                    .foregroundStyle(Color(.textPrimary))
                Text("Die Bibliothek antwortet nicht. Versuch es gleich noch einmal.")
                    .foregroundStyle(Color(.textSecondary))
                    .padding(.bottom, 12)
                PrimaryButton("Erneut versuchen") {
                    Task { await model.refresh() }
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        default:
            if let detail = model.detail {
                statusBlock(detail.statusBlock)
            }
        }
    }

    private func statusBlock(_ block: LibraryStatusBlock) -> some View {
        let background: Color
        let foreground: Color
        switch block.tone {
        case .green: (background, foreground) = (Color(.green), Color(.onGreen))
        case .blue: (background, foreground) = (Color(.blue), Color(.onBlue))
        case .neutral: (background, foreground) = (Color(.surface), Color(.textPrimary))
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text(block.title)
                .font(.headline.weight(.bold))
            Text(block.subtitle)
                .font(.subheadline)
                .opacity(0.9)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Aktionen

    @ViewBuilder
    private var actions: some View {
        let primary = model.detail?.primaryAction
        let catalogURL = model.media.catalogUrl
        if primary != nil || catalogURL != nil {
            VStack(spacing: 10) {
                if let primary {
                    PrimaryButton(LocalizedStringKey(primary.title), trailingSystemImage: "arrow.up.right") {
                        model.open(primary.url)
                    }
                    .accessibilityHint("Öffnet eine Seite der Bibliothek im Browser")
                }
                if let catalogURL {
                    SecondaryButton("Im UB-Katalog öffnen", trailingSystemImage: "arrow.up.right") {
                        model.open(catalogURL)
                    }
                    .accessibilityHint("Öffnet eine Seite der Bibliothek im Browser")
                }
                Text("↗ öffnet eine Seite der Bibliothek im Browser.")
                    .font(.caption)
                    .foregroundStyle(Color(.textTertiary))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Exemplare

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(.textSecondary))
            .padding(.top, 22)
            .padding(.bottom, 8)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func itemsSection(_ detail: LibraryMediaDetail) -> some View {
        let rows = detail.rows
        return VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Exemplare · \(rows.count)")
            Card(verticalPadding: 2) {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        itemRow(row)
                        if index < rows.count - 1 {
                            Rectangle().fill(Color(.separator)).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func itemRow(_ row: LibraryItemRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Text(row.place)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Chip(LocalizedStringKey(row.chipText), variant: row.status.chipVariant)
            }

            HStack(spacing: 8) {
                Text(row.signature)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .textSelection(.enabled)
                Button {
                    model.copySignature(row.signature)
                } label: {
                    Text("Kopieren")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.textPrimary))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(Color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Signatur kopieren")
            }

            if let extra = row.extra {
                Text(extra)
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
            }

            if let plan = row.floorPlanURL {
                Button {
                    model.open(plan)
                } label: {
                    HStack(spacing: 4) {
                        Text("Lageplan")
                        Image(systemName: "arrow.up.right").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.accent))
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .padding(.top, -6)
                .accessibilityHint("Öffnet eine Seite der Bibliothek im Browser")
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var skeletonItems: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Exemplare")
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    LibrarySkeletonPill(width: 200, height: 18)
                    LibrarySkeletonPill(width: 140, height: 14)
                }
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: Inhalt

    private func contentsSection(_ contents: LibraryContents) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Inhalt")
            Card(verticalPadding: 0) {
                VStack(spacing: 0) {
                    if contents.hasTableOfContents, let toc = contents.tableOfContents {
                        fold("Inhaltsverzeichnis", isOpen: $model.tocOpen) {
                            tableOfContents(toc)
                        }
                    }
                    if contents.hasTableOfContents, contents.hasBlurb {
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                    }
                    if contents.hasBlurb, let text = contents.blurb?.text {
                        fold("Klappentext", isOpen: $model.blurbOpen) {
                            Text(text)
                                .font(.subheadline)
                                .foregroundStyle(Color(.textSecondary))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 14)
                        }
                    }
                }
            }
        }
    }

    private func fold<Body: View>(_ title: LocalizedStringKey, isOpen: Binding<Bool>, @ViewBuilder content: () -> Body) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { isOpen.wrappedValue.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color(.textPrimary))
                    Spacer()
                    Image(systemName: isOpen.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.textTertiary))
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isOpen.wrappedValue ? "aufgeklappt" : "zugeklappt")
            .accessibilityHint(isOpen.wrappedValue ? "Zuklappen" : "Aufklappen")

            if isOpen.wrappedValue {
                content()
            }
        }
    }

    /// Gliederung mit Seiten; ohne Gliederung der Fließtext (gekürzt).
    @ViewBuilder
    private func tableOfContents(_ toc: LibraryTableOfContents) -> some View {
        if !toc.entries.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(toc.entries.enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text([entry.number ?? "", entry.title].filter { !$0.isEmpty }.joined(separator: " "))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let page = entry.page {
                            Text(page).foregroundStyle(Color(.textTertiary))
                        }
                    }
                    .font(.subheadline.weight(entry.level > 1 ? .regular : .semibold))
                    .foregroundStyle(entry.level > 1 ? Color(.textSecondary) : Color(.textPrimary))
                    .padding(.leading, CGFloat(max(0, entry.level - 1)) * 16)
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.bottom, 12)
        } else if let text = toc.shortText {
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 14)
        }
    }

    // MARK: Weitere Angaben

    @ViewBuilder
    private var factsSection: some View {
        let facts = model.media.facts
        if !facts.isEmpty {
            sectionHeader("Weitere Angaben")
            Card(verticalPadding: 2) {
                VStack(spacing: 0) {
                    let rows: [(String, String?)] = [
                        ("ISBN", facts.isbn),
                        ("Sprache", facts.language),
                        ("Verlag", facts.publisher),
                        ("Systematik (RVK)", facts.rvk)
                    ]
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        if let value = row.1 {
                            factRow(row.0, value)
                            separatorIfNeeded(facts, after: row.0)
                        }
                    }
                    if !facts.subjects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Schlagwörter").foregroundStyle(Color(.textSecondary))
                            ChipFlowLayout(spacing: 6) {
                                ForEach(Array(facts.subjects.enumerated()), id: \.offset) { _, subject in
                                    Text(subject)
                                        .font(.footnote)
                                        .foregroundStyle(Color(.textPrimary))
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 10)
                                        .background(Color(.surfaceSecondary), in: Capsule())
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 11)
                        if facts.abstract != nil {
                            Rectangle().fill(Color(.separator)).frame(height: 1)
                        }
                    }
                    if let abstract = facts.abstract {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kurzbeschreibung").foregroundStyle(Color(.textSecondary))
                            Text(abstract)
                                .font(.subheadline)
                                .foregroundStyle(Color(.textPrimary))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 11)
                    }
                }
            }
        }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).foregroundStyle(Color(.textSecondary))
            Text(value)
                .foregroundStyle(Color(.textPrimary))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    /// Trennlinie nach einer Zeile, solange danach noch etwas kommt.
    @ViewBuilder
    private func separatorIfNeeded(_ facts: LibraryTitleFacts, after label: String) -> some View {
        let order = ["ISBN", "Sprache", "Verlag", "Systematik (RVK)"]
        let values: [String: String?] = ["ISBN": facts.isbn, "Sprache": facts.language, "Verlag": facts.publisher, "Systematik (RVK)": facts.rvk]
        let index = order.firstIndex(of: label) ?? 0
        let laterRow = order.dropFirst(index + 1).contains { values[$0] ?? nil != nil }
        if laterRow || !facts.subjects.isEmpty || facts.abstract != nil {
            Rectangle().fill(Color(.separator)).frame(height: 1)
        }
    }

    // MARK: Hinweise

    private func infoRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock")
                .font(.footnote.weight(.semibold))
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color(.warning))
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.warningSoft), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var notFoundBlock: some View {
        VStack(spacing: 6) {
            Text("Titel nicht gefunden")
                .font(.headline)
                .foregroundStyle(Color(.textPrimary))
            Text("Dieser Titel ist im Katalog nicht (mehr) vorhanden.")
                .foregroundStyle(Color(.textSecondary))
                .padding(.bottom, 12)
            if model.istGemerkt {
                SecondaryButton("Von der Merkliste entfernen") { model.vonMerklisteEntfernen() }
                    .padding(.bottom, 4)
            }
            SecondaryButton(LocalizedStringKey(origin.backToTitle)) { dismiss() }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 20)
    }
}

// MARK: - Cover

/// Cover 96 × 136 oder Platzhalter mit Symbol. Bei „wird noch geholt“ lädt der Lader später erneut.
struct LibraryTitleCover: View {
    let model: LibraryTitleModel

    @State private var image: UIImage?

    private var shown: UIImage? { model.previewCover ?? image }

    var body: some View {
        ZStack {
            if let shown {
                Image(uiImage: shown)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.surfaceSecondary)
                Image(systemName: model.media.mediaType.placeholderSymbol)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color(.textTertiary))
            }
        }
        .frame(width: 96, height: 136)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: shown == nil ? .clear : Color(.brandNight).opacity(0.18), radius: 10, x: 0, y: 8)
        .accessibilityHidden(true)
        .task(id: model.media.id) {
            guard model.previewCover == nil else { return }
            image = await model.coverLoader.image(for: model.media)
        }
    }
}

// MARK: - Browser-Fenster

/// Öffnet eine Seite der Bibliothek im `SFSafariViewController`.
struct LibrarySafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
