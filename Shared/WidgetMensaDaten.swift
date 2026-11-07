import Foundation

// Mensa-Daten für den `WidgetStore`: aus Gerichten und Öffnungszeiten der API werden die Speicher-Typen,
// und der Speicher wird gepflegt. Die App und das Widget „Mensa heute“ nutzen denselben Code.

extension MensaMeal {
    /// Die Chips für Liste und Widget: nur Vegan, Vegetarisch, Bio und Regional. Ein veganes Gericht zeigt nur „Vegan“.
    var widgetChips: [WidgetChip] {
        var items: [WidgetChip] = []
        let isVegan = badges.contains("Vegan")
        if isVegan { items.append(WidgetChip(titel: "Vegan", art: .gruen)) }
        if !isVegan, badges.contains("Vegetarisch") { items.append(WidgetChip(titel: "Vegetarisch", art: .neutral)) }
        if badges.contains("Bio") { items.append(WidgetChip(titel: "Bio", art: .gruen)) }
        if categories.contains(where: { $0.localizedCaseInsensitiveContains("regional") }) {
            items.append(WidgetChip(titel: "Regional", art: .blau))
        }
        return items
    }
}

/// Pflegt einen `WidgetSnapshot`: Öffnungszeiten, Speiseplan von heute und der nächste Öffnungstag je Mensa.
@MainActor
enum WidgetMensaPflege {
    /// Die Gerichte einer Mensa aus dem Speiseplan aller Mensen.
    static func gerichte(_ speiseplan: [MensaMeal], fuer venue: MensaVenue) -> [WidgetGericht] {
        speiseplan
            .filter { venue.matches(canteenName: $0.canteenName) }
            .map { meal in
                WidgetGericht(
                    id: meal.id,
                    name: meal.name,
                    gruppe: meal.category,
                    abendessen: MensaMealtime.isDinner(meal),
                    preisStudierende: meal.price.student,
                    preisBedienstete: meal.price.staff,
                    preisGaeste: meal.price.guest,
                    waehrung: meal.price.currency,
                    chips: meal.widgetChips
                )
            }
    }

    /// Öffnungszeiten aller Mensen, die in `mensen` vorkommen; die übrigen behalten ihren Stand.
    static func uebernehmeOeffnungszeiten(_ mensen: [Canteen], in snapshot: inout WidgetSnapshot) {
        for venue in MensaVenue.allCases {
            guard let canteen = mensen.first(where: { venue.matches(canteenName: $0.name) }) else { continue }
            var eintrag = eintrag(venue, in: snapshot)
            eintrag.oeffnungszeiten = canteen.openingHours.map {
                WidgetOeffnung(wochentag: $0.weekday.lowercased(), oeffnet: $0.opensAt, schliesst: $0.closesAt)
            }
            setze(eintrag, in: &snapshot)
        }
    }

    /// Der Speiseplan von heute für alle vier Mensen (auch leer: dann ist die Mensa heute zu).
    static func uebernehmeHeute(_ speiseplan: [MensaMeal], jetzt: Date, in snapshot: inout WidgetSnapshot) {
        let tag = EventKalender.berlinDatum(jetzt)
        for venue in MensaVenue.allCases {
            var eintrag = eintrag(venue, in: snapshot)
            eintrag.heute = WidgetSpeiseplan(tag: tag, gerichte: gerichte(speiseplan, fuer: venue))
            setze(eintrag, in: &snapshot)
        }
    }

    /// Ein Tag nach heute als möglicher nächster Öffnungstag. Eine Mensa ohne Gerichte an dem Tag bleibt unberührt.
    /// - Parameter verbuergt: Alle Tage zwischen heute und `tag` sind bekannt leer oder Wochenende. Nur dann darf
    ///   der Tag einen späteren ersetzen; sonst füllt er nur Lücken und frischt den gleichen Tag auf.
    static func uebernehmeNaechsten(
        _ speiseplan: [MensaMeal], tag: Date, jetzt: Date, verbuergt: Bool, in snapshot: inout WidgetSnapshot
    ) {
        let heute = EventKalender.berlinDatum(jetzt)
        let tagText = EventKalender.berlinDatum(tag)
        guard tagText > heute else { return }
        for venue in MensaVenue.allCases {
            let gerichte = gerichte(speiseplan, fuer: venue)
            guard !gerichte.isEmpty else { continue }
            var eintrag = eintrag(venue, in: snapshot)
            let vorhanden = eintrag.naechsterOeffnungstag?.tag
            let darf = vorhanden == nil || vorhanden! <= heute || vorhanden! == tagText || (verbuergt && tagText < vorhanden!)
            guard darf else { continue }
            eintrag.naechsterOeffnungstag = WidgetSpeiseplan(tag: tagText, gerichte: gerichte)
            setze(eintrag, in: &snapshot)
        }
    }

    /// Wirft einen „nächsten Öffnungstag“ weg, der heute oder früher liegt.
    static func raeumeAuf(jetzt: Date, in snapshot: inout WidgetSnapshot) {
        let heute = EventKalender.berlinDatum(jetzt)
        for index in snapshot.mensen.indices {
            if let tag = snapshot.mensen[index].naechsterOeffnungstag?.tag, tag <= heute {
                snapshot.mensen[index].naechsterOeffnungstag = nil
            }
        }
    }

