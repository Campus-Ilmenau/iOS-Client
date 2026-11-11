import AppIntents

/// Öffnet die App an einem Ziel (`campusilmenau://…`). Das ist das Tippziel auf den Karten der Siri-Antworten:
/// `Button(intent: OeffneZielIntent(url:))`. Er meldet das Ziel am `DeepLinkEingang`, also auf demselben Weg wie
/// Deeplinks und Steuerelemente. Er erscheint weder in Kurzbefehle noch in Spotlight.
struct OeffneZielIntent: AppIntent {
    static var title: LocalizedStringResource { LocalizedStringResource("Ziel öffnen", table: "Siri") }
    static var openAppWhenRun: Bool { true }
    static var isDiscoverable: Bool { false }

    @Parameter(title: LocalizedStringResource("Link", table: "Siri"))
    var url: URL

    init() {}

    init(url: URL) {
        self.url = url
    }

    init(link: DeepLink) {
        self.url = link.url
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let link = DeepLink(url: url) else { throw OeffneZielFehler.unbekanntesZiel }
        DeepLinkEingang.melde(link)
        return .result()
    }
}

enum OeffneZielFehler: Error, CustomLocalizedStringResourceConvertible {
    case unbekanntesZiel

    var localizedStringResource: LocalizedStringResource {
        LocalizedStringResource("Dieses Ziel kenne ich nicht.", table: "Siri")
    }
}
