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

    /// Auf dem iPad (kein NFC) öffnet der Intent kein Ziel, sondern sagt, dass es nur auf dem iPhone geht.
    @MainActor
    func perform() async throws -> some IntentResult {
        guard NFCVerfuegbarkeit.vorhanden else { throw ThoskaAuslesenFehler.nurAufDemIPhone }
        DeepLinkEingang.melde(.thoskaAuslesen)
        return .result()
    }
}

/// Der Intent hinter dem Steuerelement „Thoska auslesen“. Er läuft im Hintergrund, ohne `openAppWhenRun`, und
/// entscheidet erst dann: Mit NFC (iPhone) öffnet er die App über den Link `campusilmenau://thoska/auslesen`, wie ein
/// Link aus einem Widget. Ohne NFC (iPad) öffnet er nichts und zeigt nur die Meldung „Das geht nur auf dem iPhone.“
@available(iOS 18.0, *)
struct ThoskaSteuerelementIntent: AppIntent {
    static var title: LocalizedStringResource { "Thoska auslesen" }
    static var description: IntentDescription { "Öffnet Campus Ilmenau und liest deine Thoska." }
    static var isDiscoverable: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        guard NFCVerfuegbarkeit.vorhanden else { throw ThoskaAuslesenFehler.nurAufDemIPhone }
        return .result(opensIntent: OpenURLIntent(DeepLink.thoskaAuslesen.url))
    }
}

/// Siri und Kurzbefehle sprechen bzw. zeigen den Text des Fehlers (wie auf der Apple Watch).
enum ThoskaAuslesenFehler: Error, CustomLocalizedStringResourceConvertible {
    case nurAufDemIPhone

    var localizedStringResource: LocalizedStringResource {
        LocalizedStringResource("Das geht nur auf dem iPhone. Öffne dort Campus Ilmenau.", table: "Siri")
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
