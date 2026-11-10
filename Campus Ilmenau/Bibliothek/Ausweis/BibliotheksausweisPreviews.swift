import SwiftUI

/// Beispiele für alle Zustände aus dem Mockup (Tweaks `konto`, `nutzergruppe`, `hinweis`).
enum BibliotheksausweisBeispiele {
    private static func datum(_ jahr: Int, _ monat: Int, _ tag: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.date(from: DateComponents(year: jahr, month: monat, day: tag)) ?? .now
    }

    static func konto(
        status: Int = 0,
        gruppe: String? = "Studierende",
        hinweis: Bool = false,
        abgelaufen: Bool = false
    ) -> BibliotheksausweisDaten {
        let patron = PAIAPatron(
            name: "Lena Schubert",
            expires: abgelaufen ? datum(2026, 9, 30) : datum(2027, 9, 30),
            status: status,
            type: [],
            note: hinweis ? "Bitte gib bei deinem nächsten Besuch deine neue Anschrift an der Ausleihtheke an." : nil
        )
        return BibliotheksausweisDaten(benutzernummer: "3400056749X", name: patron.name, konto: patron, nutzergruppe: gruppe)
    }

    /// `/core/{patron}` ist fehlgeschlagen: nur Nummer (und ein Name aus dem letzten Abruf).
    static let ohneKonto = BibliotheksausweisDaten(benutzernummer: "3400056749X", name: "Lena Schubert", konto: nil)
}

private struct AusweisVorschau: View {
    let daten: BibliotheksausweisDaten

    var body: some View {
        // Lange Dauer, damit die Vorschau nicht von selbst schließt.
        BibliotheksausweisView(daten: daten, dauer: 3600, onClose: { _ in })
    }
}

#Preview("Aktiv – Hell") {
    AusweisVorschau(daten: BibliotheksausweisBeispiele.konto())
}

#Preview("Aktiv – Dunkel") {
    AusweisVorschau(daten: BibliotheksausweisBeispiele.konto()).preferredColorScheme(.dark)
}

#Preview("Gesperrt, Gebühren, Hinweis – Hell") {
    AusweisVorschau(daten: BibliotheksausweisBeispiele.konto(status: 3, hinweis: true))
}

#Preview("Gesperrt, Gebühren, Hinweis – Dunkel") {
    AusweisVorschau(daten: BibliotheksausweisBeispiele.konto(status: 3, hinweis: true)).preferredColorScheme(.dark)
}

#Preview("Abgelaufen") {
    AusweisVorschau(daten: BibliotheksausweisBeispiele.konto(status: 2, abgelaufen: true))
}

#Preview("Abgelaufen + Gebühren, Beschäftigte") {
    AusweisVorschau(daten: BibliotheksausweisBeispiele.konto(status: 4, gruppe: "Beschäftigte", abgelaufen: true))
}

#Preview("Gesperrt (1), ohne Gruppe") {
    AusweisVorschau(daten: BibliotheksausweisBeispiele.konto(status: 1, gruppe: nil))
}

#Preview("Abruf fehlgeschlagen") {
    AusweisVorschau(daten: BibliotheksausweisBeispiele.ohneKonto)
}

#Preview("Große Schrift – Hell") {
    AusweisVorschau(daten: BibliotheksausweisBeispiele.konto(status: 3, hinweis: true))
        .dynamicTypeSize(.accessibility3)
}

#Preview("Große Schrift – Dunkel") {
    AusweisVorschau(daten: BibliotheksausweisBeispiele.konto())
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}
