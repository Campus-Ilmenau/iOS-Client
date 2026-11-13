#if DEBUG
import WidgetKit
import SwiftUI

/// Beispieldaten für die Previews der Watch-Widgets: Mensa und Veranstaltungen sind die Beispieldaten der iPhone-Widgets
/// (Donnerstag, 29. Oktober 2026), die Zeiten die des Tweaks `zeit` in `WatchZifferblatt.dc.html`.
enum UhrWidgetVorschau {
    static let mensaStand = MensaWidgetVorschau.snapshot(.mittag)

    private static func zeit(_ uhr: String) -> Date { MensaWidgetVorschau.zeit("2026-10-29", uhr) }

    /// 08:15, 11:45, 14:20 (Ehrenberg zu, Nanoteria offen), 16:00, 17:40, 19:40 und 21:30 (nachts).
    static func mensa(_ uhren: [String] = ["08:15", "11:45", "14:20", "16:00", "17:40", "19:40", "21:30"], einstellungen: UhrEinstellungen = .vorgabe)
        -> [MensaWatchEintrag] {
        uhren.compactMap { MensaWatchProvider.eintraege(snapshot: mensaStand, einstellungen: einstellungen, ab: zeit($0)).first }
    }

    /// Spieleabend 19–23 (Studi-Club), Kneipenquiz 20 (fällt aus), Open Stage 21 (gemerkt), Karaoke 22: wie `WatchEvents.dc.html`.
    static let abendStand: WidgetSnapshot = {
        func event(_ id: String, _ titel: String, _ von: Double, _ bis: Double, _ ort: String, abgesagt: Bool = false) -> WidgetEvent {
            WidgetEvent(id: id, titel: titel, beginn: AbendWidgetVorschau.zeit(von), ende: AbendWidgetVorschau.zeit(bis), ort: ort, abgesagt: abgesagt)
        }
        return WidgetSnapshot(events: [
            event("spiel", "Spieleabend", 19, 23, "Studi-Club"),
            event("quiz", "Kneipenquiz", 20, 23, "Baracke5", abgesagt: true),
            event("stage", "Open Stage", 21, 25, "BC-Club"),
            event("karaoke", "Karaoke-Nacht", 22, 26, "Baracke5")
        ], gemerkteEventIDs: ["stage"])
    }()

    /// 11:45, 17:40, 19:40; dazu „nichts eingetragen“.
    static func abend() -> [AbendWatchEintrag] {
        let uhren: [Double] = [11.75, 17 + 40.0 / 60, 19 + 40.0 / 60]
        let mitDaten = uhren.compactMap { AbendWatchProvider.eintraege(snapshot: abendStand, ab: AbendWidgetVorschau.zeit($0)).first }
        // „Nichts eingetragen“ steht am Ende der Zeitleiste, damit die Reihenfolge der Einträge die der Liste bleibt.
        var leer = AbendWatchProvider.eintraege(snapshot: WidgetSnapshot(), ab: AbendWidgetVorschau.zeit(19.5)).first
        leer?.date = AbendWidgetVorschau.zeit(23.5)
        return mitDaten + (leer.map { [$0] } ?? [])
    }

    /// „3 im Regal“, nichts im Regal, leer.
    static func merkliste() -> [MerklisteWatchEintrag] {
        [3, 0].map {
            MerklisteWatchEintrag(date: .now, anzeige: UhrMerklisteWidgetAnzeige(imRegal: $0, beschriftung: "Merkliste, \($0) im Regal"))
        } + [MerklisteWatchEintrag(date: .now, anzeige: UhrMerklisteWidgetAnzeige(imRegal: nil, beschriftung: "Merkliste, leer"))]
    }
}

#Preview("Mensa · Rechteck", as: .accessoryRectangular) { MensaWatchWidget() } timeline: { for eintrag in UhrWidgetVorschau.mensa() { eintrag } }
#Preview("Mensa · Kreis", as: .accessoryCircular) { MensaWatchWidget() } timeline: { for eintrag in UhrWidgetVorschau.mensa() { eintrag } }
#Preview("Mensa · Ecke", as: .accessoryCorner) { MensaWatchWidget() } timeline: { for eintrag in UhrWidgetVorschau.mensa() { eintrag } }
#Preview("Mensa · Zeile", as: .accessoryInline) { MensaWatchWidget() } timeline: { for eintrag in UhrWidgetVorschau.mensa() { eintrag } }
#Preview("Mensa · Rechteck · Filter", as: .accessoryRectangular) { MensaWatchWidget() } timeline: {
    for eintrag in UhrWidgetVorschau.mensa(["11:45"], einstellungen: UhrEinstellungen(filter: MensaWidgetVorschau.filterVeganOhneMilch)) { eintrag }
}

#Preview("Heute Abend · Rechteck", as: .accessoryRectangular) { AbendWatchWidget() } timeline: { for eintrag in UhrWidgetVorschau.abend() { eintrag } }
#Preview("Heute Abend · Kreis", as: .accessoryCircular) { AbendWatchWidget() } timeline: { for eintrag in UhrWidgetVorschau.abend() { eintrag } }
#Preview("Heute Abend · Zeile", as: .accessoryInline) { AbendWatchWidget() } timeline: { for eintrag in UhrWidgetVorschau.abend() { eintrag } }

#Preview("Merkliste · Kreis", as: .accessoryCircular) { MerklisteWatchWidget() } timeline: { for eintrag in UhrWidgetVorschau.merkliste() { eintrag } }
#endif
