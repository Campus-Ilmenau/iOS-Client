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

    /// „Abend“ beginnt um 17 Uhr (wie bei „Heute Abend“).
    static let abendBeginn = 17
    /// So viele Events gehen höchstens in den Speicher.
    static let maxEvents = 24

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
    func speichereEvents(heute: [CampusEvent]?, morgen: [CampusEvent]?, jetzt: Date = .now) {
        let tagHeute = EventKalender.tagesbeginn(jetzt)
        let tagMorgen = EventKalender.tag(jetzt, plus: 1)

        let aenderung = store.aendern { snapshot in
            // Vergangene Tage fallen heraus; ein neu geladener Tag ersetzt seine alten Einträge.
            var behalten = snapshot.events.filter { $0.beginn >= tagHeute }
            if heute != nil { behalten.removeAll { EventKalender.kalender.isDate($0.beginn, inSameDayAs: tagHeute) } }
            if morgen != nil { behalten.removeAll { EventKalender.kalender.isDate($0.beginn, inSameDayAs: tagMorgen) } }

            var neu: [WidgetEvent] = []
            for (liste, tag) in [(heute, tagHeute), (morgen, tagMorgen)] {
                for event in liste ?? [] where Self.gehoertZumAbend(event, an: tag) {
                    neu.append(WidgetEvent(
                        id: event.id,
                        titel: event.titel,
                        beginn: event.beginn,
                        ende: event.ende,
                        ganztaegig: event.ganztaegig,
                        ort: event.ort,
                        veranstalter: event.veranstalterAnzeigen
                    ))
                }
            }
            let alle = (behalten + neu).sorted { $0.beginn < $1.beginn }
            var gesehen = Set<String>()
            snapshot.events = alle.filter { gesehen.insert($0.id).inserted }.prefix(Self.maxEvents).map { $0 }
        }
        if aenderung { neuLaden([WidgetKinds.heuteAbend, WidgetKinds.events]) }
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
            jetzt: jetzt
        )
    }

    /// Die IDs gemerkter Events.
    func speichereMerkliste(_ ids: Set<String>) {
        let sortiert = ids.sorted()
        let aenderung = store.aendern { $0.gemerkteEventIDs = sortiert }
        if aenderung { neuLaden([WidgetKinds.heuteAbend, WidgetKinds.events]) }
    }

    // MARK: Einstellungen

    /// „Mensa auf der Startseite“ oder Preisgruppe haben sich geändert: Die Mensa-Widgets lesen beides aus den
    /// Einstellungen der App Group, ihr Inhalt im Speicher bleibt gleich.
    func einstellungenGeaendert() {
        neuLaden([WidgetKinds.mensa])
    }

    // MARK: Auswahl

    /// Ein Event gehört zum Abend eines Tages, wenn es an dem Tag beginnt, nicht abgesagt und nicht ganztägig ist
    /// und ab 17 Uhr beginnt oder nach 17 Uhr noch läuft.
    static func gehoertZumAbend(_ event: CampusEvent, an tag: Date) -> Bool {
        guard event.status != .abgesagt, !event.ganztaegig,
              EventKalender.kalender.isDate(event.beginn, inSameDayAs: tag),
              let grenze = EventKalender.kalender.date(bySettingHour: abendBeginn, minute: 0, second: 0, of: tag)
        else { return false }
        return event.beginn >= grenze || (event.ende ?? event.beginn) > grenze
    }
}
