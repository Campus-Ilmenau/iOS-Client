import SwiftUI

/// Ansicht „Bibliothek“ nach `BibAusleihen.dc.html`, ohne Service, damit alle Zustände als Preview möglich sind.
/// `BibliothekView` verbindet sie mit `PAIAService`.
struct BibliothekScreen: View {
    enum Tab: Hashable {
        case loans
        case holds
    }

    enum Session: Equatable {
        case signedOut(expired: Bool)
        case signedIn(username: String?)
    }

    let session: Session
    let items: [PAIALoanItem]
    let notificationCount: Int
    let isLoading: Bool
    @Binding var errorMessage: String?
    var now: Date = .now
    let onOpenNotifications: () -> Void
    let onOpenCatalog: () -> Void
    let onLogin: () -> Void
    let onLogout: () -> Void
    let onRenew: (PAIALoanItem) -> Void
    let onRefresh: () async -> Void
    /// Tippen auf eine Karte: die Details des Mediums öffnen.
    let onOpenTitle: (LibraryTitleRoute) -> Void
    /// Anzahl der Titel auf der Merkliste, für das Lesezeichen im Kopf.
    let merklisteCount: Int
    let onOpenMerkliste: () -> Void

    @State private var tab: Tab
    /// Zeitverhalten der Ziege beim ersten Laden ohne Ausleihen.
    @State private var loader: LoadingGate

    init(
        session: Session,
        items: [PAIALoanItem],
        notificationCount: Int,
        isLoading: Bool,
        errorMessage: Binding<String?>,
        initialTab: Tab = .loans,
        now: Date = .now,
        onOpenNotifications: @escaping () -> Void,
        onOpenCatalog: @escaping () -> Void,
        onLogin: @escaping () -> Void,
        onLogout: @escaping () -> Void,
        onRenew: @escaping (PAIALoanItem) -> Void,
        onRefresh: @escaping () async -> Void,
        onOpenTitle: @escaping (LibraryTitleRoute) -> Void = { _ in },
        merklisteCount: Int = 0,
        onOpenMerkliste: @escaping () -> Void = {}
    ) {
        self.session = session
        self.items = items
        self.notificationCount = notificationCount
        self.isLoading = isLoading
        self._errorMessage = errorMessage
        self._tab = State(initialValue: initialTab)
        self._loader = State(initialValue: LoadingGate(isLoading: isLoading && items.isEmpty))
        self.now = now
        self.onOpenNotifications = onOpenNotifications
        self.onOpenCatalog = onOpenCatalog
        self.onLogin = onLogin
        self.onLogout = onLogout
        self.onRenew = onRenew
        self.onRefresh = onRefresh
        self.onOpenTitle = onOpenTitle
        self.merklisteCount = merklisteCount
        self.onOpenMerkliste = onOpenMerkliste
    }

    private var lists: BibliothekLists { BibliothekLists(items: items) }
    private var isSignedIn: Bool {
        if case .signedIn = session { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            catalogButton
            switch session {
            case .signedOut(let expired):
                PAIASignedOutView(sessionExpired: expired, onLogin: onLogin)
            case .signedIn(let username):
                segment
                content(username: username)
            }
        }
        .background(Color(.background))
    }

    // MARK: - Kopf

    private var summary: String {
        switch session {
        case .signedOut(let expired):
            expired ? "Sitzung abgelaufen" : "Nicht angemeldet"
        case .signedIn:
            isLoading && items.isEmpty ? "Wird geladen …" : lists.summary(now: now)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bibliothek")
                    .display(size: 34, relativeTo: .largeTitle)
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityAddTraits(.isHeader)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                // Das Lesezeichen ist immer da, auch abgemeldet; die Glocke nur mit Anmeldung.
                bookmarkButton
                if isSignedIn {
                    bellButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var bookmarkButton: some View {
        Button(action: onOpenMerkliste) {
            Image(systemName: "bookmark")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(.textPrimary))
                .frame(width: 44, height: 44)
                .background(Color(.surfaceSecondary), in: Circle())
        }
        .accessibilityLabel(merklisteCount == 0 ? "Merkliste, leer" : "Merkliste, \(merklisteCount) Titel")
    }

    private var bellButton: some View {
        Button(action: onOpenNotifications) {
            Image(systemName: "bell")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(.textPrimary))
                .frame(width: 44, height: 44)
                .background(Color(.surfaceSecondary), in: Circle())
                .overlay(alignment: .topTrailing) {
                    if notificationCount > 0 {
                        Circle()
                            .fill(Color(.accent))
                            .frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(Color(.surfaceSecondary), lineWidth: 2).padding(-2))
                            .padding(.top, 9)
                            .padding(.trailing, 10)
                    }
                }
        }
        .accessibilityLabel(notificationCount > 0 ? "Mitteilungen, \(notificationCount) vorhanden" : "Mitteilungen")
    }

