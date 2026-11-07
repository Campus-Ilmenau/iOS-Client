import SwiftUI

/// Beispieldaten für die Previews: Fälligkeit in Tagen ab heute.
private enum BibliothekSamples {
    static func item(
        _ title: String,
        signature: String? = nil,
        status: PAIAItemStatus = .held,
        days: Int? = nil,
        renewals: Int = 0,
        canRenew: Bool? = true,
        storage: String? = nil,
        queue: Int? = nil,
        comment: String? = nil
    ) -> PAIALoanItem {
        let calendar = Calendar.current
        let end = days.flatMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: .now))?.addingTimeInterval(43_200) }
        return PAIALoanItem(
            item: "sample-\(title)",
            edition: nil,
            about: title,
            label: signature,
            queue: queue,
            renewals: renewals,
            reminder: 0,
            starttime: nil,
            endtime: end,
            cancancel: false,
            canrenew: canRenew,
            storage: storage,
            storageid: nil,
            comment: comment,
            status: status
        )
    }

    /// Überfällig und nicht verlängerbar, ≤ 3 Tage, ≤ 5 Tage, normal.
    static let loans: [PAIALoanItem] = [
        item("Analysis für Ingenieure", signature: "MAT 200 M454", days: 12),
        item("Werkstoffkunde", signature: "WER 120 B379(11)", days: 5),
        item("Grundlagen der Elektrotechnik 1", signature: "ELT 100 S421(3)", days: 2, renewals: 1),
        item("Einführung in die Informatik", signature: "INF 001 G958(2)", days: -2, renewals: 2, canRenew: false)
    ]

    static let longTitle = item(
        "Grundlagen der Elektrotechnik 1: Gleichstromnetzwerke, Wechselstromtechnik und ihre Anwendungen in der modernen Energieversorgung",
        signature: "ELT 100 S421(3)",
        days: 3,
        renewals: 1
    )

    /// Alle fünf Status ohne Laufzeit.
    static let holds: [PAIALoanItem] = [
        item("Regelungstechnik 1", signature: "MSR 300 L971", status: .provided, days: 6, storage: "Ausleihtheke"),
        item("Physik für Ingenieure", signature: "PHY 100 H523(9)", status: .ordered, storage: "Magazin"),
        item("Technische Mechanik 2: Elastostatik", signature: "MEC 210 G795", status: .reserved, queue: 2),
        item("Signale und Systeme", signature: "ELT 330 O68", status: .rejected, comment: "Das Medium ist nicht bestellbar."),
        item("Statistik kompakt", signature: "MAT 400 K55", status: .none)
    ]
}

/// Hält Tab und Fehlerzustand, damit die Previews wie die echte Ansicht reagieren.
private struct BibliothekPreviewHost: View {
    var items: [PAIALoanItem]
    var initialTab: BibliothekScreen.Tab = .loans
    var notificationCount = 2
    var isLoading = false
    @State var errorMessage: String?

    init(
        items: [PAIALoanItem],
        initialTab: BibliothekScreen.Tab = .loans,
        notificationCount: Int = 2,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.items = items
        self.initialTab = initialTab
        self.notificationCount = notificationCount
        self.isLoading = isLoading
        _errorMessage = State(initialValue: errorMessage)
    }

    var body: some View {
        BibliothekScreen(
            session: .signedIn(username: "0001234567"),
            items: items,
            notificationCount: notificationCount,
            isLoading: isLoading,
            errorMessage: $errorMessage,
            initialTab: initialTab,
            onOpenNotifications: {},
            onOpenCatalog: {},
            onLogin: {},
            onLogout: {},
            onRenew: { _ in },
            onRefresh: {},
            merklisteCount: 6
        )
    }
}

