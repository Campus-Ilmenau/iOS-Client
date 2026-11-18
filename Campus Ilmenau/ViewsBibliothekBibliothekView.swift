//
//  BibliothekView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI
import UIKit

/// Verbindet `BibliothekScreen` mit dem `PAIAService`: Sitzung, Sheets, Laden und Verlängern.
struct BibliothekView: View {
    @StateObject private var service = PAIAService.shared
    @State private var showLoginSheet = false
    @State private var showNotificationsSheet = false
    @State private var showCatalog = false
    /// Der Katalog öffnet mit Cursor im Suchfeld, außer aus der Seitenleiste des iPads: Dort bleibt die Tastatur zu.
    @State private var katalogAutofokus = true
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
    /// iPad: Suche und Auswahl des Katalogs liegen im Router (sie überleben den Wechsel der Seitenleiste); ohne Router
    /// (Vorschau) hier.
    @State private var lokalesKatalogModell = LibrarySearchModel()
    @State private var lokalerPadZustand = KatalogPadZustand()
    /// iPad: Der Cursor soll ins Suchfeld des Katalogs (⌘F, „Im Katalog suchen“, Link); der Katalog setzt es zurück.
    @State private var padKatalogFokus = false

    init() {
        let service = LibraryCatalogService()
        _catalogService = State(initialValue: service)
        _coverLoader = State(initialValue: LibraryCoverLoader(service: service))
    }

    var body: some View {
        // Die Breite der Ansicht entscheidet (siehe `PadRaster`): unter 700 pt die iPhone-Ansicht mit Segment und Glocke,
        // darüber Spalten.
        PadRasterMessung { raster in
            seite(raster)
        }
        .sheet(isPresented: $showLoginSheet) {
            PAIALoginSheet(service: service, onSuccess: {
                showLoginSheet = false
                Task { await loadData() }
            }, onOpenCatalog: {
                showLoginSheet = false
                returningFromCatalog = true
                katalogSuchbegriff = nil
                katalogAutofokus = true
                showCatalog = true
            })
            // iPad: Form Sheet (ca. 540 breit), auf dem iPhone unverändert.
            .formularBlatt(pad: UIDevice.current.userInterfaceIdiom == .pad)
        }
    }

