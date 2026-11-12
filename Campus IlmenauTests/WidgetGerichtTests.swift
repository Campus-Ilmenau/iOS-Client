import Foundation
import Testing
@testable import Campus_Ilmenau

/// `WidgetGericht.zusatzstoffe` (neu, optional) und `MensaWidgetPhasen.anzeige(maxZeilen:)`.
@MainActor
struct WidgetGerichtTests {
    // MARK: - Zusatzstoffe

    @Test func altesGespeichertesGerichtOhneZusatzstoffeLaesstSichLesen() throws {
        // Stand vor `allergene` und `zusatzstoffe`.
        let vorAllergenen = #"{"id":"1","name":"Suppe","gruppe":"Mittag","abendessen":false,"waehrung":"EUR","chips":[]}"#
        let a = try JSONDecoder().decode(WidgetGericht.self, from: Data(vorAllergenen.utf8))
        #expect(a.allergene.isEmpty)
        #expect(a.zusatzstoffe.isEmpty)

        // Stand mit `allergene`, aber ohne `zusatzstoffe`.
        let mitAllergenen = #"{"id":"2","name":"Pasta","gruppe":"Mittag","abendessen":false,"waehrung":"EUR","chips":[],"allergene":["Weizen"]}"#
        let b = try JSONDecoder().decode(WidgetGericht.self, from: Data(mitAllergenen.utf8))
        #expect(b.allergene == ["Weizen"])
        #expect(b.zusatzstoffe.isEmpty)
    }

