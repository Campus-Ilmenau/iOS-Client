//
//  BibliothekView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

/// Verbindet `BibliothekScreen` mit dem `PAIAService`: Sitzung, Sheets, Laden und Verlängern.
struct BibliothekView: View {
    @StateObject private var service = PAIAService.shared
    @State private var showLoginSheet = false
    @State private var showNotificationsSheet = false
    @State private var showCatalog = false
    @State private var returningFromCatalog = false
    /// Wunsch aus dem Link `campusilmenau://katalog/suche`: Katalogsuche mit offener Tastatur, ohne Anmeldung.
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(\.merkliste) private var merkliste
    @State private var showsMerkliste = false
    @State private var openedTitle: LibraryTitleRoute?
    // Die Katalog-API für die Details eines Mediums; Cover-Zwischenspeicher gilt, solange die Seite offen ist.
    @State private var catalogService: LibraryCatalogService
    @State private var coverLoader: LibraryCoverLoader
    @State private var toastMessage = ""
    @State private var showToast = false

    init() {
        let service = LibraryCatalogService()
        _catalogService = State(initialValue: service)
        _coverLoader = State(initialValue: LibraryCoverLoader(service: service))
    }

    var body: some View {
        BibliothekScreen(
            session: service.isAuthenticated
                ? .signedIn(username: service.lastUsername)
                : .signedOut(expired: service.sessionExpired),
            items: service.items,
            notificationCount: service.notifications.count,
            isLoading: service.isLoading,
            errorMessage: Binding(
                get: { service.errorMessage },
                set: { service.errorMessage = $0 }
            ),
            onOpenNotifications: { showNotificationsSheet = true },
            onOpenCatalog: {
                returningFromCatalog = true
                showCatalog = true
            },
            onLogin: { showLoginSheet = true },
            onLogout: { service.logout() },
            onRenew: { item in Task { await renew(item) } },
            onRefresh: { await loadData() },
            onOpenTitle: { openedTitle = $0 },
            merklisteCount: merkliste.anzahl,
            onOpenMerkliste: { showsMerkliste = true }
        )
        // Die Navigationsleiste bleibt vorerst für den Zurück-Pfeil, bis die TabBar die Navigation übernimmt.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toast(LocalizedStringKey(toastMessage), isPresented: $showToast)
        .task(id: service.isAuthenticated) {
            if service.isAuthenticated {
                await loadData()
            }
        }
        .onChange(of: router?.katalogSuche) { _, _ in oeffneKatalogAufWunsch() }
        .onAppear {
            // Ein Link zur Katalogsuche geht vor: Die Suche braucht keine Anmeldung, das Sheet bleibt zu.
            if oeffneKatalogAufWunsch() { return }
            // Nach der Rückkehr aus dem Katalog soll das Sheet nicht erneut aufspringen.
            if returningFromCatalog {
                returningFromCatalog = false
                return
            }
            if !service.isAuthenticated {
                showLoginSheet = true
            }
        }
        .onChange(of: service.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                showLoginSheet = true
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            PAIALoginSheet(service: service, onSuccess: {
                showLoginSheet = false
                Task { await loadData() }
            }, onOpenCatalog: {
                showLoginSheet = false
                returningFromCatalog = true
                showCatalog = true
            })
        }
        .navigationDestination(isPresented: $showsMerkliste) {
            BibMerklisteView(service: catalogService, coverLoader: coverLoader)
        }
        .navigationDestination(item: $openedTitle) { route in
            LibraryTitleView(
                media: route.media,
                searchId: nil,
                service: catalogService,
                coverLoader: coverLoader,
                origin: .library
            )
        }
        .navigationDestination(isPresented: $showCatalog) {
            LibraryCatalogView(autofocus: true)
        }
        .sheet(isPresented: $showNotificationsSheet) {
            PAIANotificationsView(service: service)
        }
    }

    /// Öffnet die Katalogsuche, wenn ein Link es wünscht. Gibt zurück, ob sie geöffnet wurde.
    /// `returningFromCatalog` verhindert, dass beim Zurückkommen das Anmelde-Sheet aufspringt.
    @discardableResult
    private func oeffneKatalogAufWunsch() -> Bool {
        guard router?.katalogSuche == true else { return false }
        router?.katalogSuche = false
        showLoginSheet = false
        returningFromCatalog = true
        showCatalog = true
        return true
    }

    private func loadData() async {
        try? await service.fetchItems()
        try? await service.fetchNotifications()
    }

    /// Verlängert nach der Rückfrage der Karte. Bei Erfolg Toast mit dem neuen Datum, bei Ablehnung
    /// setzt der Service `errorMessage` („Verlängerung fehlgeschlagen: …“), die der Fehlerkasten zeigt.
    private func renew(_ item: PAIALoanItem) async {
        let oldEnd = item.endtime
        do {
            try await service.renew(item)
        } catch {
            return
        }
        service.errorMessage = nil
        let newEnd = service.items.first { $0.item == item.item }?.endtime
        if let newEnd, newEnd != oldEnd {
            toastMessage = "Verlängert bis \(BibliothekFormat.shortDate(newEnd))"
        } else {
            toastMessage = "Verlängert"
        }
        showToast = true
    }
}

#Preview {
    NavigationStack {
        BibliothekView()
    }
}
