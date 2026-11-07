import Foundation
import Observation

/// Zustand der Startseite „Heute“: lädt Mensa, Events und Hinweise unabhängig voneinander und liefert fertige
/// Anzeige-Werte je nach Tagesphase. Die Regeln folgen dem Script von `Heute.dc.html`.
///
/// - Fehlt ein Teil (Fehler, Zeitlimit), blendet er nur seinen Abschnitt aus; die Seite hängt nie.
/// - Die Uhr ist injizierbar (`now`), damit sich jede Phase testen und previewen lässt.
/// - Das Abendessen ist adaptiv: Abendessen-Orte sind alle Mensen, die heute Gerichte der Gruppe „Abendessen“ liefern.
///   Normal ist das die Cafeteria Ehrenberg, in der Prüfungszeit manchmal die Mensa Ehrenberg, selten zwei Orte zugleich.
@MainActor
@Observable
final class HeuteModel {
    /// Beginn des Abendessens in Minuten seit Mitternacht (16:30). Die API nennt keinen Beginn.
    static let abendessenBeginn = 16 * 60 + 30
    /// Ab dieser Uhrzeit (15:00) steht „Heute Abend“ vor „Als Nächstes“.
    static let eventsZuerstAb = 15 * 60
    static let maxTermine = 3
    static let maxHinweise = 2
    /// Spätestens nach so langer Zeit lädt die Seite beim Aktivwerden neu (10 Minuten).
    static let ladeIntervall: TimeInterval = 10 * 60

    // MARK: Zustand

    private(set) var mensa: MensaVenue
    private(set) var jetzt: Date

    private(set) var mensen: [Canteen]?
    private(set) var speiseplanHeute: [MensaMeal]?
    private(set) var speiseplanMorgen: [MensaMeal]?
    private(set) var eventsAbend: [CampusEvent]?
    private(set) var eventsMorgen: [CampusEvent]?
    private(set) var geladeneHinweise: [Hinweis] = []
    private(set) var ausgeblendeteHinweise: Set<String>
    /// Wird `true`, sobald der erste Ladevorgang durch ist (auch mit Fehlern). Davor zeigt die Seite Platzhalter.
    private(set) var istGeladen = false

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let mensaQuelle: any HeuteMensaDatenquelle
    @ObservationIgnored private let eventsQuelle: any EventsDatenquelle
    @ObservationIgnored private let hinweiseQuelle: any HinweiseQuelle
    @ObservationIgnored private let mensaSpeicher: HeuteMensaSpeicher
    @ObservationIgnored private let ausblendSpeicher: HinweiseAusblendSpeicher
    @ObservationIgnored private let preisgruppe: () -> MensaPriceGroup
    @ObservationIgnored private let zeitlimit: Duration
    @ObservationIgnored private var geladenAm: Date?
    @ObservationIgnored private var geladenePhase: Tagesphase?

    init(
        now: @escaping () -> Date = { .now },
        mensaQuelle: (any HeuteMensaDatenquelle)? = nil,
        eventsQuelle: (any EventsDatenquelle)? = nil,
        hinweiseQuelle: (any HinweiseQuelle)? = nil,
        mensaSpeicher: HeuteMensaSpeicher = HeuteMensaSpeicher(),
        ausblendSpeicher: HinweiseAusblendSpeicher = HinweiseAusblendSpeicher(),
        preisgruppe: @escaping () -> MensaPriceGroup = {
            UserDefaults.standard.string(forKey: MensaPriceGroup.storageKey).flatMap(MensaPriceGroup.init(rawValue:))
                ?? .studierende
        },
        zeitlimit: Duration = .seconds(8)
    ) {
        self.now = now
        self.mensaQuelle = mensaQuelle ?? MensaHeuteQuelle()
        self.eventsQuelle = eventsQuelle ?? EventsService()
        self.hinweiseQuelle = hinweiseQuelle ?? LeereHinweiseQuelle()
        self.mensaSpeicher = mensaSpeicher
        self.ausblendSpeicher = ausblendSpeicher
        self.preisgruppe = preisgruppe
        self.zeitlimit = zeitlimit
        self.mensa = mensaSpeicher.venue
        self.jetzt = now()
        self.ausgeblendeteHinweise = ausblendSpeicher.ids
    }

