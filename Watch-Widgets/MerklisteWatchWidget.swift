import WidgetKit
import SwiftUI

/// Der Stand der Merkliste für den Kreis „3 im Regal“.
struct MerklisteWatchEintrag: TimelineEntry {
    var date: Date
    let anzeige: UhrMerklisteWidgetAnzeige
}

/// Liest Merkliste und Standorte aus der Watch-App-Group. Es gibt einen Eintrag; die Watch-App lädt die Zeitleiste neu,
/// nach jedem Abhaken und mit jedem neuen Stand vom iPhone.
struct MerklisteWatchProvider: TimelineProvider {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    func placeholder(in context: Context) -> MerklisteWatchEintrag {
        MerklisteWatchEintrag(date: .now, anzeige: UhrMerklisteWidgetAnzeige(imRegal: 3, beschriftung: "Merkliste, 3 im Regal"))
    }

    func getSnapshot(in context: Context, completion: @escaping (MerklisteWatchEintrag) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : MerklisteWatchEintrag(date: .now, anzeige: .gespeichert(defaults: defaults)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MerklisteWatchEintrag>) -> Void) {
        let jetzt = Date.now
        let eintrag = MerklisteWatchEintrag(date: jetzt, anzeige: .gespeichert(defaults: defaults))
        // Neuer Stand kommt von der Watch-App; zur Sicherheit nach einer Stunde noch einmal lesen.
        completion(Timeline(entries: [eintrag], policy: .after(jetzt.addingTimeInterval(60 * 60))))
    }
}

/// Das Widget „Merkliste“ auf dem Zifferblatt: ein Kreis.
struct MerklisteWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: UhrWidgetKinds.merkliste, provider: MerklisteWatchProvider()) { eintrag in
            MerklisteWatchView(anzeige: eintrag.anzeige)
        }
        .configurationDisplayName("Merkliste")
        .description("Wie viele Titel deiner Merkliste im Regal stehen.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// Lesezeichen, Zahl und „im Regal“; ohne Einträge nur das Lesezeichen. Das Symbol ist `widgetAccentable()`.
struct MerklisteWatchView: View {
    let anzeige: UhrMerklisteWidgetAnzeige
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let zahl = anzeige.imRegal {
                VStack(spacing: 0) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 12, weight: .semibold))
                        .widgetAccentable()
                    Text("\(zahl)")
                        .font(.system(size: 18, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    UhrKreisWort(text: "im Regal", ersatz: "Regal")
                }
            } else {
                Image(systemName: "bookmark")
                    .font(.system(size: 22, weight: .semibold))
                    .widgetAccentable()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(anzeige.beschriftung)
        .widgetURL(DeepLink.merkliste.url)
        .uhrWidgetHintergrund(family)
    }
}
