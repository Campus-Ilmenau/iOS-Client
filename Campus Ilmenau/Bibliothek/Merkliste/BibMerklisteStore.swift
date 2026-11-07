import SwiftUI
import Observation

/// Ein entfernter Eintrag samt seiner Stelle in der Liste, damit „Widerrufen“ ihn zurücksetzen kann.
struct EntfernterTitel: Equatable {
    let eintrag: GemerkterTitel
    let position: Int
}

/// Die Merkliste der Titel aus dem Bibliothekskatalog. Liegt nur auf diesem Gerät als JSON-Datei in
/// „Application Support“: kein iCloud, kein Schlüsselbund. Hat nichts mit PAIA oder der Anmeldung zu tun,
/// funktioniert also abgemeldet und bleibt über App-Neustarts erhalten.
///
/// Die Datei statt SwiftData: Es ist eine kurze, geordnete Liste ohne Beziehungen, und „Widerrufen“ braucht
/// die genaue Stelle. Das ist als Datei einfacher und braucht keinen Eingriff in den `ModelContainer` der App.
@Observable
final class BibMerklisteStore {
    /// Die Merkliste der App.
    static let shared = BibMerklisteStore()

    /// Schlüssel der früheren Favoriten (nur IDs), deren Einträge übernommen werden.
    static let legacyKey = "libraryFavoriteTitles"

    /// Alle Einträge, nach `gemerktAm` sortiert, neueste zuerst.
    private(set) var eintraege: [GemerkterTitel] = []

    @ObservationIgnored private let fileURL: URL?

    /// - Parameters:
    ///   - fileURL: Ort der Datei. `nil` hält die Liste nur im Speicher (für Previews).
    ///   - legacyDefaults: Aus diesen UserDefaults werden die früheren Favoriten übernommen und dort gelöscht.
    init(fileURL: URL? = BibMerklisteStore.defaultFileURL, legacyDefaults: UserDefaults? = .standard) {
        self.fileURL = fileURL
        load()
        if let legacyDefaults { migrateLegacy(from: legacyDefaults) }
    }

