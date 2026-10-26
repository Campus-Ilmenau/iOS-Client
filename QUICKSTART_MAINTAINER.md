# 🎯 Quick Start: Git Remote einrichten

**Für: Kai Gothe (Maintainer)**

## ✅ Status: Sicherheit ist eingerichtet!

Alle Schutzmechanismen sind aktiv:
- `.gitignore` → Schützt Credentials, API-Keys, Team-IDs
- `APIConfig.swift.example` → Template für Contributors
- GitHub Actions → Automatische Security-Checks
- `.gitattributes` → Optimiert für Xcode

---

## 🚀 In 5 Minuten zu GitHub

### Schritt 1: Lokales Repository initialisieren (30 Sekunden)

```bash
# Im Projektordner:
cd "/path/to/Campus Ilmenau"

git init
git branch -M main
```

### Schritt 2: API-Config sichern (1 Minute)

```bash
# Falls Sie bereits echte API-Keys im Code haben:
# 1. Kopieren Sie APIConfig.swift.example zu APIConfig.swift
cp APIConfig.swift.example APIConfig.swift

# 2. Verschieben Sie Ihre echten Keys nach APIConfig.swift
# 3. Löschen Sie Keys aus anderen Swift-Dateien
# 4. Prüfen:
git status  # APIConfig.swift sollte NICHT auftauchen
```

### Schritt 3: Erster Commit (1 Minute)

```bash
# Alle Dateien hinzufügen (geschützt durch .gitignore):
git add .

# Schauen Sie was hinzugefügt wird:
git status

# Quick Security Check:
git grep -i "DEVELOPMENT_TEAM" || echo "✅ OK"
git grep -i "api.*key.*=.*\"[A-Za-z0-9]" || echo "✅ OK"

# Commit erstellen:
git commit -m "Initial commit - Campus Ilmenau App

- SwiftUI iOS App für TU Ilmenau Studierende
- Sicherheits-Setup mit .gitignore
- API-Config-Template für Contributors
- GitHub Actions für CI/CD"
```

### Schritt 4: GitHub Repository erstellen (2 Minuten)

#### Option A: Mit GitHub CLI (schnellste Methode)

```bash
# Installieren falls noch nicht vorhanden:
brew install gh

# Anmelden:
gh auth login

# Repository erstellen und direkt pushen:
gh repo create Campus-Ilmenau-iOS \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "iOS App für Studierende der TU Ilmenau"

# Topics hinzufügen:
gh repo edit --add-topic swift,swiftui,ios,tu-ilmenau,campus-app
```

**Fertig! 🎉** Ihr Repository ist live!

#### Option B: Manuell (wenn gh nicht verfügbar)

1. Gehen Sie zu https://github.com/new
2. **Repository name:** `Campus-Ilmenau-iOS`
3. **Description:** "iOS App für Studierende der TU Ilmenau"
4. **Public** Repository
5. **NICHT** "Initialize with README" anklicken
6. Klicken Sie "Create repository"

Dann im Terminal:

```bash
# Remote hinzufügen (mit Ihrem GitHub-Username):
git remote add origin git@github.com:kaigothe/Campus-Ilmenau-iOS.git

# Oder mit HTTPS:
git remote add origin https://github.com/kaigothe/Campus-Ilmenau-iOS.git

# Pushen:
git push -u origin main
```

### Schritt 5: GitHub konfigurieren (30 Sekunden)

Im Browser auf GitHub:

1. **Settings → General:**
   - Social Preview: Fügen Sie ein Bild hinzu (optional)
   - Features: ✅ Issues, ✅ Discussions (optional)

2. **Topics hinzufügen** (oben auf der Repository-Seite):
   - `swift`, `swiftui`, `ios`, `tu-ilmenau`, `campus-app`

3. **Branch Protection** (empfohlen):
   ```
   Settings → Branches → Add rule
   - Branch name: main
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass
   ```

---

## 🔄 Tägliche Arbeit danach

```bash
# Status prüfen:
git status

# Änderungen committen:
git add .
git commit -m "Beschreibung der Änderung"
git push

# Contributors' Pull Requests mergen:
gh pr list
gh pr checkout 123  # PR-Nummer
gh pr merge 123 --squash
```

---

## 🔐 API-Keys für CI/CD (optional)

Falls Sie Tests mit echten APIs in GitHub Actions laufen lassen wollen:

```bash
# Im GitHub Repository:
Settings → Secrets and variables → Actions → New repository secret

# Beispiel Secrets:
MENSA_API_KEY
TU_API_KEY
OEPNV_API_KEY
```

Dann in `.github/workflows/ios.yml` verwenden:
```yaml
env:
  MENSA_API_KEY: ${{ secrets.MENSA_API_KEY }}
```

---

## 📊 Monitoring

### GitHub Actions Status:

```bash
# CLI:
gh run list
gh run view

# Oder im Browser:
# https://github.com/kaigothe/Campus-Ilmenau-iOS/actions
```

### Was die Actions prüfen:

1. **Build Job:** Kompiliert die App (ohne Code-Signing)
2. **Security Job:** Sucht nach versehentlich committeten Secrets
3. **SwiftLint Job:** Prüft Code-Style

Bei Fehlern erhalten Sie eine E-Mail von GitHub.

---

## 🆘 Troubleshooting

### Problem: "Team-ID im Projekt gefunden"

```bash
# Finden:
git grep -r "DEVELOPMENT_TEAM"

# Xcode: Project Settings → Signing → Team auf "None" setzen
# Dann committen und pushen
```

### Problem: "API-Key versehentlich committed"

```bash
# Aus Git-History entfernen:
brew install bfg
bfg --delete-files APIConfig.swift
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push origin --force --all

# Dann API-Keys bei Anbieter rotieren!
```

### Problem: "Push rejected"

```bash
# Erst pullen:
git pull --rebase origin main
git push
```

---

## 📝 Wichtige Dateien für Sie

| Datei | Zweck | Committed? |
|-------|-------|-----------|
| `APIConfig.swift` | **Ihre echten Keys** | ❌ NEIN |
| `APIConfig.swift.example` | Template für Contributors | ✅ JA |
| `.gitignore` | Schützt sensible Dateien | ✅ JA |
| `GIT_SETUP.md` | Ausführliche Anleitung | ✅ JA |
| `README 2.md` | Projekt-Dokumentation | ✅ JA |

---

## ✅ Checkliste

- [ ] `git init` ausgeführt
- [ ] API-Keys in `APIConfig.swift` verschoben (wenn vorhanden)
- [ ] `git status` zeigt keine Secrets
- [ ] Erster Commit erstellt
- [ ] GitHub Repository erstellt
- [ ] Remote verbunden
- [ ] Erfolgreich gepusht
- [ ] GitHub Actions laufen durch
- [ ] Branch Protection aktiviert (optional)
- [ ] Topics hinzugefügt

---

## 🎉 Fertig!

Ihr Repository ist jetzt live und sicher! 

**Nächste Schritte:**
1. Entwickeln Sie die App weiter
2. Committen & pushen Sie regelmäßig
3. Akzeptieren Sie Pull Requests von Contributors
4. Pflegen Sie Issues und Discussions

**Support:**
- Fragen zur Sicherheit: Siehe `GIT_SETUP.md`
- Allgemeine Git-Hilfe: `git help`
- GitHub CLI: `gh help`

---

**Made with ❤️ for Campus Ilmenau**
