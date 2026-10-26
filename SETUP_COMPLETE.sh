#!/bin/bash

# CAMPUS ILMENAU iOS - KOMPLETTES SETUP
# Dieses Script führt das komplette Git-Setup durch
# Remote: https://github.com/Campus-Ilmenau/iOS-Client.git

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Campus Ilmenau iOS - Automatisches Git-Setup          ║"
echo "║     Remote: github.com/Campus-Ilmenau/iOS-Client           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

REMOTE_URL="https://github.com/Campus-Ilmenau/iOS-Client.git"

# Fehlerbehandlung
set -e
trap 'echo -e "\n${RED}❌ Fehler aufgetreten! Script abgebrochen.${NC}"; exit 1' ERR

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}SCHRITT 1: Git-Initialisierung${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

if [ -d .git ]; then
    echo -e "${GREEN}✅ Git-Repository existiert bereits${NC}"
    echo ""
    git status
else
    echo -e "${YELLOW}⚠️  Kein Git-Repository gefunden${NC}"
    echo -e "${BOLD}Initialisiere Git...${NC}"
    git init
    git branch -M main
    echo -e "${GREEN}✅ Git erfolgreich initialisiert${NC}"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}SCHRITT 2: Security-Checks${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Check 1: DEVELOPMENT_TEAM
echo -e "${BOLD}🔍 Check 1/5: Suche nach DEVELOPMENT_TEAM...${NC}"
if git grep -r "DEVELOPMENT_TEAM" 2>/dev/null | grep -v xcuserdata | grep -v "\.git" | grep -v ".sh"; then
    echo -e "${RED}❌ WARNUNG: DEVELOPMENT_TEAM gefunden!${NC}"
    echo -e "${YELLOW}   → Sollte in Xcode entfernt werden (Project Settings → Signing)${NC}"
    echo ""
    read -p "   Trotzdem fortfahren? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Setup abgebrochen.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Keine DEVELOPMENT_TEAM gefunden${NC}"
fi

# Check 2: API-Keys in Code
echo -e "${BOLD}🔍 Check 2/5: Suche nach API-Keys im Code...${NC}"
if git grep -r -i "api.*key.*=.*\"[A-Za-z0-9]\{20,\}\"" 2>/dev/null | grep -v "example" | grep -v "YOUR_" | grep -v "\.git" | grep -v ".sh"; then
    echo -e "${RED}❌ WARNUNG: Potenzielle API-Keys gefunden!${NC}"
    echo -e "${YELLOW}   → Verschieben Sie echte Keys nach APIConfig.swift${NC}"
    echo ""
    read -p "   Fortfahren? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✅ Keine API-Keys im Code gefunden${NC}"
fi

# Check 3: APIConfig.swift
echo -e "${BOLD}🔍 Check 3/5: Prüfe APIConfig.swift...${NC}"
if [ -f "APIConfig.swift" ]; then
    if git ls-files --cached 2>/dev/null | grep -q "^APIConfig.swift$"; then
        echo -e "${RED}❌ FEHLER: APIConfig.swift ist im Git!${NC}"
        echo -e "${YELLOW}   → Wird jetzt entfernt...${NC}"
        git rm --cached APIConfig.swift 2>/dev/null || true
        echo -e "${GREEN}✅ APIConfig.swift aus Git entfernt${NC}"
    else
        echo -e "${GREEN}✅ APIConfig.swift existiert und ist nicht im Git${NC}"
    fi
else
    echo -e "${YELLOW}ℹ️  APIConfig.swift existiert noch nicht (OK für ersten Commit)${NC}"
fi

# Check 4: Provisioning Profiles
echo -e "${BOLD}🔍 Check 4/5: Suche nach Provisioning Profiles...${NC}"
if find . -type f \( -name "*.mobileprovision" -o -name "*.provisionprofile" \) 2>/dev/null | grep -v DerivedData | grep -v "\.git"; then
    echo -e "${RED}❌ FEHLER: Provisioning Profiles gefunden!${NC}"
    echo -e "${RED}   → Diese dürfen NICHT committed werden!${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Keine Provisioning Profiles gefunden${NC}"
fi

# Check 5: Zertifikate
echo -e "${BOLD}🔍 Check 5/5: Suche nach Zertifikaten...${NC}"
if find . -type f \( -name "*.p12" -o -name "*.cer" -o -name "*.certSigningRequest" \) 2>/dev/null | grep -v DerivedData | grep -v "\.git"; then
    echo -e "${RED}❌ FEHLER: Zertifikate gefunden!${NC}"
    echo -e "${RED}   → Diese dürfen NIEMALS committed werden!${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Keine Zertifikate gefunden${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Alle Security-Checks bestanden!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}SCHRITT 3: Remote-Konfiguration${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

if git remote 2>/dev/null | grep -q "^origin$"; then
    CURRENT_REMOTE=$(git remote get-url origin)
    echo -e "${YELLOW}⚠️  Remote 'origin' existiert bereits:${NC}"
    echo -e "   ${CURRENT_REMOTE}"
    echo ""
    
    if [ "$CURRENT_REMOTE" != "$REMOTE_URL" ]; then
        echo -e "${YELLOW}   Erwartete Remote: ${REMOTE_URL}${NC}"
        read -p "   Remote-URL aktualisieren? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            git remote set-url origin "$REMOTE_URL"
            echo -e "${GREEN}✅ Remote-URL aktualisiert${NC}"
        fi
    else
        echo -e "${GREEN}✅ Korrekte Remote bereits konfiguriert${NC}"
    fi
else
    echo -e "${BOLD}Füge Remote hinzu: ${REMOTE_URL}${NC}"
    git remote add origin "$REMOTE_URL"
    echo -e "${GREEN}✅ Remote hinzugefügt${NC}"
fi

echo ""
echo -e "${BOLD}Aktuelle Remote-Konfiguration:${NC}"
git remote -v

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}SCHRITT 4: Git-Status & Dateien${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

git status

echo ""
echo -e "${BOLD}Folgende neue Dateien werden hinzugefügt:${NC}"
git status --short 2>/dev/null | grep "^??" || echo "  (Keine neuen Dateien)"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}SCHRITT 5: Commit erstellen${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

read -p "Möchten Sie jetzt einen Commit erstellen? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "${BOLD}Füge Dateien zu Git hinzu...${NC}"
    git add .
    
    echo ""
    echo -e "${BOLD}Diese Dateien werden committed:${NC}"
    git diff --cached --name-status
    
    echo ""
    read -p "Commit jetzt erstellen? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${BOLD}Erstelle Commit...${NC}"
        
        git commit -m "Initial commit - Campus Ilmenau iOS App

- SwiftUI App für TU Ilmenau Studierende
- Vollständiges Sicherheits-Setup mit .gitignore
- API-Config-Template für Contributors (APIConfig.swift.example)
- GitHub Actions für CI/CD und Security-Checks
- Automatische Code-Qualitätsprüfung mit SwiftLint
- Dokumentation für Contributors und Maintainer
- Remote: https://github.com/Campus-Ilmenau/iOS-Client.git"
        
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}✅ Commit erfolgreich erstellt!${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
        
        echo ""
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}SCHRITT 6: Push zu GitHub${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "Jetzt zu GitHub pushen? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo ""
            echo -e "${BOLD}Pushing zu GitHub...${NC}"
            echo -e "${YELLOW}(Sie werden eventuell nach Ihren GitHub-Credentials gefragt)${NC}"
            echo ""
            
            # Prüfe ob main Branch auf Remote existiert
            if git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
                git push origin main
            else
                git push -u origin main
            fi
            
            echo ""
            echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}🎉 ERFOLGREICH ZU GITHUB GEPUSHT! 🎉${NC}"
            echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
            echo ""
            echo -e "${BOLD}📍 Ihr Repository:${NC}"
            echo -e "   https://github.com/Campus-Ilmenau/iOS-Client"
            echo ""
            echo -e "${BOLD}🔧 GitHub Actions:${NC}"
            echo -e "   https://github.com/Campus-Ilmenau/iOS-Client/actions"
            echo -e "   ${YELLOW}(Builds und Security-Checks laufen jetzt automatisch!)${NC}"
            echo ""
            echo -e "${BOLD}⚙️  Repository-Settings:${NC}"
            echo -e "   https://github.com/Campus-Ilmenau/iOS-Client/settings"
            echo ""
        else
            echo -e "${YELLOW}ℹ️  Push übersprungen. Sie können später manuell pushen mit:${NC}"
            echo -e "   git push -u origin main"
        fi
    else
        echo -e "${YELLOW}ℹ️  Commit übersprungen.${NC}"
    fi
