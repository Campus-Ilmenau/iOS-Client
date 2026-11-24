import SwiftUI

/// Die Bibliothek auf dem iPad (Breite ab 700 pt): Ausgeliehen · Vormerkungen · Mitteilungen nebeneinander statt Segment
/// und Glocke. Ab 1150 pt drei Spalten (1,3 : 1 : 0,95), darunter zwei, dann stehen die Mitteilungen hinter der Glocke
/// als Popover. Logik, PAIA, Texte und Fehlerfälle sind die von `BibliothekScreen`; hier ändert sich nur die Anordnung.
/// Nach `Uebergabe.md`, „iPad“ → „Bibliothek“.
struct BibliothekPadScreen: View {
    let session: BibliothekScreen.Session
    let items: [PAIALoanItem]
    let notifications: [PAIANotification]
    let isLoading: Bool
    @Binding var errorMessage: String?
    var now: Date = .now
    /// 2 oder 3 (siehe `PadRaster.bibliothekSpalten`).
    var spalten = 3
    /// Das Suchfeld im Kopf: öffnet den Katalog mit Fokus im Suchfeld.
    let onOpenCatalog: () -> Void
    let onLogin: () -> Void
    let onLogout: () -> Void
    /// Verlängert nach der Rückfrage. Liefert den Text für den Toast, `nil` bei einem Fehler (den zeigt der rote Hinweis).
    let onRenew: (PAIALoanItem) async -> String?
    let onRefresh: () async -> Void
    let merklisteCount: Int
    let onOpenMerkliste: () -> Void
    let onShowAusweis: () -> Void
    /// Für das Medium im Details-Blatt.
    let catalogService: LibraryCatalogService
    let coverLoader: LibraryCoverLoader

    @State private var loader: LoadingGate
    @State private var zeigtMitteilungen = false
    @State private var detail: BibliothekDetailZiel?
    @State private var toast = ""
    @State private var zeigtToast = false
    @Environment(\.padRaster) private var raster

    init(
        session: BibliothekScreen.Session,
        items: [PAIALoanItem],
        notifications: [PAIANotification],
        isLoading: Bool,
        errorMessage: Binding<String?>,
        now: Date = .now,
        spalten: Int = 3,
        onOpenCatalog: @escaping () -> Void,
        onLogin: @escaping () -> Void,
        onLogout: @escaping () -> Void,
        onRenew: @escaping (PAIALoanItem) async -> String?,
        onRefresh: @escaping () async -> Void,
        merklisteCount: Int,
        onOpenMerkliste: @escaping () -> Void,
        onShowAusweis: @escaping () -> Void,
        catalogService: LibraryCatalogService,
        coverLoader: LibraryCoverLoader
    ) {
        self.session = session
        self.items = items
        self.notifications = notifications
        self.isLoading = isLoading
        self._errorMessage = errorMessage
        self.now = now
        self.spalten = spalten
        self.onOpenCatalog = onOpenCatalog
        self.onLogin = onLogin
        self.onLogout = onLogout
        self.onRenew = onRenew
        self.onRefresh = onRefresh
        self.merklisteCount = merklisteCount
        self.onOpenMerkliste = onOpenMerkliste
        self.onShowAusweis = onShowAusweis
        self.catalogService = catalogService
        self.coverLoader = coverLoader
        self._loader = State(initialValue: LoadingGate(isLoading: isLoading && items.isEmpty))
    }

