import SwiftUI

/// Die Merkliste: Titel aus dem Bibliothekskatalog an einem Ort, nach `BibMerkliste.dc.html`.
/// Keine Anmeldung nötig, hat nichts mit PAIA zu tun. Den Status lädt die Ansicht beim Öffnen frisch.
struct BibMerklisteView: View {
    let service: LibraryCatalogService
    let coverLoader: LibraryCoverLoader
    /// Beschriftung des Zurück-Knopfs: „Bibliothek“ oder, wenn man aus einem Titel kam, „Titel“.
    var backTitle = "Bibliothek"

    @Environment(\.merkliste) private var merkliste
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router: AppRouter?
    /// Die Meldung an Siri ging für dieses Öffnen schon hinaus (die Ansicht erscheint auch wieder, wenn man aus einem
    /// Titel zurückkommt).
    @State private var anSiriGemeldet = false

    @State private var status: BibMerklisteStatus
    @State private var loadsStatus: Bool
    @State private var toast: MerklisteToast?
    @State private var toastToken = 0
    @State private var showsClearAlert = false
    @State private var showsCatalog = false
    /// Lageplan im Browser-Fenster (Sheet).
    @State private var lageplan: LibraryExternalLink?

    /// Meldung unten, ggf. mit „Widerrufen“.
    private struct MerklisteToast: Equatable {
        let message: String
        let undo: EntfernterTitel?
    }

    init(
        service: LibraryCatalogService,
        coverLoader: LibraryCoverLoader,
        backTitle: String = "Bibliothek",
        status: BibMerklisteStatus? = nil,
        loadsStatus: Bool = true
    ) {
        self.service = service
        self.coverLoader = coverLoader
        self.backTitle = backTitle
        _status = State(initialValue: status ?? BibMerklisteStatus())
        _loadsStatus = State(initialValue: loadsStatus)
    }

    private var eintraege: [GemerkterTitel] { merkliste.eintraege }