else
    echo -e "${YELLOW}ℹ️  Commit übersprungen.${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ SETUP ABGESCHLOSSEN!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BOLD}📚 NÄCHSTE SCHRITTE:${NC}"
echo ""
echo -e "${BOLD}1. GitHub-Repository konfigurieren:${NC}"
echo -e "   • Öffnen: https://github.com/Campus-Ilmenau/iOS-Client"
echo -e "   • About → Edit → Description & Topics hinzufügen"
echo -e "   • Settings → Features → Issues aktivieren"
echo -e "   • Settings → Branches → Branch Protection Rules (optional)"
echo ""
echo -e "${BOLD}2. GitHub Actions prüfen:${NC}"
echo -e "   • https://github.com/Campus-Ilmenau/iOS-Client/actions"
echo -e "   • Build, Security-Check und SwiftLint sollten grün sein ✅"
echo ""
echo -e "${BOLD}3. API-Konfiguration (für lokale Entwicklung):${NC}"
echo -e "   cp APIConfig.swift.example APIConfig.swift"
echo -e "   # Dann Ihre echten API-Keys einfügen"
echo -e "   # Diese Datei wird NICHT committed!"
echo ""
echo -e "${BOLD}4. Entwicklung starten:${NC}"
echo -e "   • Öffnen Sie das Projekt in Xcode"
echo -e "   • Implementieren Sie Features für TU Ilmenau"
echo -e "   • git add . && git commit -m \"...\" && git push"
echo ""
echo -e "${BOLD}📖 DOKUMENTATION:${NC}"
echo -e "   • REMOTE_CONFIGURED.md - Komplette Übersicht"
echo -e "   • START_NOW.md - Ausführliche Anleitung"
echo -e "   • SECURITY_STATUS.md - Sicherheits-Details"
echo -e "   • GIT_SETUP.md - Git-Hilfe"
echo ""
echo -e "${BOLD}💡 FEATURE-IDEEN:${NC}"
echo -e "   • 🍽️  Mensa-Speiseplan"
echo -e "   • 📅 Stundenplan-Ansicht"
echo -e "   • 🗺️  Campus-Karte"
echo -e "   • 📚 Bibliotheks-Integration"
echo -e "   • 🚌 ÖPNV-Verbindungen"
echo ""
echo -e "${GREEN}Viel Erfolg mit der Campus Ilmenau App! 🎓🚀${NC}"
echo ""
