import AppIntents
import SwiftUI

// Die Mensa-Antworten von Siri: gesprochener Satz plus kleine Karte. Die Intents laufen im Prozess der App (iPhone) bzw.
// der Watch-App, öffnen sie aber nicht (`openAppWhenRun` aus). Daten wie beim Widget: erst selbst laden (Zeitlimit 4 s),
// sonst der Speicher der App Group (auf der Uhr die Watch-Gruppe). Die Regeln für Sätze und Karten stehen in `Shared/`
// (`SiriMensa`, `SiriOffen`, `SiriAbendessen`); Einstellungen und Karten-Ansicht je Plattform in `SiriPlattform`.
//
// Die gesprochenen Sätze entstehen zur Laufzeit aus Daten (Gerichtsnamen, Zeiten) und sind deutsch. Die Sätze, mit denen
// man Siri anspricht, stehen in `AppShortcuts.xcstrings` auf Deutsch und Englisch.

/// „Was gibt’s heute in der Mensa?“
struct MensaHeuteIntent: AppIntent {
    static var title: LocalizedStringResource { LocalizedStringResource("Mensa heute", table: "Siri") }
    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("Sagt dir, was es heute in der Mensa gibt, mit dem Filter aus der App.", table: "Siri"))
    }

    @Parameter(title: LocalizedStringResource("Mensa", table: "Siri"))
    var mensa: MensaOrt?

    /// Gilt nur für diese Antwort und ersetzt die Ernährungsstufe des App-Filters.
    @Parameter(title: LocalizedStringResource("Ernährung", table: "Siri"))
    var ernaehrung: Ernaehrung?

    @Parameter(title: LocalizedStringResource("Filter aus der App anwenden", table: "Siri"), default: true)
    var filterAnwenden: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Mensa heute in \(\.$mensa)") {
            \.$ernaehrung
            \.$filterAnwenden
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let jetzt = WidgetUhr.jetzt
        let snapshot = await SiriMensaDaten.laden(jetzt: jetzt)
        let einstellungen = SiriPlattform.mensaEinstellungen()
        var frage = SiriMensaFrage(mensa: mensa, ernaehrung: ernaehrung, filterAnwenden: filterAnwenden)

        var ergebnis = SiriMensa.heute(frage, snapshot: snapshot, einstellungen: einstellungen, jetzt: jetzt)
        if case .rueckfrage(let rueckfrage) = ergebnis {
            // Mittags haben mehrere Cafeterien offen: Siri fragt nach, zur Wahl stehen nur die offenen.
            let wahl = try await $mensa.requestDisambiguation(
                among: rueckfrage.optionen.map(\.ort), dialog: IntentDialog(LocalizedStringResource("Welche Cafeteria meinst du?", table: "Siri"))
            )
            frage.mensa = wahl
            ergebnis = SiriMensa.heute(frage, snapshot: snapshot, einstellungen: einstellungen, jetzt: jetzt)
        }

        let antwort = if case .antwort(let antwort) = ergebnis { antwort } else {
            SiriMensaAntwort(sagt: SiriMensa.keineDaten, karte: nil)
        }
        return .result(dialog: IntentDialog(stringLiteral: antwort.sagt), view: SiriPlattform.mensaAnsicht(antwort, snapshot: snapshot, jetzt: jetzt))
    }
}

/// „Hat die Mensa offen?“
struct MensaOffenIntent: AppIntent {
    static var title: LocalizedStringResource { LocalizedStringResource("Mensa offen?", table: "Siri") }
    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("Sagt dir, ob die Mensa gerade offen hat und welche als Nächstes.", table: "Siri"))
    }

    @Parameter(title: LocalizedStringResource("Mensa", table: "Siri"))
    var mensa: MensaOrt?

    static var parameterSummary: some ParameterSummary {
        Summary("Hat \(\.$mensa) offen?")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let jetzt = WidgetUhr.jetzt
        let snapshot = await SiriMensaDaten.laden(jetzt: jetzt)
        let einstellungen = SiriPlattform.mensaEinstellungen()
        let antwort = SiriOffen.antwort(mensa: mensa, snapshot: snapshot, einstellungen: einstellungen, jetzt: jetzt)
        return .result(
            dialog: IntentDialog(stringLiteral: antwort.sagt),
            view: SiriPlattform.offenAnsicht(antwort, mensa: mensa, snapshot: snapshot, jetzt: jetzt)
        )
    }
}

/// „Gibt es heute Abendessen?“
struct AbendessenIntent: AppIntent {
    static var title: LocalizedStringResource { LocalizedStringResource("Abendessen", table: "Siri") }
    static var description: IntentDescription {
        IntentDescription(LocalizedStringResource("Sagt dir, ob es heute Abendessen gibt, wo und was.", table: "Siri"))
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let jetzt = WidgetUhr.jetzt
        let snapshot = await SiriMensaDaten.laden(jetzt: jetzt)
        let einstellungen = SiriPlattform.mensaEinstellungen()
        let antwort = SiriAbendessen.antwort(snapshot: snapshot, einstellungen: einstellungen, jetzt: jetzt)
        return .result(dialog: IntentDialog(stringLiteral: antwort.sagt), view: SiriPlattform.mensaAnsicht(antwort, snapshot: snapshot, jetzt: jetzt))
    }
}
