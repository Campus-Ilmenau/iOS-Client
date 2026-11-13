import Foundation

/// Der Eingang für Ziele von außen auf der Uhr: Links aus Komplikationen und Smart Stack (`onOpenURL`) und der Button
/// „In der App öffnen“ unter einer Siri-Antwort (`UhrOeffneZielIntent`). Anders als `DeepLinkEingang` trägt er die ganze
/// URL, denn `waehlen=1` („Nanoteria bis Mitternacht wählen“) steht nicht im `DeepLink`.
///
/// Er merkt sich auch, wann zuletzt etwas von außen kam: Eine Ansicht, die höchstens 3 s danach erscheint, wurde nicht vom
/// Nutzer geöffnet und wird nicht an Siri gemeldet (wie `AppRouter.kamGeradeVonAussen` auf dem iPhone).
/// Die Datei gehört zu iPhone-App (nur für die Tests) und Watch-App.
@MainActor
enum UhrEingang {
    /// So lange gilt eine Ansicht nach einem Link von außen als „von außen geöffnet“.
    static let aussenFenster: TimeInterval = 3

    private static var handler: ((URL) -> Void)?
    private static var ausstehend: [URL] = []
    private(set) static var letzter: Date?

    /// Ein Link kam von außen (Widget, Smart Stack). Die Watch-App öffnet ihn selbst; hier wird nur der Zeitpunkt gemerkt.
    static func vermerke(jetzt: Date = .now) {
        letzter = jetzt
    }

    /// Meldet ein Ziel (der Intent). Ohne angehängte Ansicht wartet es, bis sie da ist.
    static func melde(_ url: URL, jetzt: Date = .now) {
        vermerke(jetzt: jetzt)
        if let handler {
            handler(url)
        } else {
            ausstehend.append(url)
        }
    }

    /// Hängt die Ansicht an und reicht ihr, was schon wartet.
    static func verbinde(_ handler: @escaping (URL) -> Void) {
        self.handler = handler
        let offen = ausstehend
        ausstehend = []
        offen.forEach(handler)
    }

    static func kamGeradeVonAussen(jetzt: Date = .now) -> Bool {
        guard let letzter else { return false }
        return jetzt.timeIntervalSince(letzter) <= aussenFenster
    }

    /// Setzt alles zurück. Nur für Tests.
    static func trenne() {
        handler = nil
        ausstehend = []
        letzter = nil
    }
}
