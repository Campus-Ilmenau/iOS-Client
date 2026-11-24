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
}
