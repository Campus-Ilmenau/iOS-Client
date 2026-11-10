import Foundation

/// Alles, was der Bibliotheksausweis anzeigt. Entsteht beim Öffnen und lebt nur so lange wie die Ansicht:
/// nichts davon wird gespeichert (siehe `PAIAService.patron`).
struct BibliotheksausweisDaten: Identifiable {
    let id = UUID()
    let benutzernummer: String
    /// Name aus dem Abruf, sonst aus dem letzten Abruf der Sitzung.
    let name: String?
    /// Das Konto aus dem frischen Abruf. `nil`, wenn `/core/{patron}` fehlschlug: Dann entfallen
    /// „Gültig bis“, Nutzergruppe und Status.
    let konto: PAIAPatron?
    let nutzergruppe: String?

    init(benutzernummer: String, name: String?, konto: PAIAPatron?, nutzergruppe: String? = nil) {
        self.benutzernummer = benutzernummer
        self.name = Self.bereinigt(name)
        self.konto = konto
        self.nutzergruppe = nutzergruppe ?? konto?.nutzergruppe
    }

    /// `frisch` ist das Ergebnis des Abrufs beim Öffnen (`nil` bei Fehler), `letzter` der Stand der Sitzung.
    init(benutzernummer: String, frisch: PAIAPatron?, letzter: PAIAPatron?) {
        self.init(benutzernummer: benutzernummer, name: frisch?.name ?? letzter?.name, konto: frisch)
    }

    /// 0 = nichts. 1 bis 4 gemäß PAIA.
    var status: Int { konto?.status ?? 0 }

    /// Hinweis der Bibliothek (`note`), leer wird zu `nil`.
    var hinweis: String? { Self.bereinigt(konto?.note) }

    /// Text für den Status-Kasten, genau wie in der Übergabe. Bei Status 0 oder unbekannt `nil`.
    var statusText: String? {
        switch status {
        case 1: "Konto gesperrt – bitte an der Ausleihtheke melden."
        case 2: "Ausweis abgelaufen – bitte an der Ausleihtheke verlängern lassen."
        case 3: "Konto gesperrt wegen offener Gebühren – bitte an der Ausleihtheke bezahlen."
        case 4: "Ausweis abgelaufen und Gebühren offen – bitte an der Ausleihtheke melden."
        default: nil
        }
    }

    /// „Gültig bis“ als TT.MM.JJJJ, oder `nil` (dann entfällt die Zeile).
    var gueltigBis: String? { konto?.expires.map(Self.datum) }

    /// Datum in `danger`: das Datum liegt in der Vergangenheit oder der Status ist 2 bzw. 4.
    func gueltigBisIstKritisch(am now: Date = .now) -> Bool {
        if status == 2 || status == 4 { return true }
        guard let expires = konto?.expires else { return false }
        return Self.istVorbei(expires, am: now)
    }

    // MARK: - Hilfen

    private static func bereinigt(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    /// PAIA liefert `expires` als reines Datum, das der Dekoder als Mitternacht UTC liest; also in UTC formatieren.
    static func datum(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    /// Das Datum zählt als vorbei, wenn sein Kalendertag vor dem heutigen liegt: Am Tag „Gültig bis“ gilt der Ausweis noch.
    static func istVorbei(_ expires: Date, am now: Date) -> Bool {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let ende = utc.dateComponents([.year, .month, .day], from: expires)
        let heute = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let a = [ende.year ?? 0, ende.month ?? 0, ende.day ?? 0]
        let b = [heute.year ?? 0, heute.month ?? 0, heute.day ?? 0]
        return a.lexicographicallyPrecedes(b)
    }

    /// Restzeit als m:ss, z. B. „1:58“.
    static func restzeit(sekunden: Int) -> String {
        let s = max(0, sekunden)
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }
}
