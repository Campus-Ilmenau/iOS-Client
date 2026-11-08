import AppIntents

// Die Intents hinter den Steuerelementen (Kontrollzentrum, Aktionstaste, Sperrbildschirm). Sie sind eigene Typen in App
// und Widget-Extension, damit sie auch als App Shortcuts für Siri taugen. Sie öffnen die App und melden das Ziel am
// `DeepLinkEingang`, also über denselben Weg wie `campusilmenau://…`: keine zweite Navigationslogik.
//
// Hinweis: `OpenIntent` verlangt ein `AppEntity` als Ziel. Die Ziele hier sind feste Stellen der App, darum sind es
// einfache `AppIntent`s mit `openAppWhenRun`.

/// „Thoska auslesen“: öffnet den Tab Thoska und startet sofort das NFC-Sheet (wie `campusilmenau://thoska/auslesen`).
struct ThoskaAuslesenIntent: AppIntent {
    static var title: LocalizedStringResource { "Thoska auslesen" }
    static var description: IntentDescription { "Öffnet Campus Ilmenau und liest deine Thoska." }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkEingang.melde(.thoskaAuslesen)
        return .result()
    }
}

/// „Im Katalog suchen“: öffnet die Katalogsuche der Bibliothek mit Cursor im Suchfeld und offener Tastatur, ohne
/// Anmeldung (wie `campusilmenau://katalog/suche`).
struct KatalogSuchenIntent: AppIntent {
    static var title: LocalizedStringResource { "Im Katalog suchen" }
    static var description: IntentDescription { "Sucht im Katalog der UB Ilmenau." }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkEingang.melde(.katalogSuche)
        return .result()
    }
}
