import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Campus_Ilmenau

/// Bild-Karten zum Teilen, ohne Rendern: Größenangaben, Schrift im Target, Dateinamen. Läuft immer.
@MainActor
struct ShareCardTests {
    private typealias Vorschau = ShareCardVorschau

    @Test func widthTimesScaleIsTenEightyPixels() {
        #expect(ShareCardView<EmptyView>.width == 360)
        #expect(ShareImageRenderer.width == ShareCardView<EmptyView>.width)
        #expect(ShareImageRenderer.width * ShareImageRenderer.scale == 1080)
    }

    @Test func plusJakartaSansIsRegisteredInTheApp() {
        #expect(UIFont(name: "PlusJakartaSans-ExtraBold", size: 15) != nil)
        let plist = Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String]
        #expect(plist?.contains("PlusJakartaSans-ExtraBold.ttf") == true)
    }

    @Test func fileNames() {
        #expect(Vorschau.speiseplan().imageFileName == "Mensa-Ehrenberg-2026-10-29.png")
        #expect(Vorschau.abendessen().imageFileName == "Cafeteria-Ehrenberg-2026-10-29-Abendessen.png")
        #expect(Vorschau.gericht(Vorschau.gerichtVollstaendig).imageFileName == "Linsen-Dal.png")
        #expect(Vorschau.veranstaltung(Vorschau.party()).imageFileName == "Halloween-Party.png")
        #expect(ShareFileName.slug("Hähnchenschnitzel „Wiener Art“ / Pommes") == "Hähnchenschnitzel-Wiener-Art-Pommes")
    }
}

/// Bild-Karten zum Teilen, mit Rendern: Größe und Umbruch, feste Darstellung, Schrift im Bild, Export als PNG.
///
/// **Nur auf Wunsch:** `ImageRenderer` blockiert den MainActor, und mehrere zeitabhängige Tests der anderen Suites
/// (`eventually` mit 3 s, `HeuteAbendTests` mit 2 s) kippen oder stürzen ab, wenn er im selben Lauf wie alle Tests
/// rendert. Die Suite läuft deshalb nur, wenn `/tmp/campus-share-cards/.render` existiert
/// (`touch /tmp/campus-share-cards/.render`), dann allein (`RunSomeTests` auf `ShareCardRenderTests`).
/// Dabei entstehen auch die PNGs zum Vergleichen mit dem Artboard in `/tmp/campus-share-cards/`.
@Suite(.enabled(if: FileManager.default.fileExists(atPath: "/tmp/campus-share-cards/.render")))
@MainActor
struct ShareCardRenderTests {
    private typealias Vorschau = ShareCardVorschau

    private func image(_ png: Data?) throws -> UIImage {
        let data = try #require(png)
        return try #require(UIImage(data: data))
    }

    // MARK: - Größe

    @Test func exportIsAPNGWithTheSuggestedName() async throws {
        let share = try #require(ShareImageRenderer.png(of: Vorschau.speiseplan(gerichte: 1).card, scale: 1))
        let image = ShareImage(data: share, fileName: Vorschau.speiseplan(gerichte: 1).imageFileName)
        #expect(image.fileName == "Mensa-Ehrenberg-2026-10-29.png")
        let exported = try await image.exported(as: .png)
        #expect(exported.starts(with: [0x89, 0x50, 0x4E, 0x47]), "PNG-Kennung")
        #expect(exported == share)
    }

    @Test func dishCardIsThreeHundredSixtyPointsWide() throws {
        let dish = try image(ShareImageRenderer.png(of: Vorschau.gericht(Vorschau.gerichtVollstaendig).card, scale: 1))
        #expect(dish.size.width == 360)
    }

    @Test func brandFooterFitsIntoTheCardWithoutPushingItOverTheMargin() throws {
        // Die Karte ist 360 − 2 × 16 = 328 pt breit. Ist die Markenzeile in ihrer Wunschbreite breiter, wächst die ganze
        // Karte über den Rand.
        let footer = try image(ShareImageRenderer.png(of: ShareBrandFooter().fixedSize(horizontal: true, vertical: false), scale: 1))
        #expect(footer.size.width <= 328)
    }

    @Test func heightGrowsWithTheNumberOfDishes() throws {
        let four = try image(ShareImageRenderer.png(of: Vorschau.speiseplan(gerichte: 4).card, scale: 1))
        let eight = try image(ShareImageRenderer.png(of: Vorschau.speiseplan(gerichte: 8).card, scale: 1))
        #expect(eight.size.height > four.size.height + 150)
        #expect(four.size.width == 360)
    }

