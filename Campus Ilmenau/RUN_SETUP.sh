#!/bin/bash

###############################################################################
#                                                                             #
#   CAMPUS ILMENAU iOS - FINALES SETUP-SCRIPT                               #
#   Remote: https://github.com/Campus-Ilmenau/iOS-Client.git                #
#                                                                             #
#   Dieses Script führt Sie sicher durch das komplette Git-Setup             #
#                                                                             #
###############################################################################

set -e  # Stop bei Fehler

# Farben
R='\033[0;31m'    # Red
G='\033[0;32m'    # Green
Y='\033[1;33m'    # Yellow
B='\033[0;34m'    # Blue
M='\033[0;35m'    # Magenta
C='\033[0;36m'    # Cyan
W='\033[1;37m'    # White/Bold
NC='\033[0m'      # No Color

REMOTE_URL="https://github.com/Campus-Ilmenau/iOS-Client.git"

clear

cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║           🎓 CAMPUS ILMENAU iOS - GIT SETUP 🎓                  ║
║                                                                  ║
║              Remote: github.com/Campus-Ilmenau/iOS-Client        ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF

echo ""
echo -e "${C}Dieses Script führt Sie sicher durch das Git-Setup.${NC}"
echo -e "${C}Sie werden bei wichtigen Schritten um Bestätigung gebeten.${NC}"
echo ""
read -p "Bereit zum Start? [Enter drücken]"

###############################################################################
# SCHRITT 1: Git-Initialisierung
###############################################################################

echo ""
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${W}   SCHRITT 1/6: Git-Initialisierung${NC}"
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -d .git ]; then
    echo -e "${G}✅ Git-Repository existiert bereits${NC}"
    
    # Prüfe Branch
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [ "$CURRENT_BRANCH" = "main" ]; then
        echo -e "${G}✅ Branch 'main' ist bereits aktiv${NC}"
    elif [ "$CURRENT_BRANCH" = "master" ]; then
        echo -e "${Y}⚠️  Branch 'master' gefunden, umbenennen zu 'main'...${NC}"
        git branch -M main
        echo -e "${G}✅ Branch zu 'main' umbenannt${NC}"
    else
        echo -e "${Y}⚠️  Aktueller Branch: ${CURRENT_BRANCH}${NC}"
        read -p "Zu 'main' wechseln? [Y/n] " -r
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            git checkout -B main
            echo -e "${G}✅ Branch 'main' aktiv${NC}"
        fi
    fi
else
    echo -e "${Y}⚠️  Noch kein Git-Repository${NC}"
    echo -e "${W}Initialisiere Git...${NC}"
    git init
    git branch -M main
    echo -e "${G}✅ Git erfolgreich initialisiert${NC}"
fi

###############################################################################
# SCHRITT 2: Sicherheits-Checks
###############################################################################

echo ""
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${W}   SCHRITT 2/6: Sicherheits-Checks${NC}"
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

SECURITY_ISSUES=0

# Check 1: DEVELOPMENT_TEAM in Xcode-Projektdateien
echo -e "${C}🔍 Check 1/5: DEVELOPMENT_TEAM in Projektdateien...${NC}"
if find . -name "project.pbxproj" -type f -exec grep -l "DEVELOPMENT_TEAM" {} \; 2>/dev/null | head -1 | grep -q .; then
    echo -e "${Y}⚠️  DEVELOPMENT_TEAM in Xcode-Projekt gefunden${NC}"
    echo -e "${Y}   → Das ist OK wenn es nur in xcuserdata/ ist${NC}"
    echo -e "${Y}   → In Xcode: Project Settings → Signing → 'Automatically manage signing'${NC}"
    ((SECURITY_ISSUES++))
else
    echo -e "${G}✅ Keine DEVELOPMENT_TEAM in Projektdateien${NC}"
fi

