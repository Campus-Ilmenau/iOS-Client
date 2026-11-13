import Foundation
#if os(iOS)
import UIKit
#endif
#if canImport(CoreNFC)
import CoreNFC
#endif

/// Kann dieses Gerät eine Thoska lesen? iPads haben kein NFC. Tab, Seitenleisten-Eintrag und Intent „Thoska auslesen“
/// richten sich danach, in der iPhone- wie in der iPad-Hülle.
///
/// Die Datei gehört zu App und Widget-Extension. Im Simulator ist `readingAvailable` immer falsch; Tests und Vorschauen
/// setzen darum `ueberschreibung`, Debug-Läufe außerdem das Startargument `-NFCVorhanden YES|NO`.
@MainActor
enum NFCVerfuegbarkeit {
    /// Ersetzt die Antwort des Geräts (Tests, Vorschauen). `nil` heißt: das Gerät fragen.
    static var ueberschreibung: Bool?

    static var vorhanden: Bool {
        if let ueberschreibung { return ueberschreibung }
        #if DEBUG
        if let argument = UserDefaults.standard.object(forKey: "NFCVorhanden") as? Bool { return argument }
        #endif
        #if canImport(CoreNFC)
        return NFCTagReaderSession.readingAvailable
        #else
        // Ohne CoreNFC im Modul (Widget-Extension): iPhones lesen NFC, iPads nicht.
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom != .pad
        #else
        return false
        #endif
        #endif
    }
}
