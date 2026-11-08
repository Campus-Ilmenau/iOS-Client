//
//  ContentView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 02.09.26.
//

import SwiftUI

/// Hülle der App: der gewählte Tab und darunter die Tab-Leiste.
struct ContentView: View {
    @State private var router = AppRouter.gemeinsam
    /// Tabs werden erst beim ersten Besuch aufgebaut (sonst lädt jeder Tab schon beim Start) und danach behalten.
    @State private var besuchteTabs: Set<AppTab> = [.heute]
    @State private var tastaturSichtbar = false

    var body: some View {
        @Bindable var router = router
        // Inhalt und Leiste liegen untereinander (kein `safeAreaInset`): Der Inhalt endet über der Leiste, und die
        // Leiste wandert nicht mit der Tastatur nach oben, sondern verschwindet, solange diese sichtbar ist.
        VStack(spacing: 0) {
            ZStack {
                ForEach(AppTab.allCases) { tab in
                    if besuchteTabs.contains(tab) {
                        inhalt(tab)
                            .opacity(tab == router.tab ? 1 : 0)
                            .allowsHitTesting(tab == router.tab)
                            .accessibilityHidden(tab != router.tab)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !tastaturSichtbar {
                TabBar(selection: $router.tab)
            }
        }
        .background(Color(.background))
        .environment(router)
        .onChange(of: router.tab) { _, neu in besuchteTabs.insert(neu) }
        // Stand der Tab schon vor dem ersten Bild fest, braucht er keine Änderung, um aufgebaut zu werden.
        .onAppear { besuchteTabs.insert(router.tab) }
        .task { await beobachteTastatur() }
        // Links aus Widgets und Steuerelementen: Tab wählen, Ziel öffnen.
        .onOpenURL { url in
            guard let link = DeepLink(url: url) else { return }
            router.eingang(link)
        }
    }

    /// Setzt `tastaturSichtbar` nach den Tastatur-Meldungen des Systems. `willShow` kommt vor der Animation,
    /// damit die Leiste nicht erst kurz mit hochfährt.
    private func beobachteTastatur() async {
        await withTaskGroup(of: Void.self) { gruppe in
            gruppe.addTask { @MainActor in
                for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillShowNotification) {
                    tastaturSichtbar = true
                }
            }
            gruppe.addTask { @MainActor in
                for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillHideNotification) {
                    tastaturSichtbar = false
                }
            }
        }
    }

    @ViewBuilder
    private func inhalt(_ tab: AppTab) -> some View {
        switch tab {
        case .heute: HeuteView()
        case .mensa: NavigationStack { MensaView() }
        case .thoska: NavigationStack { ThoskaView() }
        case .bibliothek: NavigationStack { BibliothekView() }
        case .events: EventsView()
        }
    }
}

#Preview {
    ContentView()
}
