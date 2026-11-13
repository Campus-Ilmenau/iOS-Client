import AppIntents
import SwiftUI

// Katalogsuche und Merkliste für Siri: gesprochener Satz plus kleine Karte. Beides geht ohne Anmeldung und ohne
// Bibliotheks-Token. Die Intents laufen im Prozess der App, öffnen sie aber nicht. Die Regeln für Sätze und Karten
// stehen in `Shared/` (`SiriKatalog`, `SiriMerkliste`), das Laden in `SiriKatalogDaten`.

/// „Suche im Katalog“: Siri fragt nach dem Begriff. Ein Satz für App Shortcuts darf keinen freien Text enthalten.
/// Der Steuerelement-Intent `KatalogSuchenIntent` (öffnet die leere Suche) bleibt unverändert.
struct KatalogFragenIntent: AppIntent {
    static var title: LocalizedStringResource { LocalizedStringResource("Katalog fragen", table: "Siri") }
    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("Sucht im Bestand der UB Ilmenau und sagt dir die ersten Treffer. Ohne Anmeldung.", table: "Siri"))
    }

    @Parameter(title: LocalizedStringResource("Suchbegriff", table: "Siri"), requestValueDialog: IntentDialog(LocalizedStringResource("Wonach soll ich im Katalog suchen?", table: "Siri")))
    var suchbegriff: String

    static var parameterSummary: some ParameterSummary {
        Summary("Im Katalog nach \(\.$suchbegriff) suchen")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Ein leerer Begriff zählt als nicht genannt: Siri fragt noch einmal.
        var begriff = suchbegriff.trimmingCharacters(in: .whitespacesAndNewlines)
        if begriff.isEmpty {
            begriff = try await $suchbegriff.requestValue(IntentDialog(LocalizedStringResource("Wonach soll ich im Katalog suchen?", table: "Siri")))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let antwort = await SiriKatalogDaten.suche(begriff)
        return .result(dialog: IntentDialog(stringLiteral: antwort.sagt), view: SiriKatalogAntwortView(karte: antwort.karte))
    }
}