    @Test func alterGesamtstandMitGerichtenOhneZusatzstoffeLaesstSichLesen() throws {
        // Der ganze `WidgetSnapshot`, wie ihn eine frühere Version geschrieben hat.
        let json = """
        {"mensen":[{"id":"mensaEhrenberg","name":"Mensa Ehrenberg","kurzname":"Ehrenberg","oeffnungszeiten":[],
        "heute":{"tag":"2026-10-29","gerichte":[{"id":"1","name":"Suppe","gruppe":"Mittag","abendessen":false,
        "waehrung":"EUR","chips":[],"allergene":["Sellerie"]}]}}],"events":[],"gemerkteEventIDs":[]}
        """
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(json.utf8))
        let gericht = try #require(snapshot.mensa(id: "mensaEhrenberg")?.heute?.gerichte.first)
        #expect(gericht.allergene == ["Sellerie"])
        #expect(gericht.zusatzstoffe.isEmpty)
    }

    @Test func zusatzstoffeUeberstehenSpeichernUndLesen() throws {
        let gericht = WidgetGericht(
            id: "3", name: "Dal", gruppe: "Mittag", abendessen: false, preisStudierende: 2.9, preisBedienstete: 4.4,
            preisGaeste: 5.9, waehrung: "EUR", chips: [], allergene: ["Senf"], zusatzstoffe: ["Antioxidationsmittel", "Farbstoff"]
        )
        let rund = try JSONDecoder().decode(WidgetGericht.self, from: JSONEncoder().encode(gericht))
        #expect(rund == gericht)
        #expect(rund.zusatzstoffe == ["Antioxidationsmittel", "Farbstoff"])
    }

    @Test func gerichtUebernimmtZusatzstoffeOhneDoppelte() {
        let meal = MensaMeal(
            id: "m1", category: "Mittagessen", name: "Dal", description: nil,
            price: MensaMealPrice(student: 2.9, staff: 4.4, guest: 5.9, currency: "EUR"),
            allergies: [], badges: [], additives: ["Farbstoff", "Antioxidationsmittel", "Farbstoff"], categories: [],
            co2GramPerPortion: nil, components: [], canteenName: MensaVenue.mensaEhrenberg.apiName, date: .now
        )
        let gerichte = WidgetMensaPflege.gerichte([meal], fuer: .mensaEhrenberg)
        #expect(gerichte.first?.zusatzstoffe == ["Farbstoff", "Antioxidationsmittel"])
    }

    // MARK: - maxZeilen

    private func zeit(_ uhr: String) -> Date {
        let teile = uhr.split(separator: ":").compactMap { Int($0) }
        return EventKalender.kalender.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: teile[0], minute: teile[1]))!
    }

    private func gericht(_ nummer: Int, chips: [WidgetChip] = []) -> WidgetGericht {
        WidgetGericht(
            id: "g\(nummer)", name: "Gericht \(nummer)", gruppe: "Mittag", abendessen: false, preisStudierende: 2.9,
            preisBedienstete: nil, preisGaeste: nil, waehrung: "EUR", chips: chips
        )
    }

    private var plan: WidgetSnapshot {
        let vegan = [WidgetChip(titel: "Vegan", art: .gruen)]
        return WidgetSnapshot(mensen: [WidgetMensa(
            id: MensaVenue.mensaEhrenberg.rawValue, name: "Mensa Ehrenberg", kurzname: "Ehrenberg",
            oeffnungszeiten: ["thu"].map { WidgetOeffnung(wochentag: $0, oeffnet: "11:00", schliesst: "14:00") },
            heute: WidgetSpeiseplan(tag: "2026-10-29", gerichte: (1...5).map { gericht($0, chips: $0.isMultiple(of: 2) ? vegan : []) })
        )])
    }

    @Test func dieVorgabeBleibtBeiDreiGerichten() {
        let a = MensaWidgetPhasen.anzeige(snapshot: plan, mensaID: "mensaEhrenberg", preisgruppe: .studierende, jetzt: zeit("11:45"))
        #expect(a.zeilen.map(\.name) == ["Gericht 1", "Gericht 2", "Gericht 3"])
        #expect(a.gesamt == 5)
    }

    @Test func maxZeilenLiefertAlleGerichteUndAendertSonstNichts() {
        let standard = MensaWidgetPhasen.anzeige(snapshot: plan, mensaID: "mensaEhrenberg", preisgruppe: .studierende, jetzt: zeit("11:45"))
        let alle = MensaWidgetPhasen.anzeige(
            snapshot: plan, mensaID: "mensaEhrenberg", preisgruppe: .studierende, jetzt: zeit("11:45"), maxZeilen: .max
        )
        #expect(alle.zeilen.count == 5)
        #expect(Array(alle.zeilen.prefix(3)) == standard.zeilen)
        var gekappt = alle
        gekappt.zeilen = Array(alle.zeilen.prefix(3))
        #expect(gekappt == standard)
    }

    @Test func maxZeilenGiltAuchMitFilter() {
        let filter = MensaFilter(diet: .vegan)
        let alle = MensaWidgetPhasen.anzeige(
            snapshot: plan, mensaID: "mensaEhrenberg", preisgruppe: .studierende, jetzt: zeit("11:45"), filter: filter, maxZeilen: .max
        )
        #expect(alle.zeilen.map(\.name) == ["Gericht 2", "Gericht 4"])
        #expect(alle.gesamt == 2)
        #expect(alle.filterung?.ohneFilterAnzahl == 5)
    }

    @Test func siriZeigtStandardmaessigDreiUndAufWunschAlle() throws {
        let einstellungen = SiriMensaEinstellungen()
        func karte(_ maxZeilen: Int?) throws -> SiriMensaKarte {
            let ergebnis = maxZeilen.map {
                SiriMensa.heute(SiriMensaFrage(), snapshot: plan, einstellungen: einstellungen, jetzt: zeit("11:45"), maxZeilen: $0)
            } ?? SiriMensa.heute(SiriMensaFrage(), snapshot: plan, einstellungen: einstellungen, jetzt: zeit("11:45"))
            guard case .antwort(let antwort) = ergebnis, let karte = antwort.karte else { throw Fehler.keineKarte }
            return karte
        }
        #expect(try karte(nil).gerichte.count == 3)
        #expect(try karte(.max).gerichte.count == 5)
        #expect(try karte(.max).kicker == karte(nil).kicker)
    }

    private enum Fehler: Error { case keineKarte }
}