# Check 2: APIConfig.swift
echo -e "${C}🔍 Check 2/5: APIConfig.swift Status...${NC}"
if [ -f "APIConfig.swift" ]; then
    if git ls-files --error-unmatch "APIConfig.swift" >/dev/null 2>&1; then
        echo -e "${R}❌ FEHLER: APIConfig.swift ist im Git!${NC}"
        echo -e "${Y}   → Wird automatisch entfernt...${NC}"
        git rm --cached "APIConfig.swift" 2>/dev/null || true
        echo -e "${G}✅ APIConfig.swift aus Git entfernt${NC}"
    else
        echo -e "${G}✅ APIConfig.swift existiert und ist nicht im Git${NC}"
    fi
else
    echo -e "${C}ℹ️  APIConfig.swift existiert noch nicht${NC}"
    echo -e "${C}   → Erstellen Sie es später mit: cp APIConfig.swift.example APIConfig.swift${NC}"
fi

# Check 3: Provisioning Profiles
echo -e "${C}🔍 Check 3/5: Provisioning Profiles...${NC}"
PROFILES=$(find . -type f \( -name "*.mobileprovision" -o -name "*.provisionprofile" \) 2>/dev/null | grep -v "DerivedData" | grep -v ".git" || true)
if [ -n "$PROFILES" ]; then
    echo -e "${R}❌ KRITISCH: Provisioning Profiles gefunden!${NC}"
    echo "$PROFILES"
    echo -e "${R}   → Diese dürfen NICHT ins Git!${NC}"
    echo -e "${Y}   → Sind sie in .gitignore? Prüfen Sie das!${NC}"
    ((SECURITY_ISSUES++))
else
    echo -e "${G}✅ Keine Provisioning Profiles gefunden${NC}"
fi

# Check 4: Zertifikate
echo -e "${C}🔍 Check 4/5: Code-Signing-Zertifikate...${NC}"
CERTS=$(find . -type f \( -name "*.p12" -o -name "*.cer" -o -name "*.certSigningRequest" \) 2>/dev/null | grep -v "DerivedData" | grep -v ".git" || true)
if [ -n "$CERTS" ]; then
    echo -e "${R}❌ KRITISCH: Zertifikate gefunden!${NC}"
    echo "$CERTS"
    echo -e "${R}   → Diese dürfen NIEMALS ins Git!${NC}"
    exit 1
else
    echo -e "${G}✅ Keine Zertifikate gefunden${NC}"
fi

# Check 5: .gitignore existiert
echo -e "${C}🔍 Check 5/5: .gitignore Status...${NC}"
if [ -f ".gitignore" ]; then
    echo -e "${G}✅ .gitignore existiert${NC}"
    
    # Prüfe ob wichtige Einträge vorhanden sind
    if grep -q "APIConfig.swift" .gitignore 2>/dev/null; then
        echo -e "${G}   ✓ APIConfig.swift ist in .gitignore${NC}"
    else
        echo -e "${Y}   ⚠️  APIConfig.swift nicht in .gitignore gefunden${NC}"
    fi
    
    if grep -q "*.mobileprovision" .gitignore 2>/dev/null; then
        echo -e "${G}   ✓ Provisioning Profiles sind in .gitignore${NC}"
    else
        echo -e "${Y}   ⚠️  Provisioning Profiles nicht in .gitignore${NC}"
    fi
else
    echo -e "${R}❌ FEHLER: .gitignore nicht gefunden!${NC}"
    echo -e "${R}   → Kritisch für Sicherheit!${NC}"
    exit 1
fi

echo ""
if [ $SECURITY_ISSUES -eq 0 ]; then
    echo -e "${G}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${G}✅ Alle Sicherheits-Checks bestanden!${NC}"
    echo -e "${G}════════════════════════════════════════════════════════════════${NC}"
else
    echo -e "${Y}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${Y}⚠️  ${SECURITY_ISSUES} Warnung(en) gefunden${NC}"
    echo -e "${Y}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Trotzdem fortfahren? [y/N] " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${R}Setup abgebrochen.${NC}"
        exit 1
    fi
fi

###############################################################################
# SCHRITT 3: Remote-Konfiguration
###############################################################################