    // MARK: Aktionen

    /// Wählt die Mensa auf der Startseite und merkt sie sich.
    func waehleMensa(_ venue: MensaVenue) {
        mensa = venue
        mensaSpeicher.venue = venue
    }

    /// Liest die Mensa neu aus dem Speicher, falls „Mehr“ sie geändert hat. Der Speicher ist die einzige Quelle.
    func mensaNeuLesen() {
        let gespeichert = mensaSpeicher.venue
        if gespeichert != mensa { mensa = gespeichert }
    }

    /// Blendet einen Hinweis dauerhaft aus.
    func blendeHinweisAus(_ id: String) {
        ausgeblendeteHinweise.insert(id)
        ausblendSpeicher.ids = ausgeblendeteHinweise
    }

    /// Lädt alle Teile parallel und unabhängig. Jeder Teil erscheint, sobald er da ist. Scheitert ein Teil, bleibt
    /// sein alter Stand (am Anfang: nichts) und nur sein Abschnitt fehlt.
    func laden() async {
        jetzt = now()
        let heute = EventKalender.tagesbeginn(jetzt)
        let morgen = EventKalender.tag(heute, plus: 1)
        // Neuer Tag: Daten von gestern sind falsch, nicht nur alt.
        if let geladenAm, !HeuteUhr.istGleicherTag(geladenAm, jetzt) { zuruecksetzen() }
        geladenAm = jetzt
        geladenePhase = phase

        let mensaQuelle = mensaQuelle
        let eventsQuelle = eventsQuelle
        let hinweiseQuelle = hinweiseQuelle
        let limit = zeitlimit
        let zeit = jetzt

        await withTaskGroup(of: Void.self) { gruppe in
            gruppe.addTask { @MainActor in
                if let daten = await heuteMitZeitlimit(limit, { try await mensaQuelle.mensen() }) { self.mensen = daten }
            }
            gruppe.addTask { @MainActor in
                if let daten = await heuteMitZeitlimit(limit, { try await mensaQuelle.speiseplan(am: heute) }) {
                    self.speiseplanHeute = daten
                }
            }
            gruppe.addTask { @MainActor in
                if let daten = await heuteMitZeitlimit(limit, { try await mensaQuelle.speiseplan(am: morgen) }) {
                    self.speiseplanMorgen = daten
                }
            }
            gruppe.addTask { @MainActor in
                let filter = HeuteAbendModel.filter
                let seite = await heuteMitZeitlimit(limit) {
                    try await eventsQuelle.liste(filter: filter, seite: 1, jetzt: zeit)
                }
                if let seite { self.eventsAbend = seite.events.filter { $0.status != .abgesagt } }
            }
            gruppe.addTask { @MainActor in
                let filter = EventFilter(tag: morgen, abgesagteAusblenden: true)
                let seite = await heuteMitZeitlimit(limit) {
                    try await eventsQuelle.liste(filter: filter, seite: 1, jetzt: zeit)
                }
                if let seite { self.eventsMorgen = seite.events.filter { $0.status != .abgesagt } }
            }
            gruppe.addTask { @MainActor in
                if let daten = await heuteMitZeitlimit(limit, { try await hinweiseQuelle.hinweise(jetzt: zeit) }) {
                    self.geladeneHinweise = daten
                }
            }
        }
        jetzt = now()
        istGeladen = true
    }

    /// Stellt die Uhr nach und lädt neu, wenn der Tag oder die Tagesphase gewechselt hat oder die Daten älter als
    /// 10 Minuten sind.
    func aktualisieren() async {
        jetzt = now()
        guard let geladenAm else { return await laden() }
        if !HeuteUhr.istGleicherTag(geladenAm, jetzt)
            || phase != geladenePhase
            || jetzt.timeIntervalSince(geladenAm) > Self.ladeIntervall {
            await laden()
        }
    }

    /// Für `scenePhase == .active`.
    func szeneWurdeAktiv() async {
        await aktualisieren()
    }

