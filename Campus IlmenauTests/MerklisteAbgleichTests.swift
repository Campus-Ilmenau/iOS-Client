import Foundation
import Testing
@testable import Campus_Ilmenau

/// Die Konfliktregel zwischen iPhone und Apple Watch (`MerklisteAbgleich`) und ihre Anwendung im `BibMerklisteStore`.
@MainActor
struct MerklisteAbgleichTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func t(_ sekunden: Double) -> Date { t0.addingTimeInterval(sekunden) }

    private func store(_ eintraege: [GemerkterTitel]) -> BibMerklisteStore {
        let store = BibMerklisteStore(fileURL: nil, legacyDefaults: nil)
        eintraege.forEach { store.merken($0) }
        return store
    }

    private func titel(_ id: String, gemerkt: Double = 0) -> GemerkterTitel {
        GemerkterTitel(id: id, titel: "Titel \(id)", gemerktAm: t(gemerkt))
    }

    // MARK: - Die Regel (reine Funktion)

    @Test func uhrJuengerGewinnt() {
        let aenderung = UhrAenderung(id: "a", found: true, changedAt: t(10))
        let ergebnis = MerklisteAbgleich.entscheide(aenderung, aktuell: (nil, t(5)), geloescht: false)
        #expect(ergebnis == .uebernehmen(foundAt: t(10), changedAt: t(10)))
    }

    @Test func iPhoneJuengerGewinnt() {
        let aenderung = UhrAenderung(id: "a", found: true, changedAt: t(5))
        let ergebnis = MerklisteAbgleich.entscheide(aenderung, aktuell: (nil, t(10)), geloescht: false)
        #expect(ergebnis == .verwerfen(.aelter))
    }

    @Test func gleicherZeitpunktMitAnderemZustandGewinntDasIPhone() {
        let aenderung = UhrAenderung(id: "a", found: true, changedAt: t(5))
        #expect(MerklisteAbgleich.entscheide(aenderung, aktuell: (nil, t(5)), geloescht: false) == .verwerfen(.gleichzeitig))
    }

    @Test func gleicherZeitpunktMitGleichemZustandIstEineDoppelteZustellung() {
        let aenderung = UhrAenderung(id: "a", found: true, changedAt: t(5))
        #expect(MerklisteAbgleich.entscheide(aenderung, aktuell: (t(5), t(5)), geloescht: false) == .verwerfen(.duplikat))
    }

    @Test func grabsteinBleibtGeloescht() {
        let aenderung = UhrAenderung(id: "a", found: true, changedAt: t(100))
        // Auch eine viel jüngere Änderung holt nichts zurück; das gilt vor allen anderen Regeln.
        #expect(MerklisteAbgleich.entscheide(aenderung, aktuell: nil, geloescht: true) == .verwerfen(.geloescht))
        #expect(MerklisteAbgleich.entscheide(aenderung, aktuell: (nil, t(1)), geloescht: true) == .verwerfen(.geloescht))
    }

    @Test func unbekannterEintragWirdVerworfen() {
        let aenderung = UhrAenderung(id: "x", found: true, changedAt: t(5))
        #expect(MerklisteAbgleich.entscheide(aenderung, aktuell: nil, geloescht: false) == .verwerfen(.unbekannt))
    }

    @Test func foundAtFolgtDerJuengstenGefundenAktion() {
        let aenderung = UhrAenderung(id: "a", found: true, changedAt: t(20))
        let ergebnis = MerklisteAbgleich.entscheide(aenderung, aktuell: (t(10), t(10)), geloescht: false)
        #expect(ergebnis == .uebernehmen(foundAt: t(20), changedAt: t(20)))
    }

    @Test func zuruecknehmenLoeschtFoundAt() {
        let aenderung = UhrAenderung(id: "a", found: false, changedAt: t(20))
        let ergebnis = MerklisteAbgleich.entscheide(aenderung, aktuell: (t(10), t(10)), geloescht: false)
        #expect(ergebnis == .uebernehmen(foundAt: nil, changedAt: t(20)))
    }

    // MARK: - Im Store

    @Test func storeUebernimmtDieJuengereAenderungDerUhr() {
        let store = store([titel("a")])
        let ergebnis = store.uebernimm(UhrAenderung(id: "a", found: true, changedAt: t(10)))
        #expect(ergebnis == .uebernehmen(foundAt: t(10), changedAt: t(10)))
        #expect(store.eintraege.first?.foundAt == t(10))
        #expect(store.eintraege.first?.changedAt == t(10))
    }

    @Test func storeBehaeltDieJuengereAktionDesIPhones() {
        let store = store([titel("a")])
        store.setzeGefunden(true, fuer: "a", am: t(50))
        let ergebnis = store.uebernimm(UhrAenderung(id: "a", found: false, changedAt: t(40)))
        #expect(ergebnis == .verwerfen(.aelter))
        #expect(store.eintraege.first?.foundAt == t(50))
    }

    @Test func entfernterEintragBleibtNachSpaeterAenderungDerUhrGeloescht() {
        let store = store([titel("a")])
        store.entfernen("a", am: t(30))
        let ergebnis = store.uebernimm(UhrAenderung(id: "a", found: true, changedAt: t(60)))
        #expect(ergebnis == .verwerfen(.geloescht))
        #expect(store.eintraege.isEmpty)
    }

    @Test func aenderungFuerUnbekanntenEintragLegtNichtsAn() {
        let store = store([titel("a")])
        #expect(store.uebernimm(UhrAenderung(id: "zzz", found: true, changedAt: t(5))) == .verwerfen(.unbekannt))
        #expect(store.eintraege.map(\.id) == ["a"])
    }

    @Test func doppelteZustellungAendertNichts() {
        let store = store([titel("a")])
        let aenderung = UhrAenderung(id: "a", found: true, changedAt: t(10))
        store.uebernimm(aenderung)
        let danach = store.eintraege
        #expect(store.uebernimm(aenderung) == .verwerfen(.duplikat))
        #expect(store.eintraege == danach)
    }

    @Test func mehrereAenderungenInFalscherReihenfolgeErgebenDenselbenStand() {
        // Gefunden (10), zurückgenommen (20), wieder gefunden (30): Am Ende gilt die von 30, egal wie sie ankommen.
        let aenderungen = [
            UhrAenderung(id: "a", found: true, changedAt: t(10)),
            UhrAenderung(id: "a", found: false, changedAt: t(20)),
            UhrAenderung(id: "a", found: true, changedAt: t(30))
        ]
        let reihenfolgen = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
        for reihenfolge in reihenfolgen {
            let store = store([titel("a")])
            for index in reihenfolge { store.uebernimm(aenderungen[index]) }
            #expect(store.eintraege.first?.foundAt == t(30), "Reihenfolge \(reihenfolge)")
            #expect(store.eintraege.first?.changedAt == t(30), "Reihenfolge \(reihenfolge)")
        }
        // Und in der Mitte stehengeblieben: Die Rücknahme (20) gewinnt, wenn die letzte fehlt.
        let store = store([titel("a")])
        for index in [1, 0] { store.uebernimm(aenderungen[index]) }
        #expect(store.eintraege.first?.foundAt == nil)
        #expect(store.eintraege.first?.changedAt == t(20))
    }

    // MARK: - Stand der Uhr

    @Test func jungeAktionDerUhrBleibtBisDasIPhoneSieKennt() {
        let iPhone = [UhrMerklisteEintrag(id: "a", titel: "A", foundAt: nil, changedAt: t(5))]
        let lokal = [UhrMerklisteEintrag(id: "a", titel: "A", foundAt: t(10), changedAt: t(10))]
        let ergebnis = MerklisteAbgleich.verschmelze(iPhone: iPhone, lokal: lokal)
        #expect(ergebnis.first?.foundAt == t(10))
        #expect(ergebnis.first?.changedAt == t(10))
    }

    @Test func juengerStandDesIPhonesGewinntUndBeiGleichstandAuch() {
        let lokal = [UhrMerklisteEintrag(id: "a", titel: "A", foundAt: t(10), changedAt: t(10))]
        let juenger = [UhrMerklisteEintrag(id: "a", titel: "A", foundAt: nil, changedAt: t(20))]
        #expect(MerklisteAbgleich.verschmelze(iPhone: juenger, lokal: lokal) == juenger)
        let gleich = [UhrMerklisteEintrag(id: "a", titel: "A neu", foundAt: nil, changedAt: t(10))]
        #expect(MerklisteAbgleich.verschmelze(iPhone: gleich, lokal: lokal) == gleich)
    }

    @Test func dasIPhoneBestimmtWelcheEintraegeEsGibt() {
        let iPhone = [
            UhrMerklisteEintrag(id: "neu", titel: "Neu", changedAt: t(1)),
            UhrMerklisteEintrag(id: "bleibt", titel: "Bleibt", changedAt: t(1))
        ]
        let lokal = [
            UhrMerklisteEintrag(id: "bleibt", titel: "Bleibt", changedAt: t(1)),
            UhrMerklisteEintrag(id: "entfernt", titel: "Entfernt", foundAt: t(9), changedAt: t(9))
        ]
        #expect(MerklisteAbgleich.verschmelze(iPhone: iPhone, lokal: lokal).map(\.id) == ["neu", "bleibt"])
    }

    // MARK: - Übertragung

    @Test func kontextMitMerklisteUeberstehtDieUebertragung() throws {
        let original = UhrKontext(
            einstellungen: UhrEinstellungen(mensa: .nanoteria, gemerkteEvents: ["e1"]),
            merkliste: [
                UhrMerklisteEintrag(id: "a", titel: "A", foundAt: t(3.25), changedAt: t(4.5)),
                UhrMerklisteEintrag(id: "b", titel: "B", changedAt: t(1))
            ]
        )
        #expect(PropertyListSerialization.propertyList(original.kontext, isValidFor: .binary))
        let gelesen = try #require(UhrKontext(kontext: original.kontext))
        #expect(gelesen == original)
    }

    @Test func kontextOhneMerklisteLaesstDieListeDerUhrUnberuehrt() throws {
        let gelesen = try #require(UhrKontext(kontext: UhrEinstellungen().kontext))
        #expect(gelesen.merkliste == nil)
    }

    @Test func aenderungUeberstehtDieUebertragung() throws {
        let aenderung = UhrAenderung(id: "med_1", found: true, changedAt: t(12.345))
        #expect(PropertyListSerialization.propertyList(aenderung.kontext, isValidFor: .binary))
        #expect(UhrAenderung(kontext: aenderung.kontext) == aenderung)
        #expect(UhrAenderung(kontext: ["id": "x"]) == nil)
    }

    @Test func kontextDesIPhonesEnthaeltAlleEintraegeMitTitelUndZeitstempeln() {
        let store = store([titel("a", gemerkt: 1), titel("b", gemerkt: 2)])
        store.setzeGefunden(true, fuer: "a", am: t(9))
        let defaults = UserDefaults(suiteName: "MerklisteAbgleichTests-\(UUID().uuidString)")!
        let kontext = UhrKontext.aktuell(defaults: defaults, merkliste: store)
        #expect(Set((kontext.merkliste ?? []).map(\.id)) == ["a", "b"])
        #expect(kontext.merkliste?.first { $0.id == "a" }?.foundAt == t(9))
        #expect(kontext.merkliste?.first { $0.id == "a" }?.changedAt == t(9))
        #expect(kontext.merkliste?.first { $0.id == "b" }?.titel == "Titel b")
    }
}

