#if DEBUG
import SwiftUI

/// Beispiele für die Previews der Uhr. Mensa und Veranstaltungen sind die Beispieldaten der Widgets (Donnerstag,
/// 29. Oktober 2026); die Zeiten sind die des Tweaks `zeit` in `WatchMensa.dc.html`.
enum WatchVorschau {
    static func zeit(_ uhr: String) -> Date { MensaWidgetVorschau.zeit("2026-10-29", uhr) }

    /// Speiseplan des Szenarios „Mittag“ plus Veranstaltungen des Abends.
    static func snapshot(abend: AbendWidgetVorschau.Szenario? = .laeuft1940) -> WidgetSnapshot {
        var snapshot = MensaWidgetVorschau.snapshot(.mittag)
        if let abend {
            snapshot.events = AbendWidgetVorschau.events(abend)
            snapshot.gemerkteEventIDs = ["stage", "halloween"]
            snapshot.woche = WidgetWoche(von: "2026-10-29", anzahl: 14)
            snapshot.stand = zeit("12:00")
        }
        return snapshot
    }

    /// Ein vollständiges Gericht: Allergene, Zusatzstoffe, alle Preisgruppen.
    static let gerichtVoll = WidgetGericht(
        id: "dal", name: "Linsen-Dal mit Basmatireis", gruppe: "Hauptgericht", abendessen: false,
        preisStudierende: 2.90, preisBedienstete: 4.40, preisGaeste: 5.90, waehrung: "EUR",
        chips: [WidgetChip(titel: "Vegan", art: .gruen), WidgetChip(titel: "Regional", art: .blau)],
        allergene: ["Sellerie", "Senf"], zusatzstoffe: ["Antioxidationsmittel"]
    )

    /// Ein knappes: nur Name, Preise, kein Chip, nichts weiter.
    static let gerichtKnapp = WidgetGericht(
        id: "suppe", name: "Kartoffelsuppe", gruppe: "Suppe", abendessen: false,
        preisStudierende: 1.40, preisBedienstete: 2.20, preisGaeste: 2.90, waehrung: "EUR", chips: []
    )

    static func gerichtSnapshot() -> WidgetSnapshot {
        WidgetSnapshot(mensen: [
            WidgetMensa(
                id: MensaVenue.mensaEhrenberg.rawValue, name: "Mensa Ehrenberg", kurzname: "Ehrenberg",
                heute: WidgetSpeiseplan(tag: "2026-10-29", gerichte: [gerichtVoll, gerichtKnapp])
            )
        ])
    }

    // MARK: Merkliste (die Liste aus `WatchMerkliste.dc.html`)

    static let merklisteStart = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Sieben Titel, einer davon gefunden: „3 im Regal · 1 gefunden“.
    static let merkliste: [UhrMerklisteEintrag] = [
        UhrMerklisteEintrag(id: "ilm-1", titel: "Regelungstechnik für Ingenieure", changedAt: merklisteStart),
        UhrMerklisteEintrag(id: "ilm-2", titel: "Grundlagen der Elektrotechnik 1", changedAt: merklisteStart),
        UhrMerklisteEintrag(id: "ilm-3", titel: "Mathematik für Ingenieure, Band 1", changedAt: merklisteStart),
        UhrMerklisteEintrag(id: "ilm-4", titel: "Technische Mechanik 1: Statik", changedAt: merklisteStart),
        UhrMerklisteEintrag(
            id: "ilm-5", titel: "Physik für Wissenschaftler und Ingenieure",
            foundAt: merklisteStart.addingTimeInterval(60), changedAt: merklisteStart.addingTimeInterval(60)
        ),
        UhrMerklisteEintrag(id: "ilm-7", titel: "Elektrische Maschinen", changedAt: merklisteStart),
        UhrMerklisteEintrag(id: "ilm-6", titel: "Werkstoffe", changedAt: merklisteStart)
    ]

