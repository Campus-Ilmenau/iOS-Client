# 🚀 Git & GitHub Setup für Campus Ilmenau

## ✅ Sicherheits-Features sind JETZT aktiv!

Ihr Projekt ist jetzt mit folgenden Sicherheitsmechanismen geschützt:

### 🔒 Geschützte Dateien (durch .gitignore):

- ✅ **Apple Developer Credentials**
  - Provisioning Profiles (*.mobileprovision)
  - Code-Signing-Zertifikate (*.p12, *.cer)
  - App Store Connect API Keys (*.p8)
  
- ✅ **API-Keys & Secrets**
  - APIConfig.swift (Ihre echten API-Keys)
  - Secrets.plist
  - .env Dateien
  - Firebase-Konfigurationen
  
- ✅ **Xcode User Data**
  - xcuserdata/ (enthält Team-IDs)
  - Persönliche Build-Einstellungen
  
- ✅ **Lokale Datenbanken**
  - *.sqlite, *.db Dateien

### 📋 Was Sie verwenden sollen:

1. **`APIConfig.swift.example`** - Template für API-Keys
   - Kopieren Sie diese zu `APIConfig.swift`
   - Fügen Sie Ihre echten Keys ein
   - `APIConfig.swift` wird NICHT committed (ist in .gitignore)

2. **GitHub Actions** - Automatische Security-Checks
   - Prüft bei jedem Push auf versehentlich committete Secrets
   - Build-Tests ohne Code-Signing
   - SwiftLint für Code-Qualität

---

## 📝 Schritt-für-Schritt: Git & GitHub einrichten

### 1️⃣ Lokales Git Repository initialisieren

```bash
cd /path/to/Campus-Ilmenau
git init
git branch -M main
```

### 2️⃣ Sicherheits-Check BEVOR Sie committen

```bash
# Zeigen Sie, was Git sehen wird:
git status

# Prüfen Sie auf Team-IDs im Projekt:
git grep -i "DEVELOPMENT_TEAM" || echo "✅ Keine Team-IDs gefunden"

# Prüfen Sie auf API-Keys:
git grep -i "api.key\|apikey" || echo "✅ Keine API-Keys gefunden"
```

**⚠️ WICHTIG:** Wenn Sie Team-IDs oder API-Keys finden, entfernen Sie diese JETZT!

### 3️⃣ Ersten Commit erstellen

```bash
# Alle Dateien hinzufügen (geschützt durch .gitignore):
git add .

# Schauen Sie, was hinzugefügt wird:
git status

# Erstellen Sie den Commit:
git commit -m "Initial commit - Campus Ilmenau App mit Security-Setup"
```

### 4️⃣ GitHub Repository erstellen

#### Option A: Über GitHub Website
1. Gehen Sie zu https://github.com/new
2. Repository Name: `Campus-Ilmenau-iOS`
3. Description: "iOS App für Studierende der TU Ilmenau"
4. **Public** (da Open Source)
5. **NICHT** "Initialize with README" anklicken (haben wir schon)
6. Erstellen Sie das Repository

#### Option B: Über GitHub CLI (gh)
```bash
# GitHub CLI installieren (falls noch nicht vorhanden):
brew install gh

# Anmelden:
gh auth login

# Repository erstellen:
gh repo create Campus-Ilmenau-iOS --public --source=. --remote=origin --push
```

### 5️⃣ Remote verbinden und pushen (manuell)

```bash
# Remote hinzufügen (ersetzen Sie YOUR-USERNAME):
git remote add origin https://github.com/YOUR-USERNAME/Campus-Ilmenau-iOS.git

# ODER mit SSH:
git remote add origin git@github.com:YOUR-USERNAME/Campus-Ilmenau-iOS.git

# Prüfen:
git remote -v

# Ersten Push:
git push -u origin main
```

### 6️⃣ Nach dem ersten Push: GitHub konfigurieren

1. **Repository-Settings**
   - Fügen Sie Topics hinzu: `swift`, `swiftui`, `ios`, `tu-ilmenau`, `campus-app`
   - Setzen Sie eine Beschreibung
   - Aktivieren Sie Issues
   - Aktivieren Sie Discussions (optional)

2. **Branch Protection Rules** (empfohlen)
   ```
   Settings > Branches > Add rule
   - Branch name pattern: main
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass before merging
   - ✅ Require conversation resolution before merging
   ```

3. **GitHub Actions**
   - Sollte automatisch aktiviert sein
   - Erste Checks laufen nach dem Push automatisch
   - Siehe: Actions-Tab im Repository

---

## 🔐 API-Keys richtig verwenden

### Setup für lokale Entwicklung:

```bash
# 1. Kopieren Sie das Example-File:
cp APIConfig.swift.example APIConfig.swift

# 2. Öffnen Sie APIConfig.swift und fügen Sie echte Keys ein
# (Diese Datei wird NICHT committed!)

# 3. Prüfen Sie, dass sie ignoriert wird:
git status  # APIConfig.swift sollte NICHT erscheinen
```

### In Ihrem Swift-Code verwenden:

```swift
import Foundation

// Verwenden Sie die API-Config:
let apiKey = APIConfig.mensaAPIKey
let baseURL = APIConfig.mensaBaseURL
```

### Für CI/CD (GitHub Actions):

Wenn Sie API-Keys in Tests oder CI/CD benötigen:

```bash
# In GitHub Repository:
Settings > Secrets and variables > Actions > New repository secret

# Fügen Sie Secrets hinzu:
MENSA_API_KEY: ihr-echter-key
TU_API_KEY: ihr-anderer-key
```

Dann in `.github/workflows/ios.yml`:
```yaml
- name: Run tests
  env:
    MENSA_API_KEY: ${{ secrets.MENSA_API_KEY }}
  run: xcodebuild test ...
```

---

## 🧪 Testen vor dem Push

### Lokaler Security-Check:

```bash
# Erstellen Sie dieses Script: check-security.sh
cat > check-security.sh << 'EOF'
#!/bin/bash
echo "🔍 Security Check..."

# Check für Team-IDs
if git diff --cached | grep -i "DEVELOPMENT_TEAM"; then
    echo "❌ FEHLER: DEVELOPMENT_TEAM gefunden!"
    exit 1
fi

# Check für API-Keys
if git diff --cached | grep -i "api.key.*=.*['\"].*['\"]"; then
    echo "❌ FEHLER: API-Key gefunden!"
    exit 1
fi

# Check für Provisioning Profiles
if git diff --cached | grep -l "\.mobileprovision"; then
    echo "❌ FEHLER: Provisioning Profile gefunden!"
    exit 1
fi

echo "✅ Security Check bestanden!"
EOF

chmod +x check-security.sh

# Vor jedem Commit ausführen:
./check-security.sh && git push
```

---

## 🤝 Für Contributors

Contributors müssen IHRE EIGENEN API-Keys verwenden:

1. Sie klonen das Repository
2. Sie kopieren `APIConfig.swift.example` zu `APIConfig.swift`
3. Sie fügen ihre eigenen Test-Keys ein
4. Sie entwickeln lokal
5. Sie pushen NICHT `APIConfig.swift` (ist ignoriert)

**In der README.md steht:**
> "Contributors: Kopieren Sie `APIConfig.swift.example` zu `APIConfig.swift` und fügen Sie Ihre eigenen API-Keys für lokale Tests ein."

---

## 📊 GitHub Actions Status prüfen

Nach dem ersten Push:

```bash
# CLI:
gh run list

# Oder im Browser:
# https://github.com/YOUR-USERNAME/Campus-Ilmenau-iOS/actions
```

Die Actions prüfen automatisch:
- ✅ Build erfolgreich (ohne Code-Signing)
- ✅ Keine Team-IDs committed
- ✅ Keine Provisioning Profiles committed
- ✅ Keine Zertifikate committed
- ✅ Keine API-Keys committed
- ✅ SwiftLint Code-Style

---

## 🆘 Hilfe! Ich habe einen Secret committed!

### Sofort-Maßnahmen:

```bash
# 1. NICHT pushen, wenn noch lokal!
# 2. Letzten Commit rückgängig machen:
git reset --soft HEAD~1

# 3. Datei aus Staging entfernen:
git restore --staged APIConfig.swift

# 4. Neu committen ohne die Datei:
git commit -m "Your message"
```

### Wenn bereits gepusht:

```bash
# 1. Aus der kompletten History entfernen:
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch APIConfig.swift" \
  --prune-empty --tag-name-filter cat -- --all

# 2. Force push (VORSICHT!):
git push origin --force --all

# 3. API-Keys SOFORT rotieren/ändern!
# 4. GitHub Secret Scanning wird Sie eventuell automatisch warnen
```

**Besser:** BFG Repo-Cleaner verwenden:
```bash
brew install bfg
bfg --delete-files APIConfig.swift
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push origin --force --all
```

---

## ✅ Checkliste vor dem ersten Push

- [ ] `.gitignore` existiert und ist konfiguriert
- [ ] `APIConfig.swift.example` existiert
- [ ] `APIConfig.swift` (mit echten Keys) ist NICHT im Git
- [ ] `git status` zeigt keine sensiblen Dateien
- [ ] `git grep -i "DEVELOPMENT_TEAM"` findet nichts oder nur in xcuserdata/
- [ ] `git grep -i "api.key"` findet nur Beispiel-Code
- [ ] GitHub Repository ist erstellt
- [ ] Remote ist verbunden (`git remote -v`)
- [ ] Bereit für `git push -u origin main`

---

## 📚 Nützliche Befehle

```bash
# Status prüfen:
git status
git status --ignored  # Zeigt auch ignorierte Dateien

# Remote prüfen:
git remote -v

# Was wird committed:
git diff --cached

# Nach Text in Commits suchen:
git log --all --full-history --source --grep="api.key"

# In allen Dateien suchen:
git grep -i "api.key"

# Branch-Status:
git branch -vv

# Letzte Commits:
git log --oneline -n 10
```

---

## 🎯 Zusammenfassung

**Ihre Sicherheits-Infrastruktur ist JETZT komplett eingerichtet! ✅**

- `.gitignore` schützt alle sensiblen Dateien
- `APIConfig.swift.example` als Template für Contributors
- GitHub Actions prüft automatisch auf Secrets
- `.gitattributes` optimiert Git für Xcode
- SwiftLint für Code-Qualität

**Nächster Schritt:** Führen Sie die Befehle unter "Schritt-für-Schritt" aus!

Bei Fragen: Öffnen Sie ein Issue oder lesen Sie `SECURITY_CHECKLIST.md`