    var body: some View {
        VStack(spacing: 0) {
            header

            if eintraege.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color(.background))
        .onAppear {
            guard !anSiriGemeldet else { return }
            anSiriGemeldet = true
            SiriMelder.gemeinsam.neueOeffnung(.merkliste)
            SiriMelder.gemeinsam.melde(.merkliste, in: .merkliste, router: router)
        }
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                        Text(backTitle)
                    }
                    .foregroundStyle(Color(.accent))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Zurück zu \(backTitle)")
            }
        }
        .toast(
            LocalizedStringKey(toast?.message ?? ""),
            actionTitle: toast?.undo == nil ? nil : "Widerrufen",
            action: { if let undo = toast?.undo { widerrufen(undo) } },
            isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } }),
            duration: .seconds(toast?.undo == nil ? 2.4 : 4),
            token: toastToken
        )
        .alert("Merkliste leeren?", isPresented: $showsClearAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Leeren", role: .destructive) { leeren() }
        } message: {
            Text(clearMessage)
        }
        .navigationDestination(isPresented: $showsCatalog) {
            LibraryCatalogView(autofocus: true)
        }
        .sheet(item: $lageplan) { link in
            LibrarySafariView(url: link.url)
                .ignoresSafeArea()
        }
        .task {
            await ergaenzen()
            await ladeStatus()
        }
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Merkliste")
                .display(size: 34, relativeTo: .largeTitle)
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityAddTraits(.isHeader)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    private var summary: String {
        switch eintraege.count {
        case 0: "Noch keine Titel"
        case 1: "1 Titel"
        default: "\(eintraege.count) Titel · zuletzt gemerkt zuerst"
        }
    }

    // MARK: - Liste

    private var list: some View {
        List {
            Section {
                ForEach(eintraege) { eintrag in
                    NavigationLink {
                        LibraryTitleView(
                            media: eintrag.alsMedia,
                            searchId: nil,
                            service: service,
                            coverLoader: coverLoader,
                            origin: .merkliste
                        )
                    } label: {
                        BibMerklisteZeile(
                            eintrag: eintrag,
                            status: status.status(for: eintrag.id),
                            exemplar: status.exemplar(for: eintrag.id),
                            onLageplan: { lageplan = LibraryExternalLink(url: $0) }
                        )
                    }
                    .listRowBackground(Color(.surface))
                    // Wie in Mail: kurz wischen lässt „Entfernen“ offen, weit wischen entfernt sofort.
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            entfernen(eintrag)
                        } label: {
                            Label("Entfernen", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            entfernen(eintrag)
                        } label: {
                            Label("Von der Merkliste entfernen", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text("Zum Entfernen nach links wischen. Die Merkliste liegt nur auf diesem iPhone, eine Anmeldung ist nicht nötig. Die Verfügbarkeit kann bis zu 5 Minuten alt sein.")
                    .font(.caption)
                    .foregroundStyle(Color(.textTertiary))
                    .padding(.top, 4)
            }

            Section {
                SoftDestructiveButton("Merkliste leeren") { showsClearAlert = true }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable {
            await ergaenzen()
            await ladeStatus()
        }
    }

    // MARK: - Leer

    private var emptyState: some View {
        ScrollView {
            Card(verticalPadding: 32, horizontalPadding: 20) {
                VStack(spacing: 0) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color(.textTertiary))
                        .accessibilityHidden(true)
                    Text("Noch nichts gemerkt")
                        .font(.headline)
                        .foregroundStyle(Color(.textPrimary))
                        .padding(.top, 10)
                    Text("Tippe bei einem Titel auf das Lesezeichen, um ihn hier zu sammeln.")
                        .foregroundStyle(Color(.textSecondary))
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .padding(.bottom, 18)
                    PrimaryButton("Im Katalog suchen") { showsCatalog = true }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Aktionen

    private func entfernen(_ eintrag: GemerkterTitel) {
        var removed: EntfernterTitel?
        withAnimation { removed = merkliste.entfernen(eintrag.id) }
        guard let removed else { return }
        show(MerklisteToast(message: "„\(eintrag.anzeigeTitel)“ entfernt", undo: removed))
    }

    /// Setzt den Eintrag an die alte Stelle zurück.
    private func widerrufen(_ entfernt: EntfernterTitel) {
        withAnimation { merkliste.wiederherstellen(entfernt) }
        toast = nil
        Task { await ladeStatus() }
    }

    private func leeren() {
        withAnimation { merkliste.alleEntfernen() }
        show(MerklisteToast(message: "Merkliste geleert", undo: nil))
    }

    private func show(_ newToast: MerklisteToast) {
        toastToken += 1
        toast = newToast
    }

    private var clearMessage: String {
        let count = eintraege.count
        let first = count == 1 ? "Der Titel wird" : "Alle \(count) Titel werden"
        return "\(first) von der Merkliste entfernt. Das lässt sich nicht rückgängig machen."
    }

    // MARK: - Laden

    /// Status aller gemerkten Titel frisch laden, in Paketen von 20 IDs.
    private func ladeStatus() async {
        guard loadsStatus else { return }
        await status.load(ids: eintraege.map(\.id), using: service)
    }

    /// Von früher übernommene Einträge kennen nur die ID: Titel und Personen aus dem Katalog nachladen.
    private func ergaenzen() async {
        guard loadsStatus else { return }
        for eintrag in eintraege where eintrag.istUnvollstaendig {
            guard let result = try? await service.media(id: eintrag.id, searchId: nil, track: false) else { continue }
            let media = result.value.media
            let coverURL = media.cover.status == .found ? service.coverURL(for: media.cover) : nil
            merkliste.aktualisieren(GemerkterTitel(media: media, coverURL: coverURL, gemerktAm: eintrag.gemerktAm))
        }
    }
}

// MARK: - Previews

#if DEBUG
/// Beispiele aus `BibMerkliste.dc.html`, ohne Netzwerk und ohne Datei.
enum MerklisteBeispiele {
    static func store(filled: Bool = true) -> BibMerklisteStore {
        let store = BibMerklisteStore(fileURL: nil, legacyDefaults: nil)
        guard filled else { return store }
        let samples: [(String, String, String, String?, String)] = [
            ("med_1", "Regelungstechnik für Ingenieure", "Manfred Reuter, Serge Zacher", "2022", "print_book"),
            ("med_2", "Regelungstechnik 1", "Jan Lunze", "2020", "print_book"),
            ("med_3", "Einführung in die Regelungstechnik", "Heinz Mann, Horst Schiffelgen", "2018", "ebook"),
            ("med_4", "Grundlagen der Elektrotechnik 1: Gleichstromnetzwerke, Wechselstromtechnik und ihre Anwendungen in der Energieversorgung", "Gert Hagmann", "2021", "print_book"),
            ("med_5", "at – Automatisierungstechnik", "", "2024", "journal"),
            ("med_6", "Signale und Systeme", "Martin Werner", nil, "print_book")
        ]
        // Das zuerst Gemerkte steht unten.
        for (offset, sample) in samples.reversed().enumerated() {
            store.merken(GemerkterTitel(
                id: sample.0,
                titel: sample.1,
                personen: sample.2,
                jahr: sample.3,
                medientyp: sample.4,
                gemerktAm: Date(timeIntervalSinceNow: -Double(samples.count - offset) * 60)
            ))
        }
        return store
    }

    static var status: BibMerklisteStatus {
        let plan = URL(string: "https://www.tu-ilmenau.de/ub")
        return BibMerklisteStatus(status: [
            "med_1": .available, "med_2": .onLoan, "med_3": .online,
            "med_4": .referenceOnly, "med_5": .online, "med_6": .unknown
        ], exemplare: [
            "med_1": BibMerklisteExemplar(signatur: "ST 130 R434 (2)", standort: "Lehrbuchsammlung", lageplan: plan, weitere: 2),
            "med_2": BibMerklisteExemplar(signatur: "ST 130 L969", standort: "Magazin"),
            "med_4": BibMerklisteExemplar(
                signatur: "ZN 4100 H196 mit einer sehr langen Signatur",
                standort: "Lesesaal Naturwissenschaften und Technik", lageplan: plan
            ),
            "med_6": BibMerklisteExemplar(signatur: "ST 100 W491", standort: nil)
        ])
    }
}

private struct MerklistePreview: View {
    let store: BibMerklisteStore
    let status: BibMerklisteStatus

    var body: some View {
        let service = LibraryCatalogService()
        NavigationStack {
            BibMerklisteView(
                service: service,
                coverLoader: LibraryCoverLoader(service: service),
                status: status,
                loadsStatus: false
            )
        }
        .environment(\.merkliste, store)
    }
}

#Preview("Merkliste – Light") {
    MerklistePreview(store: MerklisteBeispiele.store(), status: MerklisteBeispiele.status).preferredColorScheme(.light)
}
#Preview("Merkliste – Dark") {
    MerklistePreview(store: MerklisteBeispiele.store(), status: MerklisteBeispiele.status).preferredColorScheme(.dark)
}
#Preview("Merkliste – xxxLarge") {
    MerklistePreview(store: MerklisteBeispiele.store(), status: MerklisteBeispiele.status).dynamicTypeSize(.xxxLarge)
}
#Preview("Merkliste – Status lädt") {
    MerklistePreview(store: MerklisteBeispiele.store(), status: BibMerklisteStatus()).preferredColorScheme(.light)
}
#Preview("Merkliste – leer, Light") {
    MerklistePreview(store: MerklisteBeispiele.store(filled: false), status: BibMerklisteStatus()).preferredColorScheme(.light)
}
#Preview("Merkliste – leer, Dark") {
    MerklistePreview(store: MerklisteBeispiele.store(filled: false), status: BibMerklisteStatus()).preferredColorScheme(.dark)
}
#endif