    private func seite(_ raster: PadRaster) -> some View {
        let pad = raster.bibliothekSpalten > 1
        return screen(raster)
            .fullScreenCover(item: Binding(get: { pad ? nil : ausweisDaten }, set: { ausweisDaten = $0 })) { daten in
                BibliotheksausweisView(daten: daten) { grund in
                    ausweisDaten = nil
                    if grund == .zeit {
                        toastMessage = "Ausweis geschlossen"
                        showToast = true
                    }
                }
            }
            // iPad: der Ausweis als Form Sheet mittig, Inhalt und 2-Minuten-Regel wie auf dem iPhone.
            .sheet(item: Binding(get: { pad ? ausweisDaten : nil }, set: { ausweisDaten = $0 })) { daten in
                BibliotheksausweisView(daten: daten) { grund in
                    ausweisDaten = nil
                    if grund == .zeit {
                        toastMessage = "Ausweis geschlossen"
                        showToast = true
                    }
                }
                .formularBlatt(pad: true)
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

    private var telefonScreen: some View {
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
                katalogAutofokus = true
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
    }

    private func padScreen(_ raster: PadRaster) -> some View {
        BibliothekPadScreen(
            session: service.isAuthenticated
                ? .signedIn(username: service.lastUsername)
                : .signedOut(expired: service.sessionExpired),
            items: service.items,
            notifications: service.notifications,
            isLoading: service.isLoading,
            errorMessage: Binding(
                get: { service.errorMessage },
                set: { service.errorMessage = $0 }
            ),
            spalten: raster.bibliothekSpalten,
            onOpenCatalog: {
                // Auf dem iPad ist der Katalog ein Ziel der Seitenleiste: mit Cursor im Suchfeld (wie ⌘F).
                if let router, router.padHuelleAktiv {
                    router.zeigeKatalogSuche()
                } else {
                    returningFromCatalog = true
                    katalogSuchbegriff = nil
                    katalogAutofokus = true
                    showCatalog = true
                }
            },
            onLogin: { showLoginSheet = true },
            onLogout: { service.logout() },
            onRenew: { item in await renewMitMeldung(item) },
            onRefresh: { await loadData() },
            merklisteCount: merkliste.anzahl,
            onOpenMerkliste: { showsMerkliste = true },
            onShowAusweis: { Task { await zeigeAusweis() } },
            catalogService: catalogService,
            coverLoader: coverLoader
        )
    }

    /// Was auf dem iPad die ganze Seite füllt, statt im Stapel zu liegen: Katalog und Merkliste, wenn sie ein Ziel der
    /// offenen Seitenleiste sind (dann ohne Zurück). Bei geschlossener Seitenleiste liegen sie im Stapel des Tabs.
    private enum PadWurzel { case katalog, merkliste }

    /// Ohne die Breite der Ansicht zu fragen: Ist der Katalog gerade als Stapel darübergelegt, misst diese Ansicht darunter
    /// nichts mehr. Die iPad-Hülle (nur bei regulärer Breite) genügt.
    private func padWurzel() -> PadWurzel? {
        guard let router, router.padHuelleAktiv, router.seitenleisteSichtbar else { return nil }
        switch router.ziel {
        case .katalog: return .katalog
        case .merkliste: return .merkliste
        default: return nil
        }
    }

    private var padKatalogModell: LibrarySearchModel { router?.katalogModell ?? lokalesKatalogModell }

    private var padZustand: Binding<KatalogPadZustand> {
        Binding(
            get: { router?.katalogPadZustand ?? lokalerPadZustand },
            set: { neu in
                if let router { router.katalogPadZustand = neu } else { lokalerPadZustand = neu }
            }
        )
    }

    /// Der Katalog, im Stapel (`zurueckTitel`) oder als Ziel der Seitenleiste. Die Breite misst die Oberfläche selbst (siehe
    /// `padWurzel`): Auf dem iPad stehen Treffer und Titel nebeneinander, darunter gilt die iPhone-Ansicht.
    private func katalogOberflaeche(zurueckTitel: String?) -> some View {
        PadRasterMessung { raster in
            if raster.istPad {
                padKatalog(raster, zurueckTitel: zurueckTitel)
            } else {
                // `id`: Kommt ein neuer Begriff von Siri, während die Suche offen ist, entsteht sie neu.
                LibraryCatalogView(autofocus: katalogAutofokus, suchbegriff: katalogSuchbegriff)
                    .id(katalogSuchbegriff ?? "")
            }
        }
    }

    /// Der Katalog der iPad-Anordnung; im Stapel (`zurueckTitel`) mit „‹ Bibliothek“, als Ziel der Seitenleiste ohne.
    private func padKatalog(_ raster: PadRaster, zurueckTitel: String?) -> some View {
        KatalogPadAnsicht(
            model: padKatalogModell,
            zustand: padZustand,
            raster: raster,
            zurueckTitel: zurueckTitel,
            fokusAnfrage: $padKatalogFokus,
            onMerkliste: { router?.waehle(.merkliste) }
        )
    }

    private func screen(_ raster: PadRaster) -> some View {
        let wurzel = padWurzel()
        return Group {
            switch wurzel {
            case .katalog:
                katalogOberflaeche(zurueckTitel: nil)
            case .merkliste:
                BibMerklisteView(service: catalogService, coverLoader: coverLoader, mitZurueck: false)
            case nil:
                if raster.bibliothekSpalten > 1 {
                    padScreen(raster)
                } else {
                    telefonScreen
                }
            }
        }
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
        .onChange(of: router?.katalogOeffnen) { _, _ in oeffneZielAufWunsch() }
        .onChange(of: router?.katalogBegriff) { _, _ in oeffneZielAufWunsch() }
        .onChange(of: router?.katalogTitelWunsch) { _, _ in oeffneZielAufWunsch() }
        .onChange(of: router?.merklisteOeffnen) { _, _ in oeffneZielAufWunsch() }
        .onChange(of: router?.ausweisWunsch) { _, _ in oeffneZielAufWunsch() }
        .onAppear {
            // Wartet ein Wunsch auf diese neue Ansicht (iPad, Wechsel in der Seitenleiste), kommt er jetzt an.
            router?.ansichtErschienen(.bibliothek)
            // Ein Link zu Katalog, Titel oder Merkliste geht vor: Nichts davon braucht eine Anmeldung, das Sheet bleibt zu.
            if oeffneZielAufWunsch() { return }
            // Der Wunsch ist unterwegs (Seitenleiste, Link): Das Sheet bleibt zu, bis er da ist.
            if router?.wunschUnterwegs == true { return }
            // Nach der Rückkehr aus dem Katalog soll das Sheet nicht erneut aufspringen.
            if returningFromCatalog {
                returningFromCatalog = false
                return
            }
            // Katalog und Merkliste als Ziel der Seitenleiste brauchen keine Anmeldung.
            if router?.padHuelleAktiv == true, router?.ziel == .katalog || router?.ziel == .merkliste { return }
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
        .navigationDestination(isPresented: Binding(
            get: { showsMerkliste && wurzel != .merkliste },
            set: { showsMerkliste = $0 }
        )) {
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
        .navigationDestination(isPresented: Binding(
            get: { showCatalog && wurzel != .katalog },
            set: { showCatalog = $0 }
        )) {
            katalogOberflaeche(zurueckTitel: "Bibliothek")
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
            katalogAutofokus = true
            showCatalog = true
            // iPad: Der Begriff steht im Feld, die Treffer laden ohne Cursor.
            if router.padHuelleAktiv { router.katalogModell.sucheVonAussen(begriff) }
            return true
        }
        if router.katalogSuche {
            router.katalogSuche = false
            beginneVonAussen()
            katalogSuchbegriff = nil
            katalogAutofokus = true
            showCatalog = true
            padKatalogFokus = true
            return true
        }
        if router.katalogOeffnen {
            router.katalogOeffnen = false
            beginneVonAussen()
            katalogSuchbegriff = nil
            katalogAutofokus = false
            showCatalog = true
            return true
        }
        if let id = router.katalogTitelWunsch {
            router.katalogTitelWunsch = nil
            beginneVonAussen()
            if router.padHuelleAktiv {
                // iPad: Der Titel steht rechts neben den Treffern; die Liste markiert ihn, falls er darin vorkommt.
                let treffer = router.katalogModell.sections.flatMap(\.items)
                router.katalogPadZustand.waehleVonAussen(LibraryTitleRoute(id: id).media, treffer: treffer)
                showCatalog = true
            } else {
                openedTitle = LibraryTitleRoute(id: id)
            }
            return true
        }
        if router.merklisteOeffnen {
            router.merklisteOeffnen = false
            beginneVonAussen()
            showsMerkliste = true
            return true
        }
        if router.ausweisWunsch {
            // Seitenleiste „Ausweis“: startet direkt die Systemabfrage; ohne Anmeldung kommt stattdessen das Login.
            router.ausweisWunsch = false
            if service.isAuthenticated {
                beginneVonAussen()
                Task { await zeigeAusweis() }
            } else {
                showLoginSheet = true
            }
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
        if let meldung = await renewMitMeldung(item) {
            toastMessage = meldung
            showToast = true
        }
    }

    /// Wie `renew`, liefert aber den Text des Toasts (`nil` bei einem Fehler), damit auch das Details-Blatt des iPads
    /// seinen eigenen Toast zeigen kann.
    private func renewMitMeldung(_ item: PAIALoanItem) async -> String? {
        let oldEnd = item.endtime
        do {
            try await service.renew(item)
        } catch {
            return nil
        }
        service.errorMessage = nil
        let newEnd = service.items.first { $0.item == item.item }?.endtime
        if let newEnd, newEnd != oldEnd {
            return "Verlängert bis \(BibliothekFormat.shortDate(newEnd))"
        }
        return "Verlängert"
    }
}

#Preview {
    NavigationStack {
        BibliothekView()
    }
}
