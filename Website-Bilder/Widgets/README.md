# Website-Bilder: Widgets, Sperrbildschirm und Steuerelemente

Bilder für die Website, **nur** von Widgets, Home-Bildschirm, Sperrbildschirm und Kontrollzentrum. Keine App-Ansichten.

- **Gerät:** iPhone 18 Pro im Simulator, iOS 27.2 (ein iPhone 18 Grundmodell gibt es im Simulator nicht)
- **Aufnahme:** 10.11.2026 (Dienstag), echte Daten der Mensa- und Events-API
- **Auflösung:** 1206 × 2622 px, unbearbeitet, direkt vom Simulator (`xcrun simctl io … screenshot`)
- **Sprache:** nur Deutsch (`de/`). Siehe „Nicht enthalten“.
- **Echt oder gerendert:** alle Bilder sind echte Simulator-Bildschirme, keines ist gerendert.

| Datei (`de/`) | Was man sieht | Funktion (Text für die Website) | Uhrzeit | Echt/gerendert |
|---|---|---|---|---|
| `01-home-mensa-mittag.png` | Home-Bildschirm, „Mensa heute“ mittel und groß, hell | Sieh auf einen Blick, was es heute in deiner Mensa gibt – mit Preis, Vegan- und Vegetarisch-Kennzeichnung und den nächsten Zeiten. | 11:45 (Widget und Statusleiste) | echt |
| `01-home-mensa-mittag-dunkel.png` | wie oben, dunkel | Der Dunkelmodus folgt deinem iPhone und bleibt gut lesbar. | 11:45 | echt |
| `02-home-klein-mittag.png` | „Mensa heute“ klein und „Heute Abend“ klein nebeneinander | Auch klein passt es auf deinen Home-Bildschirm: zwei Gerichte aus deiner Mensa und das Nächste, was am Abend in Ilmenau los ist. | 11:45 | echt |
| `03-home-mensa-abend.png` | „Mensa heute“ mittel (Abendessen) und „Heute Abend“ mittel, hell | Nach der Mittagszeit zeigt das Widget das Abendessen, darunter siehst du die Veranstaltungen des Abends. | 17:40 | echt |
| `03-home-mensa-abend-dunkel.png` | wie oben, dunkel | Auch abends gut lesbar im Dunkelmodus. | 17:40 | echt |
| `04-home-mensa-getoent.png` | Home-Bildschirm im Look „Getönt“ mit denselben Widgets wie 01 | Die Widgets passen sich dem getönten Home-Bildschirm an: eine Farbe, volle Lesbarkeit. | 11:45 | echt |
| `05-home-mensa-filter.png` | „Mensa heute“ mittel, Filter-Symbol hinter dem Mensa-Namen, nur veganes Gericht (Filter „Vegan“) | Zeig im Widget nur, was zu deinem Filter passt, zum Beispiel vegan. Das Symbol neben dem Namen zeigt, dass gefiltert wird. | 11:45 | echt |
| `06-sperrbildschirm-mensa.png` | Sperrbildschirm: Zeile über der Uhr, Rechteck und Kreis „Mensa heute“ | Sieh auf dem Sperrbildschirm, was es in deiner Mensa gibt – alle 5 Minuten ein anderes Gericht. | 14:33 (echte Uhr, siehe unten) | echt |
| `07-sperrbildschirm-heute-abend.png` | Sperrbildschirm: Zeile, Rechteck und Kreis „Heute Abend“ | Dein Abend auf einen Blick: die nächste Veranstaltung direkt auf dem Sperrbildschirm. | 14:38 (echte Uhr, siehe unten) | echt |
| `08-kontrollzentrum.png` | Kontrollzentrum mit den Steuerelementen „Thoska auslesen“ und „Im Katalog suchen“ | Lies deine Thoska oder such im Katalog der UB, ohne die App zu suchen – direkt aus dem Kontrollzentrum. | – (Statusleiste des Kontrollzentrums) | echt |

## Nicht enthalten

- **`09-sperrbildschirm-steuerelemente`:** Der Simulator zeichnet die beiden Tasten unten auf dem Sperrbildschirm nicht (keine Taschenlampe, keine Kamera, auch keine Steuerelemente). Das Bild geht nur auf einem echten iPhone.
- **`10-quick-actions`:** Die App hat noch keine Quick Actions (weder `UIApplicationShortcutItems` noch App Shortcuts). Es wurde nichts neu gebaut.
- **Englische Bilder (`en/`):** Die Widgets und Steuerelemente haben keine englische Übersetzung (die Widget-Extension hat keinen String-Katalog, die Texte der Anzeige stehen im Code auf Deutsch). Englische Bilder würden deutsche Widgets auf englischer Systemoberfläche zeigen. Sie lassen sich mit `./erzeugen.sh sprache en` erzeugen, sobald die Widgets übersetzt sind.
- **Sperrbildschirm 11:45 und 19:00:** Die große Uhr auf dem Sperrbildschirm lässt sich im Simulator nicht stellen. Damit Uhr, Statusleiste und Widget zusammenpassen, zeigen 06 und 07 die echte Uhrzeit der Aufnahme. Für 11:45 bzw. 19:00 müssen sie zu dieser Tageszeit aufgenommen werden.

## Bilder neu erzeugen

Voraussetzungen: Simulator „iPhone 18 Pro“ (iOS 27.2), Debug-Build der App installiert, Widgets einmal auf dem Home-Bildschirm platziert (Seite 1: „Mensa heute“ mittel + groß, Seite 2: „Mensa heute“ klein + „Heute Abend“ klein, Seite 3: „Mensa heute“ mittel + „Heute Abend“ mittel, Seite 4: „Mensa heute“ mittel mit eingeschaltetem „Filter aus der App anwenden“), Sperrbildschirme mit den Widgets und die zwei Steuerelemente im Kontrollzentrum eingerichtet.

```sh
./erzeugen.sh status                                  # Statusleiste auf 9:41
./erzeugen.sh vorbereiten 11:45 vegan light           # App laden, Widget-Uhr und Statusleiste auf 11:45, zurück zum Home-Bildschirm
# zur gewünschten Home-Seite wischen, dann:
./erzeugen.sh foto de 01-home-mensa-mittag
./erzeugen.sh vorbereiten jetzt vegan light           # Sperrbildschirm: echte Uhrzeit
# Gerät sperren, dann:
./erzeugen.sh sperrfoto de 06-sperrbildschirm-mensa
```

Die Uhr der Widgets stellt das Launch-Argument `-WidgetUhr` (und `-WidgetFilter vegan|vegetarisch|bio|aus` den Filter der App). Beides gibt es nur in Debug-Builds (`Shared/WidgetUhr.swift`, `Campus_IlmenauApp`). Danach laden alle Widgets neu (`WidgetCenter.reloadAllTimelines`). Vor dem Foto jedes Bild ansehen: Es darf kein Platzhalter, kein „Noch kein Plan“, „Der Speiseplan ist noch nicht da“, „Nichts eingetragen“, „Nichts passt zu deinem Filter“, keine Lade-Ziege und kein Systemdialog zu sehen sein. Getönt: Home-Bildschirm lange drücken › Anpassen › Getönt.