    static let merklisteStaende: [String: UhrRegalStand] = [
        "ilm-1": .regal(standort: "60 ELT", signatur: "ELT ZQ 5200 R447(10)", nurVorOrt: false),
        "ilm-2": .ausgeliehen(bis: Date(timeIntervalSince1970: 1_794_916_800)),
        "ilm-3": .online,
        "ilm-4": .regal(standort: "70 MB", signatur: "MB UF 1000 G878(14)", nurVorOrt: true),
        "ilm-5": .regal(standort: "40 PHY", signatur: "PHY UC 100 T595(8)", nurVorOrt: false),
        "ilm-7": .regal(standort: "60 ELT", signatur: "ELT ZN 4000 F542(4)", nurVorOrt: false),
        "ilm-6": .unbekannt
    ]

    /// Alle sieben gefunden.
    static let merklisteAllesGefunden: [UhrMerklisteEintrag] = merkliste.enumerated().map { index, eintrag in
        var neu = eintrag
        neu.foundAt = merklisteStart.addingTimeInterval(Double(60 + index))
        neu.changedAt = merklisteStart.addingTimeInterval(Double(60 + index))
        return neu
    }

    @MainActor
    static func umgebung<Inhalt: View>(
        _ inhalt: Inhalt, snapshot: WidgetSnapshot, einstellungen: UhrEinstellungen = .vorgabe,
        andereMensa: AndereMensa? = nil, merkliste: [UhrMerklisteEintrag] = WatchVorschau.merkliste,
        iPhoneErreichbar: Bool = true
    ) -> some View {
        inhalt
            .environment(UhrDaten(vorschau: snapshot, andereMensa: andereMensa))
            .environment(UhrVerbindung(
                vorschau: einstellungen,
                merkliste: UhrMerkliste(vorschau: merkliste, staende: merklisteStaende),
                iPhoneErreichbar: iPhoneErreichbar
            ))
    }
}

// MARK: - Mensa (Tweak `zeit`, mit und ohne Filter)

private let vorschauFilter = UhrEinstellungen(filter: MensaWidgetVorschau.filterVeganOhneMilch)

#Preview("Mensa 08:15") {
    NavigationStack { WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("08:15")), snapshot: WatchVorschau.snapshot()) }
}
#Preview("Mensa 08:15 · Filter") {
    NavigationStack {
        WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("08:15")), snapshot: WatchVorschau.snapshot(), einstellungen: vorschauFilter)
    }
}
#Preview("Mensa 11:45") {
    NavigationStack { WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("11:45")), snapshot: WatchVorschau.snapshot()) }
}
#Preview("Mensa 11:45 · Filter") {
    NavigationStack {
        WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("11:45")), snapshot: WatchVorschau.snapshot(), einstellungen: vorschauFilter)
    }
}
// 14:20: Ehrenberg hat zu, die Nanoteria bis 15:00. Die Uhr bleibt bei Ehrenberg und zeigt die Hinweiskarte.
#Preview("Mensa 14:20 · Hinweiskarte") {
    NavigationStack { WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("14:20")), snapshot: WatchVorschau.snapshot()) }
}
#Preview("Mensa 14:20 · Hinweiskarte · Filter") {
    NavigationStack {
        WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("14:20")), snapshot: WatchVorschau.snapshot(), einstellungen: vorschauFilter)
    }
}
// Nach dem Tippen auf die Hinweiskarte: Nanoteria nur auf der Uhr, mit Notiz und Fußnote.
#Preview("Mensa 14:20 · Nanoteria gewählt") {
    NavigationStack {
        WatchVorschau.umgebung(
            WatchMensaView(jetzt: WatchVorschau.zeit("14:20")), snapshot: WatchVorschau.snapshot(),
            andereMensa: AndereMensa(mensa: .nanoteria, jetzt: WatchVorschau.zeit("14:20"))
        )
    }
}
#Preview("Mensa 14:20 · Nanoteria gewählt · Filter") {
    NavigationStack {
        WatchVorschau.umgebung(
            WatchMensaView(jetzt: WatchVorschau.zeit("14:20")), snapshot: WatchVorschau.snapshot(), einstellungen: vorschauFilter,
            andereMensa: AndereMensa(mensa: .nanoteria, jetzt: WatchVorschau.zeit("14:20"))
        )
    }
}
#Preview("Mensa 17:40 Abendessen") {
    NavigationStack { WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("17:40")), snapshot: WatchVorschau.snapshot()) }
}
#Preview("Mensa 17:40 · Filter") {
    NavigationStack {
        WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("17:40")), snapshot: WatchVorschau.snapshot(), einstellungen: vorschauFilter)
    }
}
#Preview("Mensa 21:30 Nacht") {
    NavigationStack { WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("21:30")), snapshot: WatchVorschau.snapshot()) }
}
#Preview("Mensa 21:30 · Filter") {
    NavigationStack {
        WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("21:30")), snapshot: WatchVorschau.snapshot(), einstellungen: vorschauFilter)
    }
}
#Preview("Mensa · nichts passt") {
    NavigationStack {
        WatchVorschau.umgebung(
            WatchMensaView(jetzt: WatchVorschau.zeit("11:45")), snapshot: WatchVorschau.snapshot(),
            einstellungen: UhrEinstellungen(filter: MensaWidgetVorschau.filterNichtsPasst)
        )
    }
}
#Preview("Mensa · große Schrift") {
    NavigationStack { WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("11:45")), snapshot: WatchVorschau.snapshot()) }
        .dynamicTypeSize(.xxxLarge)
}
#Preview("Mensa · ohne Daten") {
    NavigationStack { WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("11:45")), snapshot: WidgetSnapshot()) }
}
#Preview("Mensa · ohne Daten · große Schrift") {
    NavigationStack { WatchVorschau.umgebung(WatchMensaView(jetzt: WatchVorschau.zeit("11:45")), snapshot: WidgetSnapshot()) }
        .dynamicTypeSize(.xxxLarge)
}
#Preview("Andere Mensa") {
    NavigationStack { WatchVorschau.umgebung(WatchMensaWahlView(jetzt: WatchVorschau.zeit("14:20")), snapshot: WatchVorschau.snapshot()) }
}

