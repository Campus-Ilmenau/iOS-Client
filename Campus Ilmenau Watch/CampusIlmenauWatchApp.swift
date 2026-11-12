import SwiftUI

@main
struct CampusIlmenauWatchApp: App {
    @State private var verbindung = UhrVerbindung.shared
    @State private var daten = UhrDaten.shared
    @Environment(\.scenePhase) private var phase

    init() {
        UhrVerbindung.shared.starten()
    }

    var body: some Scene {
        WindowGroup {
            WatchStartView()
                .environment(verbindung)
                .environment(daten)
                // Beim Öffnen und bei jedem Zurückkehren: erst der letzte Stand, dann frisch laden (Zeitlimit 4 s).
                .task(id: phase) {
                    guard phase == .active else { return }
                    verbindung.frageNachMerkliste()
                    async let speiseplan: Void = daten.laden(gemerkteEvents: verbindung.einstellungen.gemerkteEvents)
                    async let regal: Void = verbindung.merkliste.ladeStaende()
                    _ = await (speiseplan, regal)
                }
                .onChange(of: verbindung.einstellungen.gemerkteEvents) { _, neu in
                    daten.uebernimm(gemerkteEvents: neu)
                }
        }
    }
}