    private var lists: BibliothekLists { BibliothekLists(items: items) }
    private var isSignedIn: Bool {
        if case .signedIn = session { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                kopf
                if let errorMessage {
                    fehlerHinweis(errorMessage)
                        .frame(maxWidth: 680, alignment: .leading)
                }
                switch session {
                case .signedOut(let expired):
                    abgemeldetKarte(expired: expired)
                case .signedIn(let username):
                    inhalt
                    fuss(username: username)
                }
            }
            .padding(.horizontal, raster.rand)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable { await onRefresh() }
        .background(Color(.background))
        .overlay {
            if loader.isActive, isSignedIn {
                GoatLoadingBlock(message: "Ausleihen werden geladen …", gate: loader)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: isLoading && items.isEmpty, initial: true) { _, erstesLaden in
            loader.setLoading(erstesLaden)
        }
        .onChange(of: errorMessage) { _, neu in
            if let neu { AccessibilityNotification.Announcement(neu).post() }
        }
        .sheet(item: $detail) { ziel in
            BibliothekDetailBlatt(
                ziel: ziel,
                items: items,
                now: now,
                catalogService: catalogService,
                coverLoader: coverLoader,
                onRenew: onRenew
            )
            .formularBlatt(pad: true, breite: 640)
        }
        .toast(LocalizedStringKey(toast), isPresented: $zeigtToast)
    }

    // MARK: - Kopf

    private var zusammenfassung: String {
        switch session {
        case .signedOut(let expired): expired ? LocalizedStringResource("Sitzung abgelaufen").inAppSprache : LocalizedStringResource("Nicht angemeldet").inAppSprache
        case .signedIn: isLoading && items.isEmpty ? LocalizedStringResource("Wird geladen …").inAppSprache : lists.summary(now: now)
        }
    }

    private var kopf: some View {
        let titel = VStack(alignment: .leading, spacing: 2) {
            Text("Bibliothek")
                .display(size: raster.seitentitel(telefon: 34), relativeTo: .largeTitle)
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Text(zusammenfassung)
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
        }
        let knoepfe = HStack(spacing: 8) {
            suchfeld
            if isSignedIn { rundKnopf("person.text.rectangle", label: "Bibliotheksausweis zeigen", aktion: onShowAusweis) }
            rundKnopf(
                "bookmark",
                label: merklisteCount == 0 ? "Merkliste, leer" : "Merkliste, \(merklisteCount) Titel",
                aktion: onOpenMerkliste
            )
            // Die Glocke gibt es nur, wenn die Mitteilungen keine eigene Spalte haben.
            if isSignedIn, spalten < 3 { glocke }
        }
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 16) {
                titel
                Spacer(minLength: 16)
                knoepfe
            }
            VStack(alignment: .leading, spacing: 12) {
                titel
                knoepfe
            }
        }
    }

    /// „Im Katalog suchen“, 300 breit; öffnet den Katalog mit Fokus im Suchfeld.
    private var suchfeld: some View {
        Button(action: onOpenCatalog) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Im Katalog suchen")
                    .font(.callout)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color(.textSecondary))
            .padding(.horizontal, 12)
            .frame(width: 300, height: 44, alignment: .leading)
            .background(Color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    private func rundKnopf(_ symbol: String, label: LocalizedStringKey, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(.textPrimary))
                .frame(width: 44, height: 44)
                .background(Color(.surfaceSecondary), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityLabel(label)
    }

    /// Mitteilungen hinter der Glocke als Popover (380 breit).
    private var glocke: some View {
        Button { zeigtMitteilungen = true } label: {
            Image(systemName: "bell")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(.textPrimary))
                .frame(width: 44, height: 44)
                .background(Color(.surfaceSecondary), in: Circle())
                .overlay(alignment: .topTrailing) {
                    if !notifications.isEmpty {
                        Circle()
                            .fill(Color(.accent))
                            .frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(Color(.surfaceSecondary), lineWidth: 2).padding(-2))
                            .padding(.top, 9)
                            .padding(.trailing, 10)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityLabel(notifications.isEmpty ? "Mitteilungen" : "Mitteilungen, \(notifications.count) vorhanden")
        .popover(isPresented: $zeigtMitteilungen) {
            PAIANotificationsContent(
                notifications: notifications,
                isLoading: isLoading,
                onDone: { zeigtMitteilungen = false },
                onRefresh: onRefresh
            )
            .frame(width: 380, height: 520)
            .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Spalten

    private var inhalt: some View {
        Group {
            if !loader.isActive {
                if spalten >= 3 {
                    GewichteteSpalten(gewichte: [1.3, 1, 0.95]) {
                        ausgeliehenSpalte
                        vormerkungenSpalte
                        mitteilungenSpalte
                    }
                } else {
                    GewichteteSpalten(gewichte: [1.3, 1]) {
                        ausgeliehenSpalte
                        vormerkungenSpalte
                    }
                }
            }
        }
    }

    private func spaltenkopf(_ titel: LocalizedStringKey, anzahl: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(titel)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            Text("\(anzahl)")
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .accessibilityLabel("\(anzahl)")
        }
    }

    private var ausgeliehenSpalte: some View {
        VStack(alignment: .leading, spacing: 10) {
            spaltenkopf("Ausgeliehen", anzahl: lists.loans.count)
            if lists.loans.isEmpty {
                if !isLoading {
                    leerKarte(
                        titel: "Keine ausgeliehenen Medien",
                        hinweis: "Was du in der Universitätsbibliothek ausleihst, erscheint hier mit Rückgabedatum."
                    )
                }
            } else {
                ForEach(lists.loans) { item in
                    PAIALoanItemRow(
                        item: item,
                        now: now,
                        onRenew: { verlaengern(item) },
                        onOpen: oeffnen(item, ausleihe: true),
                        breit: true
                    )
                }
            }
        }
    }

    private var vormerkungenSpalte: some View {
        VStack(alignment: .leading, spacing: 10) {
            spaltenkopf("Vormerkungen", anzahl: lists.holds.count)
            if lists.holds.isEmpty {
                if !isLoading {
                    leerKarte(
                        titel: "Keine Vormerkungen",
                        hinweis: "Vorgemerkte und bestellte Medien erscheinen hier, bis du sie abholst."
                    )
                }
            } else {
                ForEach(lists.holds) { item in
                    PAIAHoldCard(item: item, onOpen: oeffnen(item, ausleihe: false), breit: true)
                }
            }
        }
    }

    private var mitteilungenSpalte: some View {
        VStack(alignment: .leading, spacing: 10) {
            spaltenkopf("Mitteilungen", anzahl: notifications.count)
            PAIANotificationsSpalte(notifications: notifications, isLoading: isLoading)
        }
    }

    /// Das Details-Blatt öffnet immer, auch ohne Katalog-ID: Dort steht dann „Weitere Angaben gerade nicht abrufbar.“
    private func oeffnen(_ item: PAIALoanItem, ausleihe: Bool) -> () -> Void {
        { detail = BibliothekDetailZiel(item: item, ausleihe: ausleihe) }
    }

    private func verlaengern(_ item: PAIALoanItem) {
        Task {
            if let meldung = await onRenew(item) {
                toast = meldung
                zeigtToast = true
            }
        }
    }

    private func leerKarte(titel: LocalizedStringKey, hinweis: LocalizedStringKey) -> some View {
        Card(verticalPadding: 28, horizontalPadding: 20) {
            VStack(spacing: 6) {
                Text(titel)
                    .font(.headline)
                    .foregroundStyle(Color(.textPrimary))
                Text(hinweis)
                    .foregroundStyle(Color(.textSecondary))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Fehler, Fuß, abgemeldet

    /// Roter Hinweis unter dem Kopf, höchstens 680 breit. Bleibt, bis man ihn schließt oder neu lädt.
    private func fehlerHinweis(_ message: String) -> some View {
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
            Button { errorMessage = nil } label: {
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

    /// Unter den Spalten mittig (höchstens 360 breit): Angemeldet mit …, „Abmelden“.
    private func fuss(username: String?) -> some View {
        VStack(spacing: 10) {
            Text(username.map { "Angemeldet mit \($0). Du bleibst angemeldet, bis du die App beendest." }
                 ?? "Du bleibst angemeldet, bis du die App beendest.")
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            SoftDestructiveButton("Abmelden", action: onLogout)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// Nicht angemeldet oder abgelaufen: Karte mittig (höchstens 440) mit Schloss, Titel und „Anmelden“.
    private func abgemeldetKarte(expired: Bool) -> some View {
        Card(verticalPadding: 32, horizontalPadding: 20) {
            VStack(spacing: 0) {
                Image(systemName: "lock")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color(.textSecondary))
                    .accessibilityHidden(true)
                Text(expired ? "Sitzung abgelaufen" : "Nicht angemeldet")
                    .font(.headline)
                    .foregroundStyle(Color(.textPrimary))
                    .padding(.top, 10)
                Text("Melde dich an, um deine ausgeliehenen Medien zu sehen.")
                    .foregroundStyle(Color(.textSecondary))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.bottom, 18)
                PrimaryButton("Anmelden", action: onLogin)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}