    /// Hält die Seite aktuell: wacht zu jeder vollen Minute auf (die Uhrzeit im Kopf zeigt Minuten) und zu jedem
    /// früheren Wechsel (Phase, Begrüßung, Öffnen/Schließen, Eventbeginn und -ende), und stellt dann `jetzt` nach.
    /// Das ist ein Wecker pro Minute, kein Sekunden-Polling. Die Daten werden dabei nur bei Wechsel der Phase oder
    /// des Tages neu geladen (siehe `aktualisieren()`). Läuft, bis die Aufgabe abgebrochen wird.
    func beobachten() async {
        jetzt = now()
        while !Task.isCancelled {
            let ziel = min(naechsterWechsel, Self.naechsteMinute(nach: jetzt))
            do { try await Task.sleep(for: .seconds(max(0.5, ziel.timeIntervalSince(jetzt)))) } catch { return }
            let vorher = jetzt
            jetzt = now()
            if Tagesphase(vorher) != phase || !HeuteUhr.istGleicherTag(vorher, jetzt) {
                await aktualisieren()
            }
        }
    }

    /// Der Beginn der nächsten vollen Minute.
    static func naechsteMinute(nach datum: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (datum.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60 + 60)
    }

    private func zuruecksetzen() {
        mensen = nil
        speiseplanHeute = nil
        speiseplanMorgen = nil
        eventsAbend = nil
        eventsMorgen = nil
    }

    // MARK: Anzeige-Werte

    var phase: Tagesphase { Tagesphase(jetzt) }

    var begruessung: Begruessung { Begruessung(jetzt) }

    /// „Donnerstag, 29. Oktober · 11:45“
    var datumZeile: String {
        "\(EventKalender.format(jetzt, "EEEE, d. MMMM")) · \(HeuteUhr.uhrzeit(jetzt))"
    }

    /// Ab 15:00 und nicht nachts steht „Heute Abend“ vor „Als Nächstes“.
    var eventsZuerst: Bool {
        HeuteUhr.minuten(jetzt) >= Self.eventsZuerstAb && phase != .nacht
    }

    /// Höchstens 2, ohne ausgeblendete und abgelaufene, wichtigste zuerst.
    var hinweise: [Hinweis] {
        geladeneHinweise
            .filter { $0.gilt(am: jetzt) && !ausgeblendeteHinweise.contains($0.id) }
            .sorted { $0.prioritaet > $1.prioritaet }
            .prefix(Self.maxHinweise)
            .map { $0 }
    }

    /// Karte „Heute Abend“: Events von heute Abend, höchstens 3. Nachts ohne das Event, das schon in der Jetzt-Karte steht.
    var heuteAbend: [CampusEvent] {
        let inJetztKarte = phase == .nacht ? nachtEvent : nil
        return (eventsAbend ?? [])
            .filter { !$0.ganztaegig && ($0.ende.map { $0 > jetzt } ?? true) && $0.id != inJetztKarte?.id }
            .sorted { $0.beginn < $1.beginn }
            .prefix(HeuteAbendModel.maxEintraege)
            .map { $0 }
    }

    /// Die große Karte oben. `nil`, wenn ihre Daten fehlen: dann entfällt sie.
    var jetztKarte: HeuteJetztKarte? {
        switch phase {
        case .morgen:
            return mensaKarte(anzahl: 2, unterzeile: "Vorschau auf das Mittagsangebot")
        case .mittag:
            return mensaKarte(anzahl: 3, unterzeile: "Mittagsangebot")
        case .nachmittag, .abend:
            // Ohne Abendessen-Daten heute (z. B. Wochenende) bleibt die gewählte Mensa.
            return abendessenKarte() ?? mensaKarte(anzahl: 3, unterzeile: "Mittagsangebot")
        case .nacht:
            return eventKarte() ?? mittagMorgenKarte()
        }
    }

    /// „Als Nächstes“, höchstens 3 Einträge. Keine Live-Daten wie Guthaben oder Ausleihen.
    var alsNaechstes: [HeuteTermin] {
        let eintraege: [HeuteTermin?]
        switch phase {
        case .morgen, .mittag:
            eintraege = mensaTermine + [abendessenTermin, eventTermin(nurHeute: true)]
        case .nachmittag:
            eintraege = [abendessenTermin, eventTermin(nurHeute: true)]
        case .abend:
            eintraege = [eventTermin(nurHeute: true), mittagMorgenTermin]
        case .nacht:
            eintraege = [mittagMorgenTermin, eventTermin(nurHeute: false)]
        }
        return Array(eintraege.compactMap { $0 }.prefix(Self.maxTermine))
    }

