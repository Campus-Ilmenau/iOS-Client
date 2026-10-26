# Campus Ilmenau

Eine Community-App für den Campus Ilmenau.

## Voraussetzungen

- Xcode 15.0 oder neuer
- iOS 17.0 oder neuer (Target Version wird im Projekt definiert)
- Ein Apple Developer Account (kostenlos für lokales Testen)

## Installation für Contributors

1. Repository klonen:
   ```bash
   git clone https://github.com/Campus-Ilmenau/iOS-Client.git
   cd iOS-Client
   ```

2. Projekt in Xcode öffnen:
   ```bash
   open "Campus Ilmenau.xcodeproj"
   ```
   
   Falls keine `.xcodeproj`-Datei vorhanden ist, öffnen Sie den Ordner direkt in Xcode.

3. **Wichtig: Code Signing konfigurieren**
   
   Da dieses Projekt keine spezifischen Team-IDs oder Provisioning Profiles enthält, müssen Sie Ihre eigenen Signing-Einstellungen vornehmen:
   
   - Öffnen Sie das Projekt in Xcode
   - Wählen Sie das Target "Campus Ilmenau"
   - Gehen Sie zum Tab "Signing & Capabilities"
   - Wählen Sie Ihr eigenes Team aus oder verwenden Sie "Automatically manage signing"
   - Ändern Sie ggf. die Bundle Identifier zu einem eindeutigen Wert (z.B. `com.IhrName.CampusIlmenau`)

4. Build und Run
   ```
   Wählen Sie einen Simulator oder Ihr Gerät und drücken Sie Cmd+R
   ```

## Für Contributors

### Code-Beiträge

Wir freuen uns über Community-Beiträge! Bitte beachten Sie:

1. Forken Sie das Repository
2. Erstellen Sie einen Feature-Branch (`git checkout -b feature/AmazingFeature`)
3. Committen Sie Ihre Änderungen (`git commit -m 'Add some AmazingFeature'`)
4. Pushen Sie zum Branch (`git push origin feature/AmazingFeature`)
5. Öffnen Sie einen Merge Request

### Wichtige Hinweise

⚠️ **Bitte committen Sie NIEMALS:**
- Ihre persönlichen Signing-Zertifikate oder Provisioning Profiles
- Team-IDs oder persönliche Developer Account-Daten
- API-Keys oder Secrets
- `.xcuserdata` oder andere benutzerspezifische Xcode-Dateien

Die `.gitignore`-Datei ist so konfiguriert, dass diese Dateien automatisch ausgeschlossen werden.

### Bundle Identifier

Wenn Sie das Projekt lokal bauen, müssen Sie möglicherweise den Bundle Identifier ändern, da der Original-Identifier bereits registriert ist. Verwenden Sie Ihren eigenen eindeutigen Identifier (z.B. `com.IhrName.CampusIlmenau`).

## Projekt-Struktur

```
Campus Ilmenau/
├── Campus_IlmenauApp.swift  # App Entry Point
├── ContentView.swift          # Main View
└── Assets/                    # (Bilder, Icons, etc.)
```

## Features (geplant)

- [ ] Feature 1
- [ ] Feature 2
- [ ] Feature 3

## Lizenz

[Fügen Sie hier Ihre gewünschte Lizenz ein, z.B. MIT, GPL, etc.]

## Kontakt

Bei Fragen oder Problemen öffnen Sie bitte ein [Issue](https://github.com/Campus-Ilmenau/iOS-Client/issues) im GitHub-Repository.