echo ""
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${W}   SCHRITT 3/6: Remote-Konfiguration${NC}"
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if git remote | grep -q "^origin$"; then
    CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    echo -e "${Y}⚠️  Remote 'origin' existiert bereits:${NC}"
    echo -e "   ${CURRENT_REMOTE}"
    echo ""
    
    if [ "$CURRENT_REMOTE" != "$REMOTE_URL" ]; then
        echo -e "${Y}   Erwartete URL: ${REMOTE_URL}${NC}"
        echo ""
        read -p "Remote-URL aktualisieren? [Y/n] " -r
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            git remote set-url origin "$REMOTE_URL"
            echo -e "${G}✅ Remote-URL aktualisiert${NC}"
        fi
    else
        echo -e "${G}✅ Korrekte Remote bereits konfiguriert${NC}"
    fi
else
    echo -e "${W}Füge Remote hinzu: ${REMOTE_URL}${NC}"
    git remote add origin "$REMOTE_URL"
    echo -e "${G}✅ Remote hinzugefügt${NC}"
fi

echo ""
echo -e "${W}Aktuelle Remote-Konfiguration:${NC}"
git remote -v

###############################################################################
# SCHRITT 4: Status & Vorschau
###############################################################################

echo ""
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${W}   SCHRITT 4/6: Git-Status & Vorschau${NC}"
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${W}Aktueller Git-Status:${NC}"
echo ""
git status --short

echo ""
echo -e "${W}Diese Dateien werden committet:${NC}"
git add . 2>/dev/null || true
git diff --cached --name-only | head -20

TOTAL_FILES=$(git diff --cached --name-only | wc -l | tr -d ' ')
if [ "$TOTAL_FILES" -gt 20 ]; then
    echo -e "${C}... und weitere $((TOTAL_FILES - 20)) Dateien${NC}"
fi

###############################################################################
# SCHRITT 5: Commit erstellen
###############################################################################

echo ""
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${W}   SCHRITT 5/6: Commit erstellen${NC}"
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "Commit jetzt erstellen? [Y/n] " -r
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    
    COMMIT_MSG="Initial commit - Campus Ilmenau iOS App

🎓 SwiftUI App für TU Ilmenau Studierende

Features:
- Vollständiges Sicherheits-Setup mit .gitignore
- API-Config-Template für Contributors (APIConfig.swift.example)
- GitHub Actions für CI/CD und Security-Checks
- Automatische Code-Qualitätsprüfung mit SwiftLint
- Dokumentation für Contributors und Maintainer

Remote: https://github.com/Campus-Ilmenau/iOS-Client.git"

    echo ""
    echo -e "${W}Commit-Nachricht:${NC}"
    echo -e "${C}────────────────────────────────────────────────${NC}"
    echo "$COMMIT_MSG"
    echo -e "${C}────────────────────────────────────────────────${NC}"
    echo ""
    
    read -p "Mit dieser Nachricht committen? [Y/n] " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        git commit -m "$COMMIT_MSG"
        echo ""
        echo -e "${G}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${G}✅ Commit erfolgreich erstellt!${NC}"
        echo -e "${G}════════════════════════════════════════════════════════════════${NC}"
        
        COMMIT_CREATED=true
    else
        echo -e "${Y}Commit übersprungen.${NC}"
        COMMIT_CREATED=false
    fi
else
    echo -e "${Y}Commit übersprungen.${NC}"
    COMMIT_CREATED=false
fi

###############################################################################
# SCHRITT 6: Push zu GitHub
###############################################################################

