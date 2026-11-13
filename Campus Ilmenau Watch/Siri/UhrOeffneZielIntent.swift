import AppIntents

/// „In der App öffnen“ unter einer Siri-Antwort auf der Uhr: öffnet die Watch-App an einem Ziel (`campusilmenau://…`,
/// bei einer anderen als der gewählten Mensa mit `waehlen=1`). Er meldet das Ziel am `UhrEingang`. Der gemeinsame
/// `OeffneZielIntent` aus `Shared/` reicht nur ein `DeepLink` weiter und kennt `waehlen=1` nicht.
/// Er erscheint weder in Kurzbefehle noch in Spotlight.
struct UhrOeffneZielIntent: AppIntent {
    static var title: LocalizedStringResource { LocalizedStringResource("Ziel öffnen", table: "Siri") }
    static var openAppWhenRun: Bool { true }
    static var isDiscoverable: Bool { false }

    @Parameter(title: LocalizedStringResource("Link", table: "Siri"))
    var url: URL

    init() {}

    init(url: URL) {
        self.url = url
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard DeepLink(url: url) != nil else { throw OeffneZielFehler.unbekanntesZiel }
        UhrEingang.melde(url)
        return .result()
    }
}