/// Abschnitte, Sortierung und Exemplarwahl der Merkliste auf der Uhr.
struct UhrMerklisteAnzeigeTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func eintrag(_ id: String, gefunden: Double? = nil) -> UhrMerklisteEintrag {
        UhrMerklisteEintrag(
            id: id, titel: "Titel \(id)", foundAt: gefunden.map { t0.addingTimeInterval($0) }, changedAt: t0
        )
    }

    private func regal(_ standort: String, _ signatur: String = "S 1", nurVorOrt: Bool = false) -> UhrRegalStand {
        .regal(standort: standort, signatur: signatur, nurVorOrt: nurVorOrt)
    }

    @Test func abschnitteUndZusammenfassungWieImArtboard() {
        let anzeige = UhrMerklisteAnzeige.erstelle(
            eintraege: [eintrag("a"), eintrag("b"), eintrag("c"), eintrag("d"), eintrag("e", gefunden: 10)],
            staende: [
                "a": regal("60 ELT"), "b": .ausgeliehen(bis: nil), "c": .online, "d": regal("70 MB", nurVorOrt: true),
                "e": regal("40 PHY")
            ]
        )
        #expect(anzeige.abschnitte.map(\.titel) == ["Im Regal · 2", "Nicht im Regal", "Gefunden · 1"])
        #expect(anzeige.zusammenfassung == "2 im Regal · 1 gefunden")
        #expect(anzeige.abschnitte[0].zeilen.map(\.id) == ["a", "d"])
        #expect(anzeige.abschnitte[2].zeilen.first?.standort == nil)   // Gefundene zeigen keinen Standort mehr
        #expect(anzeige.abschnitte[2].zeilen.first?.gefunden == true)
    }

    @Test func imRegalNachStandortNatuerlichSortiert() {
        let anzeige = UhrMerklisteAnzeige.erstelle(
            eintraege: ["a", "b", "c", "d"].map { eintrag($0) },
            staende: ["a": regal("70 MB"), "b": regal("9 X"), "c": regal("60 ELT", "ELT 2"), "d": regal("60 ELT", "ELT 10")]
        )
        // „9“ vor „60“ vor „70“ (numerisch), gleicher Standort nach Signatur („2“ vor „10“).
        #expect(anzeige.abschnitte[0].zeilen.map(\.id) == ["b", "c", "d", "a"])
    }

    @Test func gefundeneZuletztGefundenZuerst() {
        let anzeige = UhrMerklisteAnzeige.erstelle(
            eintraege: [eintrag("a", gefunden: 5), eintrag("b", gefunden: 20), eintrag("c", gefunden: 10)], staende: [:]
        )
        #expect(anzeige.abschnitte.map(\.titel) == ["Gefunden · 3"])
        #expect(anzeige.abschnitte[0].zeilen.map(\.id) == ["b", "c", "a"])
        #expect(anzeige.zusammenfassung == "0 im Regal · 3 gefunden")
    }

    @Test func chipsDerZeilen() {
        let anzeige = UhrMerklisteAnzeige.erstelle(
            eintraege: ["a", "b", "c", "d", "e", "f"].map { eintrag($0) },
            staende: [
                "a": regal("60 ELT"), "b": regal("70 MB", nurVorOrt: true),
                "c": .ausgeliehen(bis: Date(timeIntervalSince1970: 1_794_916_800)), // 17. Nov. 2026, 12:00 UTC
                "d": .online, "e": .unbekannt
                // „f“: Stand lädt noch
            ]
        )
        let zeilen = Dictionary(uniqueKeysWithValues: anzeige.abschnitte.flatMap(\.zeilen).map { ($0.id, $0) })
        #expect(zeilen["a"]?.chip == nil)
        #expect(zeilen["b"]?.chip == "Nur vor Ort")
        #expect(zeilen["b"]?.chipArt == .blau)
        #expect(zeilen["c"]?.chip == "Ausgeliehen bis 17. Nov.")
        #expect(zeilen["d"]?.chip == "Online")
        #expect(zeilen["e"]?.chip == "Standort unbekannt")
        #expect(zeilen["f"]?.chip == "…")
    }

    @Test func beschriftungenFuerVoiceOver() {
        let anzeige = UhrMerklisteAnzeige.erstelle(
            eintraege: [eintrag("a"), eintrag("b"), eintrag("c", gefunden: 1)],
            staende: ["a": regal("60 ELT", "ELT ZQ 5200"), "b": .online]
        )
        let zeilen = Dictionary(uniqueKeysWithValues: anzeige.abschnitte.flatMap(\.zeilen).map { ($0.id, $0.beschriftung) })
        #expect(zeilen["a"] == "Titel a, 60 ELT, Signatur ELT ZQ 5200")
        #expect(zeilen["b"] == "Titel b, Online")
        #expect(zeilen["c"] == "Titel c, gefunden")
    }

    @Test func leereListeHatKeineAbschnitte() {
        let anzeige = UhrMerklisteAnzeige.erstelle(eintraege: [], staende: [:])
        #expect(anzeige.istLeer)
        #expect(anzeige.zusammenfassung == "0 im Regal · 0 gefunden")
    }

    // MARK: - Exemplarwahl

    @Test func ersteAusleihbareOderNurVorOrtGibtStandortUndSignatur() {
        let stand = UhrRegalStand(gesamtstatus: "available", exemplare: [
            .init(signatur: "A 1", standort: "Magazin", status: "on_loan"),
            .init(signatur: "B 2", standort: "60 ELT", status: "reference_only"),
            .init(signatur: "C 3", standort: "70 MB", status: "available")
        ])
        #expect(stand == .regal(standort: "60 ELT", signatur: "B 2", nurVorOrt: true))
    }

    @Test func ohneStandortIstEsNichtImRegal() {
        let stand = UhrRegalStand(gesamtstatus: "available", exemplare: [.init(signatur: "A", standort: " ", status: "available")])
        #expect(stand == .unbekannt)
    }

    @Test func ausgeliehenZeigtDasFruehesteRueckgabedatum() {
        let frueh = Date(timeIntervalSince1970: 1_000), spaet = Date(timeIntervalSince1970: 2_000)
        let stand = UhrRegalStand(gesamtstatus: "on_loan", exemplare: [
            .init(signatur: "A", standort: "X", status: "on_loan", faellig: spaet),
            .init(signatur: "B", standort: "X", status: "on_loan", faellig: frueh)
        ])
        #expect(stand == .ausgeliehen(bis: frueh))
    }

    @Test func onlineUndUnbekannt() {
        #expect(UhrRegalStand(gesamtstatus: "online", exemplare: []) == .online)
        #expect(UhrRegalStand(gesamtstatus: "unknown", exemplare: []) == .unbekannt)
        #expect(UhrRegalStand(gesamtstatus: nil, exemplare: []) == .unbekannt)
    }

    @Test func standUeberstehtSpeichernUndLesen() throws {
        let stand: [String: UhrRegalStand] = [
            "a": .regal(standort: "60 ELT", signatur: "S", nurVorOrt: false), "b": .ausgeliehen(bis: Date(timeIntervalSince1970: 5)),
            "c": .online, "d": .unbekannt
        ]
        let rund = try JSONDecoder().decode([String: UhrRegalStand].self, from: JSONEncoder().encode(stand))
        #expect(rund == stand)
    }
}