// MARK: - Gericht

#Preview("Gericht · vollständig") {
    NavigationStack {
        WatchVorschau.umgebung(WatchGerichtView(id: "dal"), snapshot: WatchVorschau.gerichtSnapshot())
    }
}
#Preview("Gericht · knapp") {
    NavigationStack { WatchVorschau.umgebung(WatchGerichtView(id: "suppe"), snapshot: WatchVorschau.gerichtSnapshot()) }
}
#Preview("Gericht · große Schrift") {
    NavigationStack {
        WatchVorschau.umgebung(WatchGerichtView(id: "dal"), snapshot: WatchVorschau.gerichtSnapshot())
    }
    .dynamicTypeSize(.xxxLarge)
}

// MARK: - Heute Abend

#Preview("Heute Abend · läuft und fällt aus") {
    NavigationStack {
        WatchVorschau.umgebung(
            WatchEventsView(jetzt: AbendWidgetVorschau.zeit(19 + 40.0 / 60)),
            snapshot: eventsMitAbsage()
        )
    }
}
#Preview("Heute Abend · leer") {
    NavigationStack {
        WatchVorschau.umgebung(WatchEventsView(jetzt: AbendWidgetVorschau.zeit(19.5)), snapshot: WatchVorschau.snapshot(abend: .leer))
    }
}
#Preview("Heute Abend · ohne Daten") {
    NavigationStack { WatchVorschau.umgebung(WatchEventsView(jetzt: AbendWidgetVorschau.zeit(19.5)), snapshot: WidgetSnapshot()) }
}
#Preview("Heute Abend · große Schrift") {
    NavigationStack {
        WatchVorschau.umgebung(WatchEventsView(jetzt: AbendWidgetVorschau.zeit(19 + 40.0 / 60)), snapshot: eventsMitAbsage())
    }
    .dynamicTypeSize(.xxxLarge)
}
#Preview("Kurzinfo") {
    NavigationStack {
        WatchVorschau.umgebung(
            WatchEventInfoView(id: "spiel", vorschauBeschreibung: "Brettspiele, Kartenspiele und Snacks. Bring gern eigene Spiele mit, wir haben aber auch einen Schrank voll."),
            snapshot: WatchVorschau.snapshot()
        )
    }
}

