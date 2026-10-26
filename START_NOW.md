# 🚀 JETZT STARTEN: Git-Verbindung einrichten

**Remote-Adresse:** `https://github.com/Campus-Ilmenau/iOS-Client.git`

---

## ✅ Schritt 1: Prüfen Sie den aktuellen Status (30 Sekunden)

```bash
# Wechseln Sie in Ihr Projektverzeichnis:
cd "/path/to/Campus Ilmenau"

# Prüfen Sie, ob Git bereits initialisiert ist:
git status

# Falls "not a git repository" erscheint, initialisieren Sie Git:
git init
git branch -M main
```

---

## ✅ Schritt 2: API-Keys sichern (2 Minuten)

### Falls Sie bereits API-Keys im Code haben:

```bash
# 1. Kopieren Sie das Template:
cp APIConfig.swift.example APIConfig.swift

# 2. Öffnen Sie APIConfig.swift in Xcode:
open APIConfig.swift

# 3. Fügen Sie Ihre echten API-Keys dort ein
# 4. Entfernen Sie API-Keys aus anderen Swift-Dateien
```

### Wichtig prüfen:

```bash
# APIConfig.swift sollte NICHT in Git erscheinen:
git status | grep "APIConfig.swift$" && echo "⚠️ WARNUNG!" || echo "✅ Sicher!"

# Falls APIConfig.swift erscheint:
git rm --cached APIConfig.swift
```

---

## ✅ Schritt 3: Security-Check (1 Minute)

```bash
# Prüfen Sie auf Team-IDs:
git grep -r "DEVELOPMENT_TEAM" 2>/dev/null | grep -v xcuserdata || echo "✅ Keine Team-IDs"

# Prüfen Sie auf API-Keys im Code:
git grep -r -i "api.*key.*=.*\"[A-Za-z0-9]\{10,\}\"" 2>/dev/null || echo "✅ Keine API-Keys"

# Prüfen Sie auf Provisioning Profiles:
find . -name "*.mobileprovision" 2>/dev/null | grep -v DerivedData || echo "✅ Keine Profiles"
```

**Wenn etwas gefunden wird:**
- Team-IDs: In Xcode → Project Settings → Signing → Team auf "None"
- API-Keys: Verschieben Sie sie nach `APIConfig.swift`
- Provisioning Profiles: Sollten durch `.gitignore` geschützt sein

---

## ✅ Schritt 4: Erster Commit (1 Minute)

```bash
# Alle Dateien hinzufügen (geschützt durch .gitignore):
git add .

# Schauen Sie, was hinzugefügt wird:
git status

# WICHTIG: Prüfen Sie, dass APIConfig.swift NICHT dabei ist!
# Falls doch: git restore --staged APIConfig.swift

# Commit erstellen:
git commit -m "Initial commit - Campus Ilmenau iOS App

- SwiftUI App für TU Ilmenau Studierende
- Sicherheits-Setup mit .gitignore
- API-Config-Template für Contributors
- GitHub Actions für CI/CD und Security-Checks"
```

---

## ✅ Schritt 5: Remote verbinden und pushen (1 Minute)

### Mit HTTPS (empfohlen):

```bash
# Remote hinzufügen:
git remote add origin https://github.com/Campus-Ilmenau/iOS-Client.git

# Prüfen:
git remote -v

# Ersten Push (Sie werden nach GitHub-Credentials gefragt):
git push -u origin main
```

### Mit SSH (falls konfiguriert):

```bash
# Remote hinzufügen:
git remote add origin git@github.com:Campus-Ilmenau/iOS-Client.git

# Ersten Push:
git push -u origin main
```

### Falls "remote origin already exists":

```bash
# Prüfen Sie die aktuelle Remote:
git remote -v

# Falls falsch, ändern Sie sie:
git remote set-url origin https://github.com/Campus-Ilmenau/iOS-Client.git

# Dann pushen:
git push -u origin main
```

---

