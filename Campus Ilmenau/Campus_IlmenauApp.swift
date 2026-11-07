//
//  Campus_IlmenauApp.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 02.09.26.
//

import SwiftUI
import SwiftData

@main
struct Campus_IlmenauApp: App {
    init() {
        // „Mensa auf der Startseite“ und Preisgruppe liegen in der App Group. Bisherige Werte kommen einmalig mit.
        AppGroup.uebernimmEinstellungenEinmalig()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [ThoskaBalanceRecord.self, ThoskaCardName.self])
    }
}

private struct RootView: View {
    @State private var showLaunchAnimation = true
    /// Einstellung „Darstellung“ unter „Mehr“.
    @AppStorage(AppDarstellung.schluessel) private var darstellung = AppDarstellung.system
    /// Beides liest auch das Mensa-Widget. Ändert sich eins (hier, in „Mehr“ oder durch den Knopf im Widget),
    /// laden die Mensa-Widgets neu.
    @AppStorage(AppGroup.heuteMensaSchluessel, store: AppGroup.defaults) private var heuteMensa = MensaVenue.mensaEhrenberg
    @AppStorage(AppGroup.preisgruppeSchluessel, store: AppGroup.defaults) private var preisgruppe = MensaPriceGroup.studierende

    var body: some View {
        ContentView()
            .preferredColorScheme(darstellung.colorScheme)
            .environment(\.merkliste, BibMerklisteStore.shared)
            .launchAnimation(isPresented: $showLaunchAnimation)
            .onChange(of: heuteMensa) { _, _ in WidgetSync.shared.einstellungenGeaendert() }
            .onChange(of: preisgruppe) { _, _ in WidgetSync.shared.einstellungenGeaendert() }
    }
}
