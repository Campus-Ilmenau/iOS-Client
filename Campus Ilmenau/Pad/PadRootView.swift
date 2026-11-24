import SwiftUI

/// Hülle für `.regular`-Breite (iPad): `TabView` im Stil `.sidebarAdaptable`. Das System zeichnet die Tab-Leiste oben und
/// die Seitenleiste; hier stehen nur Tabs, Abschnitte und der Kopf der Seitenleiste. Zustand und Wünsche liegen wie
/// auf dem iPhone im `AppRouter`.
struct PadRootView: View {
    @Environment(AppRouter.self) private var router

    /// Legt fest, ob die Seitenleiste beim Start offen ist. `nil` überlässt es dem System (es merkt sich die Wahl der
    /// Person); die Vorschauen setzen es, um beide Zustände zu zeigen.
    private let seitenleisteOffen: Bool?

    init(seitenleisteOffen: Bool? = nil) {
        self.seitenleisteOffen = seitenleisteOffen
    }

    var body: some View {
        TabView(selection: auswahl) {
            Tab("Heute", systemImage: "sun.max", value: PadZiel.heute) {
                TabInhalt(tab: .heute)
            }
            Tab("Mensa", systemImage: "fork.knife", value: PadZiel.mensa) {
                TabInhalt(tab: .mensa)
            }
            // Nur mit NFC: auf dem iPad gibt es keinen Thoska-Tab.
            if NFCVerfuegbarkeit.vorhanden {
                Tab("Thoska", systemImage: "wave.3.right", value: PadZiel.thoska) {
                    TabInhalt(tab: .thoska)
                }
            }

            TabSection("Bibliothek") {
                Tab("Ausleihen", systemImage: "books.vertical", value: PadZiel.ausleihen) { geteilt(.ausleihen) }
                Tab("Katalog", systemImage: "magnifyingglass", value: PadZiel.katalog) { geteilt(.katalog) }
                Tab("Merkliste", systemImage: "bookmark", value: PadZiel.merkliste) { geteilt(.merkliste) }
                Tab("Ausweis", systemImage: "person.text.rectangle", value: PadZiel.ausweis) { geteilt(.ausweis) }
            }
            TabSection("Events") {
                Tab("Alle Veranstaltungen", systemImage: "calendar", value: PadZiel.eventsAlle) { geteilt(.eventsAlle) }
                Tab("Heute Abend", systemImage: "moon", value: PadZiel.eventsAbend) { geteilt(.eventsAbend) }
            }
            TabSection("App") {
                Tab("Mehr & Einstellungen", systemImage: "person.crop.circle", value: PadZiel.mehr) {
                    // Eintrag der Seitenleiste: ohne Zurück. Bei geschlossener Seitenleiste führt „‹ Heute“ zurück.
                    NavigationStack {
                        MehrView(
                            zurueckTitel: router.seitenleisteSichtbar ? nil : LocalizedStringResource("Heute").inAppSprache,
                            onZurueck: { router.waehle(.heute) }
                        )
                    }
                    .tint(Color(.accent))
                }
            }
            // „Mehr“ ist kein Tab oben, nur ein Eintrag der Seitenleiste (und der Personen-Button auf Heute).
            .tabPlacement(.sidebarOnly)
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultAdaptableTabBarPlacement(seitenleisteOffen.map { $0 ? .sidebar : .tabBar } ?? .automatic)
        // Das System füllt die gewählte Zeile der Seitenleiste mit der Tint und schreibt Weiß darauf: Mit `accent` im Dark
        // Mode (#FF8760) wären das nur 2,4 : 1. Solange die Seitenleiste sichtbar ist, gilt darum der Light-Wert von `accent`
        // (#CE3F00, Weiß darauf 4,84 : 1). Die Tab-Leiste oben behält `accent`.
        .tint(router.seitenleisteSichtbar ? Color.accentLightWert : Color(.accent))
        .tabViewSidebarHeader { PadSeitenleistenKopf() }
        .background(Color(.background))
        .onAppear { router.padHuelleAktiv = true }
        .onDisappear { router.padHuelleAktiv = false }
    }

    // MARK: Auswahl

    /// Das gewählte Ziel liegt im Router: Tippen in Tab-Leiste oder Seitenleiste setzt es samt Wunsch, ein Link setzt es
    /// ebenso, und die Auswahl hier folgt ihm.
    private var auswahl: Binding<PadZiel> {
        Binding(get: { router.ziel }, set: { router.waehle($0) })
    }

    /// Die Ansicht eines Tabs für ein Ziel, das sie mit anderen teilt: aufgebaut nur von einem Ziel (siehe
    /// `AppRouter.baueAnsichtAuf`).
    @ViewBuilder
    private func geteilt(_ dieses: PadZiel) -> some View {
        if router.baueAnsichtAuf(fuer: dieses) {
            TabInhalt(tab: dieses.tab)
        } else {
            Color(.background)
        }
    }
}

/// Kopf der Seitenleiste: Bildmarke (Ziege) 22 × 22 pt links neben „Campus Ilmenau“. Orange auf hellem Grund, Weiß auf
/// Nachtblau, wie im CI-Handbuch. Jedes Mal, wenn die Seitenleiste sichtbar wird, trabt die Ziege hinein (`ZiegeEinlauf`);
/// der Schriftzug steht von Anfang an. Nur Deko, für VoiceOver ausgeblendet; der Schriftzug trägt den Namen.
struct PadSeitenleistenKopf: View {
    @Environment(\.colorScheme) private var farbschema
    @Environment(AppRouter.self) private var router: AppRouter?
    /// Wann der Einlauf zuletzt gestartet wurde; `nil`, solange die Seitenleiste nicht sichtbar ist.
    @State private var einlaufStart: Date?

    /// Dasselbe Signal wie für die Tint: Die Ansicht des Tabs meldet über `tabBarPlacement`, dass die Seitenleiste zu sehen
    /// ist. Beim App-Start wartet der Einlauf auf das Ende der Start-Animation. Ohne Router (Vorschau) gilt sie als sichtbar.
    private var seitenleisteSichtbar: Bool {
        guard let router else { return true }
        return router.seitenleisteSichtbar && !router.wartetAufStart
    }

    var body: some View {
        HStack(spacing: 8) {
            ZiegeEinlauf(start: einlaufStart)
                .foregroundStyle(farbschema == .dark ? Color.white : Color(.brandOrange))
            Text("Campus Ilmenau")
                .display(size: 22, relativeTo: .title2)
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Sichtbar geworden: Einlauf von vorn. Zugeklappt: kein Einlauf, ein laufender bricht ab.
        .onChange(of: seitenleisteSichtbar, initial: true) { _, sichtbar in
            einlaufStart = sichtbar ? .now : nil
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension Color {
    /// Der Light-Wert von `accent` (#CE3F00), auch im Dark Mode. Kein eigenes Farb-Asset: Er kommt aus dem vorhandenen.
    static var accentLightWert: Color {
        Color(uiColor: UIColor(resource: .accent).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
    }
}
