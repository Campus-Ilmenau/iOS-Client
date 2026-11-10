# Katalogsuche der App – Ablauf und Parameter

Stand: 2026-11-08. Grundlage ist der Code in `Bibliothek/Katalog/` (`LibrarySearchModel.swift`, `LibraryCatalogQuery.swift`, `LibraryCatalogService.swift`, `LibraryCatalogView.swift`).

Die App sendet Suchanfragen nur an **einen** Endpunkt: die eigene API (`https://dev-api.campus-ilmenau.de/develop/v1/library/*`). Sie fragt weder den UB-Katalog noch den GBV-Gesamtkatalog direkt ab. Welche Quelle durchsucht wird, entscheidet die API aus dem Parameter `in` und den übergebenen Feldern.

## 1. Parameter von `GET /v1/library/search`

| Parameter | Wert | Wann gesendet |
|---|---|---|
| `q` | Freitext, höchstens 200 Zeichen, getrimmt | wenn nicht leer |
| `title`, `author`, `isbn`, `subject` | Feldsuche | nur wenn die erweiterte Suche offen ist, das Feld gefüllt ist und `in` nicht `local` oder `content` ist |
| `year_from`, `year_to` | vierstellig, 1000–9999, von ≤ bis, Spanne höchstens 150 Jahre | wenn gefüllt (die App prüft vorher) |
| `type` | `print_book`, `ebook`, `journal` oder `all` | immer, weil die Pill-Voreinstellung „Gedruckt“ (`print_book`) ist |
| `in` | `local`, `catalog` oder `content` | siehe Abschnitt 3 |
| `page` | ab 1 | immer |
| `per_page` | immer 20 | immer |

Sortierung wird nicht gesendet. In der App steht bei Feldsuchen „neueste zuerst“, das ist nur ein Anzeigetext. Ob die API tatsächlich so sortiert, ist offen.

## 2. Wann eine Suche startet

| Auslöser | Verhalten |
|---|---|
| Tippen im Suchfeld | 700 ms Debounce, dann Suche. Bei leerem Feld wird zurückgesetzt und nichts gesendet. Es gibt keine Mindestzeichenzahl, schon ein Buchstabe sucht. |
| Return-Taste oder „Suchen“ | sofort |
| Wechsel der Medienart-Pill | sofort neu, falls schon ein Begriff dasteht |
| Erweiterte Suche offen | kein Auto-Suchen beim Tippen, nur über „Suchen“ |
| „Erneut versuchen“ | wiederholt die letzte Anfrage |
| Pull to Refresh | dieselbe Anfrage noch einmal. Die alte Liste bleibt stehen, bis die neue da ist. |

Eine neue Suche bricht die laufende ab (Task-Cancel plus Generationszähler). Abgebrochene Anfragen erreichen die API eventuell trotzdem. Bei schnellem Tippen kommen also Anfragen für unvollständige Begriffe an, auch wenn die App das Ergebnis verwirft.

Die Felder der erweiterten Suche zählen nur, solange der Bereich offen ist. `q` und Felder können gleichzeitig gesendet werden.

## 3. Welche Quelle durchsucht wird

| Fall | Gesendet | Erwartung der App an die API |
|---|---|---|
| Freitext (Standard) | kein `in` | Bestand der UB zuerst. Die Antwort trägt `source` = `local`, `mixed` oder `catalog`. Bei `mixed` ergänzt die API aus dem Gesamtkatalog, diese Treffer haben `match.stage = catalog`. |
| Feldsuche | kein `in`, aber `title`, `author` usw. | läuft laut App-Annahme immer im Gesamtkatalog, die Antwort hat kein `source` |
| „Im Gesamtkatalog weitersuchen“ | `in=catalog`, `page=1`, sonst dieselben Parameter | Gesamtkatalog. Die Treffer haben kein `match`. |
| Inhaltssuche | `in=content` ist im Code definiert, wird aber **nirgends gesetzt** | Die App sendet es nie. Die Inhaltssuche läuft vermutlich serverseitig im Standardfall, gesteuert über `GET /v1/library/features` (`contents`). Die App zeigt dann „Auch in Inhaltsverzeichnissen und Klappentexten gesucht“, wenn ein Treffer `match.isInTableOfContents` oder `isInBlurb` hat. |

Der Hinweis „Im Gesamtkatalog weitersuchen“ erscheint in diesen Fällen:

- Die Antwort hat `catalog_suggested = true`, weil der Verbund nicht rechtzeitig geantwortet hat.
- Die Antwort ist gemischt (`source = mixed`). Dann gibt es am Ende der Liste den Button.
- Die Suche hatte keine Treffer.
- Die Suche dauert länger als 900 ms (Hinweis zur Wartezeit).

Die Fortsetzung im Gesamtkatalog beginnt bei Seite 1. Die App entfernt Titel, die schon im Bestand angezeigt wurden, anhand der `id`.

## 4. Der Button „Im Gesamtkatalog suchen / weitersuchen“

Der Button läuft über dieselbe API. Er ruft die Suche noch einmal mit `in=catalog` und `page=1` auf (`LibraryCatalogView.swift:344–408`). Er erscheint nur, solange der Gesamtkatalog in dieser Suche noch nicht versucht wurde (`catalogTried == false`).

