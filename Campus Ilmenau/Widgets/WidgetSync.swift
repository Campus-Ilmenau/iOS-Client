import Foundation
import WidgetKit

/// Die App schreibt hier den `WidgetStore` und sagt den Widgets, wann sie neu laden sollen. Die Daten kommen aus den
/// vorhandenen Quellen für Mensa und Events, die die Startseite schon lädt; hier wird nichts zusätzlich geladen,
/// außer dem nächsten Öffnungstag, wenn „morgen“ keinen Speiseplan hat (Wochenende, Feiertag).
///
/// Es gehen nur Inhalte hinein, die nicht veralten. Kontodaten (Thoska, Ausleihen, Bibliothek) kennt dieser Typ nicht.
@MainActor
struct WidgetSync {
    /// Die App-weite Instanz mit dem echten Speicher der App Group.
    static let shared = WidgetSync()

    private let store: WidgetStore
    private let neuLaden: @MainActor ([String]) -> Void

    init(
        store: WidgetStore = WidgetStore(),
        neuLaden: @escaping @MainActor ([String]) -> Void = { kinds in
            for kind in kinds { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
        }
    ) {
        self.store = store
        self.neuLaden = neuLaden
    }

    // MARK: Mensa

    /// Schreibt Öffnungszeiten und Speiseplan (heute und nächster Öffnungstag) aller vier Mensen, so wie die
    /// Heute-Seite sie geladen hat. Was `nil` ist (nicht geladen), bleibt im Speicher, wie es war.
    func speichereMensa(
        mensen: [Canteen]?,
        heute: [MensaMeal]?,
        morgen: [MensaMeal]?,
        quelle: any MensaDatenquelle,
        jetzt: Date = .now
    ) async {
        let geaendert = await WidgetMensaAktualisierung(store: store).speichere(
            mensen: mensen, heute: heute, morgen: morgen, jetzt: jetzt,
            weitereTage: { try await quelle.speiseplan(am: $0) }
        )
        if geaendert { neuLaden([WidgetKinds.mensa]) }
    }

    /// Der Mensa-Tab hat einen Tag geladen. Heute und der nächste Öffnungstag gehen in den Speicher, andere Tage nicht.
    func speichereSpeiseplan(tag: Date, speiseplan: [MensaMeal], jetzt: Date = .now) {
        let heute = EventKalender.tagesbeginn(jetzt)
        let tagesbeginn = EventKalender.tagesbeginn(tag)
        let geaendert = store.aendern { snapshot in
            if tagesbeginn == heute {
                WidgetMensaPflege.uebernehmeHeute(speiseplan, jetzt: jetzt, in: &snapshot)
            } else if tagesbeginn > heute {
                // Nur der nächste mögliche Öffnungstag: morgen, oder nach dem Wochenende der Montag.
                guard WidgetMensaPflege.nurWochenendeDazwischen(heute: heute, tag: tagesbeginn) else { return }
                WidgetMensaPflege.uebernehmeNaechsten(speiseplan, tag: tag, jetzt: jetzt, verbuergt: true, in: &snapshot)
            }
            WidgetMensaPflege.raeumeAuf(jetzt: jetzt, in: &snapshot)
        }
        if geaendert { neuLaden([WidgetKinds.mensa]) }
    }

    /// Der Mensa-Tab hat die Öffnungszeiten geladen.
    func speichereOeffnungszeiten(_ mensen: [Canteen]) {
        guard !mensen.isEmpty else { return }
        let geaendert = store.aendern { WidgetMensaPflege.uebernehmeOeffnungszeiten(mensen, in: &$0) }
        if geaendert { neuLaden([WidgetKinds.mensa]) }
    }

    // MARK: Events

    /// Schreibt die Events der nächsten zwei Abende (heute und morgen). `nil` heißt „nicht geladen“: dieser Tag
    /// bleibt, wie er war.
    /// - Parameter abgesagteMitgeliefert: Die Listen enthalten auch abgesagte Events (siehe `WidgetEventPflege`).
    func speichereEvents(heute: [CampusEvent]?, morgen: [CampusEvent]?, abgesagteMitgeliefert: Bool, jetzt: Date = .now) {
        var listen: [(tag: Date, events: [CampusEvent])] = []
        if let heute { listen.append((EventKalender.tagesbeginn(jetzt), heute)) }
        if let morgen { listen.append((EventKalender.tag(jetzt, plus: 1), morgen)) }

        let aenderung = store.aendern { snapshot in
            WidgetEventPflege.uebernehme(listen, jetzt: jetzt, abgesagteMitgeliefert: abgesagteMitgeliefert, in: &snapshot)
        }
        if aenderung { neuLaden([WidgetKinds.heuteAbend]) }
    }

    /// Der Events-Tab hat eine Liste geladen. Ein Tag geht nur in den Speicher, wenn die Liste ihn vollständig
    /// enthält: ohne Veranstalter- und Kategorie-Filter, und entweder ist es die letzte Seite oder sie reicht
    /// über den Tag hinaus (die API sortiert nach Beginn).
    func speichereEvents(aus events: [CampusEvent], hatWeitere: Bool, filter: EventFilter, jetzt: Date = .now) {
        guard filter.veranstalter == nil, filter.kategorie == nil else { return }
        let heute = EventKalender.tagesbeginn(jetzt)
        let morgen = EventKalender.tag(jetzt, plus: 1)

        func vollstaendig(_ tag: Date) -> Bool {
            switch filter.zeitfilter(jetzt: jetzt) {
            case .abend(let abend):
                return abend == tag && !hatWeitere
            case .tag(let gewaehlt):
                return gewaehlt == tag && !hatWeitere
            case .zeitraum(let von, let bis):
                guard tag >= von, bis.map({ tag < $0 }) ?? true else { return false }
                guard hatWeitere else { return true }
                return (events.last?.beginn ?? .distantPast) >= EventKalender.tag(tag, plus: 1)
            }
        }
        speichereEvents(
            heute: vollstaendig(heute) ? events : nil,
            morgen: vollstaendig(morgen) ? events : nil,
            abgesagteMitgeliefert: !filter.abgesagteAusblenden,
            jetzt: jetzt
        )
    }

    /// Die IDs gemerkter Events.
    func speichereMerkliste(_ ids: Set<String>) {
        let sortiert = ids.sorted()
        let aenderung = store.aendern { $0.gemerkteEventIDs = sortiert }
        if aenderung { neuLaden([WidgetKinds.heuteAbend]) }
    }

    // MARK: Einstellungen

    /// „Mensa auf der Startseite“ oder Preisgruppe haben sich geändert: Die Mensa-Widgets lesen beides aus den
    /// Einstellungen der App Group, ihr Inhalt im Speicher bleibt gleich.
    func einstellungenGeaendert() {
        neuLaden([WidgetKinds.mensa])
    }

    /// Der Mensa-Filter der App hat sich geändert. Er liegt in der App Group; Widgets mit dem Schalter
    /// „Filter aus der App anwenden“ lesen ihn beim Neuladen.
    func mensaFilterGeaendert() {
        neuLaden([WidgetKinds.mensa])
    }

}