private extension BibliothekPreviewHost {
    static var mixed: BibliothekPreviewHost {
        .init(items: BibliothekSamples.loans + BibliothekSamples.holds)
    }
    static var holds: BibliothekPreviewHost {
        .init(items: BibliothekSamples.loans + BibliothekSamples.holds, initialTab: .holds)
    }
    static var emptyLoans: BibliothekPreviewHost {
        .init(items: BibliothekSamples.holds, notificationCount: 0)
    }
    static var emptyHolds: BibliothekPreviewHost {
        .init(items: BibliothekSamples.loans, initialTab: .holds, notificationCount: 0)
    }
    /// Erstes Laden ohne Ausleihen: nach 0,4 s erscheint die Ziege (interaktive Preview).
    static var loading: BibliothekPreviewHost {
        .init(items: [], isLoading: true)
    }
    static var rejected: BibliothekPreviewHost {
        .init(
            items: BibliothekSamples.loans,
            errorMessage: "Verlängerung fehlgeschlagen: Für dieses Medium liegt eine Vormerkung vor."
        )
    }
    static var longTitle: BibliothekPreviewHost {
        .init(items: [BibliothekSamples.longTitle] + BibliothekSamples.loans)
    }
}

// MARK: - Gemischte Ausleihen

#Preview("Ausleihen – Light") { BibliothekPreviewHost.mixed.preferredColorScheme(.light) }
#Preview("Ausleihen – Dark") { BibliothekPreviewHost.mixed.preferredColorScheme(.dark) }
#Preview("Ausleihen – xxxLarge") { BibliothekPreviewHost.mixed.dynamicTypeSize(.xxxLarge) }

// MARK: - Vormerkungen mit allen Status

#Preview("Vormerkungen – Light") { BibliothekPreviewHost.holds.preferredColorScheme(.light) }
#Preview("Vormerkungen – Dark") { BibliothekPreviewHost.holds.preferredColorScheme(.dark) }
#Preview("Vormerkungen – xxxLarge") { BibliothekPreviewHost.holds.dynamicTypeSize(.xxxLarge) }

// MARK: - Leer: Ausleihen

#Preview("Keine Ausleihen – Light") { BibliothekPreviewHost.emptyLoans.preferredColorScheme(.light) }
#Preview("Keine Ausleihen – Dark") { BibliothekPreviewHost.emptyLoans.preferredColorScheme(.dark) }
#Preview("Keine Ausleihen – xxxLarge") { BibliothekPreviewHost.emptyLoans.dynamicTypeSize(.xxxLarge) }

// MARK: - Leer: Vormerkungen

#Preview("Keine Vormerkungen – Light") { BibliothekPreviewHost.emptyHolds.preferredColorScheme(.light) }
#Preview("Keine Vormerkungen – Dark") { BibliothekPreviewHost.emptyHolds.preferredColorScheme(.dark) }
#Preview("Keine Vormerkungen – xxxLarge") { BibliothekPreviewHost.emptyHolds.dynamicTypeSize(.xxxLarge) }

// MARK: - Erstes Laden

#Preview("Lädt – Light") { BibliothekPreviewHost.loading.preferredColorScheme(.light) }
#Preview("Lädt – Dark") { BibliothekPreviewHost.loading.preferredColorScheme(.dark) }

// MARK: - Verlängerung abgelehnt

#Preview("Abgelehnt – Light") { BibliothekPreviewHost.rejected.preferredColorScheme(.light) }
#Preview("Abgelehnt – Dark") { BibliothekPreviewHost.rejected.preferredColorScheme(.dark) }
#Preview("Abgelehnt – xxxLarge") { BibliothekPreviewHost.rejected.dynamicTypeSize(.xxxLarge) }

// MARK: - Sehr langer Titel

#Preview("Langer Titel – Light") { BibliothekPreviewHost.longTitle.preferredColorScheme(.light) }
#Preview("Langer Titel – Dark") { BibliothekPreviewHost.longTitle.preferredColorScheme(.dark) }
#Preview("Langer Titel – xxxLarge") { BibliothekPreviewHost.longTitle.dynamicTypeSize(.xxxLarge) }

// MARK: - Abgemeldet (Kopf mit Katalog-Knopf)

#Preview("Abgemeldet – Kopf – Light") {
    BibliothekScreen(
        session: .signedOut(expired: false),
        items: [],
        notificationCount: 0,
        isLoading: false,
        errorMessage: .constant(nil),
        onOpenNotifications: {},
        onOpenCatalog: {},
        onLogin: {},
        onLogout: {},
        onRenew: { _ in },
        onRefresh: {}
    )
    .preferredColorScheme(.light)
}