| Button | Bedingung | Auslöser in der API-Antwort |
|---|---|---|
| „Im Gesamtkatalog weitersuchen“ (Hinweis: „Im Bestand der UB gibt es nur wenige Treffer. Der Gesamtkatalog hat vielleicht mehr.“) | Es gibt Treffer und die Antwort hat `catalog_suggested = true`, weil der Verbund nicht rechtzeitig geantwortet hat. Die Suche ist keine Katalog- oder Feldsuche. | `catalog_suggested: true` |
| „Im Gesamtkatalog suchen“ (Hinweis: „Das sind alle Treffer dieser Suche. Für mehr Titel aus anderen Bibliotheken:“) | Es gibt Treffer und die Antwort ist gemischt. Der Button steht am Ende der Liste. | `source: "mixed"` |
| „Im Gesamtkatalog suchen“ (auf der Seite „Keine Treffer für …“) | Die Suche war erfolgreich, hatte aber keine Treffer. Die Suche ist keine Katalog- oder Feldsuche. | `data: []` |

Die App entscheidet nur anhand dieser Felder. Die Schwelle, ab der „wenig im Bestand“ gilt und `mixed` oder `catalog_suggested` gesetzt wird, liegt komplett in der API. Im App-Code steht dazu keine Zahl.

Bei Feldsuchen und bei `in=catalog` erscheint der Button nie, weil sie schon im Gesamtkatalog laufen (`isCatalogOnlySearch`).

Ablauf nach dem Tippen auf den Button:

1. Die App nimmt die zuletzt ausgeführte Suche (`executedQuery`) und setzt `in=catalog` und `page=1`. `q`, `type` und Jahre bleiben gleich.
2. Treffer, die schon im Bestand angezeigt wurden, entfernt die App nach `id`. Das gilt auch für Treffer auf späteren Seiten.
3. Das Ergebnis erscheint als eigener Block „Weitere aus dem Gesamtkatalog“ unter den bisherigen Treffern. Gab es vorher keine Treffer, hat der Block keine Überschrift.
4. Weitere Seiten lädt „Weitere N Treffer laden“ mit `in=catalog` und `page=2, 3, …`.
5. Die Kopfzeile ändert sich zu „Ergänzt um N Treffer aus dem Gesamtkatalog“.
6. Hat auch der Gesamtkatalog nichts, steht dort „Auch im Gesamtkatalog gibt es keine Treffer. Prüfe die Schreibweise.“

Zusätzlich erscheint beim Laden nach 900 ms der Text „Wenig im Bestand – frage auch den Gesamtkatalog …“. Er hängt nur an der Zeit (`catalogHintDelay`), nicht an einer API-Antwort, und kann deshalb auch bei einer langsamen Suche mit vielen Bestandstreffern erscheinen.

## 5. Weitere Anfragen rund um die Suche

| Anfrage | Auslöser |
|---|---|
| `GET /v1/library/features` | einmal beim Öffnen des Katalogs, nicht gespeichert |
| `GET /v1/library/availability?ids=a,b,c` | für sichtbare Karten, gebündelt nach 80 ms, höchstens 20 IDs pro Aufruf. Auch die Merkliste fragt so ab. |
| `GET /v1/library/media/{id}?search_id=…&track=…` | beim Öffnen eines Titels. `search_id` stammt aus der Suchantwort. `track=false` beim Neuladen der offenen Seite und bei der Merkliste. |
| Cover (`cover.url` aus der Antwort) | pro Karte. Bei 404 `cover_pending` bis zu zweimal erneut nach `Retry-After` (Standard 30 s). |

## 6. Was die App aus der Antwort liest

- Felder: `data`, `total_count`, `page`, `per_page`, `has_more`, `source`, `corrected_query`, `catalog_suggested`, `catalog_checked`, `catalog_total`, `search_id`.
- Pro Treffer: `match.stage` (`exact`, `corrected`, `relaxed`, `catalog`), `match.fields`, `match.snippet`, außerdem `fetchedAt` und der Cover-Status.
- Header: `X-Cache-Status` (`stale` löst den Hinweis „Katalog antwortet langsam“ aus), `X-Request-Id`, `Retry-After`.
- Fehler: 400 (die App prüft vorher, sollte selten vorkommen), 404 und 503 `catalog_unavailable`.

## 7. Auffälligkeiten für die Optimierung

1. Die Standard-Pill `print_book` filtert still. Wer „Alle“ will, muss umschalten.
2. Beim Debounce von 700 ms gehen Zwischenstände mit ein oder zwei Zeichen an die API, weil es keine Mindestlänge gibt.
3. Die Feldsuche geht ohne `in` an die API und die App nimmt an, dass sie im Gesamtkatalog läuft. Das sollte auf API-Seite gegengeprüft werden.
4. `in=content` ist ungenutzt. Soll die Inhaltssuche eigenständig steuerbar sein, müsste die App es senden.
5. Bei `catalog_suggested` hat die API den Verbund schon einmal angefragt, und die App fragt ihn beim Tippen auf den Button noch einmal ab. Ein Zwischenspeicher für das erste Ergebnis würde den zweiten Aufruf beschleunigen.
6. Der Ladehinweis zum Gesamtkatalog (900 ms) ist rein zeitbasiert und sagt nichts über die Trefferzahl.
