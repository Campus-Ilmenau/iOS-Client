#!/bin/zsh
# Hilfen für die Website-Bilder der Widgets (siehe README.md). Alles läuft auf dem Simulator „iPhone 18 Pro“ (iOS 27.2).
#
#   ./erzeugen.sh status                       Statusleiste auf 9:41 festsetzen
#   ./erzeugen.sh vorbereiten UHR FILTER MODUS Lädt die App (Daten), stellt die Widget-Uhr (und die Statusleiste auf
#                                              dieselbe Zeit) und den App-Filter und geht zurück auf den Home-Bildschirm.
#                                              UHR: 11:45, 17:40 …, jetzt (= echte Uhrzeit, für den Sperrbildschirm) oder aus; FILTER: vegan|vegetarisch|bio|aus;
#                                              MODUS: light|dark
#   ./erzeugen.sh foto SPRACHE NAME            Screenshot nach <SPRACHE>/<NAME>.png (de|en)
#   ./erzeugen.sh sperrfoto SPRACHE NAME       wie foto, aber Statusleiste = echte Uhrzeit (für den Sperrbildschirm)
#   ./erzeugen.sh sprache de|en                Gerätesprache stellen (startet den Simulator neu)
#
# Die Widget-Uhr gibt es nur in Debug-Builds (`WidgetUhr` in der App); sie hat in Release keine Wirkung.
GERAET=607C88D2-C057-4B81-91EB-5F6DFDB0A4CE
APP=de.kai-gothe.Campus-Ilmenau
HIER=${0:A:h}

case $1 in
  status)
    xcrun simctl status_bar $GERAET override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 ;;
  vorbereiten)
    UHR=$2
    # „jetzt“ für den Sperrbildschirm: dessen große Uhr lässt sich nicht stellen, Widget und Statusleiste zeigen darum
    # die echte Uhrzeit (in einer Minute, wenn der Screenshot kommt).
    [[ $UHR == jetzt ]] && UHR=$(date +%H:%M)
    if [[ $UHR == aus ]]; then
      xcrun simctl status_bar $GERAET override --time 9:41
    else
      xcrun simctl status_bar $GERAET override --time $UHR
    fi
    xcrun simctl ui $GERAET appearance $4
    xcrun simctl terminate $GERAET $APP 2>/dev/null
    xcrun simctl launch $GERAET $APP -WidgetUhr $UHR -WidgetFilter $3 >/dev/null
    sleep 14                                   # Start-Animation, Speiseplan und Events laden, Store füllen
    xcrun simctl terminate $GERAET $APP        # zurück auf den Home-Bildschirm
    sleep 12 ;;                                # Widgets laden neu
  foto)
    xcrun simctl io $GERAET screenshot --type=png "$HIER/$2/$3.png" ;;
  sperrfoto)
    # Sperrbildschirm: Die große Uhr lässt sich nicht stellen. Die Statusleiste zeigt darum dieselbe (echte) Minute.
    # Aufgenommen wird nur zwischen :05 und :45 einer Minute, damit die Minute beim Aufnehmen nicht wechselt.
    while (( $(date +%S) < 5 || $(date +%S) > 45 )); do sleep 1; done
    xcrun simctl status_bar $GERAET override --time $(date +%H:%M)
    sleep 1
    xcrun simctl io $GERAET screenshot --type=png "$HIER/$2/$3.png" ;;
  sprache)
    xcrun simctl shutdown $GERAET
    if [[ $2 == en ]]; then
      xcrun simctl boot $GERAET; xcrun simctl spawn $GERAET defaults write -g AppleLanguages -array en; xcrun simctl spawn $GERAET defaults write -g AppleLocale en_US
    else
      xcrun simctl boot $GERAET; xcrun simctl spawn $GERAET defaults write -g AppleLanguages -array de; xcrun simctl spawn $GERAET defaults write -g AppleLocale de_DE
    fi
    xcrun simctl shutdown $GERAET; xcrun simctl boot $GERAET; xcrun simctl bootstatus $GERAET -b >/dev/null 2>&1
    "$0" status ;;
  *) sed -n 2,13p "$0" ;;
esac