    @Test func aShortCardIsStretchedToTheMinimumHeight() throws {
        let one = MensaPlanShare(
            venue: .nanoteria, day: Vorschau.donnerstag, allMeals: [], priceGroup: .studierende, locale: Vorschau.deutsch
        )
        let image = try image(ShareImageRenderer.png(of: one.card, scale: 1))
        #expect(image.size.height == 450)
    }

    @Test func longNamesWrapInsteadOfBeingCut() throws {
        // Gemessen wird die weiße Karte allein (der Bildrahmen hat eine Mindesthöhe): Ein sehr langer Name macht sie
        // höher, statt abgeschnitten zu werden.
        func cardHeight(_ name: String) throws -> CGFloat {
            let meal = MensaMeal(
                id: "l", category: "Essen 1", name: name, description: nil,
                price: MensaMealPrice(student: 3.8, staff: nil, guest: nil, currency: "€"),
                allergies: [], badges: [], additives: [], categories: [], co2GramPerPortion: nil, components: [],
                canteenName: "Mensa Ehrenberg", date: Vorschau.donnerstag
            )
            let share = MensaPlanShare(
                venue: .mensaEhrenberg, day: Vorschau.donnerstag, allMeals: [meal], priceGroup: .studierende, locale: Vorschau.deutsch
            )
            let card = SharePlanCard(share: share).frame(width: 328)
            return try image(ShareImageRenderer.png(of: card, scale: 1)).size.height
        }
        let short = try cardHeight("Kurz")
        let long = try cardHeight(String(repeating: "Hähnchenschnitzel mit Pommes frites ", count: 4))
        #expect(long > short + 60, "der lange Name bricht um und macht die Karte höher")
    }

    // MARK: - Immer hell, feste Größe

