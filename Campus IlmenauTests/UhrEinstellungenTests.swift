import Foundation
import Testing
@testable import Campus_Ilmenau

/// Was das iPhone der Uhr schickt (`UhrEinstellungen`) und wie die Uhr es liest.
struct UhrEinstellungenTests {
    @Test func kontextUmlaufErhaeltAlles() throws {
        let original = UhrEinstellungen(
            mensa: .nanoteria, preisgruppe: .gaeste,
            filter: MensaFilter(diet: .vegan, onlyBio: true, excludedAllergens: ["Milch und Milchzucker"]),
            gemerkteEvents: ["b", "a"]
        )
        let gelesen = try #require(UhrEinstellungen(kontext: original.kontext))
        #expect(gelesen == original)
        #expect(gelesen.gemerkteEvents == ["a", "b"])
    }

    @Test func kontextBestehtNurAusPropertyListTypen() {
        let kontext = UhrEinstellungen(gemerkteEvents: ["x"]).kontext
        // `updateApplicationContext` verlangt Property-List-Typen und wirft sonst.
        #expect(PropertyListSerialization.propertyList(kontext, isValidFor: .binary))
    }

    @Test func leererKontextHeisstNochNichtsVomIPhone() {
        #expect(UhrEinstellungen(kontext: [:]) == nil)
    }

    @Test func fehlendeOderUnbekannteFelderFallenAufDieVorgabeZurueck() throws {
        let gelesen = try #require(UhrEinstellungen(kontext: ["mensa": "gibtEsNicht", "preisgruppe": 5]))
        #expect(gelesen == .vorgabe)
        #expect(gelesen.mensa == .mensaEhrenberg)
        #expect(gelesen.preisgruppe == .studierende)
        #expect(!gelesen.filter.isActive)
    }

    @Test func gleicheEinstellungenSindGleich() {
        // Darauf baut `WatchVerbindung`: Gleiches wird nicht noch einmal geschickt.
        #expect(UhrEinstellungen(mensa: .roentgenbau) == UhrEinstellungen(mensa: .roentgenbau))
        #expect(UhrEinstellungen(mensa: .roentgenbau) != UhrEinstellungen(mensa: .nanoteria))
        #expect(UhrEinstellungen(gemerkteEvents: ["a"]) != UhrEinstellungen())
    }

    @Test func aktuellerStandKommtAusDerAppGroup() {
        let suite = "UhrEinstellungenTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(MensaVenue.nanoteria.rawValue, forKey: AppGroup.heuteMensaSchluessel)
        defaults.set(MensaPriceGroup.bedienstete.rawValue, forKey: AppGroup.preisgruppeSchluessel)
        MensaFilterStore.save(MensaFilter(diet: .vegetarisch), defaults: defaults)

        let aktuell = UhrEinstellungen.aktuell(defaults: defaults)
        #expect(aktuell.mensa == .nanoteria)
        #expect(aktuell.preisgruppe == .bedienstete)
        #expect(aktuell.filter.diet == .vegetarisch)
    }

    @Test func ohneEinstellungenGiltDieVorgabe() {
        let suite = "UhrEinstellungenTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let aktuell = UhrEinstellungen.aktuell(defaults: defaults)
        #expect(aktuell.mensa == .mensaEhrenberg)
        #expect(aktuell.preisgruppe == .studierende)
        #expect(!aktuell.filter.isActive)
    }
}
