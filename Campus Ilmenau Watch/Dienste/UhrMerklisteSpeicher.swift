import Foundation
import Observation

/// Holt Standort und Signatur frisch über `/v1/library/availability`, in Paketen von höchstens 20 IDs, parallel.
/// Je Titel zählt das erste Exemplar mit `available` bzw. `reference_only` (siehe `UhrRegalStand`).
struct UhrRegalClient {
    static let paketgroesse = 20
    var baseURL = "https://dev-api.campus-ilmenau.de/develop"
    var session: URLSession = .shared

    // Die Antwort der API, nur die Felder, die die Uhr braucht (Schlüssel in snake_case, siehe `APIHilfen.decoder`).
    private struct Antwort: Decodable { let data: [Titel] }
    private struct Titel: Decodable {
        let id: String
        let availabilityStatus: String?
        let items: [Exemplar]?
    }
    private struct Exemplar: Decodable {
        let label: String?
        let location: Ort?
        let status: String?
        let dueDate: Date?
    }
    private struct Ort: Decodable { let name: String? }

    /// Stand je ID. Eine ID, die in der Antwort fehlt, ist „unbekannt“. Scheitert ein Paket, scheitert alles
    /// (die Uhr behält dann den letzten Stand).
    func staende(fuer ids: [String]) async throws -> [String: UhrRegalStand] {
        var gesehen = Set<String>()
        let eindeutig = ids.filter { gesehen.insert($0).inserted }
        let pakete = stride(from: 0, to: eindeutig.count, by: Self.paketgroesse).map {
            Array(eindeutig[$0..<min($0 + Self.paketgroesse, eindeutig.count)])
        }
        var ergebnis: [String: UhrRegalStand] = [:]
        try await withThrowingTaskGroup(of: [String: UhrRegalStand].self) { gruppe in
            for paket in pakete {
                gruppe.addTask { try await self.paket(paket) }
            }
            for try await teil in gruppe { ergebnis.merge(teil) { _, neu in neu } }
        }
        return ergebnis
    }

    private func paket(_ ids: [String]) async throws -> [String: UhrRegalStand] {
        guard let url = APIHilfen.buildURL(
            baseURL: baseURL, path: "/v1/library/availability", queryItems: [URLQueryItem(name: "ids", value: ids.joined(separator: ","))]
        ) else { throw URLError(.badURL) }
        var anfrage = URLRequest(url: url)
        anfrage.setValue("application/json", forHTTPHeaderField: "Accept")
        let (daten, antwort) = try await session.data(for: anfrage)
        guard let http = antwort as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let liste = try APIHilfen.decoder.decode(Antwort.self, from: daten)

        var stand = Dictionary(ids.map { ($0, UhrRegalStand.unbekannt) }, uniquingKeysWith: { erstes, _ in erstes })
        for titel in liste.data {
            let exemplare = (titel.items ?? []).map {
                UhrRegalStand.Exemplar(signatur: $0.label ?? "", standort: $0.location?.name, status: $0.status ?? "", faellig: $0.dueDate)
            }
            stand[titel.id] = UhrRegalStand(gesamtstatus: titel.availabilityStatus, exemplare: exemplare)
        }
        return stand
    }
}

/// Die Merkliste auf der Uhr: eine Kopie der Liste des iPhones, in der Watch-Gruppe gespeichert. Das iPhone hat die
/// Datenhoheit. „Gefunden“ gilt lokal sofort und geht als Änderung `{id, found, changedAt}` an das iPhone, auch ohne
/// Verbindung. Standort und Signatur kommen bei jedem Öffnen frisch.
@MainActor
@Observable
final class UhrMerkliste {
    static let shared = UhrMerkliste()

    /// So lange gilt ein geladener Stand, bevor die Ansicht neu fragt.
    static let frischeDauer: TimeInterval = 5 * 60

    private(set) var eintraege: [UhrMerklisteEintrag]
    private(set) var staende: [String: UhrRegalStand]
    private(set) var laedtStaende = false

    /// Schickt eine Änderung an das iPhone (`UhrVerbindung`).
    @ObservationIgnored var sender: ((UhrAenderung) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let client: UhrRegalClient
    @ObservationIgnored private var letzterStand: Date?

    private enum Schluessel {
        static let eintraege = UhrSpeicher.eintraege
        static let staende = UhrSpeicher.staende
    }

    init(defaults: UserDefaults = AppGroup.defaults, client: UhrRegalClient = UhrRegalClient()) {
        self.defaults = defaults
        self.client = client
        eintraege = (defaults.array(forKey: Schluessel.eintraege) as? [[String: Any]])?
            .compactMap(UhrMerklisteEintrag.init(kontext:)) ?? []
        staende = defaults.data(forKey: Schluessel.staende)
            .flatMap { try? JSONDecoder().decode([String: UhrRegalStand].self, from: $0) } ?? [:]
    }

    /// Für Previews: fester Stand, nichts wird geladen oder gespeichert.
    init(vorschau eintraege: [UhrMerklisteEintrag], staende: [String: UhrRegalStand]) {
        defaults = UserDefaults(suiteName: "uhr-vorschau-\(UUID().uuidString)") ?? .standard
        client = UhrRegalClient()
        self.eintraege = eintraege
        self.staende = staende
        letzterStand = .now
    }

    var anzeige: UhrMerklisteAnzeige {
        UhrMerklisteAnzeige.erstelle(eintraege: eintraege, staende: staende)
    }

    /// Die Liste des iPhones kommt an. Jüngere Aktionen der Uhr, die das iPhone noch nicht kennt, bleiben.
    func uebernimm(vomIPhone liste: [UhrMerklisteEintrag]) {
        let neu = MerklisteAbgleich.verschmelze(iPhone: liste, lokal: eintraege)
        guard neu != eintraege else { return }
        eintraege = neu
        speichern()
        UhrWidgetSync.merklisteGeaendert()
    }

    /// Haken setzen oder zurücknehmen: sofort lokal, dann als Änderung an das iPhone.
    func setzeGefunden(_ gefunden: Bool, fuer id: String, jetzt: Date = .now) {
        guard let index = eintraege.firstIndex(where: { $0.id == id }), eintraege[index].istGefunden != gefunden else { return }
        eintraege[index].foundAt = gefunden ? jetzt : nil
        eintraege[index].changedAt = jetzt
        speichern()
        UhrWidgetSync.merklisteGeaendert()
        sender?(UhrAenderung(id: id, found: gefunden, changedAt: jetzt))
    }

    /// Standort und Signatur frisch laden (Zeitlimit 4 s). Scheitert es, bleibt der letzte Stand.
    func ladeStaende(erzwingen: Bool = false) async {
        guard !laedtStaende, !eintraege.isEmpty else { return }
        if !erzwingen, let letzterStand, Date.now.timeIntervalSince(letzterStand) < Self.frischeDauer { return }
        laedtStaende = true
        defer { laedtStaende = false }
        let ids = eintraege.map(\.id), client = client
        guard let neu = await heuteMitZeitlimit(UhrDaten.zeitlimit, { try await client.staende(fuer: ids) }) else { return }
        staende.merge(neu) { _, neu in neu }
        letzterStand = .now
        defaults.set(try? JSONEncoder().encode(staende), forKey: Schluessel.staende)
        UhrWidgetSync.merklisteGeaendert()
    }

    private func speichern() {
        defaults.set(eintraege.map(\.kontext), forKey: Schluessel.eintraege)
    }
}
