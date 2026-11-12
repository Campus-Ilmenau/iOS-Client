import Foundation

/// Was die Uhr unter „Mensa heute“ zeigt. Die Phasen kommen aus `MensaWidgetPhasen` und die Kicker aus der Siri-Karte
/// (`SiriMensa`), beides aus `Shared/`; hier wird nur für die Uhr zusammengesetzt. Siri und Widget zeigen höchstens
/// drei Gerichte, die Uhr fragt mit `maxZeilen: .max` nach allen.
struct UhrMensaAnzeige: Equatable {
    struct Gericht: Identifiable, Equatable {
        let id: String
        let name: String
        /// „2,90 €“, in der Preisgruppe vom iPhone.
        let preis: String
        let chips: [WidgetChip]
    }

    enum Zustand: Equatable {
        /// Weder Stand noch Laden: „Ich komme gerade nicht an den Speiseplan. …“
        case keineDaten
        /// Es gibt Daten, aber zu dieser Zeit keinen Plan (Text von Siri, z. B. „Für heute ist der Speiseplan noch nicht da.“).
        case hinweis(String)
        case plan
    }

    var zustand: Zustand
    /// Die gezeigte Mensa. Beim Abendessen kann das die Cafeteria sein, auch wenn die Mensa gewählt ist.
    var mensa: MensaVenue
    /// „Geöffnet bis 14:00“, „Abendessen · bis 19:30“, „Mittag morgen · ab 11:00“
    var kicker = ""
    /// Grüner Punkt: jetzt geöffnet.
    var offen = false
    /// „Ehrenberg hat seit 14:00 zu“
    var notiz: String?
    /// „Vegan · ohne Milch“; nur bei aktivem Filter.
    var filterzeile: String?
    var gerichte: [Gericht] = []
    /// Der Filter lässt nichts durch: „Nichts passt zu deinem Filter.“
    var leerText: String?
    /// „3 Gerichte ohne Filter“
    var leerFuss: String?
    var preisgruppe: MensaPriceGroup = .studierende
    /// Die Zeile auf der Startseite: „Ehrenberg · bis 14:00“.
    var startzeile = ""
    /// Die gewählte Mensa hat zu, eine andere hat noch Mittag: Hinweiskarte „Nanoteria hat noch bis 15:00 offen“.
    /// Die Uhr wechselt nie von selbst; Tippen wählt die andere Mensa wie „Andere Mensa“.
    var hinweis: Hinweis?
    /// Die gezeigte Mensa gilt nur auf der Uhr (bis Mitternacht), nicht die vom iPhone.
    var aufDerUhrGewaehlt = false

    struct Hinweis: Equatable {
        let mensa: MensaVenue
        /// „Nanoteria hat noch bis 15:00 offen“
        let text: String
    }

    var titel: String { mensa.shortName }
    var fussnote: String {
        aufDerUhrGewaehlt
            ? "\(mensa.shortName) nur auf der Uhr gewählt, bis Mitternacht. Danach wieder die Mensa vom iPhone."
            : "Preise für \(preisgruppe.title). Mensa, Preisgruppe und Filter kommen vom iPhone."
    }

