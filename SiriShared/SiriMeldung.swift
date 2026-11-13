import AppIntents
import Foundation

// Die Meldungen an Siri (Donations), gemeinsam für iPhone-App und Watch-App. Die Regeln stehen in `Uebergabe.md`, Kapitel
// „Siri & Kurzbefehle“ → „Siri-Vorschläge und Smart Stack“ und „Siri auf der Uhr“. Wer sie auslöst, hängt von der
// Plattform ab: auf dem iPhone `SiriMelder.melde(…, router:)` (Erweiterung in `Siri/SiriVorschlaege.swift`), auf der Uhr
// `UhrSiriMelder`.

/// Was die App an Siri meldet, wenn jemand etwas in der App tut (Tabelle in `Uebergabe.md`, Kapitel „Siri & Kurzbefehle“
/// → „Siri-Vorschläge und Smart Stack“). iOS lernt daraus, wann es die Aktion vorschlägt; Uhrzeiten legt die App nicht fest.
///
/// Es gibt bewusst keine Meldung für die Katalogsuche mit Suchbegriff (sonst schlägt iOS alte Suchbegriffe vor), nichts mit
/// Anmeldung (Ausleihen, Vormerkungen) und kein Guthaben.
enum SiriMeldung: Equatable, Sendable {
    /// Speiseplan geöffnet oder die Mensa gewechselt; mit `ernaehrung`, wenn der Filter „vegetarisch“ oder „vegan“ steht.
    case mensaHeute(mensa: MensaOrt, ernaehrung: Ernaehrung?)
    /// Nachmittags oder abends den Plan mit Abendessen angesehen.
    case abendessen
    /// Bei Veranstaltungen „Heute Abend“ gewählt.
    case heuteAbend
    /// Die Thoska erfolgreich ausgelesen.
    case thoskaAuslesen
    /// Die Merkliste geöffnet.
    case merkliste

    /// „Mensa heute“ für die gezeigte Mensa; der Filter der App wird nur gemeldet, wenn er eine Ernährungsstufe setzt.
    static func mensa(_ venue: MensaVenue, filter: MensaFilter) -> SiriMeldung {
        let ernaehrung: Ernaehrung? = switch filter.diet {
        case .alle: nil
        case .vegetarisch: .vegetarisch
        case .vegan: .vegan
        }
        return .mensaHeute(mensa: MensaOrt(venue), ernaehrung: ernaehrung)
    }

    /// „Plan mit Abendessen“: die Cafeteria Ehrenberg zeigt das Abendessen, und zwar am heutigen Tag und nachmittags
    /// oder abends. Das entscheidet die Phase des Widgets „Mensa heute“ (`nachmittag` ab der Schließzeit des Mittags,
    /// `abend`), keine feste Uhrzeit: Schließt eine Mensa vor 14:00, beginnt der Nachmittag schon früher.
    static func zeigtAbendessen(
        venue: MensaVenue, mealtime: MensaMealtime, tag: Date, jetzt: Date, snapshot: WidgetSnapshot
    ) -> Bool {
        guard venue.hasMealtimes, mealtime == .dinner, EventKalender.kalender.isDate(tag, inSameDayAs: jetzt) else { return false }
        let phase = MensaWidgetPhasen.anzeige(
            snapshot: snapshot, mensaID: venue.rawValue, preisgruppe: .studierende, jetzt: jetzt
        ).phase
        return phase == .nachmittag || phase == .abend
    }
}

/// Meldet Handlungen aus der App an iOS: nur wenn der Nutzer sie selbst ausgelöst hat, und höchstens einmal pro Ansicht
/// und Öffnen (nicht bei jedem Neuladen oder Scrollen).
@MainActor
final class SiriMelder {
    /// Die Ansichten, die melden. Je Ansicht merkt sich der Melder die letzte Meldung dieser Öffnung.
    enum Ansicht: Hashable {
        case mensa, mensaAbendessen, events, thoska, merkliste
    }

    static let gemeinsam = SiriMelder()

    private var letzte: [Ansicht: SiriMeldung] = [:]
    /// Die Abgaben laufen nacheinander im Hintergrund; die Ansicht wartet nicht darauf.
    private var abgabe: Task<Void, Never>?
    private let abgeben: @MainActor (SiriMeldung) async -> Void

    /// - Parameter abgeben: Wie eine Meldung zu iOS kommt. Tests setzen eine eigene und merken sich die Meldungen.
    init(abgeben: @escaping @MainActor (SiriMeldung) async -> Void = SiriMelder.anIOS) {
        self.abgeben = abgeben
    }

    /// Die Ansicht wird neu geöffnet (Tab gewählt, Ansicht geschoben): Ab jetzt zählt wieder eine Meldung.
    func neueOeffnung(_ ansicht: Ansicht) {
        letzte[ansicht] = nil
    }

    /// Meldet eine Handlung, außer sie kam gerade von außen (Siri, Widget, Vorschlag) oder dieselbe Meldung ging in
    /// dieser Öffnung der Ansicht schon hinaus. Eine andere Meldung (andere Mensa, anderer Filter) geht hinaus.
    /// - Parameter vonAussen: Die Ansicht erscheint höchstens 3 s nach einem Link von außen (iPhone: `AppRouter`,
    ///   Uhr: `UhrEingang`).
    /// - Returns: ob gemeldet wurde.
    @discardableResult
    func melde(_ meldung: SiriMeldung, in ansicht: Ansicht, vonAussen: Bool) -> Bool {
        guard !vonAussen else { return false }
        guard letzte[ansicht] != meldung else { return false }
        letzte[ansicht] = meldung
        let vorher = abgabe
        abgabe = Task { [abgeben] in
            await vorher?.value
            await abgeben(meldung)
        }
        return true
    }

    /// Wartet, bis alle bisherigen Meldungen abgegeben sind. Für Tests.
    func warteAufAbgaben() async {
        await abgabe?.value
    }

    /// Der Weg zu iOS: `IntentDonationManager`. Gemeldet wird nach der Handlung; ein Fehler ist kein Problem der App.
    static func anIOS(_ meldung: SiriMeldung) async {
        // Previews sind keine Handlungen des Nutzers.
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        let manager = IntentDonationManager.shared
        switch meldung {
        case .mensaHeute(let mensa, let ernaehrung):
            let intent = MensaHeuteIntent()
            intent.mensa = mensa
            intent.ernaehrung = ernaehrung
            _ = try? await manager.donate(intent: intent)
        case .abendessen:
            _ = try? await manager.donate(intent: AbendessenIntent())
        case .heuteAbend:
            _ = try? await manager.donate(intent: HeuteAbendIntent())
        case .thoskaAuslesen:
            _ = try? await manager.donate(intent: ThoskaAuslesenIntent())
        case .merkliste:
            _ = try? await manager.donate(intent: MerklisteIntent())
        }
    }
}
