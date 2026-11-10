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
    var date: Date
    let anzeige: MensaWidgetAnzeige
    /// `nil` bei fester Mensa.
    var wechsel: MensaWechsel?
    /// Sperrbildschirm (Zeile, Rechteck, Kreis): das Gericht dieses Zeitpunkts. `nil` bei den Home-Größen.
    var sperre: MensaSperreAnzeige?
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
        MensaEintrag(
            date: .now, anzeige: MensaWidgetVorschau.anzeige(.mittag), wechsel: MensaWechsel(venue: .mensaEhrenberg),
            sperre: context.family.istSperrbildschirm ? MensaWidgetVorschau.sperre(.mittag) : nil
        )
    }

    func snapshot(for configuration: MensaWidgetKonfiguration, in context: Context) async -> MensaEintrag {
        if context.isPreview { return placeholder(in: context) }
        // Die Galerie und Momentaufnahmen laden nichts nach: sie zeigen den Speicher.
        return Self.eintraege(snapshot: store.lesen(), ab: WidgetUhr.jetzt, konfiguration: configuration, family: context.family).first
            ?? placeholder(in: context)
    }

    func timeline(for configuration: MensaWidgetKonfiguration, in context: Context) async -> Timeline<MensaEintrag> {
        let store = store
        let quelle = quelle
        let jetzt = WidgetUhr.jetzt
        let sperrbildschirm = context.family.istSperrbildschirm
        // Das Neuladen am Ende einer kurzen Sperrbildschirm-Zeitleiste (siehe unten) holt nichts nach, solange der
        // Speicher frisch ist: Die Rotation selbst kostet kein Budget und keine Netzabrufe.
        let frisch = sperrbildschirm && (store.lesen().stand.map { jetzt.timeIntervalSince($0) < Self.frischFuerSperre } ?? false)
        if !frisch {
            await WidgetMensaAktualisierung(store: store)
                .ladeUndSpeichere(quelle: quelle(), jetzt: jetzt, zeitlimit: Self.zeitlimit)
        }
        let snapshot = store.lesen()
        let eintraege = WidgetUhr.eintraege(
            Self.eintraege(snapshot: snapshot, ab: jetzt, konfiguration: configuration, family: context.family)
        ) { $0.date = $1 }
        // Sperrbildschirm: Einträge im 5-Minuten-Takt, aber höchstens `MensaSperrePhasen.maxDauer` weit; dann lädt das
        // Widget neu. Reicht die Zeitleiste bis Mitternacht, gilt wie beim Home-Widget das Neuladen um 6:00.
        let neuladen = sperrbildschirm && MensaSperrePhasen.ende(nach: jetzt) < EventKalender.tag(jetzt, plus: 1)
            ? MensaSperrePhasen.ende(nach: jetzt)
            : MensaWidgetPhasen.naechsteNeuladung(nach: jetzt)
        return Timeline(entries: eintraege, policy: .after(neuladen))
    }

    // MARK: Zeitleiste

    /// So lange gilt der Speicher für den Sperrbildschirm als frisch genug, um nicht nachzuladen.
    static let frischFuerSperre: TimeInterval = 60 * 60

    /// Heutiger Zustand und je einer pro Phasenwechsel bis Mitternacht; auf dem Sperrbildschirm einer alle 5 Minuten.
    static func eintraege(
        snapshot: WidgetSnapshot, ab jetzt: Date, konfiguration: MensaWidgetKonfiguration, family: WidgetFamily = .systemMedium
    ) -> [MensaEintrag] {
        let auswahl = konfiguration.mensa
        let defaults = AppGroup.defaults
        // Der Filter der App gilt nur mit dem Schalter; er wird bei jedem Laden der Zeitleiste neu gelesen.
        let filter: MensaFilter? = konfiguration.filterAnwenden ? MensaFilterStore.load(defaults: defaults) : nil
        let startseite = defaults.string(forKey: AppGroup.heuteMensaSchluessel).flatMap(MensaVenue.init(rawValue:))
            ?? .mensaEhrenberg
        let venue = auswahl.venue ?? startseite
        let gruppe = defaults.string(forKey: AppGroup.preisgruppeSchluessel).flatMap(MensaPriceGroup.init(rawValue:))
            ?? .studierende
        let wechsel = auswahl == .wieStartseite ? MensaWechsel(venue: venue) : nil
        if family.istSperrbildschirm {
            return sperrEintraege(snapshot: snapshot, ab: jetzt, venue: venue, gruppe: gruppe, filter: filter)
        }
        let zeitpunkte = [jetzt] + MensaWidgetPhasen.wechsel(snapshot: snapshot, mensaID: venue.rawValue, nach: jetzt)
        return zeitpunkte.map { zeit in
            MensaEintrag(
                date: zeit,
                anzeige: MensaWidgetPhasen.anzeige(snapshot: snapshot, mensaID: venue.rawValue, preisgruppe: gruppe, jetzt: zeit, filter: filter),
                wechsel: wechsel
            )
        }
    }
}

extension MensaProvider {
    /// Eine Anzeige jetzt und eine je Zeitpunkt der Rotation und der Phasenwechsel. Folgt auf einen Eintrag ein
    /// gleicher, entfällt er (ein einzelnes Gericht ändert sich nicht alle 5 Minuten).
    static func sperrEintraege(
        snapshot: WidgetSnapshot, ab jetzt: Date, venue: MensaVenue, gruppe: MensaPriceGroup, filter: MensaFilter?
    ) -> [MensaEintrag] {
        let zeitpunkte = [jetzt] + MensaSperrePhasen.zeitpunkte(snapshot: snapshot, nach: jetzt)
        var letzte: MensaSperreAnzeige?
        return zeitpunkte.compactMap { zeit in
            let sperre = MensaSperrePhasen.anzeige(
                snapshot: snapshot, mensaID: venue.rawValue, preisgruppe: gruppe, jetzt: zeit, filter: filter
            )
            defer { letzte = sperre }
            guard sperre != letzte else { return nil }
            return MensaEintrag(
                date: zeit,
                anzeige: MensaWidgetPhasen.anzeige(snapshot: snapshot, mensaID: venue.rawValue, preisgruppe: gruppe, jetzt: zeit, filter: filter),
                sperre: sperre
            )
        }
    }
}

extension WidgetFamily {
    /// Zeile, Rechteck oder Kreis auf dem Sperrbildschirm.
    var istSperrbildschirm: Bool {
        switch self {
        case .accessoryInline, .accessoryRectangular, .accessoryCircular: true
        default: false
        }
    }
}

/// Verbindet den Eintrag mit der Größe und der Darstellung des Widgets, die nur die Umgebung kennt.
struct MensaWidgetEintragView: View {
    let eintrag: MensaEintrag
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if family.istSperrbildschirm, let sperre = eintrag.sperre {
            MensaWidgetSperre(sperre: sperre, family: family)
                .containerBackground(for: .widget) {
                    // Rechteck und Kreis liegen auf der Fläche des Systems; die Zeile hat keine.
                    if family == .accessoryInline { Color.clear } else { AccessoryWidgetBackground() }
                }
        } else {
            MensaWidgetView(
                anzeige: eintrag.anzeige,
                groesse: WidgetGroesse(family),
                wechsel: eintrag.wechsel,
                getoent: eintrag.getoentVorschau || renderingMode == .accented
            )
            .containerBackground(Color(.surface), for: .widget)
        }
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
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryRectangular, .accessoryCircular
        ])
        // Der Kopf geht bis an den Rand; Abstände setzt die Ansicht selbst.
        .contentMarginsDisabled()
    }
}
