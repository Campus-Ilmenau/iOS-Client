# Campus Ilmenau

[![iOS CI](https://github.com/Campus-Ilmenau/iOS-Client/workflows/iOS%20CI/badge.svg)](https://github.com/Campus-Ilmenau/iOS-Client/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift Version](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0+-lightgrey.svg)](https://developer.apple.com/)

Eine Community-App für den Campus Ilmenau.

## 📱 Voraussetzungen

- Xcode 15.0 oder neuer
- iOS 17.0 oder neuer (Target Version wird im Projekt definiert)
- Ein Apple Developer Account (kostenlos für lokales Testen)

## 🚀 Installation für Contributors

1. **Repository klonen:**
   ```bash
   git clone https://github.com/Campus-Ilmenau/iOS-Client.git
   cd iOS-Client
   ```

2. **API-Konfiguration einrichten:**
   ```bash
   # Kopieren Sie das API-Config-Template:
   cp APIConfig.swift.example APIConfig.swift
   
   # Öffnen Sie APIConfig.swift und fügen Sie Ihre Test-API-Keys ein
   # (Diese Datei wird NICHT committed - ist in .gitignore)
   ```

3. **Projekt in Xcode öffnen:**
   ```bash
   open "Campus Ilmenau.xcodeproj"
   ```
   
   Falls keine `.xcodeproj`-Datei vorhanden ist, öffnen Sie den Ordner direkt in Xcode.

4. **⚠️ Wichtig: Code Signing konfigurieren**
   
   Da dieses Projekt keine spezifischen Team-IDs oder Provisioning Profiles enthält, müssen Sie Ihre eigenen Signing-Einstellungen vornehmen:
   
   - Öffnen Sie das Projekt in Xcode
   - Wählen Sie das Target "Campus Ilmenau"
   - Gehen Sie zum Tab "Signing & Capabilities"
   - Wählen Sie Ihr eigenes Team aus oder verwenden Sie "Automatically manage signing"
   - Ändern Sie ggf. die Bundle Identifier zu einem eindeutigen Wert (z.B. `com.IhrName.CampusIlmenau`)

5. **Build und Run**
   
   Wählen Sie einen Simulator oder Ihr Gerät und drücken Sie `Cmd+R`

## 🤝 Für Contributors

Wir freuen uns über Community-Beiträge! Bitte lesen Sie [CONTRIBUTING.md](CONTRIBUTING.md) für Details zu unserem Code of Conduct und dem Prozess für Pull Requests.

### Schnellanleitung:

1. Forken Sie das Repository
2. Erstellen Sie einen Feature-Branch (`git checkout -b feature/AmazingFeature`)
3. Committen Sie Ihre Änderungen (`git commit -m 'Add some AmazingFeature'`)
4. Pushen Sie zum Branch (`git push origin feature/AmazingFeature`)
5. Öffnen Sie einen Pull Request

### ⚠️ Wichtige Hinweise für Contributors

**Bitte committen Sie NIEMALS:**
- Ihre persönlichen Signing-Zertifikate oder Provisioning Profiles
- Team-IDs oder persönliche Developer Account-Daten
- API-Keys oder Secrets
- `.xcuserdata` oder andere benutzerspezifische Xcode-Dateien

Die `.gitignore`-Datei ist so konfiguriert, dass diese Dateien automatisch ausgeschlossen werden.

### Bundle Identifier

Wenn Sie das Projekt lokal bauen, müssen Sie möglicherweise den Bundle Identifier ändern, da der Original-Identifier bereits registriert ist. Verwenden Sie Ihren eigenen eindeutigen Identifier (z.B. `com.IhrName.CampusIlmenau`).

## 📁 Projekt-Struktur

```
Campus Ilmenau/
├── Campus_IlmenauApp.swift    # App Entry Point
├── ContentView.swift           # Main View
└── Assets/                     # (Bilder, Icons, etc.)
```

## ✨ Features (geplant)

- [ ] Feature 1
- [ ] Feature 2
- [ ] Feature 3

## 🔧 Entwicklung

### Tests ausführen

```bash
xcodebuild test \
  -project "Campus Ilmenau.xcodeproj" \
  -scheme "Campus Ilmenau" \
  -destination "platform=iOS Simulator,name=iPhone 15"
```

### SwiftLint (optional)

Dieses Projekt unterstützt SwiftLint für konsistenten Code-Stil:

```bash
brew install swiftlint
swiftlint
```

## 🤖 GitHub Actions

Dieses Projekt verwendet GitHub Actions für Continuous Integration:

- **Build Check:** Automatische Builds bei jedem Push und Pull Request
- **Security Check:** Prüft auf versehentlich committete Secrets
- **SwiftLint:** Code-Stil-Überprüfung

## 📄 Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe [LICENSE](LICENSE) Datei für Details.

## 📞 Kontakt

Bei Fragen oder Problemen öffnen Sie bitte ein [Issue](https://github.com/Campus-Ilmenau/iOS-Client/issues) im GitHub-Repository.

## 🙏 Danksagungen

Vielen Dank an alle Contributors, die zu diesem Projekt beitragen!

---

**Made with ❤️ for Campus Ilmenau**
