import Foundation

/// Zeit- und Datumstexte der Veranstaltungen in der App-Sprache und in der Zeitzone Europe/Berlin.
/// `jetzt` ist einstellbar, damit sich „Heute“, „Morgen“ und „läuft gerade“ testen lassen.
struct EventZeitFormatter {
    var jetzt: Date = .now

    // MARK: - Liste

    /// Zeitzeile der Karte: „19:00–23:00 Uhr“, „Ab 20:00 Uhr“, „Ganztägig“ oder bei mehrtägigen
    /// „Läuft seit Mi 28. Okt. · bis So 1. Nov.“.
    ///
    /// - Parameter bezugstag: Der Tag, unter dem die Karte steht. Mehrtägige, die vorher begonnen haben, „laufen seit“.
    func zeitzeile(_ event: CampusEvent, bezugstag: Date? = nil) -> String {
        let tag = EventKalender.tagesbeginn(bezugstag ?? jetzt)

        if event.istMehrtaegig {
            let bis = Self.kurz(event.letzterTag)
            if event.ersterTag < tag {
                return String(localized: "Läuft seit \(Self.kurz(event.ersterTag)) · bis \(bis)")
            }
            if event.ganztaegig {
                return "\(Self.kurz(event.ersterTag)) – \(bis)"
            }
            return String(localized: "Ab \(Self.uhrzeit(event.beginn)) Uhr · bis \(bis)")
        }
        if event.ganztaegig { return String(localized: "Ganztägig") }
        if let ende = event.ende, ende > event.beginn {
            return String(localized: "\(Self.uhrzeit(event.beginn))–\(Self.uhrzeit(ende)) Uhr")
        }
        return String(localized: "Ab \(Self.uhrzeit(event.beginn)) Uhr")
    }

    /// Titel eines Tagesabschnitts: „Heute · Donnerstag“, „Morgen · Freitag“, sonst „Sonntag, 1. Nov.“.
    func abschnittstitel(fuer tag: Date) -> String {
        let tagesbeginn = EventKalender.tagesbeginn(tag)
        let heute = EventKalender.tagesbeginn(jetzt)
        let wochentag = Self.wochentag(tagesbeginn)
        if tagesbeginn == heute { return String(localized: "Heute · \(wochentag)") }
        if tagesbeginn == EventKalender.tag(heute, plus: 1) { return String(localized: "Morgen · \(wochentag)") }
        return "\(wochentag), \(Self.tagMonat(tagesbeginn))"
    }

    /// Titel eines Tagesabschnitts bei den vergangenen Veranstaltungen: „Gestern · Mittwoch“, sonst „Sonntag, 1. Nov.“.
    func vergangenerAbschnittstitel(fuer tag: Date) -> String {
        let tagesbeginn = EventKalender.tagesbeginn(tag)
        let gestern = EventKalender.tag(EventKalender.tagesbeginn(jetzt), plus: -1)
        guard tagesbeginn == gestern else { return abschnittstitel(fuer: tagesbeginn) }
        return String(localized: "Gestern · \(Self.wochentag(tagesbeginn))")
    }

    // MARK: - Detail

    /// Datum und Zeit im Detail, zwei Zeilen: „Freitag, 30. Oktober“ / „21:00 – 03:00 Uhr“. Ganztägig mehrtägig:
    /// „Mi 28. Okt. – So 1. Nov.“ / „Ganztägig · läuft gerade“.
    func datumUndZeit(_ event: CampusEvent) -> (datum: String, zeit: String) {
        if event.istMehrtaegig {
            let datum = "\(Self.kurz(event.ersterTag)) – \(Self.kurz(event.letzterTag))"
            if event.ganztaegig {
                return (datum, läuftGerade(event) ? String(localized: "Ganztägig · läuft gerade") : String(localized: "Ganztägig"))
            }
            let beginn = String(localized: "Ab \(Self.uhrzeit(event.beginn)) Uhr")
            if let ende = event.ende, ende > event.beginn {
                return (datum, String(localized: "\(beginn) · bis \(Self.uhrzeit(ende)) Uhr"))
            }
            return (datum, beginn)
        }

        let datum = EventKalender.lokal(event.beginn) { $0.weekday(.wide).day().month(.wide) }
        if event.ganztaegig { return (datum, String(localized: "Ganztägig")) }
        if let ende = event.ende, ende > event.beginn {
            return (datum, String(localized: "\(Self.uhrzeit(event.beginn)) – \(Self.uhrzeit(ende)) Uhr"))
        }
        return (datum, String(localized: "Ab \(Self.uhrzeit(event.beginn)) Uhr"))
    }

    private func läuftGerade(_ event: CampusEvent) -> Bool {
        guard let ende = event.ende else { return false }
        return event.beginn <= jetzt && jetzt < ende
    }

    // MARK: - Bausteine

    /// „19:00“.
    static func uhrzeit(_ datum: Date) -> String {
        EventKalender.lokal(datum) { $0.hour(.twoDigits(amPM: .abbreviated)).minute(.twoDigits) }
    }

    /// „Donnerstag“.
    static func wochentag(_ datum: Date) -> String {
        EventKalender.lokal(datum) { $0.weekday(.wide) }
    }

    /// „1. Nov.“.
    static func tagMonat(_ datum: Date) -> String {
        EventKalender.lokal(datum) { $0.day().month(.abbreviated) }
    }

    /// „Mi 28. Okt.“ (Wochentag ohne Punkt).
    static func kurz(_ datum: Date) -> String {
        let wochentag = EventKalender.lokal(datum) { $0.weekday(.abbreviated) }.replacingOccurrences(of: ".", with: "")
        return "\(wochentag) \(tagMonat(datum))"
    }
}
