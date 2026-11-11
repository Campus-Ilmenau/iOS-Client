# Changelog

Alle nennenswerten Änderungen an der Campus-Ilmenau-App. Das Format folgt [Keep a Changelog](https://keepachangelog.com/de/1.1.0/). Der Stand wurde aus der Git-Historie (2026-10-26 bis 2026-11-11) zusammengestellt.

## [1.0.0] – Build 2

Erste Version der App. Sie umfasst alle Funktionen, die in der Git-Historie bis zum Stand 2026-11-11 enthalten sind.

### Heute
- Startseite mit Tagesphasen. Je nach Uhrzeit zeigt sie Mensa, Abendessen oder Veranstaltungen.
- Karte „Heute Abend“ mit Veranstaltungen des Abends.
- Der Mensa-Filter gilt auch für die Essenskarten auf der Startseite.

### Mensa
- Speiseplan der Mensen mit Live-Daten, Auswahl künftiger Tage per Datumsauswahl und Wischen zwischen den Mensen.
- Filter nach Essensattributen, die auf dem Gerät gespeichert werden.
- Detailansicht zu jedem Gericht mit Nährwerten und Komponenten.
- Preise für Studierende, Mitarbeitende und Gäste.
- Öffnungszeiten.
- Das Label „vegetarisch“ erscheint auch bei veganen Gerichten.
- Zufällige, verspielte Ladetexte.

### Thoska
- Guthaben der Thoska per NFC auslesen.
- Animierte Karte, die sich per Wischgeste umdreht und das Guthaben zeigt.
- Verlauf des Guthabens, lokal mit SwiftData gespeichert.
- Gescannte Karten lassen sich benennen.

### Bibliothek
- Bibliothekskonto über GBV PAIA mit Ausleihen und Mitteilungen.
- Login-Sheet mit Scan der Benutzernummer per Kamera. Buchstaben in Benutzernummern werden akzeptiert.
- Katalogsuche mit Titelansicht und Merkliste. Die Ansicht aktualisiert sich per Pull-to-Refresh, und die Filter klappen bei der Suche ein.
- Bibliotheksausweis mit Strichcode, geschützt per Face ID.

### Events
- Veranstaltungsliste mit Filter, Detailansicht und Merkliste.
- Beim Hinzufügen zum Kalender lässt sich der Kalender auswählen.

### Teilen
- Teilkarten und Teilen-Menü für Gerichte, Veranstaltungen und Medien.

### Siri und Kurzbefehle
- Siri beantwortet Fragen zu Mensa heute, Öffnungszeiten, Abendessen und „Heute Abend“.
- Siri beantwortet Katalogsuche und Merkliste. Die Karten öffnen sich beim Suchbegriff, beim Titel oder in der Merkliste.
- Die App meldet Aktionen an Siri, damit die Widgets im Smart Stack passend eingeordnet werden.
- Im Bereich „Mehr“ gibt es Siri-Tipps.

### Widgets
- Widget „Mensa heute“ mit gemeinsamem Mensa-Filter über eine App Group.
- Widget „Heute Abend“.
- Sperrbildschirm-Widgets und Steuerelemente.
- Deeplinks aus den Widgets in die App.

### Mehr
- Ansicht „Gespeicherte Daten“.
- Einstellungen für Darstellung (Hell, Dunkel), alternative App-Icons und Links.

### Design
- Neue Oberfläche nach dem Design „Logo 2026“, als Submodul `Design/` eingebunden.
- Farben nur über Assets, Light und Dark. Dark Mode in Nachtblau.
- Schrift Plus Jakarta Sans für große Titel und Zahlen, sonst SF Pro mit Dynamic Type.
- Wiederkehrende Bausteine: TabBar, Card, Chip, Buttons, DiagonalBands, Toast und Ziegen-Ladeanimation.
- Start-Animation „Durch die Ziege“, die vom Launch Screen in die App übergeht.
- App-Icons als Light-, Dark- und Tinted-Variante.

### Technik
- Unit-Test-Target mit Tests für Mensa-Filter und Gerichtsdetails.
- String Catalog für Lokalisierung. Neue Nutzungsbeschreibungen für Kamera, Kalender und Fotos.
- Schemes für Widget-Extension und Test-Target.

### Dokumentation
- Screenshots für App Store und Website, Teilen-Bilder und Widget-Bilder.
- Analyse der Katalog-Such-API, englischer Siri-Entwurf und Testprotokoll für Siri auf dem Gerät.
