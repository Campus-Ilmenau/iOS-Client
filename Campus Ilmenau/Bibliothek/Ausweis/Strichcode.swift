import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Strichcode der Benutzernummer. Das Format steht nur hier in `format`.
enum Strichcode {
    enum Format {
        /// Wie auf der Thoska (im Scanner als `VNBarcodeSymbologyCode39` erkannt). Gezeichnet von der App selbst.
        case code39
        /// Über `CIFilter.code128BarcodeGenerator()`. Nicht im Einsatz, bleibt als Alternative.
        case code128
    }

    static let format: Format = .code39

    /// Fertig gerendertes Bild. `breite` ist die Breite in Punkten, passend zur Pixelzahl: Jeder Strich ist
    /// eine ganze Zahl Pixel breit, damit nichts weichgezeichnet wird und kein Strich dicker ist als der andere.
    struct Bild {
        let cgImage: CGImage
        let breite: CGFloat
    }

    /// - Parameters:
    ///   - verfügbareBreite: Platz in Punkten für das Bild samt eigener Ruhezone.
    ///   - displayScale: Pixel pro Punkt.
    /// - Returns: `nil`, wenn der Text im Format nicht darstellbar ist (z. B. ein Zeichen, das Code 39 nicht kennt).
    static func bild(für text: String, verfügbareBreite: CGFloat, displayScale: CGFloat) -> Bild? {
        guard displayScale > 0, verfügbareBreite > 0 else { return nil }
        switch format {
        case .code39:
            guard let elemente = code39Elemente(für: text) else { return nil }
            return raster(elemente, verfügbareBreite: verfügbareBreite, displayScale: displayScale)
        case .code128:
            return code128(für: text, verfügbareBreite: verfügbareBreite, displayScale: displayScale)
        }
    }

    // MARK: - Code 39

    /// Muster je Zeichen: neun Elemente, abwechselnd Strich und Lücke, beginnend mit einem Strich.
    /// `n` = schmal, `w` = breit (genau drei breite je Zeichen).
    static let code39Muster: [Character: String] = [
        "0": "nnnwwnwnn", "1": "wnnwnnnnw", "2": "nnwwnnnnw", "3": "wnwwnnnnn", "4": "nnnwwnnnw",
        "5": "wnnwwnnnn", "6": "nnwwwnnnn", "7": "nnnwnnwnw", "8": "wnnwnnwnn", "9": "nnwwnnwnn",
        "A": "wnnnnwnnw", "B": "nnwnnwnnw", "C": "wnwnnwnnn", "D": "nnnnwwnnw", "E": "wnnnwwnnn",
        "F": "nnwnwwnnn", "G": "nnnnnwwnw", "H": "wnnnnwwnn", "I": "nnwnnwwnn", "J": "nnnnwwwnn",
        "K": "wnnnnnnww", "L": "nnwnnnnww", "M": "wnwnnnnwn", "N": "nnnnwnnww", "O": "wnnnwnnwn",
        "P": "nnwnwnnwn", "Q": "nnnnnnwww", "R": "wnnnnnwwn", "S": "nnwnnnwwn", "T": "nnnnwnwwn",
        "U": "wwnnnnnnw", "V": "nwwnnnnnw", "W": "wwwnnnnnn", "X": "nwnnwnnnw", "Y": "wwnnwnnnn",
        "Z": "nwwnwnnnn", "-": "nwnnnnwnw", ".": "wwnnnnwnn", " ": "nwwnnnwnn", "$": "nwnwnwnnn",
        "/": "nwnwnnnwn", "+": "nwnnnwnwn", "%": "nnnwnwnwn", "*": "nwnnwnwnn"
    ]

    /// Ein Element des Codes: Strich oder Lücke, schmal oder breit.
    struct Element: Equatable {
        let istStrich: Bool
        let istBreit: Bool
    }

