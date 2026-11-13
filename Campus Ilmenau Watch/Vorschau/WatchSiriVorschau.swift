#if DEBUG
import SwiftUI

/// Previews der Siri-Ansichten auf der Uhr, eine je Tweak `frage` aus `WatchSiri.dc.html` (Zeiten wie dort), jeweils auch
/// mit großer Schrift. Die Karten kommen aus der echten Siri-Logik (`SiriMensa`, `SiriOffen`, …) mit den Daten der
/// anderen Watch-Previews, nicht aus Beispieltexten. 40 und 46 mm: Ziel der Preview wechseln.
@MainActor
private enum SiriVorschau {
    static func zeit(_ uhr: String) -> Date { WatchVorschau.zeit(uhr) }
    static let einstellungen = UhrSiri.mensaEinstellungen(.vorgabe)

    /// Die Mensa, die die Mensa-Ansicht zu dieser Uhrzeit zeigt: nur wenn die Antwort eine andere nennt, wählt der Button.
    static func gezeigt(_ uhr: String) -> MensaVenue {
        UhrSiri.gezeigteMensa(snapshot: WatchVorschau.snapshot(), einstellungen: .vorgabe, andere: nil, jetzt: zeit(uhr))
    }

    static func mensa(_ uhr: String, ernaehrung: Ernaehrung? = nil) -> some View {
        let ergebnis = SiriMensa.heute(
            SiriMensaFrage(ernaehrung: ernaehrung), snapshot: WatchVorschau.snapshot(), einstellungen: einstellungen, jetzt: zeit(uhr)
        )
        guard case .antwort(let antwort) = ergebnis else { return AnyView(EmptyView()) }
        return AnyView(rahmen(UhrSiriMensaAnsicht(karte: antwort.karte, ziel: UhrSiri.mensaZiel(antwort.karte, gezeigt: gezeigt(uhr)))))
    }

    static func offen(_ uhr: String) -> some View {
        let antwort = SiriOffen.antwort(mensa: nil, snapshot: WatchVorschau.snapshot(), einstellungen: einstellungen, jetzt: zeit(uhr))
        return rahmen(UhrSiriOffenAnsicht(karte: antwort.karte, ziel: UhrSiri.offenZiel(antwort.karte, mensa: nil, startseite: .mensaEhrenberg, gezeigt: gezeigt(uhr))))
    }

    static func abendessen(_ uhr: String) -> some View {
        let antwort = SiriAbendessen.antwort(snapshot: WatchVorschau.snapshot(), einstellungen: einstellungen, jetzt: zeit(uhr))
        return rahmen(UhrSiriMensaAnsicht(karte: antwort.karte, ziel: UhrSiri.mensaZiel(antwort.karte, gezeigt: gezeigt(uhr))))
    }

    static func abend(_ uhr: String) -> some View {
        let antwort = SiriAbend.antwort(snapshot: WatchVorschau.snapshot(), jetzt: zeit(uhr))
        return rahmen(UhrSiriAbendAnsicht(karte: antwort.karte, ziel: UhrSiri.abendZiel(antwort.karte)))
    }

    static func merkliste(gefunden: Bool = true) -> some View {
        let liste = gefunden ? WatchVorschau.merkliste : WatchVorschau.merkliste.filter { !$0.istGefunden }
        let antwort = SiriMerkliste.antwort(UhrSiri.merklisteEintraege(liste, staende: WatchVorschau.merklisteStaende))
        return rahmen(UhrSiriMerklisteAnsicht(karte: antwort.karte, ziel: UhrSiri.merklisteZiel))
    }

    /// Wie das System die Ansicht zeigt: auf dem Hintergrund der Uhr, scrollbar.
    static func rahmen<Inhalt: View>(_ inhalt: Inhalt) -> some View {
        ScrollView { inhalt.padding(.horizontal, 4) }
            .containerBackground(Color(.watchBackground), for: .navigation)
    }
}

// Große Schrift, 40 und 46 mm: in der Preview „Dynamic Type“ bzw. das Ziel wechseln (jede Ansicht folgt der Systemschrift).
#Preview("Siri · Mensa heute 11:45") { NavigationStack { SiriVorschau.mensa("11:45") } }
#Preview("Siri · Vegetarisch abends 17:40") { NavigationStack { SiriVorschau.mensa("17:40", ernaehrung: .vegetarisch) } }
#Preview("Siri · Mensa offen? 14:35") { NavigationStack { SiriVorschau.offen("14:35") } }
#Preview("Siri · Abendessen 15:10") { NavigationStack { SiriVorschau.abendessen("15:10") } }
#Preview("Siri · Heute Abend 19:40") { NavigationStack { SiriVorschau.abend("19:40") } }
#Preview("Siri · Merkliste") { NavigationStack { SiriVorschau.merkliste() } }
#Preview("Siri · Merkliste ohne Gefundene") { NavigationStack { SiriVorschau.merkliste(gefunden: false) } }
#endif
