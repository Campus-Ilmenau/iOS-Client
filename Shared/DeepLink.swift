import Foundation

/// Die Links, mit denen Widgets, Steuerelemente und später Siri die App an einer bestimmten Stelle öffnen.
/// Schema `campusilmenau://`, Tabelle in `Uebergabe.md` unter „Deeplinks“.
///
/// | Ziel | URL |
/// |---|---|
/// | Speiseplan einer Mensa | `campusilmenau://mensa?mensa=<id>` |
/// | Gericht | `campusilmenau://mensa/gericht/<id>` (optional `?tag=yyyy-MM-dd`) |
/// | Veranstaltungen „Heute Abend“ | `campusilmenau://events?filter=heute-abend` |
/// | Alle Veranstaltungen | `campusilmenau://events` |
/// | Event-Detail | `campusilmenau://events/<id>` |
/// | Thoska auslesen (NFC-Sheet) | `campusilmenau://thoska/auslesen` |
/// | Katalogsuche mit Fokus | `campusilmenau://katalog/suche` |
///
/// `<id>` der Mensa ist `MensaVenue.rawValue` (z. B. `mensaEhrenberg`). Die Datei gehört zu App und Widget-Extension.
nonisolated enum DeepLink: Equatable, Sendable {
    static let schema = "campusilmenau"

    /// Speiseplan; ohne ID die zuletzt gezeigte Mensa.
    case mensa(id: String?)
    /// Ein Gericht. Die IDs der Mensa-API gelten nur für einen Tag und lassen sich nicht einzeln abfragen,
    /// darum kann der Link den Tag (`yyyy-MM-dd`, Berliner Tag) mitgeben.
    case gericht(id: String, tag: String?)
    /// Die Veranstaltungsliste ohne Filter („Alle“, leeres Widget).
    case events
    case eventsHeuteAbend
    case event(id: String)
    case thoskaAuslesen
    case katalogSuche

    // MARK: Lesen

    /// `nil`, wenn die URL nicht zur App gehört oder kein bekanntes Ziel hat.
    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.schema,
              let komponenten = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let bereich = komponenten.host?.lowercased() else { return nil }
        let pfad = url.pathComponents.filter { $0 != "/" }
        func parameter(_ name: String) -> String? {
            komponenten.queryItems?.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }

        switch bereich {
        case "mensa" where pfad.isEmpty:
            self = .mensa(id: parameter("mensa"))
        case "mensa" where pfad.count == 2 && pfad[0] == "gericht":
            self = .gericht(id: pfad[1], tag: parameter("tag"))
        case "events" where pfad.isEmpty:
            switch parameter("filter") {
            case nil: self = .events
            case "heute-abend": self = .eventsHeuteAbend
            default: return nil
            }
        case "events" where pfad.count == 1:
            self = .event(id: pfad[0])
        case "thoska" where pfad == ["auslesen"]:
            self = .thoskaAuslesen
        case "katalog" where pfad == ["suche"]:
            self = .katalogSuche
        default:
            return nil
        }
    }

    // MARK: Schreiben

    /// Die URL zum Ziel, z. B. für `widgetURL` und `Link` im Widget.
    var url: URL {
        var komponenten = URLComponents()
        komponenten.scheme = Self.schema
        switch self {
        case .mensa(let id):
            komponenten.host = "mensa"
            if let id { komponenten.queryItems = [URLQueryItem(name: "mensa", value: id)] }
        case .gericht(let id, let tag):
            komponenten.host = "mensa"
            komponenten.percentEncodedPath = "/gericht/" + Self.pfadteil(id)
            if let tag { komponenten.queryItems = [URLQueryItem(name: "tag", value: tag)] }
        case .events:
            komponenten.host = "events"
        case .eventsHeuteAbend:
            komponenten.host = "events"
            komponenten.queryItems = [URLQueryItem(name: "filter", value: "heute-abend")]
        case .event(let id):
            komponenten.host = "events"
            komponenten.percentEncodedPath = "/" + Self.pfadteil(id)
        case .thoskaAuslesen:
            komponenten.host = "thoska"
            komponenten.path = "/auslesen"
        case .katalogSuche:
            komponenten.host = "katalog"
            komponenten.path = "/suche"
        }
        // Die Bestandteile sind fest oder kodiert; ein Fehlschlag wäre ein Programmierfehler.
        return komponenten.url ?? URL(fileURLWithPath: "/")
    }

    /// Ein Pfadteil ohne `/` und andere Sonderzeichen.
    private static func pfadteil(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? text
    }
}