    /// Liegen zwischen heute und `tag` nur Samstage und Sonntage? Dann ist `tag` der nächste mögliche Öffnungstag.
    static func nurWochenendeDazwischen(heute: Date, tag: Date) -> Bool {
        var zwischen = EventKalender.tag(heute, plus: 1)
        let ziel = EventKalender.tagesbeginn(tag)
        guard ziel > EventKalender.tagesbeginn(heute) else { return false }
        while zwischen < ziel {
            let wochentag = EventKalender.kalender.component(.weekday, from: zwischen)
            if wochentag != 1 && wochentag != 7 { return false }
            zwischen = EventKalender.tag(zwischen, plus: 1)
        }
        return true
    }

    // MARK: Hilfen

    private static func eintrag(_ venue: MensaVenue, in snapshot: WidgetSnapshot) -> WidgetMensa {
        snapshot.mensa(id: venue.rawValue)
            ?? WidgetMensa(id: venue.rawValue, name: venue.displayName, kurzname: venue.shortName)
    }

    /// Setzt den Eintrag und hält die Reihenfolge der App ein.
    private static func setze(_ eintrag: WidgetMensa, in snapshot: inout WidgetSnapshot) {
        if let index = snapshot.mensen.firstIndex(where: { $0.id == eintrag.id }) {
            snapshot.mensen[index] = eintrag
        } else {
            snapshot.mensen.append(eintrag)
        }
        let reihenfolge = MensaVenue.allCases.map(\.rawValue)
        snapshot.mensen.sort { (reihenfolge.firstIndex(of: $0.id) ?? 0) < (reihenfolge.firstIndex(of: $1.id) ?? 0) }
    }
}

/// Schreibt Mensa-Daten in den `WidgetStore`. Zwei Wege führen hierher: die App reicht aus, was sie gerade geladen hat
/// (`speichere`), und das Widget lädt selbst über die öffentliche Mensa-API (`ladeUndSpeichere`).
@MainActor
struct WidgetMensaAktualisierung {
    /// So viele Tage nach heute sucht man höchstens nach dem nächsten Speiseplan einer Mensa.
    static let maxSuchtage = 7

    let store: WidgetStore

    /// Schreibt, was bekannt ist (`nil` heißt „nicht geladen“ und lässt den Stand, wie er war), und sucht dann für
    /// Mensen ohne Plan am nächsten Tag weiter (Wochenende, Feiertag). Gibt zurück, ob sich der Speicher geändert hat.
    @discardableResult
    func speichere(
        mensen: [Canteen]?,
        heute: [MensaMeal]?,
        morgen: [MensaMeal]?,
        jetzt: Date,
        weitereTage: (Date) async throws -> [MensaMeal]
    ) async -> Bool {
        var geaendert = false
        let heuteTag = EventKalender.berlinDatum(jetzt)
        let morgenTag = EventKalender.tag(jetzt, plus: 1)

        if store.aendern({ snapshot in
            if let mensen { WidgetMensaPflege.uebernehmeOeffnungszeiten(mensen, in: &snapshot) }
            if let heute { WidgetMensaPflege.uebernehmeHeute(heute, jetzt: jetzt, in: &snapshot) }
            if let morgen {
                WidgetMensaPflege.uebernehmeNaechsten(morgen, tag: morgenTag, jetzt: jetzt, verbuergt: true, in: &snapshot)
            }
            WidgetMensaPflege.raeumeAuf(jetzt: jetzt, in: &snapshot)
        }) { geaendert = true }

        // Ohne Plan für „morgen“ weiß man nicht, ob es leer oder nur nicht geladen ist: dann keine Suche.
        guard morgen != nil else { return geaendert }

        var offset = 2
        while offset <= Self.maxSuchtage {
            let fehlend = MensaVenue.allCases.contains { venue in
                guard let tag = store.lesen().mensa(id: venue.rawValue)?.naechsterOeffnungstag?.tag else { return true }
                return tag <= heuteTag
            }
            guard fehlend else { break }
            let tag = EventKalender.tag(jetzt, plus: offset)
            offset += 1
            // Scheitert ein Tag, hört die Suche auf; die Mensen ohne Treffer behalten ihren alten Stand.
            guard let gerichte = try? await weitereTage(tag) else { break }
            if store.aendern({ snapshot in
                WidgetMensaPflege.uebernehmeNaechsten(gerichte, tag: tag, jetzt: jetzt, verbuergt: true, in: &snapshot)
            }) { geaendert = true }
        }
        return geaendert
    }

    /// Der Weg des Widgets: lädt Öffnungszeiten, heute und morgen selbst und schreibt sie. Die ganze Aktion hat ein
    /// Zeitlimit; klappt sie nicht (offline, Zeitablauf), bleibt der Speicher der App, wie er ist.
    @discardableResult
    func ladeUndSpeichere(quelle: any MensaDatenquelle, jetzt: Date, zeitlimit: Duration) async -> Bool {
        let morgen = EventKalender.tag(jetzt, plus: 1)
        let ergebnis = await heuteMitZeitlimit(zeitlimit) {
            async let mensen = try? quelle.mensen()
            async let heute = try? quelle.speiseplan(am: jetzt)
            async let naechster = try? quelle.speiseplan(am: morgen)
            let daten = await (mensen, heute, naechster)
            return await speichere(
                mensen: daten.0, heute: daten.1, morgen: daten.2, jetzt: jetzt,
                weitereTage: { try await quelle.speiseplan(am: $0) }
            )
        }
        return ergebnis ?? false
    }
}
