import SwiftUI
import Observation

/// Gemerkte Veranstaltungen, nur auf diesem Gerät. Gespeichert werden nur die Event-IDs als JSON-Datei in
/// „Application Support“ (wie die Merkliste der Bibliothek): kein iCloud, keine Anmeldung. Den Filter „Gemerkt“
/// wendet die App auf die geladene Liste an; auf dem Server gibt es kein Merken.
@Observable
final class EventsMerkStore {
    /// Der Speicher der App.
    static let shared = EventsMerkStore()

    /// IDs der gemerkten Veranstaltungen.
    private(set) var ids: Set<String> = []

    @ObservationIgnored private let fileURL: URL?

    /// - Parameter fileURL: Ort der Datei. `nil` hält die IDs nur im Speicher (Previews, Tests).
    init(fileURL: URL? = EventsMerkStore.defaultFileURL) {
        self.fileURL = fileURL
        laden()
    }

    static var defaultFileURL: URL? {
        guard let basis = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return basis.appendingPathComponent("MerklisteEvents.json")
    }

    func istGemerkt(_ id: String) -> Bool {
        ids.contains(id)
    }

    /// Merkt die Veranstaltung oder nimmt sie wieder weg. Gibt zurück, ob sie danach gemerkt ist.
    @discardableResult
    func umschalten(_ id: String) -> Bool {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        speichern()
        return ids.contains(id)
    }

    // MARK: Datei

    private func laden() {
        guard let fileURL, let daten = try? Data(contentsOf: fileURL),
              let geladen = try? JSONDecoder().decode([String].self, from: daten) else { return }
        ids = Set(geladen)
    }

    private func speichern() {
        guard let fileURL else { return }
        // Sortiert, damit die Datei sich nicht ohne Grund ändert.
        guard let daten = try? JSONEncoder().encode(ids.sorted()) else { return }
        try? daten.write(to: fileURL, options: [.atomic])
    }
}

extension EnvironmentValues {
    /// Die gemerkten Veranstaltungen. Vorgabe ist der gemeinsame Speicher; Previews und Tests setzen einen eigenen.
    @Entry var eventsMerkStore: EventsMerkStore = .shared
}