if [ "$COMMIT_CREATED" = true ]; then
    echo ""
    echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${W}   SCHRITT 6/6: Push zu GitHub${NC}"
    echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "Jetzt zu GitHub pushen? [Y/n] " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${W}Pushing zu GitHub...${NC}"
        echo -e "${C}(Sie werden eventuell nach GitHub-Credentials gefragt)${NC}"
        echo ""
        
        # Versuche Push
        if git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
            # Main Branch existiert bereits
            git push origin main
        else
            # Erster Push
            git push -u origin main
        fi
        
        PUSH_SUCCESS=$?
        
        if [ $PUSH_SUCCESS -eq 0 ]; then
            echo ""
            echo -e "${G}╔════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${G}║                                                                ║${NC}"
            echo -e "${G}║              🎉 ERFOLGREICH ZU GITHUB GEPUSHT! 🎉             ║${NC}"
            echo -e "${G}║                                                                ║${NC}"
            echo -e "${G}╚════════════════════════════════════════════════════════════════╝${NC}"
        else
            echo ""
            echo -e "${R}❌ Push fehlgeschlagen!${NC}"
            echo -e "${Y}Mögliche Ursachen:${NC}"
            echo -e "${Y}  - Keine Berechtigung (GitHub-Login erforderlich)${NC}"
            echo -e "${Y}  - Keine Internetverbindung${NC}"
            echo -e "${Y}  - Repository existiert nicht auf GitHub${NC}"
            echo ""
            echo -e "${C}Versuchen Sie manuell:${NC}"
            echo -e "${W}  git push -u origin main${NC}"
            exit 1
        fi
    else
        echo -e "${Y}Push übersprungen.${NC}"
        echo -e "${C}Sie können später pushen mit: git push -u origin main${NC}"
    fi
fi

###############################################################################
# ABSCHLUSS & NÄCHSTE SCHRITTE
###############################################################################

echo ""
echo -e "${G}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${G}║                                                                ║${NC}"
echo -e "${G}║                   ✅ SETUP ABGESCHLOSSEN! ✅                   ║${NC}"
echo -e "${G}║                                                                ║${NC}"
echo -e "${G}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${W}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${W}📚 NÄCHSTE SCHRITTE${NC}"
echo -e "${W}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${M}1. GitHub-Repository öffnen:${NC}"
echo -e "   ${C}https://github.com/Campus-Ilmenau/iOS-Client${NC}"
echo ""

echo -e "${M}2. GitHub Actions prüfen:${NC}"
echo -e "   ${C}https://github.com/Campus-Ilmenau/iOS-Client/actions${NC}"
echo -e "   → Build, Security-Check und SwiftLint laufen automatisch"
echo ""

echo -e "${M}3. Repository konfigurieren:${NC}"
echo -e "   • About → Edit → Description & Topics hinzufügen"
echo -e "   • Settings → Features → Issues aktivieren"
echo -e "   • Settings → Branches → Branch Protection (optional)"
echo ""

echo -e "${M}4. API-Konfiguration für lokale Entwicklung:${NC}"
echo -e "   ${W}cp APIConfig.swift.example APIConfig.swift${NC}"
echo -e "   → Dann Ihre echten API-Keys einfügen"
echo -e "   → Diese Datei wird NICHT committed!"
echo ""

echo -e "${M}5. Entwicklung starten:${NC}"
echo -e "   • Xcode öffnen"
echo -e "   • Features für TU Ilmenau implementieren"
echo -e "   • ${W}git add . && git commit -m \"...\" && git push${NC}"
echo ""

echo -e "${W}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${W}💡 FEATURE-IDEEN${NC}"
echo -e "${W}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "   🍽️  Mensa-Speiseplan (Studentenwerk API)"
echo -e "   📅 Stundenplan-Ansicht (iCal-Import)"
echo -e "   🗺️  Campus-Karte (MapKit)"
echo -e "   📚 Bibliotheks-Integration"
echo -e "   🚌 ÖPNV-Verbindungen (VMT API)"
echo ""

echo -e "${W}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${W}📖 DOKUMENTATION${NC}"
echo -e "${W}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "   • ${C}REMOTE_CONFIGURED.md${NC} - Komplette Übersicht"
echo -e "   • ${C}START_NOW.md${NC} - Ausführliche Anleitung"
echo -e "   • ${C}SECURITY_STATUS.md${NC} - Sicherheits-Details"
echo -e "   • ${C}README 2.md${NC} - Projekt-README"
echo ""

echo -e "${G}════════════════════════════════════════════════════════════════${NC}"
echo -e "${G}Viel Erfolg mit der Campus Ilmenau App! 🎓🚀${NC}"
echo -e "${G}════════════════════════════════════════════════════════════════${NC}"
echo ""
