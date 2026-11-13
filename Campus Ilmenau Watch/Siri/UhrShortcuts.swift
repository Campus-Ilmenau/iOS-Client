import AppIntents

/// „Thoska auslesen“ auf der Uhr: Die Uhr hat kein NFC. Siri sagt nur, dass es auf dem iPhone geht, ohne Ansicht und
/// ohne Guthaben (wie beim HomePod). Der Satz steht in `Siri.xcstrings`. Dieselben Sätze wie `ThoskaAuslesenIntent`; der Intent gibt es nur im Watch-Target.
struct ThoskaHinweisIntent: AppIntent {
    static var title: LocalizedStringResource { LocalizedStringResource("Thoska auslesen", table: "Siri") }
    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("Sagt dir, dass die Thoska nur auf dem iPhone ausgelesen wird.", table: "Siri"))
    }
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(LocalizedStringResource("Das geht nur auf dem iPhone. Öffne dort Campus Ilmenau.", table: "Siri")))
    }
}

/// Die Sätze für Siri auf der Uhr: die fünf Intents von `CampusShortcuts` ohne Katalog (kein `KatalogFragenIntent`, nichts mit
/// Anmeldung) plus der Thoska-Hinweis. Es gibt genau einen Provider je Target; die Sätze stehen wie auf dem iPhone in
/// `AppShortcuts.xcstrings`. Jeder Satz enthält `\(.applicationName)`; als kürzerer Name gilt „Campus“
/// (`INAlternativeAppNames` in der Watch-Info.plist).
struct UhrShortcuts: AppShortcutsProvider {
    /// Nachtblau wie die Marke: Orange (`accent`) ist nie die Farbe von Buttons und Kacheln.
    static var shortcutTileColor: ShortcutTileColor { .navy }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MensaHeuteIntent(),
            phrases: [
                "Was gibt’s heute in der Mensa bei \(.applicationName)?",
                "Was gibt’s zu essen bei \(.applicationName)?",
                "Mensa heute bei \(.applicationName)",
                "Was gibt’s in der \(\.$mensa) bei \(.applicationName)?",
                "Was gibt’s zu essen in der \(\.$mensa) bei \(.applicationName)?",
                "Was gibt’s heute \(\.$ernaehrung) bei \(.applicationName)?",
            ],
            shortTitle: "Mensa heute",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: MensaOffenIntent(),
            phrases: [
                "Hat die Mensa bei \(.applicationName) offen?",
                "Hat die \(\.$mensa) bei \(.applicationName) offen?",
                "Welche Mensa hat bei \(.applicationName) offen?",
            ],
            shortTitle: "Hat die Mensa offen?",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: AbendessenIntent(),
            phrases: [
                "Gibt es heute Abendessen bei \(.applicationName)?",
                "Abendessen bei \(.applicationName)",
            ],
            shortTitle: "Abendessen",
            systemImageName: "fork.knife.circle"
        )
        AppShortcut(
            intent: HeuteAbendIntent(),
            phrases: [
                "Was ist heute Abend los bei \(.applicationName)?",
                "Heute Abend bei \(.applicationName)",
            ],
            shortTitle: "Heute Abend",
            systemImageName: "moon.fill"
        )
        AppShortcut(
            intent: MerklisteIntent(),
            phrases: [
                "Was steht auf meiner Merkliste bei \(.applicationName)?",
                "Merkliste bei \(.applicationName)",
            ],
            shortTitle: "Merkliste",
            systemImageName: "bookmark"
        )
        AppShortcut(
            intent: ThoskaHinweisIntent(),
            phrases: [
                "Lies meine Thoska mit \(.applicationName) aus",
                "Thoska auslesen mit \(.applicationName)",
            ],
            shortTitle: "Thoska auslesen",
            systemImageName: "wave.3.right"
        )
    }
}
