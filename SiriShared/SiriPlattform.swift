import SwiftUI

/// Die Stellen, an denen iPhone und Uhr bei Siri verschiedene Wege gehen. Die Intents in diesem Ordner und die Logik
/// in `Shared/` sind für beide dieselben; hier steht nur, woher Einstellungen und Merkliste kommen und wie die Karte
/// aussieht:
/// - iPhone: Einstellungen aus der App Group, Merkliste der App mit frischem `/availability`, Karten aus `SiriKarten.swift`.
/// - Uhr: Einstellungen und Merkliste aus der Watch-Gruppe (`UhrSpeicher`), Karten im Stil der Watch-Karten
///   (`WatchSiriAnsichten.swift`) mit dem Button „In der App öffnen“.
@MainActor
enum SiriPlattform {
    static func mensaEinstellungen() -> SiriMensaEinstellungen {
        #if os(watchOS)
        UhrSiri.mensaEinstellungen(UhrSpeicher.einstellungen())
        #else
        SiriMensaEinstellungen.lesen()
        #endif
    }

    static func merkliste() async -> SiriMerklisteAntwort {
        #if os(watchOS)
        // Standort und Signatur erst selbst laden (`/availability`, Zeitlimit 4 s); klappt das nicht, gilt der letzte Stand
        // aus der Watch-Gruppe. `ladeStaende` speichert den neuen Stand dort und meldet ihn den Komplikationen.
        let merkliste = UhrMerkliste.shared
        await merkliste.ladeStaende(erzwingen: true)
        return UhrSiri.merklisteAntwort(eintraege: merkliste.eintraege, staende: merkliste.staende)
        #else
        await SiriKatalogDaten.merkliste(BibMerklisteStore.shared.eintraege)
        #endif
    }

    // MARK: Karten

    #if os(watchOS)
    /// Die Mensa, die die Mensa-Ansicht der Uhr jetzt zeigt (mit der „Andere Mensa“ von heute): Nur wenn die Antwort eine
    /// andere nennt, wählt „In der App öffnen“ sie.
    private static func gezeigteMensa(snapshot: WidgetSnapshot, jetzt: Date) -> MensaVenue {
        UhrSiri.gezeigteMensa(
            snapshot: snapshot, einstellungen: UhrSpeicher.einstellungen(), andere: AndereMensa.gespeichert(), jetzt: jetzt
        )
    }
    #endif

    @ViewBuilder
    static func mensaAnsicht(_ antwort: SiriMensaAntwort, snapshot: WidgetSnapshot, jetzt: Date) -> some View {
        #if os(watchOS)
        UhrSiriMensaAnsicht(karte: antwort.karte, ziel: UhrSiri.mensaZiel(antwort.karte, gezeigt: gezeigteMensa(snapshot: snapshot, jetzt: jetzt)))
        #else
        SiriMensaAntwortView(karte: antwort.karte)
        #endif
    }

    @ViewBuilder
    static func offenAnsicht(_ antwort: SiriOffenAntwort, mensa: MensaOrt?, snapshot: WidgetSnapshot, jetzt: Date) -> some View {
        #if os(watchOS)
        UhrSiriOffenAnsicht(
            karte: antwort.karte,
            ziel: UhrSiri.offenZiel(
                antwort.karte, mensa: mensa, startseite: UhrSpeicher.einstellungen().mensa,
                gezeigt: gezeigteMensa(snapshot: snapshot, jetzt: jetzt)
            )
        )
        #else
        SiriOffenAntwortView(karte: antwort.karte)
        #endif
    }

    @ViewBuilder
    static func abendAnsicht(_ antwort: SiriAbendAntwort) -> some View {
        #if os(watchOS)
        UhrSiriAbendAnsicht(karte: antwort.karte, ziel: UhrSiri.abendZiel(antwort.karte))
        #else
        SiriAbendAntwortView(karte: antwort.karte)
        #endif
    }

    @ViewBuilder
    static func merklisteAnsicht(_ antwort: SiriMerklisteAntwort) -> some View {
        #if os(watchOS)
        UhrSiriMerklisteAnsicht(karte: antwort.karte, ziel: UhrSiri.merklisteZiel)
        #else
        SiriMerklisteAntwortView(karte: antwort.karte)
        #endif
    }
}
