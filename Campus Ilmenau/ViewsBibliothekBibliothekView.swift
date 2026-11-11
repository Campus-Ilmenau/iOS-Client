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
    /// Wünsche aus Links und von Siri (`campusilmenau://katalog/suche`, `…/katalog/titel/<id>`, `…/bibliothek/merkliste`):
    /// Keiner braucht eine Anmeldung.
    @Environment(AppRouter.self) private var router: AppRouter?
    /// Begriff für die Katalogsuche, wenn Siri sie mit Suchbegriff öffnet (Treffer laden sofort, kein Fokus).
    @State private var katalogSuchbegriff: String?
    @Environment(\.merkliste) private var merkliste
    @State private var showsMerkliste = false
    @State private var openedTitle: LibraryTitleRoute?
    // Die Katalog-API für die Details eines Mediums; Cover-Zwischenspeicher gilt, solange die Seite offen ist.
    @State private var catalogService: LibraryCatalogService
    @State private var coverLoader: LibraryCoverLoader
    @State private var ausweisDaten: BibliotheksausweisDaten?
    @State private var isCheckingBiometrics = false
    @State private var biometrieHinweis: BibliotheksausweisZugang.Hinweis?
    @State private var toastMessage = ""
    @State private var showToast = false

    init() {
        let service = LibraryCatalogService()
        _catalogService = State(initialValue: service)
        _coverLoader = State(initialValue: LibraryCoverLoader(service: service))
    }

    var body: some View {
        screen
            .fullScreenCover(item: $ausweisDaten) { daten in
                BibliotheksausweisView(daten: daten) { grund in
                    ausweisDaten = nil
                    if grund == .zeit {
                        toastMessage = "Ausweis geschlossen"
                        showToast = true
                    }
                }
            }
            .alert(
                biometrieHinweis?.titel ?? "",
                isPresented: Binding(
                    get: { biometrieHinweis != nil },
                    set: { if !$0 { biometrieHinweis = nil } }
                ),
                presenting: biometrieHinweis
            ) { _ in
                Button("OK") {}
            } message: { hinweis in
                Text(hinweis.text)
            }
    }

    private var screen: some View {
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
                katalogSuchbegriff = nil
                showCatalog = true
            },
            onLogin: { showLoginSheet = true },
            onLogout: { service.logout() },
            onRenew: { item in Task { await renew(item) } },
            onRefresh: { await loadData() },
            onOpenTitle: { openedTitle = $0 },
            merklisteCount: merkliste.anzahl,
            onOpenMerkliste: { showsMerkliste = true },
            onShowAusweis: { Task { await zeigeAusweis() } }
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
        .onChange(of: router?.katalogSuche) { _, _ in oeffneZielAufWunsch() }
        .onChange(of: router?.katalogBegriff) { _, _ in oeffneZielAufWunsch() }
        .onChange(of: router?.katalogTitelWunsch) { _, _ in oeffneZielAufWunsch() }
        .onChange(of: router?.merklisteOeffnen) { _, _ in oeffneZielAufWunsch() }
        .onAppear {
            // Ein Link zu Katalog, Titel oder Merkliste geht vor: Nichts davon braucht eine Anmeldung, das Sheet bleibt zu.
            if oeffneZielAufWunsch() { return }
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
                // Ausweisdaten gehören zum Token und werden mit ihm verworfen.
                ausweisDaten = nil
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
                katalogSuchbegriff = nil
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
            // `id`: Kommt ein neuer Begriff von Siri, während die Suche offen ist, entsteht sie neu.
            LibraryCatalogView(autofocus: true, suchbegriff: katalogSuchbegriff)
                .id(katalogSuchbegriff ?? "")
        }
        .sheet(isPresented: $showNotificationsSheet) {
            PAIANotificationsView(service: service)
        }
    }

    /// Öffnet, was ein Link oder Siri wünscht: die Katalogsuche (leer mit Tastatur oder mit Begriff und gleich geladenen
    /// Treffern), einen Titel oder die Merkliste. Gibt zurück, ob etwas geöffnet wurde.
    /// `returningFromCatalog` verhindert, dass beim Zurückkommen das Anmelde-Sheet aufspringt.
    @discardableResult
    private func oeffneZielAufWunsch() -> Bool {
        guard let router else { return false }
        if let begriff = router.katalogBegriff {
            router.katalogBegriff = nil
            beginneVonAussen()
            katalogSuchbegriff = begriff
            showCatalog = true
            return true
        }
        if router.katalogSuche {
            router.katalogSuche = false
            beginneVonAussen()
            katalogSuchbegriff = nil
            showCatalog = true
            return true
        }
        if let id = router.katalogTitelWunsch {
            router.katalogTitelWunsch = nil
            beginneVonAussen()
            openedTitle = LibraryTitleRoute(id: id)
            return true
        }
        if router.merklisteOeffnen {
            router.merklisteOeffnen = false
            beginneVonAussen()
            showsMerkliste = true
            return true
        }
        return false
    }

    /// Ein Ziel von außen braucht keine Anmeldung: Das Sheet bleibt zu, auch nach der Rückkehr.
    private func beginneVonAussen() {
        showLoginSheet = false
        returningFromCatalog = true
    }

    /// Face ID / Touch ID bei jedem Tippen neu, danach Konto frisch laden und den Ausweis öffnen.
    /// Abbruch oder Fehlschlag der Prüfung bleibt ohne Meldung.
    private func zeigeAusweis() async {
        guard !isCheckingBiometrics else { return }
        isCheckingBiometrics = true
        defer { isCheckingBiometrics = false }

        switch await BibliotheksausweisZugang.pruefen() {
        case .erlaubt:
            let letzter = service.patron
            // Schlägt der Abruf fehl, wird der Ausweis trotzdem gezeigt: mit Name und Nummer aus der Sitzung,
            // aber ohne „Gültig bis“, Gruppe und Status.
            let frisch = try? await service.fetchPatron()
            // Lief die Sitzung währenddessen ab (401/403), öffnet sich stattdessen das Login-Sheet.
            if service.isAuthenticated {
                ausweisDaten = BibliotheksausweisDaten(
                    benutzernummer: service.lastUsername ?? "",
                    frisch: frisch,
                    letzter: letzter
                )
            }
        case .hinweis(let hinweis):
            biometrieHinweis = hinweis
        case .abgebrochen:
            break
        }
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
