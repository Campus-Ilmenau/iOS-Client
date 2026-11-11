# Siri auf Englisch: Entwurf zur Durchsicht

Stand: Entwurf, nicht geprüft. Alles hier ist von Claude formuliert und wartet auf deine Durchsicht.

## Was schon in den Katalogen steht

| Datei | Inhalt | Status |
|---|---|---|
| `AppShortcuts.xcstrings` | Sätze und Kurztitel aller 7 Kurzbefehle, Deutsch und Englisch | Englisch: `needs_review` |
| `Localizable.xcstrings` | Titel, Beschreibungen, Parameter, Dialoge, Enum-Namen und Synonyme der Intents, Texte von „Mehr“ und der Satzliste | Englisch: `needs_review` (60 Schlüssel) |

In Xcode: Katalog öffnen, Filter „Needs Review“. Nach der Durchsicht auf „Translated“ stellen.

**Folge für die Oberfläche:** Einige Schlüssel gelten auch für die App selbst (`Heute Abend`, `Abendessen`, `Merkliste`, `Vegetarisch`, `Alle ›`, `Speiseplan ›`, `Läuft gerade`, `Gemerkt`). Mit englischer Systemsprache erscheinen sie jetzt englisch, der Rest der App bleibt deutsch (Mischung). Soll das so bleiben, oder soll ich diese Schlüssel für Siri getrennt halten?

## Die gesprochenen Antworten

Die Antworten setzt die App zur Laufzeit aus Daten zusammen (`Shared/Siri*.swift`, deutsche Texte im Code). Sie stehen deshalb in keinem Katalog. Damit Siri sie auf Englisch sagen kann, müssten die Satzbausteine auf lokalisierte Vorlagen umgestellt werden (eigene Aufgabe, siehe unten). Hier der Entwurf der englischen Fassung je Vorlage; `A`, `B`, `C` sind Gerichts- oder Veranstaltungsnamen.

### Mensa heute
| Deutsch | Englisch (Entwurf) |
|---|---|
| Zum Mittag gibt es in Ehrenberg A für 2,90 €, B und C. Geöffnet bis 14 Uhr. | For lunch, Ehrenberg has A for €2.90, B and C. Open until 2 pm. |
| Heute Mittag gibt es ab 11 Uhr in Ehrenberg … | Lunch today starts at 11 am at Ehrenberg: … |
| Zum Abendessen gibt es ab 16:30 Uhr in der Cafeteria Ehrenberg … | Dinner starts at 4:30 pm at Cafeteria Ehrenberg: … |
| Zum Abendessen gibt es bis 19:30 Uhr in der Cafeteria Ehrenberg … | Dinner is served until 7:30 pm at Cafeteria Ehrenberg: … |
| Heute gibt es nichts mehr. Morgen Mittag gibt es ab 11 Uhr in Ehrenberg … | Nothing more today. Tomorrow’s lunch starts at 11 am at Ehrenberg: … |
| Ehrenberg hat heute zu. Montag Mittag gibt es ab 11 Uhr … | Ehrenberg is closed today. Monday’s lunch starts at 11 am: … |
| Heute haben die Cafeterien zu. | The cafeterias are closed today. |
| Zum Mittag passen in Ehrenberg zwei Gerichte zu deinem Filter: … | For lunch, two dishes at Ehrenberg match your filter: … |
| Zum Mittag passt heute nichts zu deinem Filter. Ohne Filter gibt es 6 Gerichte. | Nothing matches your filter for lunch today. Without the filter there are 6 dishes. |
| … zwei vegetarische Gerichte, nur Bio und ohne Milch: … | … two vegetarian dishes, organic only and without milk: … |
| … 5 vegetarische Gerichte, zum Beispiel A, B und C. | … 5 vegetarian dishes, for example A, B and C. |
| Zum Abendessen gibt es heute nichts Vegetarisches. Morgen Mittag in Ehrenberg: A. | There’s nothing vegetarian for dinner today. Tomorrow’s lunch at Ehrenberg: A. |
| Für heute ist der Speiseplan noch nicht da. | Today’s menu isn’t available yet. |
| Ich komme gerade nicht an den Speiseplan. Versuch es gleich noch mal. | I can’t reach the menu right now. Try again in a moment. |

