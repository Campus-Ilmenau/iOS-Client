# Siri-Testprotokoll (iPhone und HomePod, Deutsch)

**Noch nicht ausgefüllt.** Das Sprechen auf einem Gerät konnte Claude nicht ausführen; dieses Protokoll ist die Vorlage dafür. Trage ein, was Siri versteht (✓), nicht versteht (✗) oder falsch versteht (Notiz).

## Vorbereitung
- App frisch installiert (Debug-Build vom iPhone), einmal geöffnet, damit die Sätze registriert sind.
- iPhone und HomePod im selben Zuhause, „Persönliche Anfragen“ in der Home-App an, Siri auf Deutsch.
- Für „Merkliste“ mindestens drei Titel vormerken (zwei am selben Standort, einer ausgeliehen).
- Für „Heute Abend“ testen mit und ohne laufende Veranstaltung. Mit dem Debug-Argument `-WidgetUhr 20:15` rechnen Mensa, Abendessen und Heute Abend zu einer festen Uhrzeit (`-WidgetUhr aus` hebt es auf).
- Wer „Campus“ statt „Campus Ilmenau“ sagt, testet `INAlternativeAppNames`.

## Die 7 Kurzbefehle
| # | Kurzbefehl | Satz (so sprechen) | iPhone | HomePod | Notiz |
|---|---|---|---|---|---|
| 1 | Mensa heute | „Was gibt’s heute in der Mensa bei Campus Ilmenau?“ | | | |
| 1 | | „Was gibt’s zu essen bei Campus Ilmenau?“ | | | |
| 1 | | „Mensa heute bei Campus Ilmenau“ | | | |
| 1 | | „Was gibt’s in der Nanoteria bei Campus Ilmenau?“ | | | |
| 1 | | „Was gibt’s zu essen in der Mensa Ehrenberg bei Campus Ilmenau?“ | | | |
| 1 | | „Was gibt’s heute Vegetarisches bei Campus Ilmenau?“ | | | |
| 1 | | „Was gibt’s heute Veganes bei Campus Ilmenau?“ | | | |
| 1 | | „Was gibt’s in der Cafeteria bei Campus Ilmenau?“ (Rückfrage mittags, bei mehreren offenen) | | | |
| 2 | Hat die Mensa offen? | „Hat die Mensa bei Campus Ilmenau offen?“ | | | |
| 2 | | „Hat die Nanoteria bei Campus Ilmenau offen?“ | | | |
| 2 | | „Hat die Cafeteria bei Campus Ilmenau offen?“ | | | |
| 2 | | „Welche Mensa hat bei Campus Ilmenau offen?“ | | | |
| 3 | Abendessen | „Gibt es heute Abendessen bei Campus Ilmenau?“ | | | |
| 3 | | „Abendessen bei Campus Ilmenau“ | | | |
| 4 | Heute Abend | „Was ist heute Abend los bei Campus Ilmenau?“ | | | |
| 4 | | „Heute Abend bei Campus Ilmenau“ | | | |
| 5 | Im Katalog suchen | „Suche im Katalog von Campus Ilmenau“ → Siri fragt nach dem Begriff → „Regelungstechnik“ | | | |
| 5 | | „Such ein Buch mit Campus Ilmenau“ | | | |
| 6 | Merkliste | „Was steht auf meiner Merkliste bei Campus Ilmenau?“ | | | |
| 6 | | „Merkliste bei Campus Ilmenau“ | | | |
| 7 | Thoska auslesen | „Lies meine Thoska mit Campus Ilmenau aus“ | | (siehe unten) | |
| 7 | | „Thoska auslesen mit Campus Ilmenau“ | | (siehe unten) | |

## Was beim HomePod zu prüfen ist
1. **Rückfragen per Sprache:** Cafeteria-Wahl (mittags, mehrere offen) und Suchbegriff im Katalog gesprochen beantworten. Liest Siri die Auswahl verständlich vor? Die Namen heißen heute „Cafeteria Ehrenberg“, „Cafeteria Nanoteria“, „Cafeteria Röntgenbau“; die Übergabe wünscht kürzere („Ehrenberg, Nanoteria oder Röntgenbau?“).
2. **Kein Verweis auf die Karte:** Kommt in einer Antwort etwas wie „siehe unten“ vor? (Im Code kommt kein solcher Satz vor, aber hören.)
3. **Merkliste:** Antwortet der HomePod nur der Stimme, deren iPhone die Liste hat?
4. **Thoska auslesen auf dem HomePod:** Was sagt Siri, wenn die App sich nicht öffnen lässt? Genau mitschreiben:

   > Siri sagt: ______________________________________________

   - Sagt das System etwas Passendes („Das geht nur auf dem iPhone …“): nichts zu tun.
   - Sagt es nichts Passendes: Der Intent soll den Fall erkennen und „Das geht nur auf dem iPhone. Öffne dort Campus Ilmenau.“ zurückgeben. Dafür kommt `systemContext.currentMode.canContinueInForeground` in Frage (siehe Dokumentation zu `supportedModes`). Es lässt sich nur am Gerät klären, ob es auf dem HomePod `false` liefert. Erst nach diesem Test sollte `ThoskaAuslesenIntent` angefasst werden, denn er steuert auch das Steuerelement.

## Nicht erkannt oder falsch verstanden
| Satz | Gerät | Was Siri tat | Idee |
|---|---|---|---|
| | | | |
