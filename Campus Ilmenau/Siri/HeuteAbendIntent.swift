import AppIntents
import SwiftUI

/// „Was ist heute Abend los?“ Gesprochener Satz plus nachtblaue Karte. Der Intent läuft im Prozess der App, öffnet sie
/// aber nicht. Daten wie beim Widget „Heute Abend“: erst selbst laden (Zeitlimit 4 s), sonst der Speicher der App Group.
/// Die Regeln für Satz und Karte stehen in `Shared/SiriAbend.swift`.
struct HeuteAbendIntent: AppIntent {
    static var title: LocalizedStringResource { LocalizedStringResource("Heute Abend", table: "Siri") }
    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("Sagt dir, was heute Abend los ist, und nennt Absagen.", table: "Siri"))
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let jetzt = WidgetUhr.jetzt
        let snapshot = await SiriEventsDaten.laden(jetzt: jetzt)
        let antwort = SiriAbend.antwort(snapshot: snapshot, jetzt: jetzt)
        return .result(dialog: IntentDialog(stringLiteral: antwort.sagt), view: SiriAbendAntwortView(karte: antwort.karte))
    }
}