## ✅ Schritt 6: GitHub Actions prüfen (30 Sekunden)

Nach dem Push laufen automatisch die GitHub Actions:

### Im Browser:
Öffnen Sie: https://github.com/Campus-Ilmenau/iOS-Client/actions

### Mit GitHub CLI:
```bash
# GitHub CLI installieren (falls noch nicht):
brew install gh

# Anmelden:
gh auth login

# Status prüfen:
gh run list --repo Campus-Ilmenau/iOS-Client

# Details ansehen:
gh run view --repo Campus-Ilmenau/iOS-Client
```

### Was läuft ab:

1. **Build Job** ✅
   - Kompiliert die App
   - Läuft auf iOS Simulator
   - Ohne Code-Signing

2. **Security-Check Job** 🔍
   - Sucht nach DEVELOPMENT_TEAM
   - Sucht nach Provisioning Profiles
   - Sucht nach Zertifikaten
   - Sucht nach API-Keys
   - **BLOCKIERT** bei Fund!

3. **SwiftLint Job** 🎨
   - Prüft Code-Style
   - Warnt bei `print()` Statements

---

## ✅ Schritt 7: GitHub Repository konfigurieren (2 Minuten)

### Im Browser: https://github.com/Campus-Ilmenau/iOS-Client

#### About-Sektion (rechts oben):
```
⚙️ → Edit repository details:
- Description: "iOS App für Studierende der TU Ilmenau - SwiftUI"
- Website: (optional)
- Topics: swift, swiftui, ios, tu-ilmenau, campus-app, student-app
- ✅ Issues
- ✅ Discussions (optional)
```

#### Settings → General:
```
Features:
- ✅ Issues
- ✅ Discussions (optional für Community-Austausch)
- ✅ Projects (optional für Roadmap)
- ✅ Wiki (optional)

Pull Requests:
- ✅ Allow squash merging
- ✅ Allow auto-merge
- ✅ Automatically delete head branches
```

#### Settings → Branches:
```
Branch protection rules → Add rule:

Branch name pattern: main

Protection rules:
- ✅ Require a pull request before merging
  - ✅ Require approvals (1)
- ✅ Require status checks to pass before merging
  - ✅ Require branches to be up to date
  - Status checks: build, security-check, swiftlint
- ✅ Require conversation resolution before merging
- ✅ Do not allow bypassing the above settings
```

---

## 🎉 Fertig! Was jetzt?

### Tägliche Arbeit:

```bash
# Änderungen machen in Xcode...

# Status prüfen:
git status

# Committen:
git add .
git commit -m "Add Mensa-Feature"
git push

# GitHub Actions laufen automatisch!
```

### Contributors einladen:

1. **Settings → Collaborators** (für direkten Zugriff)
2. **Oder:** Contributors forken das Repo und erstellen Pull Requests

### Pull Requests reviewen:

```bash
# PR herunterladen:
gh pr checkout 123

# Lokal testen...

# Mergen:
gh pr merge 123 --squash
```

---

## 📊 Monitoring

### GitHub Actions Status:

```bash
# Letzte Runs:
gh run list --repo Campus-Ilmenau/iOS-Client --limit 10

# Einen Run ansehen:
gh run view RUN_ID --repo Campus-Ilmenau/iOS-Client

# Logs ansehen:
gh run view RUN_ID --log --repo Campus-Ilmenau/iOS-Client
```

### Im Browser:
- **Actions:** https://github.com/Campus-Ilmenau/iOS-Client/actions
- **Issues:** https://github.com/Campus-Ilmenau/iOS-Client/issues
- **Pull Requests:** https://github.com/Campus-Ilmenau/iOS-Client/pulls
- **Insights → Traffic:** Besucher-Statistiken
- **Insights → Community:** Community-Health

---

## 🔐 API-Keys für Contributors

### In der README steht bereits:

> **Contributors:** Kopieren Sie `APIConfig.swift.example` zu `APIConfig.swift` und fügen Sie Ihre eigenen Test-API-Keys ein. Diese Datei wird nicht committed.

