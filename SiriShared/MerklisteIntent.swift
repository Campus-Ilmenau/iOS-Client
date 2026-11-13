import AppIntents
import SwiftUI

// Die Merkliste für Siri: gesprochener Satz plus kleine Karte, ohne Anmeldung und ohne Bibliotheks-Token. Der Intent läuft
// im Prozess der App (iPhone) bzw. der Watch-App, öffnet sie aber nicht. Die Regeln für Satz und Karte stehen in
// `Shared/SiriMerkliste.swift`; woher die Merkliste kommt und wie die Karte aussieht, entscheidet `SiriPlattform`.

/// „Was steht auf meiner Merkliste?“: Anzahl und Standorte, keine Signaturen.
struct MerklisteIntent: AppIntent {
    static var title: LocalizedStringResource { LocalizedStringResource("Merkliste", table: "Siri") }
    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("Sagt dir, wie viele Titel deiner Merkliste im Regal stehen und wo. Ohne Anmeldung.", table: "Siri"))
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let antwort = await SiriPlattform.merkliste()
        return .result(dialog: IntentDialog(stringLiteral: antwort.sagt), view: SiriPlattform.merklisteAnsicht(antwort))
    }
}
