import SwiftUI
import UniformTypeIdentifiers

/// Ein teilbarer Inhalt, der auch als Bild geht: `card` ist die View fürs Bild (Speiseplan, Gericht, Veranstaltung).
protocol ShareImageContent: ShareContent {
    associatedtype Card: View
    @MainActor @ViewBuilder var card: Card { get }
    /// Dateiname mit Endung, z. B. „Mensa-Ehrenberg-2026-10-29.png“.
    var imageFileName: String { get }
}

/// Ein fertig gerendertes Bild als PNG. Es geht **ohne** Zusatztext raus; die Marke steht im Bild.
nonisolated struct ShareImage: Transferable, Sendable {
    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName { $0.fileName }
    }
}

enum ShareImageRenderer {
    /// Breite des Bildes in Punkten; mit `scale` 3 sind das 1080 px.
    static let width: CGFloat = 360
    static let scale: CGFloat = 3

    /// Rendert die Karte als PNG. Erst aufrufen, wenn jemand „Als Bild teilen“ wählt, nicht vorab.
    @MainActor
    static func render<Content: ShareImageContent>(_ content: Content) -> ShareImage? {
        guard let data = png(of: content.card) else { return nil }
        return ShareImage(data: data, fileName: content.imageFileName)
    }

    /// - Parameter scale: Standard ist 3 (1080 px breit); die Tests rendern kleiner, wo es nur um Größen geht.
    /// - Parameter opaque: `false` lässt durchsichtige Stellen durchsichtig (Test der Kerben).
    @MainActor
    static func png<Card: View>(of card: Card, scale: CGFloat = ShareImageRenderer.scale, opaque: Bool = true) -> Data? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        renderer.isOpaque = opaque
        return renderer.uiImage?.pngData()
    }
}

enum ShareImageFile {
    /// Schreibt das PNG in den temporären Ordner „Teilen“ und gibt die Adresse zurück. Gleicher Name, gleiche Datei:
    /// Ein neueres Bild ersetzt das ältere.
    static func write(_ data: Data, named fileName: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Teilen", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}

enum ShareFileName {
    /// „Mensa Ehrenberg“ → „Mensa-Ehrenberg“. Buchstaben und Ziffern bleiben, alles andere wird ein Bindestrich.
    static func slug(_ text: String) -> String {
        var result = ""
        var pendingDash = false
        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if pendingDash, !result.isEmpty { result += "-" }
                pendingDash = false
                result.unicodeScalars.append(scalar)
            } else {
                pendingDash = true
            }
        }
        return String(result.prefix(80))
    }

    /// „2026-10-29“ in der Zeitzone des Geräts.
    static func isoDay(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