    private var catalogButton: some View {
        Button(action: onOpenCatalog) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Im Katalog suchen")
                    .font(.callout)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color(.textTertiary))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var segment: some View {
        SegmentedControl(
            selection: $tab,
            options: [
                (.loans, segmentTitle("Ausgeliehen", count: lists.loans.count)),
                (.holds, segmentTitle("Vormerkungen", count: lists.holds.count))
            ]
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func segmentTitle(_ title: String, count: Int) -> LocalizedStringKey {
        LocalizedStringKey(count > 0 ? "\(title) · \(count)" : title)
    }

    // MARK: - Inhalt

    private func content(username: String?) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if let errorMessage {
                    errorBox(errorMessage)
                }

                // Beim ersten Laden gehört der Bereich der Ziege; die Listen kommen erst danach.
                if !loader.isActive {
                    switch tab {
                    case .loans:
                        if lists.loans.isEmpty {
                            if !isLoading {
                                emptyCard(
                                    title: "Keine ausgeliehenen Medien",
                                    hint: "Was du in der Universitätsbibliothek ausleihst, erscheint hier mit Rückgabedatum."
                                )
                            }
                        } else {
                            ForEach(lists.loans) { item in
                                PAIALoanItemRow(item: item, now: now, onRenew: { onRenew(item) }, onOpen: openAction(for: item))
                            }
                        }
                    case .holds:
                        if lists.holds.isEmpty {
                            if !isLoading {
                                emptyCard(
                                    title: "Keine Vormerkungen",
                                    hint: "Vorgemerkte und bestellte Medien erscheinen hier, bis du sie abholst."
                                )
                            }
                        } else {
                            ForEach(lists.holds) { item in
                                PAIAHoldCard(item: item, onOpen: openAction(for: item))
                            }
                        }
                    }
                }

                footer(username: username)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable { await onRefresh() }
        .overlay {
            if loader.isActive {
                GoatLoadingBlock(message: "Ausleihen werden geladen …", gate: loader)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: isLoading && items.isEmpty, initial: true) { _, isFirstLoad in
            loader.setLoading(isFirstLoad)
        }
        .onChange(of: errorMessage) { _, newValue in
            if let newValue {
                AccessibilityNotification.Announcement(newValue).post()
            }
        }
    }

    /// Aktion zum Öffnen der Details oder `nil`, wenn sich der Titel im Katalog nicht finden lässt.
    private func openAction(for item: PAIALoanItem) -> (() -> Void)? {
        guard let route = item.catalogRoute else { return nil }
        return { onOpenTitle(route) }
    }

    private func emptyCard(title: LocalizedStringKey, hint: LocalizedStringKey) -> some View {
        Card(verticalPadding: 36, horizontalPadding: 20) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color(.textPrimary))
                Text(hint)
                    .foregroundStyle(Color(.textSecondary))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    /// Fehler der Bibliothek, z. B. „Verlängerung fehlgeschlagen: …“. Bleibt, bis man ihn schließt oder neu lädt.
    private func errorBox(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.body.weight(.semibold))
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color(.danger))
        .padding(.vertical, 12)
        .padding(.leading, 14)
        .padding(.trailing, 44)
        .background(Color(.dangerSoft), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button {
                errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(.danger))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Meldung schließen")
        }
        .accessibilityElement(children: .contain)
    }

    private func footer(username: String?) -> some View {
        VStack(spacing: 10) {
            Text(username.map { "Angemeldet mit \($0). Du bleibst angemeldet, bis du die App beendest." }
                 ?? "Du bleibst angemeldet, bis du die App beendest.")
                .font(.footnote)
                .foregroundStyle(Color(.textTertiary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            SoftDestructiveButton("Abmelden", action: onLogout)
        }
        .padding(.top, 4)
    }
}
