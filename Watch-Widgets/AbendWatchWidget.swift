import WidgetKit
import SwiftUI

/// Ein Zustand des Widgets „Heute Abend“, fertig berechnet.
struct AbendWatchEintrag: TimelineEntry {
    var date: Date
    let anzeige: UhrAbendWidgetAnzeige
    var relevance: TimelineEntryRelevance?
}

/// Legt die Zeitleiste an (`UhrAbendZeitleiste`): ein Eintrag zu jedem Beginn und Ende, danach Neuladen nach einer
/// Stunde. Wie auf dem iPhone holt das Widget die Events beim Laden selbst (öffentliche Events-API, Zeitlimit 4 s), denn
/// eine Absage sieht es nur so, und schreibt sie in den `WidgetStore` der Watch-Gruppe. Klappt das nicht (offline,
/// Zeitlimit), gilt der Stand der Watch-App. Die Debug-Uhr `WidgetUhr` gilt wie auf dem iPhone.
struct AbendWatchProvider: TimelineProvider {
    /// Wie lange das Widget auf die Events-API wartet; so lange wie die Watch-App (`UhrDaten.zeitlimit`).
    static let zeitlimit: Duration = .seconds(4)

    private let store: WidgetStore
    private let quelle: @MainActor () -> any EventsDatenquelle

    init(store: WidgetStore = WidgetStore(), quelle: @escaping @MainActor () -> any EventsDatenquelle = { EventsService() }) {
        self.store = store
        self.quelle = quelle
    }

    func placeholder(in context: Context) -> AbendWatchEintrag {
        AbendWatchEintrag(date: .now, anzeige: UhrAbendWidgetAnzeige.erstelle(snapshot: WidgetSnapshot(), jetzt: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (AbendWatchEintrag) -> Void) {
        // Die Galerie und Momentaufnahmen laden nichts nach: sie zeigen den Speicher.
        completion(context.isPreview ? placeholder(in: context) : eintraege(ab: WidgetUhr.jetzt).first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AbendWatchEintrag>) -> Void) {
        let store = store
        let quelle = quelle
        Task { @MainActor in
            let jetzt = WidgetUhr.jetzt
            await WidgetEventsAktualisierung(store: store)
                .ladeUndSpeichere(quelle: quelle(), jetzt: jetzt, zeitlimit: Self.zeitlimit)
            let eintraege = WidgetUhr.eintraege(eintraege(ab: jetzt)) { $0.date = $1 }
            completion(Timeline(entries: eintraege, policy: .after(UhrAbendZeitleiste.neuladen(nach: jetzt))))
        }
    }

    private func eintraege(ab jetzt: Date) -> [AbendWatchEintrag] {
        Self.eintraege(snapshot: store.lesen(), ab: jetzt)
    }

    static func eintraege(snapshot: WidgetSnapshot, ab jetzt: Date) -> [AbendWatchEintrag] {
        UhrAbendZeitleiste.eintraege(snapshot: snapshot, ab: jetzt).map {
            AbendWatchEintrag(date: $0.date, anzeige: $0.anzeige, relevance: $0.relevanz.eintragRelevanz)
        }
    }
}

/// Das Widget „Heute Abend“ auf dem Zifferblatt: Rechteck, Kreis und Zeile.
struct AbendWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: UhrWidgetKinds.heuteAbend, provider: AbendWatchProvider()) { eintrag in
            AbendWatchView(anzeige: eintrag.anzeige)
        }
        .configurationDisplayName("Heute Abend")
        .description("Die nächsten Veranstaltungen in Ilmenau.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

/// Die Familien. `widgetAccentable()` tragen nur Mond und Kicker.
struct AbendWatchView: View {
    let anzeige: UhrAbendWidgetAnzeige
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                rechteck
            case .accessoryInline:
                zeile
            default:
                kreis
            }
        }
        .widgetURL(anzeige.link)
        .uhrWidgetHintergrund(family)
    }

    /// Die Zeile. Ist gar nichts eingetragen, ist der lange Text („Heute Abend nichts eingetragen“) für die Zeile zu
    /// lang und würde mit „…“ enden: Dann folgen „Heute Abend frei“ und „Abend frei“, sobald der vorige nicht passt.
    @ViewBuilder
    private var zeile: some View {
        if anzeige.istLeer, anzeige.kreisZeit == nil {
            ViewThatFits(in: .horizontal) {
                zeilenLabel(anzeige.zeile)
                zeilenLabel("Heute Abend frei")
                zeilenLabel("Abend frei")
            }
        } else {
            Label {
                Text(anzeige.zeile).lineLimit(1).minimumScaleFactor(0.6)
            } icon: {
                Image(systemName: "moon.fill").widgetAccentable()
            }
        }
    }

    private func zeilenLabel(_ text: String) -> some View {
        Label {
            Text(text).lineLimit(1).fixedSize(horizontal: true, vertical: false)
        } icon: {
            Image(systemName: "moon.fill").widgetAccentable()
        }
    }

    /// Kicker mit Mond („LÄUFT GERADE · STUDI-CLUB“), Titel (2 Zeilen), unten „Dann 21:00“ und das Nächste.
    private var rechteck: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 10))
                Text(anzeige.kicker)
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.22)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .widgetAccentable()
            if anzeige.istLeer {
                Text("Heute Abend nichts eingetragen")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(anzeige.titel)
                        .font(.system(size: 14, weight: .semibold))
                        .strikethrough(anzeige.abgesagt)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if anzeige.gemerkt {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .accessibilityLabel("gemerkt")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(anzeige.links)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Text(anzeige.rechts)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: 12))
                .monospacedDigit()
                .opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Mond, Uhrzeit des Nächsten und Kurztitel; ohne Veranstaltung nur der Mond.
    @ViewBuilder
    private var kreis: some View {
        Group {
            if let zeit = anzeige.kreisZeit {
                VStack(spacing: 0) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                        .widgetAccentable()
                    Text(zeit)
                        .font(.system(size: 16, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !anzeige.kreisWort.isEmpty {
                        // Der Titel, wenn er passt; sonst „Abend“.
                        UhrKreisWort(text: anzeige.kreisWort, ersatz: "Abend")
                    }
                }
            } else {
                Image(systemName: "moon.fill")
                    .font(.system(size: 22))
                    .widgetAccentable()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(anzeige.kreisBeschriftung)
    }
}
