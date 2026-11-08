import WidgetKit
import SwiftUI

/// Ein Zustand des Widgets „Heute Abend“: alles, was die Ansicht braucht, ist schon als Text berechnet.
struct AbendEintrag: TimelineEntry {
    let date: Date
    let anzeige: AbendWidgetAnzeige
    /// Nur für Previews: zeichnet auch ohne Tönung des Systems so, wie „Getönt / Klar“ aussieht.
    var getoentVorschau = false
}

/// Liefert die Zeitleiste: ein Eintrag zu jedem Beginn und Ende (dann wechselt „Läuft gerade“ ohne Nachladen),
/// danach Neuladen nach einer Stunde. Beim Laden holt das Widget die Events selbst über die öffentliche Events-API
/// (ohne Anmeldung) und schreibt sie in den `WidgetStore`, denn eine Absage sieht es nur so. Klappt das nicht
/// (offline, Zeitlimit), gilt der Speicher der App.
struct AbendProvider: TimelineProvider {
    /// Wie lange das Widget auf die Events-API wartet. Kurz, denn das System gibt einer Zeitleiste nur wenig Zeit.
    static let zeitlimit: Duration = .seconds(6)

    private let store: WidgetStore
    private let quelle: @MainActor () -> any EventsDatenquelle

    init(store: WidgetStore = WidgetStore(), quelle: @escaping @MainActor () -> any EventsDatenquelle = { EventsService() }) {
        self.store = store
        self.quelle = quelle
    }

    func placeholder(in context: Context) -> AbendEintrag {
        AbendEintrag(date: .now, anzeige: AbendWidgetVorschau.anzeige(.abend1830))
    }

    func getSnapshot(in context: Context, completion: @escaping (AbendEintrag) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        // Die Galerie und Momentaufnahmen laden nichts nach: sie zeigen den Speicher.
        completion(Self.eintraege(snapshot: store.lesen(), ab: .now).first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AbendEintrag>) -> Void) {
        let store = store
        let quelle = quelle
        Task { @MainActor in
            let jetzt = Date.now
            await WidgetEventsAktualisierung(store: store)
                .ladeUndSpeichere(quelle: quelle(), jetzt: jetzt, zeitlimit: Self.zeitlimit)
            let eintraege = Self.eintraege(snapshot: store.lesen(), ab: jetzt)
            completion(Timeline(entries: eintraege, policy: .after(AbendWidgetPhasen.zeitleistenEnde(nach: jetzt))))
        }
    }

    // MARK: Zeitleiste

    /// Der heutige Zustand und je einer pro Beginn und Ende.
    static func eintraege(snapshot: WidgetSnapshot, ab jetzt: Date) -> [AbendEintrag] {
        let gemerkt = Set(snapshot.gemerkteEventIDs)
        let zeitpunkte = [jetzt] + AbendWidgetPhasen.wechsel(events: snapshot.events, nach: jetzt)
        return zeitpunkte.map { zeit in
            AbendEintrag(
                date: zeit,
                anzeige: AbendWidgetPhasen.anzeige(events: snapshot.events, gemerkteIDs: gemerkt, woche: snapshot.woche, jetzt: zeit)
            )
        }
    }
}

/// Verbindet den Eintrag mit der Familie und der Darstellung des Widgets, die nur die Umgebung kennt.
struct AbendWidgetEintragView: View {
    let eintrag: AbendEintrag
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    private var getoent: Bool { eintrag.getoentVorschau || renderingMode == .accented }

    private var istSperrbildschirm: Bool {
        switch family {
        case .accessoryInline, .accessoryRectangular, .accessoryCircular: true
        default: false
        }
    }

    var body: some View {
        Group {
            if istSperrbildschirm {
                AbendWidgetSperre(sperre: eintrag.anzeige.sperre, family: family)
                    .containerBackground(for: .widget) { sperrHintergrund }
            } else {
                let groesse = WidgetGroesse(family)
                AbendWidgetView(anzeige: eintrag.anzeige, groesse: groesse, getoent: getoent)
                    .containerBackground(for: .widget) { hintergrund(groesse) }
            }
        }
    }

    /// Rechteck und Kreis liegen auf der Fläche des Systems; die Zeile hat keine.
    @ViewBuilder
    private var sperrHintergrund: some View {
        if family == .accessoryInline { Color.clear } else { AccessoryWidgetBackground() }
    }

    /// Klein ist immer nachtblau: im hellen Modus `brandNight`, im dunklen `surfaceSecondary`, damit es sich vom
    /// Hintergrund abhebt. Mittel und groß haben die normale Fläche. Getönt zeichnet das System den Grund.
    @ViewBuilder
    private func hintergrund(_ groesse: WidgetGroesse) -> some View {
        if getoent {
            Color.clear
        } else if groesse == .klein {
            colorScheme == .dark ? Color(.surfaceSecondary) : Color(.brandNight)
        } else {
            Color(.surface)
        }
    }
}

/// Das Widget „Heute Abend“: klein, mittel und groß auf dem Home-Bildschirm, dazu Zeile, Rechteck und Kreis auf dem
/// Sperrbildschirm. Alle Familien teilen Provider, Zeitleiste und Anzeige-Logik.
struct AbendWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.heuteAbend, provider: AbendProvider()) { eintrag in
            AbendWidgetEintragView(eintrag: eintrag)
        }
        .configurationDisplayName("Heute Abend")
        .description("Die nächsten Veranstaltungen in Ilmenau.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryRectangular, .accessoryCircular
        ])
    }
}