### Workflow:

1. Contributor klont: `git clone https://github.com/Campus-Ilmenau/iOS-Client.git`
2. Contributor kopiert: `cp APIConfig.swift.example APIConfig.swift`
3. Contributor fügt Test-Keys ein
4. Contributor entwickelt lokal
5. Contributor pusht → `APIConfig.swift` wird ignoriert ✅

---

## 🆘 Troubleshooting

### Problem: "Permission denied"

```bash
# Prüfen Sie Ihre GitHub-Authentifizierung:
gh auth status

# Neu anmelden:
gh auth login

# Oder generieren Sie ein Personal Access Token:
# GitHub → Settings → Developer settings → Personal access tokens
```

### Problem: "Updates were rejected"

```bash
# Jemand anderes hat schon gepusht, erst pullen:
git pull --rebase origin main
git push
```

### Problem: "GitHub Actions failed"

```bash
# Logs ansehen:
gh run view --log --repo Campus-Ilmenau/iOS-Client

# Oder im Browser:
# https://github.com/Campus-Ilmenau/iOS-Client/actions
```

**Häufige Ursachen:**
- Security-Check findet DEVELOPMENT_TEAM
- Security-Check findet API-Keys im Code
- Build-Fehler (fehlende Dependencies)
- SwiftLint-Warnungen

---

## 📋 Checkliste

- [ ] Git initialisiert (`git init`)
- [ ] API-Keys gesichert (in `APIConfig.swift`)
- [ ] Security-Check durchgeführt (keine Secrets)
- [ ] Erster Commit erstellt
- [ ] Remote hinzugefügt (`origin`)
- [ ] Erfolgreich gepusht (`main`)
- [ ] GitHub Actions laufen (alle grün ✅)
- [ ] Repository konfiguriert (Description, Topics)
- [ ] Branch Protection aktiviert (optional)
- [ ] Contributors eingeladen (optional)

---

## 🎯 Nächste Schritte für die App

Jetzt können Sie Features entwickeln! Ideen:

### Phase 1: Grundfunktionen
- [ ] 🍽️ Mensa-Speiseplan (API-Integration)
- [ ] 📅 Stundenplan-Ansicht
- [ ] 🗓️ Semesterkalender

### Phase 2: Campus-Services
- [ ] 🗺️ Campus-Karte mit Navigation
- [ ] 📚 Bibliotheks-Integration (Suche, Verfügbarkeit)
- [ ] 🚌 ÖPNV-Verbindungen nach Ilmenau

### Phase 3: Community
- [ ] 📰 News & Ankündigungen
- [ ] 👥 Veranstaltungskalender
- [ ] 💬 Campus-Forum (optional)

---

## 📚 Hilfreiche Links

- **Repository:** https://github.com/Campus-Ilmenau/iOS-Client
- **Actions:** https://github.com/Campus-Ilmenau/iOS-Client/actions
- **Issues:** https://github.com/Campus-Ilmenau/iOS-Client/issues
- **GitHub Docs:** https://docs.github.com
- **Swift Docs:** https://docs.swift.org
- **SwiftUI Docs:** https://developer.apple.com/xcode/swiftui/

---

## ✅ Zusammenfassung

**Sie haben:**
- ✅ Remote-Adresse konfiguriert
- ✅ Vollständigen Security-Schutz
- ✅ Automatische CI/CD-Pipeline
- ✅ API-Key-Management für Contributors
- ✅ Code-Qualitäts-Checks

**Bereit für:**
- 🚀 Open-Source-Entwicklung
- 👥 Community-Contributions
- 🔒 Sichere API-Key-Verwaltung
- 🤖 Automatische Tests & Checks

---

**Viel Erfolg mit der Campus Ilmenau App! 🎓**

Bei Fragen: Issues auf GitHub oder lesen Sie `GIT_SETUP.md`