### Hat die Mensa offen?
| Deutsch | Englisch (Entwurf) |
|---|---|
| Ehrenberg hat seit 14 Uhr zu. Die Nanoteria hat noch 25 Minuten offen, bis 15 Uhr. | Ehrenberg has been closed since 2 pm. Nanoteria is open for another 25 minutes, until 3 pm. |
| Ja, Ehrenberg hat bis 14 Uhr offen. | Yes, Ehrenberg is open until 2 pm. |
| Ja, Ehrenberg hat noch 30 Minuten offen, bis 14 Uhr. | Yes, Ehrenberg is open for another 30 minutes, until 2 pm. |
| Ehrenberg öffnet um 11 Uhr. | Ehrenberg opens at 11 am. |
| Ehrenberg hat heute zu. Morgen ab 11 Uhr. | Ehrenberg is closed today. Tomorrow from 11 am. |
| Heute haben alle Mensen zu. Montag ab 11 Uhr. | All canteens are closed today. Monday from 11 am. |
| Heute hat keine Mensa mehr offen. Morgen ab 11 Uhr. | No canteen is open any more today. Tomorrow from 11 am. |
| Ja, die Nanoteria hat bis 15 Uhr offen, Ehrenberg und Röntgenbau bis 14 Uhr. | Yes, Nanoteria is open until 3 pm, Ehrenberg and Röntgenbau until 2 pm. |
| Die Cafeterien haben zu. Das Abendessen gibt es ab 16:30 Uhr in der Cafeteria Ehrenberg. | The cafeterias are closed. Dinner starts at 4:30 pm at Cafeteria Ehrenberg. |
| Ich komme gerade nicht an die Öffnungszeiten. Versuch es gleich noch mal. | I can’t reach the opening hours right now. Try again in a moment. |

### Abendessen
| Deutsch | Englisch (Entwurf) |
|---|---|
| Ja. Zum Abendessen gibt es ab 16:30 Uhr in der Cafeteria Ehrenberg A für 3,20 €, B und C. | Yes. Dinner starts at 4:30 pm at Cafeteria Ehrenberg: A for €3.20, B and C. |
| Ja, noch bis 19:30 Uhr gibt es zum Abendessen in der Cafeteria Ehrenberg … | Yes, dinner is served until 7:30 pm at Cafeteria Ehrenberg: … |
| Das Abendessen ist für heute vorbei. Morgen ab 16:30 in der Cafeteria Ehrenberg. | Dinner is over for today. Tomorrow from 4:30 pm at Cafeteria Ehrenberg. |
| Heute gibt es kein Abendessen. Das nächste ist am Montag ab 16:30. | There’s no dinner today. The next one is on Monday from 4:30 pm. |
| Heute gibt es kein Abendessen. Das nächste ist morgen ab 16:30. | There’s no dinner today. The next one is tomorrow from 4:30 pm. |

### Heute Abend
Titel stehen ohne Artikel, weil das Geschlecht unbekannt ist. Auf Englisch entfällt das Problem.

| Deutsch | Englisch (Entwurf) |
|---|---|
| Gerade läuft Spieleabend im Studi-Club. Um 21 Uhr ist Open Stage im BC-Club, um 22 Uhr Karaoke-Nacht in der Baracke5. Kneipenquiz fällt aus. | Spieleabend is on right now at Studi-Club. At 9 pm there’s Open Stage at BC-Club, at 10 pm Karaoke-Nacht at Baracke5. Kneipenquiz is cancelled. |
| Heute Abend ist um 19 Uhr Spieleabend im Studi-Club, um 21 Uhr Open Stage … und um 22 Uhr … | Tonight at 7 pm there’s Spieleabend at Studi-Club, at 9 pm Open Stage … and at 10 pm … |
| Kneipenquiz und Open Stage fallen aus. | Kneipenquiz and Open Stage are cancelled. |
| Heute Abend ist nichts eingetragen. Morgen um 21 Uhr: Halloween-Party im Studi-Club. | Nothing is scheduled tonight. Tomorrow at 9 pm: Halloween-Party at Studi-Club. |
| Heute Abend ist alles vorbei. Morgen Abend ist um 20 Uhr … | Tonight is over. Tomorrow evening at 8 pm there’s … |
| Heute Abend ist alles vorbei. Für morgen Abend ist nichts eingetragen. | Tonight is over. Nothing is scheduled for tomorrow evening. |
| Heute Abend ist nichts los. Kneipenquiz fällt aus. | Nothing is on tonight. Kneipenquiz is cancelled. |
| Ich komme gerade nicht an die Veranstaltungen. Versuch es gleich noch mal. | I can’t reach the events right now. Try again in a moment. |

