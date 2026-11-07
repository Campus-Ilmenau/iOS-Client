import WidgetKit
import SwiftUI

/// Ein Zustand des Widgets „Mensa heute“: alles, was die Ansicht braucht, ist schon als Text berechnet.
struct MensaEintrag: TimelineEntry {
    let date: Date
    let anzeige: MensaWidgetAnzeige
}

/// Liefert die Zeitleiste: ein Eintrag pro Phasenwechsel für den ganzen Tag, dann Neuladen am nächsten Morgen um 6:00.
///
/// Beim Laden der Zeitleiste holt das Widget den Speiseplan selbst über die öffentliche Mensa-API (ohne Anmeldung) und
/// schreibt ihn in den `WidgetStore`. Klappt das nicht (offline, Zeitlimit), gilt der Speicher der App.
struct MensaProvider: TimelineProvider {
    /// Wie lange das Widget auf die Mensa-API wartet. Kurz, denn das System gibt einer Zeitleiste nur wenig Zeit.
    static let zeitlimit: Duration = .seconds(6)
    private let store: WidgetStore
    private let quelle: @MainActor () -> any MensaDatenquelle

    init(store: WidgetStore = WidgetStore(), quelle: @escaping @MainActor () -> any MensaDatenquelle = { MensaHeuteQuelle() }) {
        self.store = store
        self.quelle = quelle
    }

    func placeholder(in context: Context) -> MensaEintrag {
        MensaEintrag(date: .now, anzeige: MensaWidgetVorschau.anzeige(.mittag))
    }

    func getSnapshot(in context: Context, completion: @escaping (MensaEintrag) -> Void) {
        if context.isPreview {
            completion(MensaEintrag(date: .now, anzeige: MensaWidgetVorschau.anzeige(.mittag)))
            return
        }
        // Die Vorschau in der Galerie und Momentaufnahmen laden nichts nach: sie zeigen den Speicher.
        completion(Self.eintraege(snapshot: store.lesen(), ab: .now).first ?? MensaEintrag(date: .now, anzeige: MensaWidgetVorschau.anzeige(.kein)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MensaEintrag>) -> Void) {
        let store = store
        let quelle = quelle
        Task { @MainActor in
            let jetzt = Date.now
            await WidgetMensaAktualisierung(store: store)
                .ladeUndSpeichere(quelle: quelle(), jetzt: jetzt, zeitlimit: Self.zeitlimit)
            let eintraege = Self.eintraege(snapshot: store.lesen(), ab: jetzt)
            completion(Timeline(entries: eintraege, policy: .after(MensaWidgetPhasen.naechsteNeuladung(nach: jetzt))))
        }
    }

    // MARK: Zeitleiste

    /// Heutiger Zustand und je einer pro Phasenwechsel bis Mitternacht.
    static func eintraege(snapshot: WidgetSnapshot, ab jetzt: Date) -> [MensaEintrag] {
        let mensa = AppGroup.defaults.string(forKey: AppGroup.heuteMensaSchluessel) ?? MensaVenue.mensaEhrenberg.rawValue
        let gruppe = AppGroup.defaults.string(forKey: AppGroup.preisgruppeSchluessel).flatMap(MensaPriceGroup.init(rawValue:))
            ?? .studierende
        let zeitpunkte = [jetzt] + MensaWidgetPhasen.wechsel(snapshot: snapshot, mensaID: mensa, nach: jetzt)
        return zeitpunkte.map { zeit in
            MensaEintrag(
                date: zeit,
                anzeige: MensaWidgetPhasen.anzeige(snapshot: snapshot, mensaID: mensa, preisgruppe: gruppe, jetzt: zeit)
            )
        }
    }
}

/// Verbindet den Eintrag mit der Größe des Widgets, die nur die Umgebung kennt.
struct MensaWidgetEintragView: View {
    let eintrag: MensaEintrag
    @Environment(\.widgetFamily) private var family

    var body: some View {
        MensaWidgetView(anzeige: eintrag.anzeige, groesse: MensaWidgetGroesse(family))
            .containerBackground(Color(.surface), for: .widget)
    }
}

/// Das Widget „Mensa heute“ in klein, mittel und groß.
struct MensaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.mensa, provider: MensaProvider()) { eintrag in
            MensaWidgetEintragView(eintrag: eintrag)
        }
        .configurationDisplayName("Mensa heute")
        .description("Was es gerade in deiner Mensa gibt.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // Der Kopf geht bis an den Rand; Abstände setzt die Ansicht selbst.
        .contentMarginsDisabled()
    }
}
