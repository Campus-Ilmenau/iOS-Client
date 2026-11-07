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

    var body: some View {
        ContentView()
            .preferredColorScheme(darstellung.colorScheme)
            .environment(\.merkliste, BibMerklisteStore.shared)
            .launchAnimation(isPresented: $showLaunchAnimation)
    }
}
