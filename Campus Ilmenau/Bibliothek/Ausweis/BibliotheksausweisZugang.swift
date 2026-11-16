import LocalAuthentication
import UIKit

/// Prüfung vor dem Bibliotheksausweis: Face ID oder Touch ID, nie der Gerätecode als Ersatz.
enum BibliotheksausweisZugang {
    enum Ergebnis: Equatable {
        case erlaubt
        /// Abgebrochen oder fehlgeschlagen: nichts anzeigen.
        case abgebrochen
        case hinweis(Hinweis)
    }

    /// Alert für „nicht eingerichtet / nicht verfügbar“ und „gesperrt“.
    struct Hinweis: Equatable {
        let titel: String
        let text: String
    }

    /// Legt bei jedem Aufruf einen neuen `LAContext` an, damit keine frühere Bestätigung gilt.
    @MainActor
    static func pruefen() async -> Ergebnis {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        // Auf dem iPad heißt der Grund kurz „Ausweis zeigen“ (Touch ID oder Face ID entscheidet `biometryType`).
        let grund = geraetName == "iPad" ? "Ausweis zeigen" : "Bibliotheksausweis zeigen"

        var error: NSError?
        // `biometryType` ist erst nach `canEvaluatePolicy` gesetzt.
        guard context.canEvaluatePolicy(policy, error: &error) else {
            return ergebnis(for: error, istTouchID: context.biometryType == .touchID, geraet: geraetName)
        }
        do {
            let ok = try await context.evaluatePolicy(policy, localizedReason: grund)
            return ok ? .erlaubt : .abgebrochen
        } catch {
            return ergebnis(for: error, istTouchID: context.biometryType == .touchID, geraet: geraetName)
        }
    }

    /// „iPad“ oder „iPhone“ für die Hinweise („Entsperre dein iPad einmal mit dem Code …“).
    @MainActor
    static var geraetName: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }

    nonisolated static func ergebnis(for error: Error?, istTouchID: Bool, geraet: String = "iPhone") -> Ergebnis {
        let name = istTouchID ? "Touch ID" : "Face ID"
        guard let code = (error as? LAError)?.code else { return .abgebrochen }
        switch code {
        case .biometryNotEnrolled, .biometryNotAvailable:
            return .hinweis(Hinweis(
                titel: "\(name) nicht eingerichtet",
                text: "Um den Ausweis zu zeigen, richte in den Einstellungen Face ID oder Touch ID ein."
            ))
        case .passcodeNotSet:
            return .hinweis(Hinweis(
                titel: "\(name) nicht eingerichtet",
                text: "Um den Ausweis zu zeigen, lege in den Einstellungen einen Code fest und richte Face ID oder Touch ID ein."
            ))
        case .biometryLockout:
            return .hinweis(Hinweis(
                titel: "\(name) ist gesperrt",
                text: "Entsperre dein \(geraet) einmal mit dem Code und versuche es dann erneut."
            ))
        default:
            return .abgebrochen
        }
    }
}
