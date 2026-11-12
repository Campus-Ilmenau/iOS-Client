import SwiftUI
import UniformTypeIdentifiers

/// Teilen-Taste mit Menü: Kopfzeile (was geteilt wird), „Als Bild teilen“ und „Als Text teilen“. Beide Einträge sind
/// `ShareLink`s, also folgt auf die Wahl das System-Teilen-Blatt.
///
/// Kurz nach dem Erscheinen (0,5 s) entsteht das PNG als Datei im temporären Ordner; erst dann ist „Als Bild teilen“
/// wählbar. Beide Einträge haben bewusst keine `SharePreview`: Mit Vorschau fehlt beim Text „Kopieren“, und Telegram
/// nimmt das Bild nicht an. Das Bild hat bewusst auch keinen `subject`, sonst sendet Messages zusätzlich eine Textnachricht.
struct ShareMenuButton<Content: ShareImageContent & Sendable, ButtonLabel: View>: View {
    let content: Content
    /// Kopfzeile des Menüs, z. B. „Mensa Ehrenberg · Heute · Mittag“.
    let caption: String
    var isEnabled = true
    @ViewBuilder let label: () -> ButtonLabel

    @State private var preparedFile: URL?

    var body: some View {
        Menu {
            Section(caption) {
                // Das fertige PNG als Datei-Adresse, so wie Dateien aus der Dateien-App: Das nehmen auch Erweiterungen wie
                // Telegram an. Mit einem eigenen Transferable samt `SharePreview` bleibt Telegram beim Bild im Ladekreis hängen.
                // Bis die Datei bereitliegt (rund 0,5 s nach dem Erscheinen), ist der Eintrag ausgegraut.
                if let preparedFile {
                    // Ohne `subject`: Messages schickt den Betreff sonst als eigene Textnachricht zusätzlich zum Bild.
                    ShareLink(item: preparedFile) {
                        Label("Als Bild teilen", systemImage: "photo")
                    }
                } else {
                    Button {} label: {
                        Label("Als Bild teilen", systemImage: "photo")
                    }
                    .disabled(true)
                }
                // Ohne `SharePreview`: Mit Vorschau bietet das Blatt für Text kein „Kopieren“ an, mit `subject` schon.
                ShareLink(item: content.text, subject: Text(content.title)) {
                    Label("Als Text teilen", systemImage: "text.alignleft")
                }
            }
        } label: {
            label()
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .task(id: isEnabled ? content.imageFileName + content.text : "") {
            preparedFile = nil
            guard isEnabled else { return }
            // Erst wenn die Ansicht zur Ruhe gekommen ist: Rendern blockiert den MainActor kurz.
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            // Das Bild liegt danach als Datei bereit, bevor jemand das Menü öffnet.
            if let data = ShareImageRenderer.png(of: content.card) {
                preparedFile = try? ShareImageFile.write(data, named: content.imageFileName)
            }
        }
    }
}

extension MensaPlanShare {
    /// Kopfzeile des Menüs im Speiseplan: „Mensa Ehrenberg · Heute · Mittag“. Abendessen nur bei der Cafeteria Ehrenberg.
    func menuCaption(now: Date = .now) -> String {
        let strings = ShareStrings(locale: locale)
        let meal = strings(mealtime == .dinner && venue.hasMealtimes ? "share.menu.dinner" : "share.menu.lunch")
        return "\(venue.displayName) · \(MensaFormatting.dayLabel(day, now: now)) · \(meal)"
    }
}

extension MensaMealShare {
    /// „Linsen-Dal · alle Angaben“
    var menuCaption: String {
        "\(meal.name) · \(ShareStrings(locale: locale)("share.menu.allDetails"))"
    }
}

extension EventShare {
    /// „Halloween-Party · Fr 30. Okt.“
    var menuCaption: String { title }
}
