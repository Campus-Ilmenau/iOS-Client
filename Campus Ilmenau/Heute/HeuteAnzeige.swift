import Foundation

/// Wohin ein Tipp auf Karte, Link oder Termin führt. Die Ansicht übersetzt das in Navigation.
enum HeuteZiel: Equatable {
    /// Speiseplan im Mensa-Tab, mit dieser Mensa.
    case speiseplan(MensaVenue)
    case oeffnungszeiten(MensaVenue)
    case event(CampusEvent)
    case alleEvents
}

/// Eine Zeile der Jetzt-Karte: Gericht mit Chips und Preis, oder „Danach: …“ mit Zeit.
struct HeuteZeile: Identifiable, Equatable {
    let id: String
    let name: String
    let chips: [MensaChipItem]
    /// Preis bzw. Zeit rechts.
    let rechts: String?
}

/// Fertige Anzeige der Jetzt-Karte.
struct HeuteJetztKarte: Equatable {
    enum Stil: Equatable {
        /// Kopf Blau mit grünem Band.
        case mensa
        /// Kopf Nachtblau mit Sonnen-Ausschnitt.
        case event
    }

    /// „Heute“, „Jetzt“, „Gleich“, steht über der Karte.
    let ueberschrift: String
    let kicker: String
    let titel: String
    let unterzeile: String
    let zeilen: [HeuteZeile]
    let linkText: String
    let ziel: HeuteZiel
    /// „Mensa ändern“ neben der Überschrift.
    let mensaAendernSichtbar: Bool
    let stil: Stil
}

/// Farbpunkt eines Termins in „Als Nächstes“.
enum HeuteFarbe: Equatable {
    /// Mensa und Abendessen
    case brandOrange
    /// Events
    case blue
}

/// Ein Eintrag von „Als Nächstes“.
struct HeuteTermin: Identifiable, Equatable {
    let id: String
    /// „11:00“ oder Wochentag „Fr“
    let zeit: String
    let farbe: HeuteFarbe
    let titel: String
    let unterzeile: String
    let ziel: HeuteZiel
}
