import SwiftUI

/// Hält den Zustand für die Previews des Login-Sheets, damit sich die Felder wie echt verhalten.
private struct LoginPreviewHost: View {
    let reason: PAIALoginContent.Reason
    var errorMessage: String?
    var isLoggingIn = false
    var scanSupported = false
    var scannedNumber: String?
    @State var username: String
    @State var password: String

    init(
        reason: PAIALoginContent.Reason,
        username: String = "",
        password: String = "",
        errorMessage: String? = nil,
        isLoggingIn: Bool = false,
        scanSupported: Bool = false,
        scannedNumber: String? = nil
    ) {
        self.reason = reason
        self.errorMessage = errorMessage
        self.isLoggingIn = isLoggingIn
        self.scanSupported = scanSupported
        self.scannedNumber = scannedNumber
        _username = State(initialValue: username)
        _password = State(initialValue: password)
    }

    var body: some View {
        PAIALoginContent(
            reason: reason,
            username: $username,
            password: $password,
            errorMessage: errorMessage,
            isLoggingIn: isLoggingIn,
            onLogin: {},
            onCancel: {},
            onOpenCatalog: {},
            scanSupported: scanSupported,
            initiallyScanned: scannedNumber
        )
    }
}

private extension LoginPreviewHost {
    static var fresh: LoginPreviewHost { .init(reason: .missing) }
    static var expired: LoginPreviewHost { .init(reason: .expired, username: "0001234567") }
    static var loading: LoginPreviewHost {
        .init(reason: .missing, username: "0001234567", password: "geheim", isLoggingIn: true)
    }
    /// Gerät mit Kamera: Button „Scannen“ im Feld.
    static var withScanButton: LoginPreviewHost { .init(reason: .missing, scanSupported: true) }
    /// Nach einem Scan: grüner Rand und „Von deiner Thoska übernommen.“
    static var afterScan: LoginPreviewHost {
        .init(reason: .missing, username: "0001234567", scanSupported: true, scannedNumber: "0001234567")
    }
    static var serverError: LoginPreviewHost {
        .init(
            reason: .missing,
            username: "0001234567",
            password: "falsch",
            errorMessage: "Benutzernummer oder Passwort ist falsch."
        )
    }
}

// MARK: - Neu anmelden

#Preview("Neu anmelden – Light") { LoginPreviewHost.fresh.preferredColorScheme(.light) }
#Preview("Neu anmelden – Dark") { LoginPreviewHost.fresh.preferredColorScheme(.dark) }
#Preview("Neu anmelden – xxxLarge") {
    LoginPreviewHost.fresh.dynamicTypeSize(.xxxLarge)
}

// MARK: - Mit Scan-Button (Gerät mit Kamera)

#Preview("Scannen – Light") { LoginPreviewHost.withScanButton.preferredColorScheme(.light) }
#Preview("Scannen – Dark") { LoginPreviewHost.withScanButton.preferredColorScheme(.dark) }
#Preview("Scannen – xxxLarge") { LoginPreviewHost.withScanButton.dynamicTypeSize(.xxxLarge) }

// MARK: - Nach erfolgreichem Scan

#Preview("Nach Scan – Light") { LoginPreviewHost.afterScan.preferredColorScheme(.light) }
#Preview("Nach Scan – Dark") { LoginPreviewHost.afterScan.preferredColorScheme(.dark) }

// MARK: - Sitzung abgelaufen

#Preview("Sitzung abgelaufen – Light") { LoginPreviewHost.expired.preferredColorScheme(.light) }
#Preview("Sitzung abgelaufen – Dark") { LoginPreviewHost.expired.preferredColorScheme(.dark) }
#Preview("Sitzung abgelaufen – xxxLarge") {
    LoginPreviewHost.expired.dynamicTypeSize(.xxxLarge)
}

// MARK: - Ladezustand

#Preview("Lädt – Light") { LoginPreviewHost.loading.preferredColorScheme(.light) }
#Preview("Lädt – Dark") { LoginPreviewHost.loading.preferredColorScheme(.dark) }
#Preview("Lädt – xxxLarge") {
    LoginPreviewHost.loading.dynamicTypeSize(.xxxLarge)
}

// MARK: - Serverfehler

#Preview("Serverfehler – Light") { LoginPreviewHost.serverError.preferredColorScheme(.light) }
#Preview("Serverfehler – Dark") { LoginPreviewHost.serverError.preferredColorScheme(.dark) }
#Preview("Serverfehler – xxxLarge") {
    LoginPreviewHost.serverError.dynamicTypeSize(.xxxLarge)
}

// MARK: - Abgemeldet (Platzhalter nach Abbrechen)

#Preview("Abgemeldet – Light") {
    PAIASignedOutView(sessionExpired: false, onLogin: {}).preferredColorScheme(.light)
}
#Preview("Abgemeldet – Dark") {
    PAIASignedOutView(sessionExpired: false, onLogin: {}).preferredColorScheme(.dark)
}
#Preview("Abgemeldet – xxxLarge") {
    PAIASignedOutView(sessionExpired: false, onLogin: {}).dynamicTypeSize(.xxxLarge)
}
#Preview("Sitzung abgelaufen (Platzhalter) – Light") {
    PAIASignedOutView(sessionExpired: true, onLogin: {}).preferredColorScheme(.light)
}
#Preview("Sitzung abgelaufen (Platzhalter) – Dark") {
    PAIASignedOutView(sessionExpired: true, onLogin: {}).preferredColorScheme(.dark)
}
