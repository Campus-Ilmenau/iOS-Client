# 🚀 SETUP - Kopieren Sie diese Befehle ins Terminal

## Schritt 1: Git initialisieren
```bash
cd "/path/to/Campus Ilmenau"  # ← Passen Sie den Pfad an!
git init
git branch -M main
```

## Schritt 2: Quick Security-Check
```bash
# Check für Team-IDs:
git grep -i "DEVELOPMENT_TEAM" || echo "✅ OK"

# Check für APIConfig.swift:
git status | grep "APIConfig.swift$" && echo "⚠️ WARNUNG" || echo "✅ OK"
```

## Schritt 3: Remote hinzufügen
```bash
git remote add origin https://github.com/Campus-Ilmenau/iOS-Client.git
git remote -v
```

## Schritt 4: Ersten Commit
```bash
git add .
git status  # Prüfen Sie was hinzugefügt wird
git commit -m "Initial commit - Campus Ilmenau iOS App

- SwiftUI App für TU Ilmenau Studierende
- Sicherheits-Setup mit .gitignore
- API-Config-Template für Contributors
- GitHub Actions für CI/CD"
```

## Schritt 5: Push zu GitHub
```bash
git push -u origin main
```

## Nach dem Push:
```bash
# Im Browser öffnen:
open https://github.com/Campus-Ilmenau/iOS-Client
open https://github.com/Campus-Ilmenau/iOS-Client/actions
```

## ✅ Fertig!

Ihr Repository ist jetzt live: https://github.com/Campus-Ilmenau/iOS-Client

### Nächste Schritte:
1. GitHub-Repository konfigurieren (Description, Topics)
2. GitHub Actions prüfen (sollten alle grün sein ✅)
3. API-Config erstellen: `cp APIConfig.swift.example APIConfig.swift`
4. Features entwickeln!