    /// Alle Elemente von links nach rechts mit Start-/Stoppzeichen `*` und je einer schmalen Lücke zwischen den
    /// Zeichen, ohne Ruhezone (die liefert der Rand um das Bild). Kleinbuchstaben werden zu Großbuchstaben
    /// (Code 39 kennt nur diese). `nil` bei unbekannten Zeichen.
    static func code39Elemente(für text: String) -> [Element]? {
        let zeichen = Array(text.uppercased())
        guard !zeichen.isEmpty, !zeichen.contains("*"), zeichen.allSatisfy({ code39Muster[$0] != nil }) else { return nil }

        var elemente: [Element] = []
        for (index, c) in (["*"] + zeichen + ["*"]).enumerated() {
            guard let muster = code39Muster[c] else { return nil }
            if index > 0 { elemente.append(Element(istStrich: false, istBreit: false)) }
            for (position, form) in muster.enumerated() {
                elemente.append(Element(istStrich: position % 2 == 0, istBreit: form == "w"))
            }
        }
        return elemente
    }

    /// Breiter Strich in Pixeln zu einem schmalen: etwa 2,5 : 1 (zulässig sind 2 bis 3).
    private static func breit(zu schmal: Int) -> Int {
        max(schmal + 1, Int((Double(schmal) * 2.5).rounded()))
    }

    private static func breiteInPixeln(_ elemente: [Element], schmal: Int) -> Int {
        let breit = breit(zu: schmal)
        return elemente.reduce(0) { $0 + ($1.istBreit ? breit : schmal) }
    }

    /// Wählt die größte ganzzahlige Strichbreite (in Pixeln), bei der der Code in den Platz passt, und zeichnet
    /// ihn damit. Der Code füllt so die Breite fast aus, und trotzdem ist jeder schmale Strich gleich breit.
    /// Die Ruhezone von 10 schmalen Strichen liegt im Rand des Felds (mindestens 18 pt): Damit sie dort Platz
    /// hat, darf ein schmaler Strich höchstens 1,8 Pixel pro Punkt breit sein.
    private static func raster(_ elemente: [Element], verfügbareBreite: CGFloat, displayScale: CGFloat) -> Bild? {
        let platz = Int((verfügbareBreite * displayScale).rounded(.down))
        let obergrenze = max(1, Int((1.8 * displayScale).rounded(.down)))
        var schmal = 1
        for kandidat in 1...obergrenze where breiteInPixeln(elemente, schmal: kandidat) <= platz {
            schmal = kandidat
        }
        let breit = breit(zu: schmal)
        let breite = breiteInPixeln(elemente, schmal: schmal)
        let höhe = 32
        var pixel = [UInt8](repeating: 255, count: breite * höhe)
        var x = 0
        for element in elemente {
            let b = element.istBreit ? breit : schmal
            if element.istStrich {
                for spalte in x..<(x + b) {
                    for y in 0..<höhe { pixel[y * breite + spalte] = 0 }
                }
            }
            x += b
        }
        guard let provider = CGDataProvider(data: Data(pixel) as CFData),
              let cgImage = CGImage(
                width: breite, height: höhe, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: breite,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { return nil }
        return Bild(cgImage: cgImage, breite: CGFloat(breite) / displayScale)
    }

    // MARK: - Code 128

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    private static func code128(für text: String, verfügbareBreite: CGFloat, displayScale: CGFloat) -> Bild? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(text.utf8)
        filter.quietSpace = 10
        guard let basis = filter.outputImage, basis.extent.width > 0 else { return nil }
        let faktor = max(1, (verfügbareBreite * displayScale / basis.extent.width).rounded(.down))
        let skaliert = basis
            .samplingNearest()
            .transformed(by: CGAffineTransform(scaleX: faktor, y: faktor))
        guard let cgImage = context.createCGImage(skaliert, from: skaliert.extent) else { return nil }
        return Bild(cgImage: cgImage, breite: skaliert.extent.width / displayScale)
    }
}
