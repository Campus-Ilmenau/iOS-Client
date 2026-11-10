import CoreGraphics
import Foundation
import LocalAuthentication
import Testing
@testable import Campus_Ilmenau

struct BibliotheksausweisTests {
    @Test func patronUebernimmtNurDieAusweisFelder() throws {
        let json = """
        {"name":"Muster, Max","email":"max@example.org","address":"Musterweg 1",
         "expires":"2027-03-31","status":2,"type":["urn:x:student"],"note":"Bitte melden"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // `expires` kommt vom Server als Datum; hier genügt ein volles ISO-Datum.
        let patron = try decoder.decode(
            PAIAPatron.self,
            from: Data(json.replacingOccurrences(of: "2027-03-31", with: "2027-03-31T00:00:00Z").utf8)
        )
        #expect(patron.name == "Muster, Max")
        #expect(patron.status == 2)
        #expect(patron.note == "Bitte melden")
        #expect(patron.expires != nil)
    }

    @Test func nutzergruppeNimmtErsteBekannteUri() {
        let tabelle = ["urn:b": "Beschäftigte", "urn:s": "Studierende"]
        #expect(PAIANutzergruppe.text(for: ["urn:x", "urn:s", "urn:b"], tabelle: tabelle) == "Studierende")
    }

    @Test func unbekannteUriErgibtNil() {
        #expect(PAIANutzergruppe.text(for: ["urn:x"], tabelle: ["urn:s": "Studierende"]) == nil)
        #expect(PAIANutzergruppe.text(for: [], tabelle: [:]) == nil)
    }

    @Test func biometrieFehlerWerdenAbgebildet() {
        let nichtDa = BibliotheksausweisZugang.ergebnis(for: LAError(.biometryNotEnrolled), istTouchID: false)
        guard case .hinweis(let h1) = nichtDa else { Issue.record("Hinweis erwartet"); return }
        #expect(h1.titel == "Face ID nicht eingerichtet")

        let gesperrt = BibliotheksausweisZugang.ergebnis(for: LAError(.biometryLockout), istTouchID: true)
        guard case .hinweis(let h2) = gesperrt else { Issue.record("Hinweis erwartet"); return }
        #expect(h2.titel == "Touch ID ist gesperrt")

        let ohneCode = BibliotheksausweisZugang.ergebnis(for: LAError(.passcodeNotSet), istTouchID: true)
        guard case .hinweis(let h3) = ohneCode else { Issue.record("Hinweis erwartet"); return }
        #expect(h3.titel == "Touch ID nicht eingerichtet")
        #expect(h3.text == "Um den Ausweis zu zeigen, lege in den Einstellungen einen Code fest und richte Face ID oder Touch ID ein.")

        #expect(BibliotheksausweisZugang.ergebnis(for: LAError(.userCancel), istTouchID: false) == .abgebrochen)
        #expect(BibliotheksausweisZugang.ergebnis(for: LAError(.authenticationFailed), istTouchID: false) == .abgebrochen)
    }

    // MARK: - Ausweisdaten

    private func utc(_ jahr: Int, _ monat: Int, _ tag: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.date(from: DateComponents(year: jahr, month: monat, day: tag)) ?? .now
    }

    private func lokal(_ jahr: Int, _ monat: Int, _ tag: Int, stunde: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: jahr, month: monat, day: tag, hour: stunde)) ?? .now
    }

    @Test func statusTexteStehenWieInDerUebergabe() {
        func text(_ status: Int?) -> String? {
            BibliotheksausweisDaten(benutzernummer: "1", name: nil, konto: PAIAPatron(status: status)).statusText
        }
        #expect(text(0) == nil)
        #expect(text(nil) == nil)
        #expect(text(1) == "Konto gesperrt – bitte an der Ausleihtheke melden.")
        #expect(text(2) == "Ausweis abgelaufen – bitte an der Ausleihtheke verlängern lassen.")
        #expect(text(3) == "Konto gesperrt wegen offener Gebühren – bitte an der Ausleihtheke bezahlen.")
        #expect(text(4) == "Ausweis abgelaufen und Gebühren offen – bitte an der Ausleihtheke melden.")
    }

    @Test func gueltigBisIstKritischBeiVergangenheitOderStatus2Und4() {
        let heute = lokal(2026, 11, 10)
        func daten(_ expires: Date?, status: Int) -> BibliotheksausweisDaten {
            BibliotheksausweisDaten(benutzernummer: "1", name: nil, konto: PAIAPatron(expires: expires, status: status))
        }
        #expect(daten(utc(2027, 9, 30), status: 0).gueltigBisIstKritisch(am: heute) == false)
        #expect(daten(utc(2026, 9, 30), status: 0).gueltigBisIstKritisch(am: heute) == true)
        #expect(daten(utc(2026, 11, 10), status: 0).gueltigBisIstKritisch(am: heute) == false, "Am Tag selbst gilt er noch")
        #expect(daten(utc(2027, 9, 30), status: 2).gueltigBisIstKritisch(am: heute) == true)
        #expect(daten(utc(2027, 9, 30), status: 4).gueltigBisIstKritisch(am: heute) == true)
        #expect(daten(utc(2027, 9, 30), status: 3).gueltigBisIstKritisch(am: heute) == false)
    }

    @Test func gueltigBisWirdAlsTagMonatJahrGezeigt() {
        let daten = BibliotheksausweisDaten(benutzernummer: "1", name: nil, konto: PAIAPatron(expires: utc(2027, 9, 30)))
        #expect(daten.gueltigBis == "30.09.2027")
        #expect(BibliotheksausweisDaten(benutzernummer: "1", name: nil, konto: PAIAPatron()).gueltigBis == nil)
    }

    @Test func ohneFrischenAbrufBleibtNurDerNameAusDerSitzung() {
        let alt = PAIAPatron(name: "Lena Schubert", expires: utc(2027, 9, 30), status: 3, type: ["x"], note: "Hinweis")
        let daten = BibliotheksausweisDaten(benutzernummer: "0001234567", frisch: nil, letzter: alt)
        #expect(daten.name == "Lena Schubert")
        #expect(daten.konto == nil)
        #expect(daten.gueltigBis == nil)
        #expect(daten.nutzergruppe == nil)
        #expect(daten.statusText == nil)
        #expect(daten.hinweis == nil)
    }

    @Test func leereHinweiseUndNamenEntfallen() {
        let daten = BibliotheksausweisDaten(benutzernummer: "1", name: "  ", konto: PAIAPatron(note: " \n"))
        #expect(daten.name == nil)
        #expect(daten.hinweis == nil)
    }

    @Test func restzeitWirdAlsMinutenUndSekundenGezeigt() {
        #expect(BibliotheksausweisDaten.restzeit(sekunden: 118) == "1:58")
        #expect(BibliotheksausweisDaten.restzeit(sekunden: 120) == "2:00")
        #expect(BibliotheksausweisDaten.restzeit(sekunden: 5) == "0:05")
        #expect(BibliotheksausweisDaten.restzeit(sekunden: -3) == "0:00")
    }

    // MARK: - Strichcode

    @Test func strichcodeWirdInGanzzahligenPixelnGerendert() throws {
        let bild = try #require(Campus_Ilmenau.Strichcode.bild(für: "0001234567", verfügbareBreite: 282, displayScale: 3))
        #expect(bild.cgImage.width > 0)
        // Die Breite in Pixeln ist ein ganzzahliges Vielfaches der Modulzahl und passt in den Platz.
        #expect(CGFloat(bild.cgImage.width) <= 282 * 3)
        #expect(bild.breite * 3 == CGFloat(bild.cgImage.width))
    }

    @Test func strichcodeOhneZeichenErgibtKeinBild() {
        #expect(Campus_Ilmenau.Strichcode.bild(für: "0001234567", verfügbareBreite: 0, displayScale: 3) == nil)
    }

    @Test func jedesCode39MusterHatDreiBreiteElemente() {
        for (zeichen, muster) in Campus_Ilmenau.Strichcode.code39Muster {
            #expect(muster.count == 9, "Zeichen \(zeichen)")
            #expect(muster.filter { $0 == "w" }.count == 3, "Zeichen \(zeichen)")
        }
        #expect(Campus_Ilmenau.Strichcode.code39Muster.count == 44)
    }

    @Test func code39ErlaubtKleinbuchstabenAberKeineUnbekanntenZeichen() {
        #expect(Campus_Ilmenau.Strichcode.code39Elemente(für: "3400056749x") == Campus_Ilmenau.Strichcode.code39Elemente(für: "3400056749X"))
        #expect(Campus_Ilmenau.Strichcode.code39Elemente(für: "34000*56749") == nil)
        #expect(Campus_Ilmenau.Strichcode.code39Elemente(für: "ÄÖÜ") == nil)
        #expect(Campus_Ilmenau.Strichcode.code39Elemente(für: "") == nil)
    }

    @Test func testnummerMitXHatDieErwarteteElementfolge() throws {
        let elemente = try #require(Campus_Ilmenau.Strichcode.code39Elemente(für: "3400056749X"))
        // 13 Zeichen (Start, 11 Zeichen, Stopp) zu je 9 Elementen und 12 Lücken dazwischen.
        #expect(elemente.count == 13 * 9 + 12)
        // Start- und Stoppzeichen `*` (nwnnwnwnn), Strich zuerst.
        let stern = "nwnnwnwnn"
        func form(_ bereich: Range<Int>) -> String { bereich.map { elemente[$0].istBreit ? "w" : "n" }.joined() }
        #expect(form(0..<9) == stern)
        #expect(form((elemente.count - 9)..<elemente.count) == stern)
        #expect(elemente[0].istStrich && !elemente[1].istStrich)
        #expect(elemente[9] == .init(istStrich: false, istBreit: false), "Lücke zwischen den Zeichen")
    }

    @Test func langeNummerFuelltDieBreiteFastAus() throws {
        // Aus dem Screenshot: 12 Zeichen, 3x, 282 pt Platz. Vorher nur etwa die Hälfte der Breite.
        let lang = try #require(Campus_Ilmenau.Strichcode.bild(für: "340000429691", verfügbareBreite: 282, displayScale: 3))
        #expect(lang.breite >= 282 * 0.9)
        #expect(lang.breite <= 282)
        let testnummer = try #require(Campus_Ilmenau.Strichcode.bild(für: "3400056749X", verfügbareBreite: 282, displayScale: 3))
        #expect(testnummer.breite >= 282 * 0.85)
    }

    @Test func code39ZeichnetBeiZweifachemDisplayInGanzenPixeln() throws {
        let bild = try #require(Campus_Ilmenau.Strichcode.bild(für: "3400056749X", verfügbareBreite: 282, displayScale: 2))
        #expect(bild.breite * 2 == CGFloat(bild.cgImage.width))
        #expect(CGFloat(bild.cgImage.width) <= 282 * 2)
    }
}
