# Campus Ilmenau – App

iOS-App für Studierende der TU Ilmenau (SwiftUI). Eine Android-Version folgt später, dieselbe CI gilt dort auch.

Schon umgesetzt und funktionsfähig: Thoska auslesen (NFC), Mensa-Speiseplan für 4 Mensen bis 3 Wochen im Voraus, Bibliotheksausleihen über GBV PAIA mit Mitteilungen. Diese Fachlogik bleibt. Die Oberfläche wird nach dem Design neu gebaut.

## Design

Das Design liegt im Submodul `Design/` (Repo `campus-ilmenau-ci`, Branch `design/logo-refresh`). **Dort nichts ändern.** Änderungen am Design kommen aus dem CI-Repo und werden mit `git submodule update --remote Design` geholt.

| Was | Datei |
|---|---|
| Beschreibung aller Ansichten, Bausteine, Farben-Zuordnung | `Design/Logo 2026/Mockup/Uebergabe.md` – **zuerst lesen** |
| Quelltext jeder Ansicht (Aufbau, Maße, Texte, Zustände) | `Design/Logo 2026/Mockup/artboards/<Name>.dc.html` |
| Bilder der Ansichten zum Vergleichen | `Design/Logo 2026/Mockup/bilder/` (falls vorhanden) |
| Start-Animation | `Design/Logo 2026/Launch/Launch-Animation.md`, Maske `Goat Mask.pdf`, Ablauf zum Nachsehen in `index.html` |
| Farben | `Design/Logo 2026/Farben/Colors.xcassets` (Light und Dark), Werte in `tokens.json` |
| Schrift | `Design/Logo 2026/Schrift/iOS/*.ttf`, Hinweise in `Schrift/README.md` |
| App-Icons | `Design/Logo 2026/App Icon Light/Dark/Tinted.svg`, PNG in `Export/` |
| Regeln mit Beispielen | `Design/Logo 2026/Handbuch/index.html` |

Die `.dc.html`-Dateien laufen nicht im Browser, sind aber als Text gut lesbar: Farben stehen als CSS-Variablen im `<style>`, `{{…}}` sind Platzhalter, das Verhalten (Zustände, Uhrzeit-Logik, Klicks) steht im `<script>` in `renderVals()`.

## Regeln

- **Farben nur über die Assets**, nie Hex-Werte im Code: `Color(.background)`, `Color(.accent)` … Die Zuordnung Mockup-Variable → Asset steht in `Uebergabe.md`.
- Grün und Blau **nur als Flächen** (Bänder, Badges), nie als Text oder Button.
- Buttons neutral (`buttonPrimary`, `buttonSecondary`). **Rot nur für kritische Aktionen** (Abmelden, Löschen).
- `accent` (Orange) für Links, aktiven Tab, Auswahl – nicht für Buttons.
- Dark Mode ist Nachtblau `#0E1A2E`, nicht Schwarz. Kommt über die Assets automatisch.
- Text braucht mindestens 4,5 : 1 Kontrast. Die Asset-Paare (`green`/`onGreen` usw.) erfüllen das.
- **Schrift:** Oberfläche in SF Pro mit Dynamic Type. Nur große Titel und Zahlen in Plus Jakarta Sans ExtraBold, Laufweite −2 %.
- **Startseite „Heute“ zeigt keine Live-Daten** wie Thoska-Guthaben oder Anzahl Ausleihen – sie veralten. Sie zeigt je nach Uhrzeit Mensa, Abendessen oder Veranstaltungen, dazu Hinweise.
- Tippziele mindestens 44 × 44 pt, Abstände in 4-pt-Schritten.
- VoiceOver-Beschriftungen wie im Mockup (`aria-label`).

## Arbeitsweise

- **Eine Ansicht pro Schritt.** Erst `Uebergabe.md` zur Ansicht lesen, dann die `.dc.html`, dann umsetzen.
- Für jede Ansicht SwiftUI-Previews in Light und Dark anlegen, bei „Heute“ zusätzlich für Morgen, Nachmittag, Abend und Nacht. Preview mit dem Mockup bzw. dem Bild in `bilder/` vergleichen.
- Wiederkehrende Bausteine (`TabBar`, `Card`, `Chip`, `PrimaryButton`, `DiagonalBands`, `Toast`, Sheets) einmal als eigene Views bauen und überall nutzen.
- Die vorhandenen Services und Modelle für Mensa, Thoska und PAIA weiterverwenden, nicht neu schreiben. Wenn das Mockup Daten braucht, die es noch nicht gibt (z. B. Club-Beacons, Hinweise), zuerst nachfragen.
- Weicht das Mockup von dem ab, was technisch sinnvoll ist, nachfragen statt raten.

## Reihenfolge

1. Grundlage: `Colors.xcassets` ins Projekt, Schrift einbinden (`UIAppFonts` in der Info.plist), App-Icons Light/Dark/Tinted.
2. Bausteine (siehe oben).
3. Start-Animation nach `Launch-Animation.md`: statischer Launch Screen = erster Frame, dann „Durch die Ziege“ in 1,1 s.
4. Ansichten: Heute → Mensa → Thoska → Bibliothek (mit Login-Sheet und Barcode-Scan) → Events → Mehr → Club.
