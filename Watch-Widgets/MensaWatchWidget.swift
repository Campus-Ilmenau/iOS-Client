import WidgetKit
import SwiftUI

/// Ein Zustand des Widgets „Mensa heute“: ein Gericht und die Texte der vier Familien, fertig berechnet.
struct MensaWatchEintrag: TimelineEntry {
    var date: Date
    let sperre: MensaSperreAnzeige
    /// Wie wichtig der Eintrag im Smart Stack gerade ist.
    var relevance: TimelineEntryRelevance?
}

/// Legt die Zeitleiste an (`UhrMensaZeitleiste`). Wie auf dem iPhone holt das Widget den Speiseplan beim Laden selbst
/// (öffentliche Mensa-API, Zeitlimit 4 s) und schreibt ihn in den `WidgetStore` der Watch-Gruppe. Klappt das nicht
/// (offline, Zeitlimit), gilt der Stand, den die Watch-App dort abgelegt hat. Mensa, Preisgruppe und Filter kommen vom
/// iPhone (`UhrSpeicher`). Die Debug-Uhr `WidgetUhr` gilt wie auf dem iPhone.
struct MensaWatchProvider: TimelineProvider {
    /// Wie lange das Widget auf die Mensa-API wartet; so lange wie die Watch-App (`UhrDaten.zeitlimit`).
    static let zeitlimit: Duration = .seconds(4)
    /// So lange gilt der Speicher als frisch genug, um nicht nachzuladen: Die Zeitleiste reicht höchstens 3 Stunden, die
    /// Rotation selbst kostet weder Budget noch Netz (wie beim Sperrbildschirm des iPhones).
    static let frischFuer: TimeInterval = 60 * 60

    private let store: WidgetStore
    private let defaults: UserDefaults
    private let quelle: @MainActor () -> any MensaDatenquelle

    init(
        store: WidgetStore = WidgetStore(), defaults: UserDefaults = AppGroup.defaults,
        quelle: @escaping @MainActor () -> any MensaDatenquelle = { MensaHeuteQuelle() }
    ) {
        self.store = store
        self.defaults = defaults
        self.quelle = quelle
    }

    func placeholder(in context: Context) -> MensaWatchEintrag {
        MensaWatchEintrag(date: .now, sperre: MensaWidgetVorschau.sperre(.mittag))
    }

    func getSnapshot(in context: Context, completion: @escaping (MensaWatchEintrag) -> Void) {
        // Die Galerie und Momentaufnahmen laden nichts nach: sie zeigen den Speicher.
        completion(context.isPreview ? placeholder(in: context) : eintraege(ab: WidgetUhr.jetzt).first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MensaWatchEintrag>) -> Void) {
        let store = store
        let quelle = quelle
        Task { @MainActor in
            let jetzt = WidgetUhr.jetzt
            let frisch = store.lesen().stand.map { jetzt.timeIntervalSince($0) < Self.frischFuer } ?? false
            if !frisch {
                await WidgetMensaAktualisierung(store: store)
                    .ladeUndSpeichere(quelle: quelle(), jetzt: jetzt, zeitlimit: Self.zeitlimit)
            }
            let eintraege = WidgetUhr.eintraege(eintraege(ab: jetzt)) { $0.date = $1 }
            completion(Timeline(entries: eintraege, policy: .after(UhrMensaZeitleiste.neuladen(nach: jetzt))))
        }
    }

    private func eintraege(ab jetzt: Date) -> [MensaWatchEintrag] {
        Self.eintraege(snapshot: store.lesen(), einstellungen: UhrSpeicher.einstellungen(defaults: defaults), ab: jetzt)
    }

    static func eintraege(snapshot: WidgetSnapshot, einstellungen: UhrEinstellungen, ab jetzt: Date) -> [MensaWatchEintrag] {
        UhrMensaZeitleiste.eintraege(snapshot: snapshot, einstellungen: einstellungen, ab: jetzt).map {
            MensaWatchEintrag(date: $0.date, sperre: $0.sperre, relevance: $0.relevanz.eintragRelevanz)
        }
    }
}