    /// Nächster Zeitpunkt, an dem sich etwas an der Anzeige ändert.
    var naechsterWechsel: Date {
        var kandidaten = [Tagesphase.naechsterWechsel(nach: jetzt)]
        if let zeiten = oeffnung(mensa, am: jetzt) {
            kandidaten += [zeiten.opens, zeiten.closes].map { HeuteUhr.datum(am: jetzt, minuten: $0) }
        }
        for event in (eventsAbend ?? []) + (eventsMorgen ?? []) {
            kandidaten.append(event.beginn)
            if let ende = event.ende { kandidaten.append(ende) }
        }
        kandidaten.append(HeuteUhr.datum(am: jetzt, minuten: Self.abendessenBeginn))
        return kandidaten.filter { $0 > jetzt }.min() ?? EventKalender.tag(jetzt, plus: 1)
    }

    // MARK: Mensa-Wahl und Fehlerkarte

    struct MensaOption: Identifiable, Equatable {
        let venue: MensaVenue
        /// „11:00–14:00 Uhr“, bei Cafeteria Ehrenberg mit Abendessen; `nil`, solange Öffnungszeiten fehlen.
        let info: String?
        var id: MensaVenue { venue }
    }

    /// Die vier Mensen für das Auswahl-Sheet, mit den heutigen Öffnungszeiten aus der API.
    var mensaOptionen: [MensaOption] {
        MensaVenue.allCases.map { venue in
            var info: String?
            if mensen != nil {
                info = oeffnung(venue, am: jetzt).map { "\(HeuteUhr.uhrzeit(minuten: $0.opens))–\(HeuteUhr.uhrzeit(minuten: $0.closes)) Uhr" }
                    ?? "Heute geschlossen"
                if abendessenOrte?.contains(venue) == true, let text = info, text != "Heute geschlossen" {
                    info = "\(text) · Abendessen ab \(HeuteUhr.uhrzeit(minuten: Self.abendessenBeginn))"
                }
            }
            return MensaOption(venue: venue, info: info)
        }
    }

    /// Ersatz für die Jetzt-Karte, wenn nach dem Laden Daten fehlen.
    var fehlerKarte: HeuteJetztKarte {
        HeuteJetztKarte(
            ueberschrift: phase.ueberschrift,
            kicker: "",
            titel: mensa.displayName,
            unterzeile: "Speiseplan gerade nicht verfügbar",
            zeilen: [],
            linkText: "Zum Mensa-Tab",
            ziel: .speiseplan(mensa),
            mensaAendernSichtbar: phase != .nacht,
            stil: .mensa
        )
    }

    // MARK: Mensa

    /// Öffnungszeit der Mensa am Tag in Minuten; `nil` bei geschlossen oder ohne Angabe.
    private func oeffnung(_ venue: MensaVenue, am tag: Date) -> (opens: Int, closes: Int)? {
        guard let canteen = mensen?.first(where: { venue.matches(canteenName: $0.name) }) else { return nil }
        let schluessel = HeuteUhr.wochentagSchluessel(tag)
        guard let zeit = canteen.openingHours.first(where: { $0.weekday.lowercased() == schluessel }),
              let opens = HeuteUhr.minuten(aus: zeit.opensAt), let closes = HeuteUhr.minuten(aus: zeit.closesAt)
        else { return nil }
        return (opens, closes)
    }

    /// Mittagsgerichte der Mensa: alles, was nicht zur Gruppe „Abendessen“ gehört.
    private func mittagGerichte(_ venue: MensaVenue, in speiseplan: [MensaMeal]?) -> [MensaMeal] {
        (speiseplan ?? []).filter { venue.matches(canteenName: $0.canteenName) && !MensaMealtime.isDinner($0) }
    }

    private func zeile(_ gericht: MensaMeal) -> HeuteZeile {
        HeuteZeile(
            id: gericht.id,
            name: gericht.name,
            chips: gericht.listChips,
            rechts: gericht.price.formatted(for: preisgruppe())
        )
    }

