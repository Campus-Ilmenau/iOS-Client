import Foundation

/// Der eine Eingang für Ziele von außen: Deeplinks (`onOpenURL`) und Intents (Steuerelemente, später Siri und
/// Kurzbefehle) melden hier ein `DeepLink`-Ziel. Die App hängt beim Start ihren Router an (`verbinde`); Ziele, die vorher
/// eintreffen (die App wurde gerade erst vom Intent gestartet), warten, bis der Router da ist.
///
/// Die Datei gehört zu App und Widget-Extension, damit die Intents in beiden verfügbar sind. In der Extension hängt nie
/// ein Router; dort läuft kein Intent mit `openAppWhenRun`, das System startet dafür die App.
@MainActor
enum DeepLinkEingang {
    private static var handler: ((DeepLink) -> Void)?
    private static var ausstehend: [DeepLink] = []

    /// Meldet ein Ziel. Ohne angehängten Router wartet es.
    static func melde(_ link: DeepLink) {
        if let handler {
            handler(link)
        } else {
            ausstehend.append(link)
        }
    }

    /// Trennt den Router und verwirft, was wartet. Nur für Tests.
    static func trenne() {
        handler = nil
        ausstehend = []
    }

    /// Hängt den Router an und reicht ihm, was schon wartet.
    static func verbinde(_ handler: @escaping (DeepLink) -> Void) {
        self.handler = handler
        let offen = ausstehend
        ausstehend = []
        offen.forEach(handler)
    }
}
