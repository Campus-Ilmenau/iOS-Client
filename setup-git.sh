#!/bin/bash

# Campus Ilmenau iOS - Git Setup Script
# Remote: https://github.com/Campus-Ilmenau/iOS-Client.git

set -e  # Exit bei Fehler

echo "🚀 Campus Ilmenau iOS - Git Setup"
echo "=================================="
echo ""

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Remote URL
REMOTE_URL="https://github.com/Campus-Ilmenau/iOS-Client.git"

# Schritt 1: Git-Status prüfen
echo "📋 Schritt 1: Git-Status prüfen..."
if [ -d .git ]; then
    echo -e "${GREEN}✅ Git ist bereits initialisiert${NC}"
else
    echo -e "${YELLOW}⚠️  Git ist nicht initialisiert${NC}"
    read -p "Git jetzt initialisieren? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git init
        git branch -M main
        echo -e "${GREEN}✅ Git initialisiert${NC}"
    else
        echo -e "${RED}❌ Abgebrochen${NC}"
        exit 1
    fi
fi
echo ""

# Schritt 2: Security-Check
echo "🔍 Schritt 2: Security-Check..."

# Check für Team-IDs
echo "   Prüfe Team-IDs..."
if git grep -r "DEVELOPMENT_TEAM" 2>/dev/null | grep -v xcuserdata | grep -v "\.git"; then
    echo -e "${RED}❌ WARNUNG: DEVELOPMENT_TEAM gefunden!${NC}"
    echo "   Bitte entfernen Sie Team-IDs aus dem Projekt."
    read -p "Trotzdem fortfahren? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✅ Keine Team-IDs gefunden${NC}"
fi

# Check für API-Keys
echo "   Prüfe API-Keys..."
if git grep -r -i "api.*key.*=.*\"[A-Za-z0-9]\{20,\}\"" 2>/dev/null | grep -v "example" | grep -v "\.git"; then
    echo -e "${YELLOW}⚠️  Potenzielle API-Keys gefunden!${NC}"
    echo "   Bitte überprüfen Sie, ob echte Keys im Code sind."
    read -p "Fortfahren? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✅ Keine API-Keys gefunden${NC}"
fi

# Check APIConfig.swift
echo "   Prüfe APIConfig.swift..."
if git ls-files --cached | grep -q "APIConfig.swift$"; then
    echo -e "${RED}❌ FEHLER: APIConfig.swift ist im Git!${NC}"
    echo "   Diese Datei sollte in .gitignore sein."
    read -p "Aus Git entfernen? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git rm --cached APIConfig.swift || true
        echo -e "${GREEN}✅ APIConfig.swift entfernt${NC}"
    fi
else
    echo -e "${GREEN}✅ APIConfig.swift ist nicht im Git${NC}"
fi

# Check für Provisioning Profiles
echo "   Prüfe Provisioning Profiles..."
if find . -name "*.mobileprovision" -o -name "*.provisionprofile" 2>/dev/null | grep -v DerivedData | grep -v "\.git"; then
    echo -e "${RED}❌ FEHLER: Provisioning Profiles gefunden!${NC}"
    echo "   Diese sollten durch .gitignore geschützt sein."
    exit 1
else
    echo -e "${GREEN}✅ Keine Provisioning Profiles gefunden${NC}"
fi

echo ""

# Schritt 3: Remote prüfen/hinzufügen
echo "🌐 Schritt 3: Remote-Verbindung prüfen..."
if git remote | grep -q "^origin$"; then
    CURRENT_REMOTE=$(git remote get-url origin)
    echo -e "${YELLOW}⚠️  Remote 'origin' existiert bereits: ${CURRENT_REMOTE}${NC}"
    
    if [ "$CURRENT_REMOTE" != "$REMOTE_URL" ]; then
        read -p "Auf ${REMOTE_URL} ändern? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git remote set-url origin "$REMOTE_URL"
            echo -e "${GREEN}✅ Remote geändert${NC}"
        fi
    else
        echo -e "${GREEN}✅ Korrekte Remote bereits konfiguriert${NC}"
    fi
else
    read -p "Remote hinzufügen (${REMOTE_URL})? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote add origin "$REMOTE_URL"
        echo -e "${GREEN}✅ Remote hinzugefügt${NC}"
    else
        echo -e "${YELLOW}⚠️  Remote nicht hinzugefügt${NC}"
    fi
fi

# Remote anzeigen
echo ""
echo "Aktuelle Remote-Konfiguration:"
git remote -v
echo ""

# Schritt 4: Status anzeigen
echo "📊 Schritt 4: Git-Status..."
git status
echo ""

# Schritt 5: Commit (optional)
read -p "Möchten Sie jetzt committen? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Füge Dateien hinzu..."
    git add .
    
    echo ""
    echo "Folgende Dateien werden committed:"
    git status --short
    echo ""
    
    read -p "Fortfahren mit Commit? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git commit -m "Initial commit - Campus Ilmenau iOS App

- SwiftUI App für TU Ilmenau Studierende
- Sicherheits-Setup mit .gitignore
- API-Config-Template für Contributors
- GitHub Actions für CI/CD und Security-Checks"
        
        echo -e "${GREEN}✅ Commit erstellt${NC}"
        echo ""
        
        # Schritt 6: Push (optional)
        read -p "Möchten Sie jetzt pushen? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "Pushing zu GitHub..."
            
            # Prüfe ob main Branch existiert auf Remote
            if git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
                git push origin main
            else
                git push -u origin main
            fi
            
            echo -e "${GREEN}✅ Erfolgreich gepusht!${NC}"
            echo ""
            echo "🎉 Setup abgeschlossen!"
            echo ""
            echo "📍 Repository: https://github.com/Campus-Ilmenau/iOS-Client"
            echo "🔧 Actions: https://github.com/Campus-Ilmenau/iOS-Client/actions"
            echo ""
            echo "GitHub Actions werden jetzt automatisch ausgeführt."
            echo "Prüfen Sie den Status auf der Actions-Seite."
        fi
    fi
fi

echo ""
echo "✅ Setup-Script abgeschlossen!"
echo ""
echo "📚 Nächste Schritte:"
echo "   1. Öffnen Sie: https://github.com/Campus-Ilmenau/iOS-Client"
echo "   2. Konfigurieren Sie Repository-Settings"
echo "   3. Fügen Sie Topics hinzu"
echo "   4. Aktivieren Sie Branch Protection (optional)"
echo "   5. Beginnen Sie mit der Entwicklung!"
echo ""
echo "📖 Dokumentation:"
echo "   - START_NOW.md - Komplette Anleitung"
echo "   - GIT_SETUP.md - Ausführliche Git-Hilfe"
echo "   - SECURITY_STATUS.md - Sicherheits-Übersicht"
echo ""
