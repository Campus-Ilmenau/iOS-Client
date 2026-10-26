# Contributing zu Campus Ilmenau

Vielen Dank für Ihr Interesse, zu Campus Ilmenau beizutragen! Dieses Dokument enthält Richtlinien für Contributors.

## Code of Conduct

Dieses Projekt folgt dem [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). Durch Ihre Teilnahme verpflichten Sie sich, diesen Code einzuhalten.

## Sicherheit und Datenschutz

### ⚠️ Was Sie NIEMALS committen dürfen:

1. **Apple Developer Account-Daten:**
   - Team-IDs (außer sie sind im Code als Platzhalter)
   - Signing-Zertifikate (`.p12`, `.cer`)
   - Provisioning Profiles (`.mobileprovision`)
   - App Store Connect API-Keys (`.p8` Dateien)

2. **Persönliche Informationen:**
   - Ihre persönliche E-Mail-Adresse (außer in Commits)
   - Telefonnummern
   - Adressen

3. **Secrets und API-Keys:**
   - Firebase-Konfigurationen
   - Backend-API-Keys
   - Verschlüsselungs-Keys
   - OAuth-Secrets

4. **Xcode-Benutzerdaten:**
   - `xcuserdata/` Ordner
   - `.xcworkspace` (wenn SPM verwendet wird)
   - Persönliche Breakpoints oder Schemes

### ✅ Best Practices:

1. **Überprüfen Sie vor dem Commit:**
   ```bash
   git status
   git diff
   ```

2. **Verwenden Sie die bereitgestellte .gitignore:**
   Die `.gitignore`-Datei ist bereits konfiguriert, um sensible Dateien auszuschließen.

3. **API-Keys auslagern:**
   Wenn Sie API-Keys benötigen, verwenden Sie eine separate Konfigurationsdatei:
   ```swift
   // Config.swift (nicht im Repository)
   enum Config {
       static let apiKey = "YOUR_API_KEY"
   }
   ```
   
   Und erstellen Sie eine Template-Datei:
   ```swift
   // Config.swift.template (im Repository)
   enum Config {
       static let apiKey = "REPLACE_WITH_YOUR_API_KEY"
   }
   ```

4. **Bundle Identifier:**
   Verwenden Sie für lokale Entwicklung Ihren eigenen Bundle Identifier. Der Original-Identifier sollte nur vom Projekt-Owner verwendet werden.

## Code-Stil

### Swift-Konventionen:

- Verwenden Sie Swift-Naming-Konventionen (camelCase für Variablen, PascalCase für Types)
- Nutzen Sie SwiftUI best practices
- Bevorzugen Sie Swift Concurrency (async/await) über Completion Handlers
- Kommentieren Sie komplexe Logik

### Beispiel:

```swift
import SwiftUI

struct FeatureView: View {
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else {
                // Your content here
            }
        }
    }
}
```

## Pull Request Prozess

1. **Erstellen Sie einen aussagekräftigen Branch-Namen:**
   - `feature/new-map-view`
   - `bugfix/login-crash`
   - `improvement/performance-optimization`

2. **Schreiben Sie klare Commit-Messages:**
   ```
   Add map view for campus navigation
   
   - Implemented MapKit integration
   - Added location services permission
   - Created custom annotations for buildings
   ```

3. **Testen Sie Ihre Änderungen:**
   - Build erfolgreich?
   - Keine Warnings?
   - Funktioniert auf verschiedenen Geräten/Simulatoren?

4. **Aktualisieren Sie die Dokumentation:**
   - README aktualisieren bei neuen Features
   - Code-Kommentare hinzufügen

## Feature-Requests und Bugs

### Bug Reports sollten enthalten:

- iOS/iPadOS Version
- Gerät/Simulator
- Schritte zur Reproduktion
- Erwartetes vs. tatsächliches Verhalten
- Screenshots/Videos (wenn hilfreich)

### Feature Requests sollten enthalten:

- Beschreibung des Features
- Use Case / Warum ist es nützlich?
- Mögliche Implementierungsideen (optional)

## Code Review

Alle Pull Requests werden reviewed. Bitte seien Sie offen für Feedback und Verbesserungsvorschläge.

### GitHub Actions

Ihr Pull Request wird automatisch durch GitHub Actions geprüft:
- Build-Check für iOS Simulator
- Security-Check für versehentlich committete Secrets
- SwiftLint Code-Stil-Überprüfung

Stellen Sie sicher, dass alle Checks erfolgreich sind, bevor Sie um ein Review bitten.

## Lizenz

Indem Sie zu diesem Projekt beitragen, stimmen Sie zu, dass Ihre Beiträge unter derselben Lizenz wie das Projekt lizenziert werden.

## Fragen?

Öffnen Sie ein [Issue](https://github.com/kaigothe/Campus-Ilmenau---iOS-Client/issues) oder kontaktieren Sie die Projekt-Maintainer.

## Hilfreich Links

- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)
- [Swift Style Guide](https://google.github.io/swift/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
