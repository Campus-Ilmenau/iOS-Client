## Checkliste vor dem ersten Commit

Bevor Sie Ihr Projekt auf GitHub veröffentlichen, stellen Sie bitte sicher:

### 1. Xcode-Projekt überprüfen

- [ ] Öffnen Sie Ihr Projekt in Xcode
- [ ] Gehen Sie zu Project Settings > Signing & Capabilities
- [ ] Stellen Sie sicher, dass "Automatically manage signing" aktiviert ist (empfohlen für Open Source)
- [ ] Entfernen Sie spezifische Team-IDs (diese werden lokal von Contributors gesetzt)

### 2. Sensible Daten entfernen

- [ ] Suchen Sie im gesamten Projekt nach persönlichen Daten:
  - Team-IDs
  - Bundle-IDs (überlegen Sie, ob Sie eine generische verwenden möchten)
  - API-Keys
  - Persönliche E-Mail-Adressen (außer in Autoren-Feldern)

- [ ] Prüfen Sie diese Dateien besonders:
  - `*.xcodeproj/project.pbxproj` - Enthält möglicherweise Team-IDs
  - `*.entitlements` - Kann App-spezifische Berechtigungen enthalten
  - `Info.plist` - Kann API-Keys oder URLs enthalten

### 3. .gitignore validieren

- [ ] Die bereitgestellte `.gitignore` ist bereits konfiguriert
- [ ] Testen Sie mit: `git status --ignored` um zu sehen, was ignoriert wird

### 4. Git Repository initialisieren

```bash
# Im Projekt-Verzeichnis:
git init
git add .gitignore README.md CONTRIBUTING.md SECURITY_CHECKLIST.md
git add Campus_IlmenauApp.swift ContentView.swift
# Fügen Sie weitere Dateien hinzu, überprüfen Sie diese einzeln!
git commit -m "Initial commit"
```

### 5. Vor jedem Commit überprüfen

```bash
# Zeigt alle Dateien, die committet werden:
git diff --cached

# Suchen Sie nach sensiblen Informationen:
git diff --cached | grep -i "team"
git diff --cached | grep -i "apple"
git diff --cached | grep -i "DEVELOPMENT_TEAM"
```

### 6. Remote Repository hinzufügen

```bash
# GitHub Repository URL hinzufügen:
git remote add origin https://github.com/YOUR-USERNAME/campus-ilmenau.git
git branch -M main
git push -u origin main
```

### 7. GitHub-Repository-Einstellungen

Nach dem ersten Push:

- [ ] Fügen Sie eine Repository-Beschreibung hinzu
- [ ] Fügen Sie Topics/Tags hinzu (z.B. "swift", "ios", "swiftui", "ilmenau")
- [ ] Konfigurieren Sie Branch-Protection-Rules für `main`:
  - Require pull request reviews before merging
  - Require status checks to pass (GitHub Actions)
- [ ] Setzen Sie die Repository-Sichtbarkeit (Public/Private)
- [ ] Aktivieren Sie Issues
- [ ] Aktivieren Sie Discussions (optional)

### 8. GitHub Actions ist bereits eingerichtet!

Die `.github/workflows/ios.yml` ist bereits vorbereitet und wird automatisch ausgeführt:

✅ **Build-Check** - Baut das Projekt für iOS Simulator
✅ **Security-Check** - Prüft auf versehentlich committete Secrets
✅ **SwiftLint** - Code-Stil-Überprüfung

Die Workflows laufen automatisch bei:
- Push auf `main` oder `develop`
- Pull Requests auf `main` oder `develop`

### 9. Dokumentation vervollständigen

- [ ] README.md: Ersetzen Sie `YOUR-USERNAME` mit Ihrem GitHub-Username
- [ ] Screenshots hinzufügen (ohne persönliche Daten!)
- [ ] LICENSE ist bereits vorhanden (MIT)
- [ ] CODE_OF_CONDUCT.md ist bereits vorhanden
- [ ] CONTRIBUTING.md ist bereits vorhanden

### 10. Community-Features aktivieren

- [ ] Issue-Templates sind bereits vorhanden (`.github/ISSUE_TEMPLATE/`)
- [ ] Pull Request-Template ist bereits vorhanden
- [ ] Wiki aktivieren (optional)
- [ ] Discussions aktivieren (optional)
- [ ] GitHub Sponsors konfigurieren (optional, siehe `.github/FUNDING.yml`)

## Wichtige Befehle

### Prüfen, was committet wird:
```bash
git status
git diff
git diff --cached
```

### Dateien aus Git-History entfernen (falls versehentlich committed):
```bash
# Einzelne Datei:
git rm --cached <datei>

# Aus gesamter History entfernen (VORSICHT!):
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch <datei>" \
  --prune-empty --tag-name-filter cat -- --all
```

### Nach sensiblen Daten suchen:
```bash
# Im gesamten Repository:
git grep -i "DEVELOPMENT_TEAM"
git grep -i "api_key"
git grep -i "@icloud.com"
```

## Fortlaufende Sicherheit

- Aktivieren Sie GitHub's Secret Scanning (automatisch für Public Repos)
- Aktivieren Sie Dependabot für Security Updates
- Reviewen Sie alle Pull Requests sorgfältig
- Weisen Sie Contributors auf die CONTRIBUTING.md hin
- Aktualisieren Sie regelmäßig die .gitignore

## Bei Problemen

Falls Sie versehentlich sensible Daten committed haben:

1. **NICHT** einfach weitermachen
2. **SOFORT** den Commit aus der History entfernen (siehe unten)
3. **EVENTUELL** API-Keys rotieren/ändern
4. **Bei Public Repos:** GitHub's Secret Scanning wird Sie automatisch warnen
5. **DANN** mit sauberem Zustand neu pushen

### Sensible Daten aus Git-History entfernen:

**Option 1: BFG Repo-Cleaner (empfohlen)**
```bash
# BFG installieren (macOS)
brew install bfg

# Datei aus gesamter History entfernen
bfg --delete-files sensitive-file.txt

# Aufräumen
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

**Option 2: git filter-repo**
```bash
# git-filter-repo installieren
brew install git-filter-repo

# Datei aus History entfernen
git filter-repo --path sensitive-file.txt --invert-paths
```

## Hilfreiche Links

- [Git Documentation](https://git-scm.com/doc)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [Apple Developer Program](https://developer.apple.com/programs/)