    static var defaultFileURL: URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return base.appendingPathComponent("Merkliste.json")
    }

    // MARK: - Abfragen

    var anzahl: Int { eintraege.count }

    func istGemerkt(_ id: String) -> Bool {
        eintraege.contains { $0.id == id }
    }

    // MARK: - Ändern

    /// Setzt einen Titel auf die Merkliste. Dieselbe ID gibt es nur einmal: Ist sie schon da, bleibt der Eintrag,
    /// wie er ist (nur ein von früher übernommener ohne Daten wird ergänzt).
    func merken(_ titel: GemerkterTitel) {
        if let index = eintraege.firstIndex(where: { $0.id == titel.id }) {
            if eintraege[index].istUnvollstaendig {
                aktualisieren(titel)
            }
            return
        }
        einfuegen(titel)
        speichern()
    }

    /// Nimmt einen Titel von der Merkliste und gibt ihn mit seiner Stelle zurück, damit er sich wiederherstellen lässt.
    @discardableResult
    func entfernen(_ id: String) -> EntfernterTitel? {
        guard let index = eintraege.firstIndex(where: { $0.id == id }) else { return nil }
        let eintrag = eintraege.remove(at: index)
        speichern()
        return EntfernterTitel(eintrag: eintrag, position: index)
    }

    /// Setzt einen entfernten Eintrag an seine alte Stelle zurück. Gibt es die ID inzwischen wieder, passiert nichts.
    func wiederherstellen(_ eintrag: GemerkterTitel, an position: Int) {
        guard !istGemerkt(eintrag.id) else { return }
        eintraege.insert(eintrag, at: min(max(0, position), eintraege.count))
        speichern()
    }

    func wiederherstellen(_ entfernt: EntfernterTitel) {
        wiederherstellen(entfernt.eintrag, an: entfernt.position)
    }

    func alleEntfernen() {
        guard !eintraege.isEmpty else { return }
        eintraege = []
        speichern()
    }

    /// Ersetzt die Angaben eines gemerkten Titels (z. B. nach dem Laden des Details), `gemerktAm` und Stelle bleiben.
    func aktualisieren(_ titel: GemerkterTitel) {
        guard let index = eintraege.firstIndex(where: { $0.id == titel.id }) else { return }
        var neu = titel
        neu.gemerktAm = eintraege[index].gemerktAm
        guard neu != eintraege[index] else { return }
        eintraege[index] = neu
        speichern()
    }

    // MARK: - Speichern

    /// Neueste oben: nach `gemerktAm` einsortieren.
    private func einfuegen(_ titel: GemerkterTitel) {
        let index = eintraege.firstIndex { $0.gemerktAm <= titel.gemerktAm } ?? eintraege.count
        eintraege.insert(titel, at: index)
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let geladen = try? decoder.decode([GemerkterTitel].self, from: data) else { return }
        eintraege = geladen.sorted { $0.gemerktAm > $1.gemerktAm }
    }

    private func speichern() {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Schlägt das Schreiben fehl, bleibt die Liste im Speicher; beim nächsten Ändern wird es erneut versucht.
        guard let data = try? encoder.encode(eintraege) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    /// Übernimmt die IDs der früheren Favoriten. Titel und Personen sind unbekannt und kommen nach,
    /// sobald die Merkliste geöffnet wird.
    private func migrateLegacy(from defaults: UserDefaults) {
        guard let ids = defaults.stringArray(forKey: Self.legacyKey) else { return }
        defer { defaults.removeObject(forKey: Self.legacyKey) }
        let neue = ids.filter { !istGemerkt($0) }
        guard !neue.isEmpty else { return }
        // Die alte Liste lief von alt nach neu; die letzte ID war die zuletzt gemerkte.
        for (offset, id) in neue.enumerated() {
            let alter = TimeInterval(neue.count - offset)
            einfuegen(GemerkterTitel(id: id, titel: "", gemerktAm: Date(timeIntervalSinceNow: -alter)))
        }
        speichern()
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// Die Merkliste der App. Vorgabe ist die gemeinsame Instanz; Previews und Tests setzen eine eigene.
    @Entry var merkliste: BibMerklisteStore = .shared
}

// MARK: - Verfügbarkeit der gemerkten Titel

/// Signatur und Standort eines gemerkten Titels, aus den Exemplaren der Verfügbarkeit. Wird nicht gespeichert.
struct BibMerklisteExemplar: Equatable {
    /// Signatur des gezeigten Exemplars.
    let signatur: String?
    /// Name des Standorts („Lehrbuchsammlung“).
    let standort: String?
    /// Link zum Lageplan des Standorts, nur http(s).
    let lageplan: URL?
    /// Anzahl weiterer Exemplare, die nicht gezeigt werden.
    let weitere: Int

    /// Zeigt das Exemplar, das man am ehesten bekommt: erst ein ausleihbares, dann eines nur vor Ort, dann ein
    /// ausgeliehenes, sonst das erste. `nil`, wenn weder Signatur noch Standort bekannt sind (z. B. E-Books).
    init?(availability: LibraryAvailability) {
        let items = availability.items
        let reihenfolge: [LibraryAvailabilityStatus] = [.available, .referenceOnly, .onLoan]
        let wahl = reihenfolge.lazy.compactMap { status in items.first { $0.status == status } }.first ?? items.first
        guard let wahl else { return nil }

        func gekuerzt(_ text: String?) -> String? {
            let text = text?.trimmingCharacters(in: .whitespacesAndNewlines)
            return text?.isEmpty == false ? text : nil
        }
        let plan = wahl.location?.floorPlanUrl.flatMap { ["http", "https"].contains($0.scheme?.lowercased()) ? $0 : nil }
        signatur = gekuerzt(wahl.label)
        standort = gekuerzt(wahl.location?.name)
        lageplan = plan
        weitere = items.count - 1
        if signatur == nil, standort == nil { return nil }
    }

    init(signatur: String?, standort: String?, lageplan: URL? = nil, weitere: Int = 0) {
        self.signatur = signatur
        self.standort = standort
        self.lageplan = lageplan
        self.weitere = weitere
    }
}

/// Lädt den Verfügbarkeitsstatus der Merkliste frisch über `/v1/library/availability`, in Paketen von höchstens
/// 20 IDs, parallel. Gespeichert wird er nicht. Fehler zeigen „Unbekannt“, die Einträge bleiben stehen.
@MainActor
@Observable
final class BibMerklisteStatus {
    /// Status je ID. Fehlt eine ID, lädt sie noch.
    private(set) var status: [String: LibraryAvailabilityStatus] = [:]
    /// Signatur und Standort je ID, soweit bekannt.
    private(set) var exemplare: [String: BibMerklisteExemplar] = [:]
    private(set) var isLoading = false

    init(status: [String: LibraryAvailabilityStatus] = [:], exemplare: [String: BibMerklisteExemplar] = [:]) {
        self.status = status
        self.exemplare = exemplare
    }

    static let packetSize = LibraryCatalogService.maxAvailabilityIDs

    func status(for id: String) -> LibraryAvailabilityStatus? { status[id] }

    func exemplar(for id: String) -> BibMerklisteExemplar? { exemplare[id] }

    func load(ids: [String], using service: LibraryCatalogService) async {
        var seen = Set<String>()
        let unique = ids.filter { seen.insert($0).inserted }
        guard !unique.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let packets = stride(from: 0, to: unique.count, by: Self.packetSize).map {
            Array(unique[$0..<min($0 + Self.packetSize, unique.count)])
        }
        typealias Teil = (status: [String: LibraryAvailabilityStatus], exemplare: [String: BibMerklisteExemplar])
        await withTaskGroup(of: Teil.self) { group in
            for packet in packets {
                group.addTask {
                    do {
                        let result = try await service.availability(ids: packet)
                        let status = Dictionary(
                            packet.map { ($0, result.value[$0]?.status ?? .unknown) },
                            uniquingKeysWith: { first, _ in first }
                        )
                        let exemplare = Dictionary(
                            packet.compactMap { id in
                                result.value[id].flatMap(BibMerklisteExemplar.init(availability:)).map { (id, $0) }
                            },
                            uniquingKeysWith: { first, _ in first }
                        )
                        return (status, exemplare)
                    } catch is CancellationError {
                        return ([:], [:])
                    } catch {
                        // Fehler: „Unbekannt“, nicht abbrechen.
                        return (Dictionary(packet.map { ($0, LibraryAvailabilityStatus.unknown) }, uniquingKeysWith: { first, _ in first }), [:])
                    }
                }
            }
            for await part in group {
                status.merge(part.status) { _, new in new }
                exemplare.merge(part.exemplare) { _, new in new }
            }
        }
    }
}
