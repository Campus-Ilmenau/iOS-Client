//
//  Campus_IlmenauApp.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 02.09.26.
//

import SwiftUI
import SwiftData
import WidgetKit

@main
struct Campus_IlmenauApp: App {
    init() {
        // „Mensa auf der Startseite“ und Preisgruppe liegen in der App Group. Bisherige Werte kommen einmalig mit.
        AppGroup.uebernimmEinstellungenEinmalig()
        // Intents (Steuerelemente) erreichen die Navigation über denselben Router wie die Deeplinks.
        AppRouter.gemeinsam.verbinden()
        #if DEBUG
        Self.uebernimmWidgetFotoArgumente()
        #endif
    }

    #if DEBUG
    /// Für Website-Bilder: `-WidgetUhr 11:45` (oder `aus`) stellt die Uhr der Widgets, `-WidgetFilter vegan|bio|aus`
    /// den Mensa-Filter der App. Danach laden alle Widgets neu. Nur in Debug-Builds.
    private static func uebernimmWidgetFotoArgumente() {
        let argumente = UserDefaults.standard
        var geaendert = false
        if let uhr = argumente.string(forKey: "WidgetUhr") {
            if uhr == "aus" { AppGroup.defaults.removeObject(forKey: WidgetUhr.schluessel) } else { AppGroup.defaults.set(uhr, forKey: WidgetUhr.schluessel) }
            geaendert = true
        }
        if let filter = argumente.string(forKey: "WidgetFilter") {
            switch filter {
            case "vegan": MensaFilterStore.save(MensaFilter(diet: .vegan))
            case "vegetarisch": MensaFilterStore.save(MensaFilter(diet: .vegetarisch))
            case "bio": MensaFilterStore.save(MensaFilter(onlyBio: true))
            default: MensaFilterStore.save(MensaFilter())
            }
            geaendert = true
        }
        if geaendert { WidgetCenter.shared.reloadAllTimelines() }
    }
    #endif

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
            // Ein Ziel von außen, das beim Kaltstart eintraf, wartet bis hierher: erst Start-Animation, dann Ziel.
            .onChange(of: showLaunchAnimation) { _, laeuft in if !laeuft { AppRouter.gemeinsam.startBeendet() } }
            .onChange(of: heuteMensa) { _, _ in WidgetSync.shared.einstellungenGeaendert() }
            .onChange(of: preisgruppe) { _, _ in WidgetSync.shared.einstellungenGeaendert() }
    }
}