### Katalogsuche
| Deutsch | Englisch (Entwurf) |
|---|---|
| Ich habe 128 Treffer für „Regelungstechnik“. Der erste, „Regelungstechnik für Ingenieure“, ist ausleihbar. | I found 128 results for “Regelungstechnik”. The first, “Regelungstechnik für Ingenieure”, is available to borrow. |
| … ist nur vor Ort nutzbar / ist online lesbar / ist ausgeliehen bis zum 17. November. | … can only be used in the library / can be read online / is on loan until November 17. |
| Der erste ist „…“. (ohne Status) | The first one is “…”. |
| Ich habe einen Treffer für „X“: „T“. Er ist ausleihbar. | I found one result for “X”: “T”. It’s available to borrow. |
| Für „X“ habe ich nichts gefunden. | I didn’t find anything for “X”. |
| Ich habe nach „K“ gesucht. Das sind 128 Treffer. | I searched for “K”. That’s 128 results. |
| Ich komme gerade nicht an den Katalog. Versuch es gleich noch mal. | I can’t reach the catalog right now. Try again in a moment. |
| Dein Suchbegriff passt nicht. Versuch es mit ein paar Stichworten. | That search term doesn’t work. Try a few keywords. |

### Merkliste
| Deutsch | Englisch (Entwurf) |
|---|---|
| Drei Titel stehen im Regal: zwei im Bereich 60 ELT, einer in 70 MB. Einer ist ausgeliehen. | Three titles are on the shelf: two in 60 ELT, one in 70 MB. One is on loan. |
| Ein Titel steht im Regal, im Bereich 60 ELT. | One title is on the shelf, in 60 ELT. |
| Zwei Titel stehen im Regal, alle im Bereich 60 ELT. | Two titles are on the shelf, both in 60 ELT. |
| Einer ist online verfügbar. | One is available online. |
| Bei einem Titel kenne ich den Standort nicht. | I don’t know where one title is shelved. |
| Gerade steht keiner deiner 2 Titel im Regal. | None of your 2 titles is on the shelf right now. |
| Deine Merkliste ist leer. Titel merkst du dir im Katalog. | Your reading list is empty. Save titles from the catalog. |
| Auf deiner Merkliste stehen 3 Titel. Den Stand im Regal kenne ich gerade nicht. | You have 3 titles on your reading list. I can’t tell right now what’s on the shelf. |

### Rückfragen
| Deutsch | Englisch (Entwurf) |
|---|---|
| Welche Cafeteria meinst du? | Which cafeteria do you mean? |
| Wonach soll ich im Katalog suchen? | What should I search for in the catalog? |

## Zu klären, bevor es eingebaut wird
1. **Uhrzeiten:** Englisch sagt „2 pm“, Deutsch „14 Uhr“. Das müsste `SiriSprache.uhr` je Sprache liefern.
2. **Preise:** „2,90 €“ → „€2.90“ (Zahlenformat nach Sprache).
3. **Ortsangaben:** Das deutsche „im/in der“ (Wortende-Regel in `SiriSprache.ortsangabe`) entfällt, englisch genügt „at“.
4. **Namen:** „Nanoteria“, „Röntgenbau“, „Ehrenberg“ und Veranstaltungs- und Buchtitel bleiben unübersetzt.
5. **Umstellung:** Die Satzbausteine in `Shared/Siri*.swift` müssten von Strings auf lokalisierte Vorlagen (`String(localized:)` mit Platzhaltern, mit Kommentaren für die Übersetzung) umgestellt werden. Das betrifft alle Satzbausteine in sechs Dateien und alle Tests, die Sätze vergleichen. Sag Bescheid, wenn ich das bauen soll.