/// Das Widget „Mensa heute“ auf dem Zifferblatt: Rechteck, Kreis, Ecke und Zeile.
struct MensaWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: UhrWidgetKinds.mensa, provider: MensaWatchProvider()) { eintrag in
            MensaWatchView(sperre: eintrag.sperre)
        }
        .configurationDisplayName("Mensa heute")
        .description("Was es gerade in deiner Mensa gibt.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

/// Die Familien. Die Farben bestimmt das Zifferblatt; `widgetAccentable()` tragen nur Symbol und Kicker.
struct MensaWatchView: View {
    let sperre: MensaSperreAnzeige
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                rechteck.widgetURL(UhrMensaLink.url(sperre, rechteck: true))
            case .accessoryCorner:
                // Die Gabel in der Ecke, die Zeile des Sperrbildschirms folgt der Rundung des Zifferblatts.
                Image(systemName: "fork.knife")
                    .font(.system(size: 20, weight: .semibold))
                    .widgetAccentable()
                    .widgetLabel { Text(sperre.zeile) }
                    .widgetURL(UhrMensaLink.url(sperre))
            case .accessoryInline:
                Label {
                    Text(sperre.zeile).lineLimit(1).minimumScaleFactor(0.6)
                } icon: {
                    Image(systemName: "fork.knife").widgetAccentable()
                }
                .widgetURL(UhrMensaLink.url(sperre))
            default:
                kreis.widgetURL(UhrMensaLink.url(sperre))
            }
        }
        .uhrWidgetHintergrund(family)
    }

    /// Kicker mit Gabel („EHRENBERG · BIS 14:00“, ggf. Filter-Symbol), Gericht (2 Zeilen), unten Preis und „1/3“.
    /// Wo die Höhe nicht für Titel (2 Zeilen) und Preiszeile reicht (40 mm), entfällt die Preiszeile; der Titel bleibt
    /// in 14 pt und bekommt seine zwei Zeilen.
    private var rechteck: some View {
        ViewThatFits(in: .vertical) {
            rechteckInhalt(mitPreiszeile: true)
            rechteckInhalt(mitPreiszeile: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rechteckBeschriftung)
    }

    /// Alles, auch die Preiszeile, die auf kleinen Uhren fehlen kann.
    private var rechteckBeschriftung: String {
        let titel = sperre.gericht?.name ?? sperre.leerTitel
        let preis = sperre.gericht?.preis ?? sperre.leerDetail
        let position = sperre.anzahl > 1 ? "Gericht \(sperre.position) von \(sperre.anzahl)" : ""
        return [sperre.kicker, titel, preis, position].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private func rechteckInhalt(mitPreiszeile: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 10, weight: .bold))
                Text(sperre.kicker)
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.22)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if sperre.filterung != nil {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .widgetAccentable()
            Text(sperre.gericht?.name ?? sperre.leerTitel)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if mitPreiszeile {
                HStack {
                    Text(sperre.gericht?.preis ?? sperre.leerDetail)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Text(sperre.positionText)
                }
                .font(.system(size: 12))
                .monospacedDigit()
                .opacity(0.8)
            }
        }
    }

    /// Gabel, Uhrzeit und ein kurzes Wort („14:00 bis“, „16:30 Abend“, „15:00 Nanoteria“, nachts „Fr 11:00“).
    private var kreis: some View {
        VStack(spacing: 0) {
            Image(systemName: "fork.knife")
                .font(.system(size: 12, weight: .semibold))
                .widgetAccentable()
            Text(sperre.kreisGross)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !sperre.kreisKlein.isEmpty {
                // „Nanoteria“ (Noch offen) wird zu „bis“, wenn es nicht passt.
                UhrKreisWort(text: sperre.kreisKlein, ersatz: sperre.phase == .nochOffen ? "bis" : sperre.kreisKlein)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sperre.kreisBeschriftung)
    }
}
