import Testing
import Foundation
@testable import Campus_Ilmenau

/// Die Widgets in englischer App-Sprache: Über alle Beispiel-Szenarien darf kein deutsches Wort und kein Katalogschlüssel
/// in einem Text stehen bleiben (Gerichte und Veranstaltungen aus den Beispieldaten sind Inhalt und bleiben deutsch).
struct WidgetEnglischTests {
    private static let deutsch = [
        "Uhr", "Heute", "heute", "Morgen", "morgen", "Abendessen", "Mittag", "Geöffnet", "geöffnet", "Öffnet", "öffnet",
        "Schließt", "geschlossen", "Gericht", "weitere", "Nichts", "Noch kein", "Veranstaltung", "Läuft", "fällt", "Fällt",
        "Gefiltert", "Tippen", "siri."
    ]

    /// Alle Texte eines Wertes, auch in verschachtelten Strukturen.
    private func texte(_ wert: Any) -> [String] {
        if let text = wert as? String { return [text] }
        if let url = wert as? URL { _ = url; return [] }
        return Mirror(reflecting: wert).children.flatMap { texte($0.value) }
    }

    private func pruefe(_ wert: Any, _ name: String) {
        for text in texte(wert) {
            for wort in Self.deutsch where text.contains(wort) {
                // Inhalte der Beispieldaten (Veranstaltungs- und Gerichtsnamen) sind keine Oberfläche.
                if ["Filmabend", "Lola", "Spieleabend", "Kneipenquiz", "Halloween"].contains(where: text.contains) { continue }
                Issue.record("\(name): „\(text)“ enthält „\(wort)“")
            }
        }
    }

    @Test func mensaWidgetAufEnglisch() {
        AppLanguage.$test.withValue(.en) {
            for szenario in MensaWidgetVorschau.Szenario.allCases {
                pruefe(MensaWidgetVorschau.anzeige(szenario), "Mensa \(szenario)")
                pruefe(MensaWidgetVorschau.sperre(szenario), "Mensa Sperre \(szenario)")
            }
            pruefe(MensaWidgetVorschau.anzeige(.mittag, filter: MensaWidgetVorschau.filterVeganOhneMilch), "Mensa gefiltert")
            pruefe(MensaWidgetVorschau.anzeige(.mittag, filter: MensaWidgetVorschau.filterNichtsPasst), "Mensa nichts passt")
        }
    }

    @Test func abendWidgetAufEnglisch() {
        AppLanguage.$test.withValue(.en) {
            for szenario in AbendWidgetVorschau.Szenario.allCases {
                pruefe(AbendWidgetVorschau.anzeige(szenario), "Abend \(szenario)")
            }
        }
    }

    @Test func mensaWidgetEnglischBeispiel() {
        AppLanguage.$test.withValue(.en) {
            let a = MensaWidgetVorschau.anzeige(.mittag)
            #expect(a.kicker.hasPrefix("Open until"))
            let nacht = MensaWidgetVorschau.anzeige(.nacht)
            #expect(!nacht.kicker.isEmpty)
        }
    }
}
