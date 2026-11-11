import Foundation

/// Wann die App den Siri-Tipp (`SiriTipView`) zeigt. Die Schlüssel liegen in `@AppStorage`; nach dem × erscheint der Tipp
/// nie wieder. Kein Tipp in Thoska und Bibliothek. Regeln aus `Uebergabe.md`, „Kurzbefehle-App, Spotlight, Tipps“.
enum SiriTipp {
    /// Der Speiseplan zeigt den Tipp ab dem 3. Öffnen.
    static let mensaAbOeffnung = 3

    /// Wie oft der Speiseplan geöffnet wurde.
    static let mensaOeffnungen = "siriTippMensaOeffnungen"
    /// Der Nutzer hat den Tipp im Speiseplan mit × geschlossen.
    static let mensaVerborgen = "siriTippMensaVerborgen"
    /// Der Tipp in „Heute Abend“ ist schon erschienen (er erscheint nur einmal, auch ohne ×).
    static let abendGezeigt = "siriTippAbendGezeigt"

    static func zeigtMensa(oeffnungen: Int, verborgen: Bool) -> Bool {
        !verborgen && oeffnungen >= mensaAbOeffnung
    }

    /// Der Tipp in „Heute Abend“ erscheint genau einmal: beim ersten Mal, dass die Liste „Heute Abend“ zeigt.
    static func zeigtAbendErstmals(heuteAbendAktiv: Bool, schonGezeigt: Bool) -> Bool {
        heuteAbendAktiv && !schonGezeigt
    }
}
