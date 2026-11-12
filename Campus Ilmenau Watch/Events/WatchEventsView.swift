import SwiftUI

struct UhrEventZiel: Hashable {
    let id: String
}

/// „Heute Abend“ auf der Uhr nach `WatchEvents.dc.html`. Die Zeitleiste ist die des Widgets (`AbendWidgetPhasen`):
/// heute ab 17 Uhr, ohne Ganztägige, Laufendes zuerst, Vorbei ausgeblendet. Keine Bilder, keine Logos.
struct WatchEventsView: View {
    @Environment(UhrDaten.self) private var daten
    @Environment(\.dynamicTypeSize) private var schriftgroesse
    var jetzt: Date?

    var body: some View {
        UhrZeitgeber(festgelegt: jetzt) { jetzt in
            let anzeige = AbendWidgetPhasen.anzeige(
                events: daten.snapshot.events, gemerkteIDs: Set(daten.snapshot.gemerkteEventIDs),
                woche: daten.snapshot.woche, jetzt: jetzt
            )
            ScrollView {
                VStack(spacing: 6) {
                    if daten.hatKeineVeranstaltungen {
                        WatchKarte {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(SiriAbend.keineDaten)
                                    .font(.footnote)
                                    .foregroundStyle(Color(.watchText2))
                                    .fixedSize(horizontal: false, vertical: true)
                                WatchButton("Neu laden", systemImage: "arrow.clockwise") {
                                    Task { await daten.laden(gemerkteEvents: daten.snapshot.gemerkteEventIDs) }
                                }
                            }
                        }
                    } else {
                        Text(anzeige.datum)
                            .uhrSchrift(13)
                            .foregroundStyle(Color(.watchText2))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 4)

                        if anzeige.zeilen.isEmpty {
                            leer(anzeige)
                        }
                        ForEach(anzeige.zeilen) { zeile in
                            NavigationLink(value: UhrEventZiel(id: zeile.id)) {
                                zeileKarte(zeile)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Tippen zeigt Ort, Veranstalter und Beschreibung.")
                            .uhrSchrift(12)
                            .foregroundStyle(Color(.watchText3))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Heute Abend")
            .containerBackground(Color(.watchBackground), for: .navigation)
        }
    }

    private func zeileKarte(_ zeile: AbendWidgetAnzeige.Zeile) -> some View {
        let titel = Text(zeile.titel)
        let stern = Text(Image(systemName: "star.fill")).uhrSchrift(11).foregroundColor(Color(.watchAccent))
        let zeit = Text(zeile.zeit)
            .uhrSchrift(15, .bold)
            .monospacedDigit()
            .foregroundStyle(Color(zeile.abgesagt ? .watchText3 : .watchText))
        let text = VStack(alignment: .leading, spacing: 2) {
            Group {
                if zeile.gemerkt { Text("\(titel) \(stern)") } else { titel }
            }
            .uhrSchrift(15, .semibold)
            .strikethrough(zeile.abgesagt)
            .foregroundStyle(Color(zeile.abgesagt ? .watchText2 : .watchText))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            if !zeile.ort.isEmpty {
                Text(zeile.ort)
                    .uhrSchrift(13)
                    .foregroundStyle(Color(.watchText2))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if zeile.abgesagt {
                WatchChip("Fällt aus", variante: .danger).padding(.top, 2)
            } else if zeile.laeuft {
                WatchChip("Läuft gerade", variante: .green).padding(.top, 2)
            }
        }
        return WatchKarte {
            // Zeit links (40 pt) wie im Artboard; bei großer Schrift über dem Titel, damit der Titel Platz hat.
            if schriftgroesse >= .xxLarge {
                VStack(alignment: .leading, spacing: 2) {
                    zeit
                    text
                }
            } else {
                HStack(alignment: .top, spacing: 9) {
                    zeit.lineLimit(1).minimumScaleFactor(0.6).frame(width: 40, alignment: .leading)
                    text
                }
            }
        }
        .frame(minHeight: 44)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(zeile.zeit) Uhr, \(zeile.titel)" + (zeile.ort.isEmpty ? "" : ", \(zeile.ort)")
                + (zeile.gemerkt ? ", gemerkt" : "") + (zeile.abgesagt ? ", fällt aus" : zeile.laeuft ? ", läuft gerade" : "")
        )
    }

    private func leer(_ anzeige: AbendWidgetAnzeige) -> some View {
        WatchKarte {
            VStack(spacing: 2) {
                Image(systemName: "moon")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(.watchText3))
                    .accessibilityHidden(true)
                Text("Heute Abend nichts eingetragen")
                    .uhrSchrift(15, .semibold)
                    .foregroundStyle(Color(.watchText))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
                if !anzeige.morgenZeilen.isEmpty {
                    Text("Morgen: \(UhrAbendStart.anzahl(anzeige.morgenZeilen.count))")
                        .uhrSchrift(13)
                        .foregroundStyle(Color(.watchText2))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Kurzinfo zu einer Veranstaltung: Zeit, Ort, Veranstalter, Beschreibung (400 Zeichen) und „Auf iPhone öffnen“ (Handoff).
struct WatchEventInfoView: View {
    @Environment(UhrDaten.self) private var daten
    let id: String
    /// Previews zeigen eine feste Beschreibung, ohne zu laden.
    var vorschauBeschreibung: String?

    @State private var beschreibung: String?
    @State private var uebergeben = false

    var body: some View {
        ScrollView {
            if let event = daten.snapshot.events.first(where: { $0.id == id }) {
                inhalt(event)
            } else {
                WatchKarte {
                    Text("Die Veranstaltung ist nicht mehr da.")
                        .font(.footnote)
                        .foregroundStyle(Color(.watchText2))
                }
            }
        }
        .navigationTitle("Heute Abend")
        .containerBackground(Color(.watchBackground), for: .navigation)
        .task {
            if let vorschauBeschreibung { beschreibung = vorschauBeschreibung; return }
            beschreibung = await daten.beschreibung(eventID: id)
        }
    }

    private func zeitText(_ event: WidgetEvent) -> String {
        let tag = AbendWidgetPhasen.datumText(AbendBezug.tag(von: event))
        var zeit = HeuteUhr.uhrzeit(event.beginn)
        if event.ende != nil { zeit += "–" + HeuteUhr.uhrzeit(AbendBezug.ende(event)) }
        return "\(tag) · \(zeit)"
    }

    private func inhalt(_ event: WidgetEvent) -> some View {
        let link = DeepLink.event(id: event.id).url.absoluteString
        return VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.titel)
                    .uhrSchrift(17, .semibold)
                    .strikethrough(event.abgesagt)
                    .foregroundStyle(Color(.watchText))
                    .fixedSize(horizontal: false, vertical: true)
                Text(zeitText(event))
                    .uhrSchrift(13)
                    .foregroundStyle(Color(.watchText2))
                if event.abgesagt {
                    WatchChip("Fällt aus", variante: .danger).padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .accessibilityElement(children: .combine)

            if let ort = event.ort, !ort.isEmpty { infoKarte("Ort", ort) }
            if let veranstalter = event.veranstalter, !veranstalter.isEmpty { infoKarte("Veranstalter", veranstalter) }
            if let beschreibung { infoKarte("Beschreibung", beschreibung) }

            WatchButton("Auf iPhone öffnen", systemImage: "iphone") { uebergeben = true }
                .padding(.top, 4)
            if uebergeben {
                Text("Auf dem iPhone: Campus Ilmenau im App-Wechsler antippen.")
                    .uhrSchrift(12)
                    .foregroundStyle(Color(.watchText3))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
        }
        // Handoff: Das iPhone öffnet `campusilmenau://events/<id>`.
        .userActivity(UhrHandoff.eventTyp, isActive: uebergeben) { aktivitaet in
            aktivitaet.title = event.titel
            aktivitaet.isEligibleForHandoff = true
            aktivitaet.userInfo = [UhrHandoff.urlSchluessel: link]
        }
    }

    private func infoKarte(_ titel: LocalizedStringKey, _ text: String) -> some View {
        WatchKarte {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                    .uhrSchrift(13, .semibold)
                    .foregroundStyle(Color(.watchText2))
                Text(text)
                    .uhrSchrift(15, .medium)
                    .foregroundStyle(Color(.watchText))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