    /// - Parameters:
    ///   - mensa: Die gewählte Mensa: die vom iPhone oder die „Andere Mensa“ von heute.
    ///   - aufDerUhrGewaehlt: `mensa` ist eine „Andere Mensa“ (nur Uhr, bis Mitternacht).
    static func erstelle(
        snapshot: WidgetSnapshot, mensa: MensaVenue, einstellungen: UhrEinstellungen, jetzt: Date, aufDerUhrGewaehlt: Bool = false
    ) -> UhrMensaAnzeige {
        typealias P = MensaWidgetPhasen
        var anzeige = UhrMensaAnzeige(
            zustand: .keineDaten, mensa: mensa, preisgruppe: einstellungen.preisgruppe, aufDerUhrGewaehlt: aufDerUhrGewaehlt
        )
        guard !snapshot.mensen.isEmpty else { return anzeige }

        let filter = einstellungen.filter.isActive ? einstellungen.filter : nil
        let siri = SiriMensa.heute(
            SiriMensaFrage(),
            snapshot: snapshot,
            einstellungen: SiriMensaEinstellungen(startseite: mensa, preisgruppe: einstellungen.preisgruppe, appFilter: einstellungen.filter),
            jetzt: jetzt,
            maxZeilen: .max
        )
        guard case .antwort(let antwort) = siri, let karte = antwort.karte else {
            var text = SiriMensa.keineDaten
            if case .antwort(let a) = siri { text = a.sagt }
            anzeige.zustand = .hinweis(text)
            anzeige.kicker = "Heute"
            anzeige.startzeile = "\(mensa.shortName) · Heute"
            return anzeige
        }

        var gezeigt = mensa
        if case .mensa(let id)? = DeepLink(url: karte.kopfLink), let id, let venue = MensaVenue(rawValue: id) { gezeigt = venue }

        let gerichte = karte.gerichte.map { Gericht(id: $0.id, name: $0.name, preis: $0.preis, chips: $0.chips) }

        let kicker = karte.kicker
        anzeige.zustand = .plan
        anzeige.mensa = gezeigt
        anzeige.hinweis = offeneAndere(snapshot: snapshot, gewaehlt: mensa, jetzt: jetzt)
        anzeige.kicker = kicker
        anzeige.offen = kicker.hasPrefix("Geöffnet") || (kicker.hasPrefix("Abendessen") && kicker.contains("bis"))
        anzeige.filterzeile = filter.map(\.activeDescription)
        anzeige.gerichte = gerichte

        // Ist eine andere Mensa noch offen, obwohl Ehrenberg schon zu hat, sagt es die Zeile unter dem Namen.
        if kicker.hasPrefix("Geöffnet bis"), gezeigt != .mensaEhrenberg, gezeigt != .cafeteriaEhrenberg,
           let ehrenberg = P.zeiten(.mensaEhrenberg, am: jetzt, in: snapshot), HeuteUhr.minuten(jetzt) >= ehrenberg.schliesst {
            anzeige.notiz = "Ehrenberg hat seit \(HeuteUhr.uhrzeit(minuten: ehrenberg.schliesst)) zu"
        }

        if gerichte.isEmpty {
            if filter != nil, karte.fuss.contains("ohne Filter") {
                anzeige.leerText = "Nichts passt zu deinem Filter."
                anzeige.leerFuss = karte.fuss
            } else {
                anzeige.leerText = "Keine Gerichte eingetragen."
            }
        }

        // „Geöffnet bis 14:00“ → „Ehrenberg · bis 14:00“, „Heute ab 11:00“ → „Ehrenberg · ab 11:00“, sonst der Kicker.
        if kicker.hasPrefix("Geöffnet ") {
            anzeige.startzeile = "\(gezeigt.shortName) · \(kicker.dropFirst("Geöffnet ".count))"
        } else if kicker.hasPrefix("Heute ") {
            anzeige.startzeile = "\(gezeigt.shortName) · \(kicker.dropFirst("Heute ".count))"
        } else {
            anzeige.startzeile = kicker
        }
        return anzeige
    }
}

extension UhrMensaAnzeige {
    /// Hat die gewählte Mensa für heute zu, während eine andere noch Mittag anbietet (z. B. 14:20: Ehrenberg zu,
    /// Nanoteria bis 15:00), ist es diese. Die Cafeteria Ehrenberg zählt nur mit Mittagsgerichten.
    static func offeneAndere(snapshot: WidgetSnapshot, gewaehlt: MensaVenue, jetzt: Date) -> Hinweis? {
        typealias P = MensaWidgetPhasen
        let minuten = HeuteUhr.minuten(jetzt)
        guard let eigene = P.zeiten(gewaehlt, am: jetzt, in: snapshot), minuten >= eigene.schliesst else { return nil }
        let heute = EventKalender.berlinDatum(jetzt)
        for venue in MensaVenue.allCases where venue != gewaehlt {
            guard let zeiten = P.zeiten(venue, am: jetzt, in: snapshot), minuten >= zeiten.oeffnet, minuten < zeiten.schliesst,
                  P.plan(venue, tag: heute, in: snapshot)?.gerichte.contains(where: { !$0.abendessen }) == true else { continue }
            return Hinweis(mensa: venue, text: "\(venue.shortName) hat noch bis \(HeuteUhr.uhrzeit(minuten: zeiten.schliesst)) offen")
        }
        return nil
    }
}

// MARK: - Mensen zur Auswahl

/// Eine Zeile der Liste „Andere Mensa“: Name und Öffnungsstatus von jetzt.
struct UhrMensaStatus: Identifiable, Equatable {
    let mensa: MensaVenue
    /// „Geöffnet bis 14:00“, „Öffnet um 11:00“, „Geschlossen“
    let status: String
    let offen: Bool
    var id: String { mensa.rawValue }

    static func alle(snapshot: WidgetSnapshot, jetzt: Date) -> [UhrMensaStatus] {
        let minuten = HeuteUhr.minuten(jetzt)
        return MensaVenue.allCases.map { mensa in
            guard let zeiten = MensaWidgetPhasen.zeiten(mensa, am: jetzt, in: snapshot) else {
                return UhrMensaStatus(mensa: mensa, status: "Heute geschlossen", offen: false)
            }
            if minuten < zeiten.oeffnet {
                return UhrMensaStatus(mensa: mensa, status: "Öffnet um \(HeuteUhr.uhrzeit(minuten: zeiten.oeffnet))", offen: false)
            }
            if minuten < zeiten.schliesst {
                return UhrMensaStatus(mensa: mensa, status: "Geöffnet bis \(HeuteUhr.uhrzeit(minuten: zeiten.schliesst))", offen: true)
            }
            return UhrMensaStatus(mensa: mensa, status: "Geschlossen", offen: false)
        }
    }
}
