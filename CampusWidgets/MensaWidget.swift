import WidgetKit
import SwiftUI
import AppIntents

/// Der Wechsel-Knopf im mittleren Widget und die vier Punkte daneben. Nur bei „Wie auf der Startseite“ da;
/// bei einer festen Mensa gibt es beides nicht.
struct MensaWechsel: Equatable {
    /// Stelle der gezeigten Mensa in der Reihenfolge der App (0 …).
    let aktuell: Int
    let anzahl: Int
    /// Die Mensa, auf die der Knopf schaltet, für VoiceOver.
    let naechsterName: String

    init(venue: MensaVenue) {
        aktuell = MensaVenue.allCases.firstIndex(of: venue) ?? 0
        anzahl = MensaVenue.allCases.count
        naechsterName = venue.naechste.displayName
    }
}

/// Ein Zustand des Widgets „Mensa heute“: alles, was die Ansicht braucht, ist schon als Text berechnet.
struct MensaEintrag: TimelineEntry {
    let date: Date
    let anzeige: MensaWidgetAnzeige
    /// `nil` bei fester Mensa.
    var wechsel: MensaWechsel?
    /// Nur für Previews: zeichnet auch ohne Tönung des Systems so, wie „Getönt / Klar“ aussieht.
    var getoentVorschau = false
}

/// Liefert die Zeitleiste: ein Eintrag pro Phasenwechsel für den ganzen Tag, dann Neuladen am nächsten Morgen um 6:00.
///
/// Beim Laden der Zeitleiste holt das Widget den Speiseplan selbst über die öffentliche Mensa-API (ohne Anmeldung) und
/// schreibt ihn in den `WidgetStore`. Klappt das nicht (offline, Zeitlimit), gilt der Speicher der App.
struct MensaProvider: AppIntentTimelineProvider {
    /// Wie lange das Widget auf die Mensa-API wartet. Kurz, denn das System gibt einer Zeitleiste nur wenig Zeit.
    static let zeitlimit: Duration = .seconds(6)

    private let store: WidgetStore
    private let quelle: @MainActor () -> any MensaDatenquelle

    init(store: WidgetStore = WidgetStore(), quelle: @escaping @MainActor () -> any MensaDatenquelle = { MensaHeuteQuelle() }) {
        self.store = store
        self.quelle = quelle
    }

    func placeholder(in context: Context) -> MensaEintrag {
        MensaEintrag(date: .now, anzeige: MensaWidgetVorschau.anzeige(.mittag), wechsel: MensaWechsel(venue: .mensaEhrenberg))
    }

    func snapshot(for configuration: MensaWidgetKonfiguration, in context: Context) async -> MensaEintrag {
        if context.isPreview { return placeholder(in: context) }
        // Die Galerie und Momentaufnahmen laden nichts nach: sie zeigen den Speicher.
        return Self.eintraege(snapshot: store.lesen(), ab: .now, auswahl: configuration.mensa).first ?? placeholder(in: context)
    }

    func timeline(for configuration: MensaWidgetKonfiguration, in context: Context) async -> Timeline<MensaEintrag> {
        let store = store
        let quelle = quelle
        let jetzt = Date.now
        await WidgetMensaAktualisierung(store: store)
            .ladeUndSpeichere(quelle: quelle(), jetzt: jetzt, zeitlimit: Self.zeitlimit)
        let eintraege = Self.eintraege(snapshot: store.lesen(), ab: jetzt, auswahl: configuration.mensa)
        return Timeline(entries: eintraege, policy: .after(MensaWidgetPhasen.naechsteNeuladung(nach: jetzt)))
    }

    // MARK: Zeitleiste

    /// Heutiger Zustand und je einer pro Phasenwechsel bis Mitternacht.
    static func eintraege(snapshot: WidgetSnapshot, ab jetzt: Date, auswahl: MensaAuswahl) -> [MensaEintrag] {
        let defaults = AppGroup.defaults
        let startseite = defaults.string(forKey: AppGroup.heuteMensaSchluessel).flatMap(MensaVenue.init(rawValue:))
            ?? .mensaEhrenberg
        let venue = auswahl.venue ?? startseite
        let gruppe = defaults.string(forKey: AppGroup.preisgruppeSchluessel).flatMap(MensaPriceGroup.init(rawValue:))
            ?? .studierende
        let wechsel = auswahl == .wieStartseite ? MensaWechsel(venue: venue) : nil
        let zeitpunkte = [jetzt] + MensaWidgetPhasen.wechsel(snapshot: snapshot, mensaID: venue.rawValue, nach: jetzt)
        return zeitpunkte.map { zeit in
            MensaEintrag(
                date: zeit,
                anzeige: MensaWidgetPhasen.anzeige(snapshot: snapshot, mensaID: venue.rawValue, preisgruppe: gruppe, jetzt: zeit),
                wechsel: wechsel
            )
        }
    }
}

/// Verbindet den Eintrag mit der Größe und der Darstellung des Widgets, die nur die Umgebung kennt.
struct MensaWidgetEintragView: View {
    let eintrag: MensaEintrag
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        MensaWidgetView(
            anzeige: eintrag.anzeige,
            groesse: WidgetGroesse(family),
            wechsel: eintrag.wechsel,
            getoent: eintrag.getoentVorschau || renderingMode == .accented
        )
        .containerBackground(Color(.surface), for: .widget)
    }
}

/// Das Widget „Mensa heute“ in klein, mittel und groß.
struct MensaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.mensa, intent: MensaWidgetKonfiguration.self, provider: MensaProvider()) { eintrag in
            MensaWidgetEintragView(eintrag: eintrag)
        }
        .configurationDisplayName("Mensa heute")
        .description("Was es gerade in deiner Mensa gibt.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // Der Kopf geht bis an den Rand; Abstände setzt die Ansicht selbst.
        .contentMarginsDisabled()
    }
}
