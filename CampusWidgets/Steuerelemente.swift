import SwiftUI
import WidgetKit
import AppIntents

// Steuerelemente (iOS 18): zwei Knöpfe für das Kontrollzentrum, die Aktionstaste und die zwei Felder unten auf dem
// Sperrbildschirm. Das System zeichnet sie selbst; geliefert werden nur Symbol, Titel und Intent. Keine eigene Tönung
// (Accent nie für Buttons) und kein Betrag: Das Guthaben würde veralten.

/// „Thoska auslesen“. Das Symbol ist das des Tabs.
@available(iOS 18.0, *)
struct ThoskaSteuerelement: ControlWidget {
    static let kind = "de.kai-gothe.Campus-Ilmenau.control.thoska"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ThoskaAuslesenIntent()) {
                Label("Thoska auslesen", systemImage: "wave.3.right")
            }
        }
        .displayName("Thoska auslesen")
        .description("Öffnet Campus Ilmenau und liest deine Thoska.")
    }
}

/// „Im Katalog suchen“.
@available(iOS 18.0, *)
struct KatalogSteuerelement: ControlWidget {
    static let kind = "de.kai-gothe.Campus-Ilmenau.control.katalog"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: KatalogSuchenIntent()) {
                Label("Im Katalog suchen", systemImage: "text.magnifyingglass")
            }
        }
        .displayName("Im Katalog suchen")
        .description("Sucht im Katalog der UB Ilmenau.")
    }
}
