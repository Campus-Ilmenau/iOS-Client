//
//  ContentView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 02.09.26.
//

import SwiftUI

/// Die Wurzel der App: wählt je nach Gerät und Breite die Hülle. iPhone, schmaler Split View und Slide Over (`.compact`)
/// bekommen die eigene Tab-Leiste unten (`PhoneHuelle`), das iPad bei `.regular` die Hülle mit Tab-Leiste oben und
/// Seitenleiste (`PadRootView`). Der Zustand liegt im `AppRouter`, den beide teilen; Deeplinks und Handoff laufen hier, damit sie in
/// beiden Hüllen ankommen und beim Wechsel der Breite nichts verloren geht.
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var breite
    @State private var router = AppRouter.gemeinsam
    #if DEBUG
    /// Nur Debug: Der Link `campusilmenau://debug-kompakt` schaltet die schmale Breite (Split View) an und aus. Der
    /// Simulator kann Split View nicht per Skript öffnen; so lässt sich der Wechsel der Hülle zur Laufzeit prüfen.
    @State private var erzwingtKompakt = false
    #endif

    /// Die iPad-Hülle nur auf dem iPad und bei `.regular`-Breite. Ein iPhone Max im Querformat ist auch `.regular`,
    /// bleibt aber in der iPhone-Hülle.
    static func nutztPadHuelle(breite: UserInterfaceSizeClass?, geraet: UIUserInterfaceIdiom) -> Bool {
        geraet == .pad && breite == .regular
    }

    private var wirksameBreite: UserInterfaceSizeClass? {
        #if DEBUG
        if erzwingtKompakt { return .compact }
        #endif
        return breite
    }

    var body: some View {
        Group {
            if Self.nutztPadHuelle(breite: wirksameBreite, geraet: UIDevice.current.userInterfaceIdiom) {
                PadRootView()
            } else {
                PhoneHuelle()
            }
        }
        .environment(router)
        // Links aus Widgets und Steuerelementen: Tab wählen, Ziel öffnen.
        .onOpenURL { url in
            #if DEBUG
            if url.host() == "debug-kompakt" { erzwingtKompakt.toggle(); return }
            #endif
            guard let link = DeepLink(url: url) else { return }
            router.eingang(link)
        }
        // „Auf iPhone öffnen“ von der Apple Watch (Handoff): derselbe Weg wie ein Deeplink.
        .onContinueUserActivity(UhrHandoff.eventTyp) { aktivitaet in
            guard let text = aktivitaet.userInfo?[UhrHandoff.urlSchluessel] as? String,
                  let url = URL(string: text), let link = DeepLink(url: url) else { return }
            router.eingang(link)
        }
    }
}

extension EnvironmentValues {
    /// Vorschauen der Hüllen zeigen statt der Ansichten einen Platzhalter: Die Ansichten laden Daten und brauchen länger,
    /// als eine Vorschau Zeit bekommt. Nur dort gesetzt.
    @Entry var tabInhaltAlsPlatzhalter = false
}

/// Der Inhalt eines Tabs, in beiden Hüllen derselbe.
struct TabInhalt: View {
    let tab: AppTab
    @Environment(\.tabInhaltAlsPlatzhalter) private var alsPlatzhalter
    @Environment(AppRouter.self) private var router: AppRouter?
    /// Wo das System die Tabs zeigt: oben, unten oder als Seitenleiste.
    @Environment(\.tabBarPlacement) private var platzierung

    var body: some View {
        inhalt
            // Die Hülle tönt die Seitenleiste dunkler (Kontrast der Auswahl). Der Inhalt behält `accent`: Links, Kicker
            // und Pfeile bleiben im Dark Mode #FF8760.
            .tint(Color(.accent))
            .onChange(of: platzierung, initial: true) { _, neu in
                router?.seitenleisteSichtbar = (neu == .sidebar)
            }
    }

    @ViewBuilder
    private var inhalt: some View {
        if alsPlatzhalter {
            VStack(spacing: 8) {
                Text(tab.title).display(size: 38, relativeTo: .largeTitle)
                Text("Inhalt des Tabs").foregroundStyle(Color(.textSecondary))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.background))
        } else {
            switch tab {
            case .heute: HeuteView()
            case .mensa: NavigationStack { MensaView() }
            case .thoska: NavigationStack { ThoskaView() }
            case .bibliothek: NavigationStack { BibliothekView() }
            // Das Modell liegt im Router: Wechselt die Hülle, bleiben Tag, Filter und geladene Daten.
            case .events: EventsView(model: router?.eventsModel)
            }
        }
    }
}

/// Hülle für `.compact`-Breite: der gewählte Tab und darunter die Tab-Leiste.
struct PhoneHuelle: View {
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
                ForEach(AppTab.sichtbar) { tab in
                    if besuchteTabs.contains(tab) {
                        TabInhalt(tab: tab)
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
        .onChange(of: router.tab) { _, neu in besuchteTabs.insert(neu) }
        // Stand der Tab schon vor dem ersten Bild fest, braucht er keine Änderung, um aufgebaut zu werden.
        .onAppear { besuchteTabs.insert(router.tab) }
        .task { await beobachteTastatur() }
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
}

#Preview {
    ContentView()
}