    /// Jetzt-Karte der gewählten Mensa (morgens, mittags und als Rückfall am Nachmittag und Abend).
    private func mensaKarte(anzahl: Int, unterzeile: String) -> HeuteJetztKarte? {
        // Ohne Speiseplan oder Öffnungszeiten fehlt die Karte.
        guard speiseplanHeute != nil, mensen != nil else { return nil }
        let minuten = HeuteUhr.minuten(jetzt)
        let kicker: String
        if let zeiten = oeffnung(mensa, am: jetzt), minuten < zeiten.closes {
            kicker = minuten >= zeiten.opens
                ? "Jetzt geöffnet · bis \(HeuteUhr.uhrzeit(minuten: zeiten.closes))"
                : "Heute · ab \(HeuteUhr.uhrzeit(minuten: zeiten.opens))"
        } else {
            kicker = "Heute geschlossen"
        }
        return HeuteJetztKarte(
            ueberschrift: phase.ueberschrift,
            kicker: kicker,
            titel: mensa.displayName,
            unterzeile: unterzeile,
            zeilen: mittagGerichte(mensa, in: speiseplanHeute).prefix(anzahl).map(zeile),
            linkText: "Ganzer Speiseplan",
            ziel: .speiseplan(mensa),
            mensaAendernSichtbar: true,
            stil: .mensa
        )
    }

    // MARK: Abendessen

    /// Mensen, die heute Abendessen ausgeben, nach den Daten der API. Die Cafeteria Ehrenberg steht vorn, weil sie
    /// der Normalfall ist. `nil`, solange der Speiseplan fehlt.
    private var abendessenOrte: [MensaVenue]? {
        guard let speiseplan = speiseplanHeute else { return nil }
        let reihenfolge: [MensaVenue] = [.cafeteriaEhrenberg, .mensaEhrenberg, .nanoteria, .roentgenbau]
        return reihenfolge.filter { venue in
            speiseplan.contains { venue.matches(canteenName: $0.canteenName) && MensaMealtime.isDinner($0) }
        }
    }

    /// Der Ort, den die Seite zeigt: die gewählte Mensa, wenn sie Abendessen hat, dann ein Ort im selben Haus, sonst der erste.
    private var abendessenOrt: MensaVenue? {
        guard let orte = abendessenOrte, !orte.isEmpty else { return nil }
        return orte.first { $0 == mensa } ?? orte.first { gebaeudeName($0) == gebaeudeName(mensa) } ?? orte[0]
    }

    /// Die gewählte Mensa gibt Abendessen aus. Mensa und Cafeteria Ehrenberg zählen als ein Haus: Wer die Mensa
    /// Ehrenberg gewählt hat, bekommt das Abendessen der Cafeteria nicht als „Tipp“.
    private var eigeneMensaHatAbendessen: Bool {
        abendessenOrte?.contains { gebaeudeName($0) == gebaeudeName(mensa) } == true
    }

    /// „Mensa Ehrenberg“: Beide Ehrenberg-Orte heißen so, das Gebäude.
    private func gebaeudeName(_ venue: MensaVenue) -> String {
        switch venue {
        case .mensaEhrenberg, .cafeteriaEhrenberg: "Mensa Ehrenberg"
        default: venue.displayName
        }
    }

    /// „Cafeteria“ bzw. „Mensa“: wo im Gebäude.
    private func ortKurz(_ venue: MensaVenue) -> String {
        switch venue {
        case .cafeteriaEhrenberg: "Cafeteria"
        case .mensaEhrenberg: "Mensa"
        default: venue.shortName
        }
    }

