import Foundation

/// Basis-URL der Campus-Ilmenau-API. Nur sie wechselt zwischen den Umgebungen, die Pfade (`/v1/...`) bleiben gleich.
/// Debug-Builds sprechen den Dev-Stand (Branch `develop`), Release-Builds und TestFlight die Produktion.
/// Für einen Feature-Branch den Slug im Debug-Zweig anpassen, z. B. `.../feat-files-owner-info`.
/// Die Datei gehört zu allen Targets, die die API nutzen.
nonisolated enum APIUmgebung {
    #if DEBUG
    static let baseURL = "https://dev-api.campus-ilmenau.de/develop"
    #else
    static let baseURL = "https://api.campus-ilmenau.de"
    #endif
}