/// 19:40: Spieleabend läuft, Kneipenquiz fällt aus, Open Stage ist gemerkt (wie `WatchEvents.dc.html`).
private func eventsMitAbsage() -> WidgetSnapshot {
    var snapshot = WatchVorschau.snapshot(abend: nil)
    func event(_ id: String, _ titel: String, _ von: Double, _ bis: Double, _ ort: String, abgesagt: Bool = false) -> WidgetEvent {
        WidgetEvent(
            id: id, titel: titel, beginn: AbendWidgetVorschau.zeit(von), ende: AbendWidgetVorschau.zeit(bis), ort: ort, abgesagt: abgesagt
        )
    }
    snapshot.events = [
        event("spiel", "Spieleabend", 19, 23, "Studi-Club"),
        event("quiz", "Kneipenquiz", 20, 23, "Baracke5", abgesagt: true),
        event("stage", "Open Stage", 21, 25, "BC-Club"),
        event("karaoke", "Karaoke-Nacht", 22, 26, "Baracke5")
    ]
    snapshot.gemerkteEventIDs = ["stage"]
    snapshot.stand = WatchVorschau.zeit("12:00")
    return snapshot
}

// MARK: - Merkliste (Tweak `zustand`: unterwegs, ohne iPhone, leer)

#Preview("Merkliste · unterwegs") {
    NavigationStack { WatchVorschau.umgebung(WatchMerklisteView(), snapshot: WatchVorschau.snapshot()) }
}
#Preview("Merkliste · ohne iPhone") {
    NavigationStack { WatchVorschau.umgebung(WatchMerklisteView(), snapshot: WatchVorschau.snapshot(), iPhoneErreichbar: false) }
}
#Preview("Merkliste · leer") {
    NavigationStack { WatchVorschau.umgebung(WatchMerklisteView(), snapshot: WatchVorschau.snapshot(), merkliste: []) }
}
#Preview("Merkliste · alles gefunden") {
    NavigationStack {
        WatchVorschau.umgebung(WatchMerklisteView(), snapshot: WatchVorschau.snapshot(), merkliste: WatchVorschau.merklisteAllesGefunden)
    }
}
#Preview("Merkliste · große Schrift") {
    NavigationStack { WatchVorschau.umgebung(WatchMerklisteView(), snapshot: WatchVorschau.snapshot()) }
        .dynamicTypeSize(.xxxLarge)
}
#Preview("Merkliste · ohne iPhone · große Schrift") {
    NavigationStack { WatchVorschau.umgebung(WatchMerklisteView(), snapshot: WatchVorschau.snapshot(), iPhoneErreichbar: false) }
        .dynamicTypeSize(.xxxLarge)
}

// Ohne die Titel im Regal: Die Chips „Ausgeliehen bis 17. Nov.“, „Online“ und „Standort unbekannt“ sind oben zu sehen.
#Preview("Merkliste · nicht im Regal") {
    NavigationStack {
        WatchVorschau.umgebung(
            WatchMerklisteView(), snapshot: WatchVorschau.snapshot(),
            merkliste: WatchVorschau.merkliste.filter { ["ilm-2", "ilm-3", "ilm-6"].contains($0.id) }
        )
    }
}

// MARK: - Start

#Preview("Start · Mittag") {
    WatchVorschau.umgebung(WatchStartView(jetzt: WatchVorschau.zeit("11:45")), snapshot: WatchVorschau.snapshot())
}
#Preview("Start · Abend") {
    WatchVorschau.umgebung(WatchStartView(jetzt: AbendWidgetVorschau.zeit(19 + 40.0 / 60)), snapshot: eventsMitAbsage())
}
#Preview("Start · ohne Daten") {
    WatchVorschau.umgebung(WatchStartView(jetzt: WatchVorschau.zeit("11:45")), snapshot: WidgetSnapshot())
}
#Preview("Start · schmale Uhr") {
    WatchVorschau.umgebung(WatchStartView(jetzt: AbendWidgetVorschau.zeit(19 + 40.0 / 60)), snapshot: eventsMitAbsage())
}
#Preview("Start · große Schrift") {
    WatchVorschau.umgebung(WatchStartView(jetzt: WatchVorschau.zeit("11:45")), snapshot: WatchVorschau.snapshot())
        .dynamicTypeSize(.xxxLarge)
}
#endif
