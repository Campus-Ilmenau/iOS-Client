import SwiftUI
import SwiftData

/// Eine Karte mit Namen, wie sie Auswahl und Umbenennen brauchen.
struct ThoskaCardOption: Identifiable, Equatable {
    let id: String
    /// Name zur Anzeige: der vergebene Name oder „Karte …C3D4“.
    let displayName: String
    /// Nur der vom Nutzer vergebene Name, sonst `nil`.
    let customName: String?
}

/// Namen für Karten: Der Name hängt an der Karten-ID und bleibt nur auf dem Gerät.
enum ThoskaCardNaming {
    /// Der vergebene Name. Früher wurde die Karten-ID als Platzhalter gespeichert, das gilt als „ohne Namen“.
    static func customName(for cardId: String, names: [ThoskaCardName]) -> String? {
        guard let stored = names.first(where: { $0.cardId == cardId })?.name
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !stored.isEmpty, stored != cardId else { return nil }
        return stored
    }

    static func fallbackName(for cardId: String) -> String {
        "Karte …\(cardId.suffix(4).uppercased())"
    }

    static func option(for cardId: String, names: [ThoskaCardName]) -> ThoskaCardOption {
        let custom = customName(for: cardId, names: names)
        return ThoskaCardOption(id: cardId, displayName: custom ?? fallbackName(for: cardId), customName: custom)
    }

    /// Legt den Namen an oder ändert ihn. Ein leerer Name setzt die Karte zurück.
    @MainActor
    static func rename(cardId: String, to newName: String, names: [ThoskaCardName], context: ModelContext) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = names.first(where: { $0.cardId == cardId })
        if trimmed.isEmpty {
            if let existing { context.delete(existing) }
        } else if let existing {
            existing.name = trimmed
        } else {
            context.insert(ThoskaCardName(cardId: cardId, name: trimmed))
        }
    }
}

extension View {
    /// Alert zum Benennen einer Karte. `renamingCardId` gesetzt öffnet ihn.
    func thoskaRenameAlert(
        renamingCardId: Binding<String?>,
        currentName: @escaping (String) -> String?,
        onSave: @escaping (_ cardId: String, _ name: String) -> Void
    ) -> some View {
        modifier(ThoskaRenameAlert(renamingCardId: renamingCardId, currentName: currentName, onSave: onSave))
    }
}

private struct ThoskaRenameAlert: ViewModifier {
    @Binding var renamingCardId: String?
    let currentName: (String) -> String?
    let onSave: (String, String) -> Void

    @State private var text = ""

    func body(content: Content) -> some View {
        content
            .alert(
                "Karte benennen",
                isPresented: Binding(
                    get: { renamingCardId != nil },
                    set: { if !$0 { renamingCardId = nil } }
                )
            ) {
                TextField("Name", text: $text)
                Button("Sichern") {
                    if let cardId = renamingCardId { onSave(cardId, text) }
                    renamingCardId = nil
                }
                Button("Abbrechen", role: .cancel) { renamingCardId = nil }
            } message: {
                Text("Der Name bleibt nur auf deinem Gerät.")
            }
            .onChange(of: renamingCardId) { _, newValue in
                text = newValue.flatMap(currentName) ?? ""
            }
    }
}