    private func abendessenKarte() -> HeuteJetztKarte? {
        guard let ort = abendessenOrt, let speiseplan = speiseplanHeute else { return nil }
        let gerichte = speiseplan.filter { ort.matches(canteenName: $0.canteenName) && MensaMealtime.isDinner($0) }
        let eigeneMensaHatAbendessen = eigeneMensaHatAbendessen
        let kicker: String
        let titel: String
        let unterzeile: String

        switch phase {
        case .abend where eigeneMensaHatAbendessen:
            kicker = "Jetzt geöffnet · Abendessen"
            titel = gebaeudeName(ort)
            unterzeile = ortKurz(ort)
        case .abend:
            kicker = "\(mensa.displayName) hat geschlossen"
            titel = "Abendessen in der \(gebaeudeName(ort))"
            unterzeile = "Tipp · jetzt geöffnet"
        case _ where eigeneMensaHatAbendessen:
            kicker = "Heute ab \(HeuteUhr.uhrzeit(minuten: Self.abendessenBeginn))"
            titel = "Abendessen in der \(gebaeudeName(ort))"
            unterzeile = ortKurz(ort)
        default:
            kicker = "\(mensa.displayName) hat geschlossen"
            titel = "Abendessen in der \(gebaeudeName(ort))"
            unterzeile = "Tipp · ab \(HeuteUhr.uhrzeit(minuten: Self.abendessenBeginn)) in der \(ortKurz(ort))"
        }

        return HeuteJetztKarte(
            ueberschrift: phase.ueberschrift,
            kicker: kicker,
            titel: titel,
            unterzeile: unterzeile,
            zeilen: gerichte.prefix(3).map(zeile),
            linkText: "Zum Abendangebot",
            ziel: .speiseplan(ort),
            mensaAendernSichtbar: true,
            stil: .mensa
        )
    }

    private var abendessenTermin: HeuteTermin? {
        guard HeuteUhr.minuten(jetzt) < Self.abendessenBeginn, let ort = abendessenOrt else { return nil }
        return HeuteTermin(
            id: "abendessen",
            zeit: HeuteUhr.uhrzeit(minuten: Self.abendessenBeginn),
            farbe: .brandOrange,
            titel: "Abendessen",
            unterzeile: "\(gebaeudeName(ort)) · \(ortKurz(ort))",
            ziel: .speiseplan(ort)
        )
    }

    /// „Öffnet“ und „Schließt“ der gewählten Mensa, nur in der Zukunft.
    private var mensaTermine: [HeuteTermin?] {
        guard let zeiten = oeffnung(mensa, am: jetzt) else { return [] }
        let minuten = HeuteUhr.minuten(jetzt)
        var termine: [HeuteTermin?] = []
        if zeiten.opens > minuten {
            termine.append(HeuteTermin(
                id: "mensa-oeffnet", zeit: HeuteUhr.uhrzeit(minuten: zeiten.opens), farbe: .brandOrange,
                titel: "Öffnet", unterzeile: mensa.displayName, ziel: .speiseplan(mensa)
            ))
        }
        if zeiten.closes > minuten {
            termine.append(HeuteTermin(
                id: "mensa-schliesst", zeit: HeuteUhr.uhrzeit(minuten: zeiten.closes), farbe: .brandOrange,
                titel: "Schließt", unterzeile: mensa.displayName, ziel: .oeffnungszeiten(mensa)
            ))
        }
        return termine
    }

    // MARK: Morgen

    /// Mittag morgen in der gewählten Mensa; `nil` ohne Speiseplan für morgen.
    private var morgenGerichte: [MensaMeal] {
        mittagGerichte(mensa, in: speiseplanMorgen)
    }

    private var morgenTag: Date { EventKalender.tag(jetzt, plus: 1) }

    private func mittagMorgenKarte() -> HeuteJetztKarte? {
        let gerichte = morgenGerichte
        guard !gerichte.isEmpty else { return nil }
        let kicker = oeffnung(mensa, am: morgenTag)
            .map { "Morgen · ab \(HeuteUhr.uhrzeit(minuten: $0.opens))" } ?? "Morgen"
        return HeuteJetztKarte(
            ueberschrift: phase.ueberschrift,
            kicker: kicker,
            titel: mensa.displayName,
            unterzeile: "Mittagsangebot morgen",
            zeilen: gerichte.prefix(3).map(zeile),
            linkText: "Ganzer Speiseplan",
            ziel: .speiseplan(mensa),
            mensaAendernSichtbar: true,
            stil: .mensa
        )
    }

    private var mittagMorgenTermin: HeuteTermin? {
        guard let erstes = morgenGerichte.first else { return nil }
        let ab = oeffnung(mensa, am: morgenTag).map { "morgen ab \(HeuteUhr.uhrzeit(minuten: $0.opens))" } ?? "morgen"
        return HeuteTermin(
            id: "mittag-morgen",
            zeit: HeuteUhr.wochentagKurz(morgenTag),
            farbe: .brandOrange,
            titel: "Mittag: \(erstes.name)",
            unterzeile: "\(mensa.displayName) · \(ab)",
            ziel: .speiseplan(mensa)
        )
    }

