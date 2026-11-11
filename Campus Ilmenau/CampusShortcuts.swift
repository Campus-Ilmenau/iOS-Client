import AppIntents

/// Die Sätze für Siri, ohne Einrichtung nach der Installation. Reihenfolge, kurze Titel und Symbole wie in
/// `Uebergabe.md` („Kurzbefehle-App, Spotlight, Tipps“); die Kachel ist nachtblau, nicht orange. Es gibt genau einen Provider, in der App. Jeder Satz
/// enthält `\(.applicationName)`; als kürzerer Name gilt „Campus“ (`INAlternativeAppNames` in der Info.plist).
/// Die Sätze stehen in `AppShortcuts.xcstrings`. Erlaubt sind höchstens 10 App Shortcuts, genutzt werden am Ende 7.
/// Ein Satz darf nur Parameter vom Typ `AppEnum`/`AppEntity` enthalten (`MensaOrt`, `Ernaehrung`), und zwar höchstens
/// einen: „Was gibt’s vegetarisch in der Nanoteria …“ mit beiden Parametern lässt der Build nicht zu.
struct CampusShortcuts: AppShortcutsProvider {
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
            intent: KatalogFragenIntent(),
            phrases: [
                "Suche im Katalog von \(.applicationName)",
                "Such ein Buch mit \(.applicationName)",
            ],
            shortTitle: "Im Katalog suchen",
            systemImageName: "text.magnifyingglass"
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
            intent: ThoskaAuslesenIntent(),
            phrases: [
                "Lies meine Thoska mit \(.applicationName) aus",
                "Thoska auslesen mit \(.applicationName)",
            ],
            shortTitle: "Thoska auslesen",
            systemImageName: "wave.3.right"
        )
    }
}
