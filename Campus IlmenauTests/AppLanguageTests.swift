import Foundation
import Testing
@testable import Campus_Ilmenau

struct AppLanguageTests {
    @Test func englishLocalesGiveEnglish() {
        #expect(AppLanguage(locale: Locale(identifier: "en")) == .en)
        #expect(AppLanguage(locale: Locale(identifier: "en_US")) == .en)
        #expect(AppLanguage(locale: Locale(identifier: "en_GB")) == .en)
    }

    @Test func germanAndAllOthersGiveGerman() {
        for id in ["de", "de_DE", "de_AT", "fr_FR", "es", "ja_JP", "zh-Hans_CN"] {
            #expect(AppLanguage(locale: Locale(identifier: id)) == .de, "\(id)")
        }
    }

    @Test func apiCodeIsLowercaseTwoLetterCode() {
        #expect(AppLanguage.de.apiCode == "de")
        #expect(AppLanguage.en.apiCode == "en")
    }

    @Test func deviceLanguageIsTheFirstKnownOne() {
        #expect(AppLanguage.geraet(preferred: ["en-DE", "de-DE"]) == .en)
        #expect(AppLanguage.geraet(preferred: ["de-DE", "en-DE"]) == .de)
        #expect(AppLanguage.geraet(preferred: ["fr-FR", "en-GB"]) == .en)
        #expect(AppLanguage.geraet(preferred: ["fr-FR", "es-ES"]) == .de)
        #expect(AppLanguage.geraet(preferred: []) == .de)
    }

    @Test func formatsAlwaysUseTheRegionGermany() {
        #expect(AppLanguage.de.locale.identifier == "de_DE")
        #expect(AppLanguage.en.locale.identifier == "en_DE")
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(day.formatted(.dateTime.day().month(.abbreviated).locale(AppLanguage.en.locale)).hasPrefix("1"))
        #expect(2.9.formatted(.currency(code: "EUR").locale(AppLanguage.en.locale)).contains("2,90"))
    }

    @Test func chosenLanguageWinsOverTheDevice() {
        #expect(AppLanguage.bestimmen(wahl: .en, preferred: ["de-DE"]) == .en)
        #expect(AppLanguage.bestimmen(wahl: .de, preferred: ["en-US"]) == .de)
        #expect(AppLanguage.bestimmen(wahl: nil, preferred: ["en-US"]) == .en)
        #expect(AppLanguage.bestimmen(wahl: nil, preferred: ["ja-JP"]) == .de)
    }

    /// Ohne globalen Zustand: ein Text mit der `Locale` der App löst in dieser Sprache auf (so arbeitet `inAppSprache`).
    @Test func resourceWithTheAppLocaleResolvesInThatLanguage() {
        var englisch = LocalizedStringResource("Heute")
        englisch.locale = AppLanguage.en.locale
        #expect(String(localized: englisch) == "Today")
        var deutsch = LocalizedStringResource("Weizen", table: "Shared")
        deutsch.locale = AppLanguage.de.locale
        #expect(String(localized: deutsch) == "Weizen")
        var wheat = LocalizedStringResource("Weizen", table: "Shared")
        wheat.locale = AppLanguage.en.locale
        #expect(String(localized: wheat) == "Wheat")
    }
}