    // MARK: Events

    /// Das Event, das gerade läuft: Beginn ≤ jetzt < Ende, ohne Ende bis Mitternacht. Abgesagte und ganztägige zählen nicht.
    private var laufendesEvent: CampusEvent? {
        let mitternacht = EventKalender.tag(jetzt, plus: 1)
        return (eventsAbend ?? [])
            .filter { !$0.ganztaegig && $0.status != .abgesagt }
            .sorted { $0.beginn < $1.beginn }
            .first { $0.beginn <= jetzt && jetzt < ($0.ende ?? mitternacht) }
    }

    /// Kommende Events von heute Abend und morgen, nach Beginn.
    private var kommendeEvents: [CampusEvent] {
        ((eventsAbend ?? []) + (eventsMorgen ?? []))
            .filter { !$0.ganztaegig && $0.status != .abgesagt && $0.beginn > jetzt }
            .sorted { $0.beginn < $1.beginn }
    }

    private func ortUndVeranstalter(_ event: CampusEvent) -> String {
        [event.ort, event.veranstalterAnzeigen]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Das Event der Jetzt-Karte in der Phase nacht: das laufende, sonst das nächste des Abends.
    private var nachtEvent: CampusEvent? {
        guard let abend = eventsAbend else { return nil }
        if let laufend = laufendesEvent { return laufend }
        return abend
            .filter { !$0.ganztaegig && $0.status != .abgesagt }
            .sorted { $0.beginn < $1.beginn }
            .first { $0.beginn > jetzt }
    }

    /// Nachts: das laufende Event, sonst das nächste des Abends. `nil`, wenn es keins gibt.
    private func eventKarte() -> HeuteJetztKarte? {
        guard let hauptEvent = nachtEvent else { return nil }
        let laeuft = laufendesEvent

        let kicker = laeuft != nil
            ? "Läuft gerade · seit \(HeuteUhr.uhrzeit(hauptEvent.beginn))"
            : "Heute · ab \(HeuteUhr.uhrzeit(hauptEvent.beginn))"
        let danach = kommendeEvents.first { $0.id != hauptEvent.id && $0.beginn > hauptEvent.beginn }
        let zeilen = danach.map { event in
            [HeuteZeile(
                id: event.id,
                name: "Danach: \(event.titel)",
                chips: [],
                rechts: HeuteUhr.istGleicherTag(event.beginn, jetzt)
                    ? HeuteUhr.uhrzeit(event.beginn)
                    : "\(HeuteUhr.wochentagKurz(event.beginn)) \(HeuteUhr.uhrzeit(event.beginn))"
            )]
        } ?? []

        return HeuteJetztKarte(
            ueberschrift: phase.ueberschrift,
            kicker: kicker,
            titel: hauptEvent.titel,
            unterzeile: ortUndVeranstalter(hauptEvent),
            zeilen: zeilen,
            linkText: "Alle Veranstaltungen",
            ziel: .alleEvents,
            mensaAendernSichtbar: false,
            stil: .event
        )
    }

    /// Das nächste Event als Termin. Heute: Uhrzeit; an einem anderen Tag: Wochentag, die Uhrzeit steht darunter.
    private func eventTermin(nurHeute: Bool) -> HeuteTermin? {
        let kandidaten = nurHeute ? kommendeEvents.filter { HeuteUhr.istGleicherTag($0.beginn, jetzt) } : kommendeEvents
        guard let event = kandidaten.first else { return nil }
        let heute = HeuteUhr.istGleicherTag(event.beginn, jetzt)
        let wer = event.veranstalterAnzeigen ?? event.ort ?? ""
        let unterzeile = heute ? wer : [wer, HeuteUhr.uhrzeit(event.beginn)].filter { !$0.isEmpty }.joined(separator: " · ")
        return HeuteTermin(
            id: "event-\(event.id)",
            zeit: heute ? HeuteUhr.uhrzeit(event.beginn) : HeuteUhr.wochentagKurz(event.beginn),
            farbe: .blue,
            titel: event.titel,
            unterzeile: unterzeile,
            ziel: .event(event)
        )
    }
}
