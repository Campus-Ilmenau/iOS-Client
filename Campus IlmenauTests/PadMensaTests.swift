import Testing
import SwiftUI
@testable import Campus_Ilmenau

/// Anordnung und Filter der Mensa auf dem iPad.
@MainActor
struct PadMensaTests {
    @Test func spaltenSpringenBei700Und1150() {
        func spalten(_ breite: CGFloat) -> Int { PadRaster(breite: breite).mensaSpalten }
        #expect(spalten(438) == 1)
        #expect(spalten(699.5) == 1)
        #expect(spalten(700) == 2)
        #expect(spalten(1032) == 2)   // iPad Pro 13″ hochkant
        #expect(spalten(1096) == 2)   // quer mit Seitenleiste
        #expect(spalten(1149.5) == 2)
        #expect(spalten(1150) == 4)
        #expect(spalten(1376) == 4)   // quer ohne Seitenleiste
    }

    @Test func einIPhoneBleibtBeiDerLeiste() {
        #expect(PadRaster(breite: 932, geraetIstPad: false).mensaSpalten == 1)
    }

    @Test func allergeneImPopoverNurVomGeladenenTagUndAusgeschlossene() {
        func meal(_ id: String, _ allergies: [String]) -> MensaMeal {
            MensaMeal(id: id, category: "", name: id, description: nil,
                      price: MensaMealPrice(student: 1, staff: 2, guest: 3, currency: "€"),
                      allergies: allergies, badges: [], additives: [], categories: [], co2GramPerPortion: nil,
                      components: [], canteenName: "Mensa Ehrenberg", date: .now)
        }
        let tag = [meal("a", ["Weizen", "Soja"]), meal("b", ["Soja", "Fisch"])]
        #expect(MensaFilter.allergens(onDay: tag, keeping: []) == ["Fisch", "Soja", "Weizen"])
        // Ausgeschlossene bleiben sichtbar, auch wenn der Tag sie nicht nennt.
        #expect(MensaFilter.allergens(onDay: tag, keeping: ["Sellerie"]) == ["Fisch", "Sellerie", "Soja", "Weizen"])
        // Im Sheet dagegen stehen alle bekannten Allergene.
        #expect(MensaFilter.availableAllergens(in: tag, keeping: []).count >= MensaFilter.knownAllergens.count)
        #expect(MensaFilter.allergens(onDay: [], keeping: []).isEmpty)
    }
}
