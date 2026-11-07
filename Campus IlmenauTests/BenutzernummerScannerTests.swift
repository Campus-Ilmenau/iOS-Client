import Testing
@testable import Campus_Ilmenau

struct BenutzernummerScannerTests {
    // MARK: - Prüfung des gelesenen Werts

    @Test func plainDigitsInRangeAreAccepted() {
        #expect(BenutzernummerFormat.normalize("0001234567") == "0001234567")
        #expect(BenutzernummerFormat.normalize("12345678") == "12345678")     // 8 Stellen
        #expect(BenutzernummerFormat.normalize("12345678901234") == "12345678901234")   // 14 Stellen
    }

    @Test func lengthOutsideEightToFourteenIsIgnored() {
        #expect(BenutzernummerFormat.normalize("1234567") == nil)             // 7
        #expect(BenutzernummerFormat.normalize("123456789012345") == nil)     // 15
        #expect(BenutzernummerFormat.normalize("") == nil)
    }

    @Test func spacesAreRemoved() {
        #expect(BenutzernummerFormat.normalize(" 0001 234567 ") == "0001234567")
        #expect(BenutzernummerFormat.normalize("0001\n234567") == "0001234567")
    }

    @Test func codabarStartAndStopCharactersAreCutOff() {
        #expect(BenutzernummerFormat.normalize("A0001234567B", isCodabar: true) == "0001234567")
        #expect(BenutzernummerFormat.normalize("c0001234567d", isCodabar: true) == "0001234567")
        #expect(BenutzernummerFormat.normalize("D0001234567D", isCodabar: true) == "0001234567")
        // Ein einzelnes Zeichen vorn oder hinten wird ebenfalls abgeschnitten.
        #expect(BenutzernummerFormat.normalize("A0001234567", isCodabar: true) == "0001234567")
        #expect(BenutzernummerFormat.normalize("0001234567B", isCodabar: true) == "0001234567")
    }

    @Test func lettersAreKeptForOtherSymbologies() {
        // Bei Code 39/128 gehört auch ein A–D am Ende zur Nummer.
        #expect(BenutzernummerFormat.normalize("0001234567B") == "0001234567B")
        #expect(BenutzernummerFormat.normalize("0001234567X") == "0001234567X")
        #expect(BenutzernummerFormat.normalize("000123456X") == "000123456X")
        #expect(BenutzernummerFormat.normalize("0001234567X", isCodabar: true) == "0001234567X")
    }

    @Test func nothingElseIsAcceptedSilently() {
        #expect(BenutzernummerFormat.normalize("ABC12345678") == nil)         // beginnt nicht mit einer Ziffer
        #expect(BenutzernummerFormat.normalize("0001-234567") == nil)
        #expect(BenutzernummerFormat.normalize("0001234567ä") == nil)         // kein ASCII
        #expect(BenutzernummerFormat.normalize("https://example.org/00012345678") == nil)
        #expect(BenutzernummerFormat.normalize("٠٠٠١٢٣٤٥٦٧") == nil)           // arabisch-indische Ziffern
        #expect(BenutzernummerFormat.normalize("ABCD") == nil)
    }

    // MARK: - Zustände

    @Test func cameraIsOnlyShownWhileScanningOrAfterAHit() {
        #expect(BenutzernummerScannerState.scanning.showsCamera)
        #expect(BenutzernummerScannerState.found("0001234567").showsCamera)
        #expect(!BenutzernummerScannerState.checking.showsCamera)
        #expect(!BenutzernummerScannerState.denied.showsCamera)
        #expect(!BenutzernummerScannerState.unavailable.showsCamera)
    }
}