    @Test func lookIsTheSameInDarkModeAndWithLargeText() throws {
        let share = Vorschau.speiseplan()
        let reference = try #require(ShareImageRenderer.png(of: share.card, scale: 1))
        let changed = try #require(ShareImageRenderer.png(
            of: share.card.environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, .accessibility3), scale: 1
        ))
        #expect(reference == changed, "Dark Mode und Textgröße des Geräts ändern das Bild nicht")
    }

    @Test func plusJakartaSansReachesTheRenderedImage() throws {
        // Dasselbe Wort einmal in Plus Jakarta Sans, einmal in der Systemschrift: Das Bild muss sich unterscheiden,
        // sonst hätte ImageRenderer still auf die Systemschrift zurückgegriffen.
        func word(_ font: Font) -> some View {
            Text("Campus Ilmenau 2,90 €").font(font).foregroundStyle(.black)
                .padding(8).background(Color.white)
        }
        let jakarta = try #require(ShareImageRenderer.png(of: word(.custom("PlusJakartaSans-ExtraBold", fixedSize: 30))))
        let system = try #require(ShareImageRenderer.png(of: word(.system(size: 30, weight: .heavy))))
        let jakartaImage = try image(jakarta)
        let systemImage = try image(system)
        #expect(jakarta != system)
        #expect(jakartaImage.size.width != systemImage.size.width, "andere Laufweite, also andere Schrift")
    }

    // MARK: - Veranstaltung

    /// Alpha-Wert (0…255) des Pixels `(x, y)`, von links oben gezählt.
    private func alpha(_ image: UIImage, x: Int, y: Int) throws -> UInt8 {
        let cgImage = try #require(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: -x, y: -(cgImage.height - 1 - y), width: cgImage.width, height: cgImage.height))
        return pixel[3]
    }

    @Test func ticketNotchesAreReallyTransparent() throws {
        // Die Karte allein, auf durchsichtigem Grund: An den Kerben darf nichts stehen, nicht einmal die Farbe des Hintergrunds.
        let ticket = ShareEventTicket(share: Vorschau.veranstaltung(Vorschau.party())).frame(width: 328)
        let image = try image(ShareImageRenderer.png(of: ticket, scale: 1, opaque: false))
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        #expect(width == 328)

        // Am linken und rechten Rand die Zeilen suchen, die durchsichtig sind (ohne die runden Ecken oben und unten).
        for x in [0, width - 1] {
            var transparent: [Int] = []
            for y in 30..<(height - 30) where try alpha(image, x: x, y: y) == 0 { transparent.append(y) }
            #expect(transparent.count >= 18, "Spalte \(x): Kerbe von etwa 22 pt Höhe")
            let center = (transparent.first ?? 0) + transparent.count / 2
            #expect(transparent.last.map { $0 - (transparent.first ?? 0) + 1 } == transparent.count, "eine zusammenhängende Kerbe")
            // Eine Kerbe ist ein Halbkreis mit Radius 11: 15 pt vom Rand ist die Karte wieder voll da.
            let inside = x == 0 ? 15 : width - 16
            #expect(try alpha(image, x: inside, y: center) == 255)
            // Die Karte selbst ist deckend.
            #expect(try alpha(image, x: width / 2, y: 30) == 255)
        }
        // Die Ecken sind abgerundet (Radius 22).
        #expect(try alpha(image, x: 0, y: 0) == 0)
    }

    @Test func allEventStatesRenderAtTheRightWidth() throws {
        let events = [
            Vorschau.party(), Vorschau.party(status: .abgesagt), Vorschau.party(status: .unbestaetigt),
            Vorschau.party(mitEnde: false), Vorschau.partyKnapp
        ]
        for event in events {
            let image = try image(ShareImageRenderer.png(of: Vorschau.veranstaltung(event).card, scale: 1))
            #expect(image.size.width == 360)
            #expect(image.size.height >= 450)
        }
    }

    @Test func eventCardLooksTheSameOnALightDevice() throws {
        let share = Vorschau.veranstaltung(Vorschau.party())
        let reference = try #require(ShareImageRenderer.png(of: share.card, scale: 1))
        let light = try #require(ShareImageRenderer.png(of: share.card.environment(\.colorScheme, .light), scale: 1))
        #expect(reference == light, "Die Veranstaltung ist immer nachtblau, auch wenn das Gerät hell ist")
    }

    // MARK: - Beispiele zum Vergleichen

    @Test func rendersExamplesForComparison() throws {
        let examples: [(String, Data?)] = [
            ("Speiseplan-4-Gerichte", ShareImageRenderer.png(of: Vorschau.speiseplan().card)),
            ("Speiseplan-8-Gerichte", ShareImageRenderer.png(of: Vorschau.speiseplan(gerichte: 8).card)),
            ("Speiseplan-Abendessen", ShareImageRenderer.png(of: Vorschau.abendessen().card)),
            ("Speiseplan-Gaeste-Preis-fehlt", ShareImageRenderer.png(of: Vorschau.speiseplan(gruppe: .gaeste).card)),
            ("Gericht-vollstaendig", ShareImageRenderer.png(of: Vorschau.gericht(Vorschau.gerichtVollstaendig).card)),
            ("Gericht-knapp", ShareImageRenderer.png(of: Vorschau.gericht(Vorschau.gerichtKnapp).card)),
            ("Gericht-knapp-Gaeste", ShareImageRenderer.png(of: Vorschau.gericht(Vorschau.gerichtKnapp, gruppe: .gaeste).card)),
            ("Speiseplan-4-Gerichte-Englisch", ShareImageRenderer.png(of: Vorschau.speiseplan(locale: Locale(identifier: "en_US")).card)),
            ("Veranstaltung", ShareImageRenderer.png(of: Vorschau.veranstaltung(Vorschau.party()).card)),
            ("Veranstaltung-abgesagt", ShareImageRenderer.png(of: Vorschau.veranstaltung(Vorschau.party(status: .abgesagt)).card)),
            ("Veranstaltung-unbestaetigt", ShareImageRenderer.png(of: Vorschau.veranstaltung(Vorschau.party(status: .unbestaetigt)).card)),
            ("Veranstaltung-ohne-Ende", ShareImageRenderer.png(of: Vorschau.veranstaltung(Vorschau.party(mitEnde: false)).card)),
            ("Veranstaltung-knapp", ShareImageRenderer.png(of: Vorschau.veranstaltung(Vorschau.partyKnapp).card)),
            ("Veranstaltung-Englisch", ShareImageRenderer.png(of: Vorschau.veranstaltung(Vorschau.party(), locale: Locale(identifier: "en_US")).card))
        ]
        let folder = URL(fileURLWithPath: "/tmp/campus-share-cards", isDirectory: true)
        for (name, png) in examples {
            let data = try #require(png, "\(name) ließ sich nicht rendern")
            let decoded = try #require(UIImage(data: data))
            #expect(decoded.size.width == 1080, "\(name): 360 pt mit Faktor 3")
            #expect(decoded.size.height >= 1350, "\(name): mindestens 450 pt")
            try data.write(to: folder.appendingPathComponent("\(name).png"))
        }
    }
}
