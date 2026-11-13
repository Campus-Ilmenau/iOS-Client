import Foundation

// Siri auf der Apple Watch, soweit es reine Rechnung ist: Einstellungen und Merkliste der Uhr in die Eingaben der
// Siri-Logik in `Shared/` (`SiriMensa`, `SiriOffen`, `SiriAbendessen`, `SiriAbend`, `SiriMerkliste`), die Zeilen der
// Ansicht und das Ziel von „In der App öffnen“. Die Sätze und Karten entstehen dort, nichts davon ist hier nachgebaut.
// Die Datei gehört zu iPhone-App (nur für die Tests) und Watch-App.

nonisolated enum UhrSiri {
    // MARK: Eingaben

    /// Die Einstellungen vom iPhone (Mensa, Preisgruppe, Filter) als Eingabe der Siri-Logik.
    static func mensaEinstellungen(_ uhr: UhrEinstellungen) -> SiriMensaEinstellungen {
        SiriMensaEinstellungen(startseite: uhr.mensa, preisgruppe: uhr.preisgruppe, appFilter: uhr.filter)
    }

    /// Die Merkliste aus der Watch-Gruppe samt dem letzten Stand im Regal, ohne neu zu laden.
    static func merklisteEintraege(_ eintraege: [UhrMerklisteEintrag], staende: [String: UhrRegalStand]) -> [SiriMerklisteEintrag] {
        eintraege.map { eintrag in
            let stand: SiriMerklisteStand = switch staende[eintrag.id] {
            case .regal(let standort, let signatur, _)?: .imRegal(standort: standort, signatur: signatur.isEmpty ? nil : signatur)
            case .ausgeliehen?: .ausgeliehen
            case .online?: .online
            case .unbekannt?, nil: .unbekannt
            }
            return SiriMerklisteEintrag(id: eintrag.id, titel: eintrag.titel, stand: stand, gefunden: eintrag.istGefunden)
        }
    }

    /// Die Antwort auf „Was steht auf meiner Merkliste?“ aus Liste und Stand im Regal.
    static func merklisteAntwort(eintraege: [UhrMerklisteEintrag], staende: [String: UhrRegalStand]) -> SiriMerklisteAntwort {
        SiriMerkliste.antwort(merklisteEintraege(eintraege, staende: staende))
    }

    /// Dasselbe aus dem Stand in der Watch-Gruppe, ohne zu laden (Liste und letzter Stand im Regal).
    static func merkliste(defaults: UserDefaults = AppGroup.defaults) -> SiriMerklisteAntwort {
        merklisteAntwort(eintraege: UhrSpeicher.merkliste(defaults: defaults), staende: UhrSpeicher.regalStaende(defaults: defaults))
    }

    // MARK: Welche Mensa die Ansicht zeigt

    /// Die Mensa, die die Mensa-Ansicht der Watch-App in diesem Moment zeigt: die gewählte (die „Andere Mensa“ von heute,
    /// sonst die vom iPhone), außer die Phasen schicken sie woandershin (Abendessen in der Cafeteria Ehrenberg). Dieselbe
    /// Rechnung wie `UhrMensaAnzeige`: die Antwort von `SiriMensa` auf die Frage ohne Ort.
    static func gezeigteMensa(
        snapshot: WidgetSnapshot, einstellungen: UhrEinstellungen, andere: AndereMensa?, jetzt: Date
    ) -> MensaVenue {
        let gewaehlt = andere?.mensa(jetzt: jetzt) ?? einstellungen.mensa
        let ergebnis = SiriMensa.heute(
            SiriMensaFrage(), snapshot: snapshot, einstellungen: mensaEinstellungen(UhrEinstellungen(
                mensa: gewaehlt, preisgruppe: einstellungen.preisgruppe, filter: einstellungen.filter
            )), jetzt: jetzt, maxZeilen: .max
        )
        guard case .antwort(let antwort) = ergebnis else { return gewaehlt }
        return mensa(antwort.karte) ?? gewaehlt
    }

    /// Die Mensa einer Karte, aus ihrem Link (`campusilmenau://mensa?mensa=<id>`).
    static func mensa(_ karte: SiriMensaKarte?) -> MensaVenue? {
        guard let karte, case .mensa(let id?)? = DeepLink(url: karte.kopfLink) else { return nil }
        return MensaVenue(rawValue: id)
    }

    // MARK: Ziel von „In der App öffnen“

    /// Mensa heute und Abendessen: der Speiseplan der Mensa, die die Antwort nennt. Zeigt die Watch-App diese Mensa ohnehin
    /// (`gezeigt`, siehe `gezeigteMensa`), bleibt es beim Speiseplan; sonst wählt sie die Uhr bis Mitternacht
    /// (`waehlen=1`), wie die Hinweiskarte.
    static func mensaZiel(_ karte: SiriMensaKarte?, gezeigt: MensaVenue) -> URL {
        guard let genannt = mensa(karte) else { return DeepLink.mensa(id: nil).url }
        return UhrMensaLink.mensa(genannt, waehlen: genannt != gezeigt)
    }

    /// Mensa offen?: Nennt die Antwort eine andere Mensa, als die Watch-App gerade zeigt, wird sie gewählt („Hat die Mensa
    /// offen?“ um 14:20: Ehrenberg hat zu, die Nanoteria noch offen). Hat die Startseiten-Mensa offen, ist es sie. Ohne offene
    /// Mensa bleibt es beim Speiseplan.
    /// - Parameter startseite: Die Mensa, auf die sich die Antwort ohne Ort bezieht (die vom iPhone).
    static func offenZiel(_ karte: SiriOffenKarte?, mensa: MensaOrt?, startseite: MensaVenue, gezeigt: MensaVenue) -> URL {
        guard let karte else { return DeepLink.mensaZeiten.url }
        let genannt: MensaVenue?
        if let venue = mensa?.venue {
            genannt = venue
        } else {
            var offene = karte.zeilen.filter(\.offen).compactMap { zeile in MensaVenue(rawValue: zeile.id) }
            // „Cafeteria“ meint nur die Cafeterien.
            if mensa == .cafeteria { offene = offene.filter(SiriMensa.cafeterien.contains) }
            genannt = offene.contains(startseite) && mensa == nil ? startseite : offene.first
        }
        guard let genannt else { return DeepLink.mensaZeiten.url }
        return UhrMensaLink.mensa(genannt, waehlen: genannt != gezeigt)
    }

    static func abendZiel(_ karte: SiriAbendKarte?) -> URL {
        karte?.kopfLink ?? DeepLink.eventsHeuteAbend.url
    }

    static var merklisteZiel: URL { DeepLink.merkliste.url }
}

// MARK: - Zeilen der Ansicht

/// Eine Zeile der Gerichte auf der Uhr: Kurzname (wie gesprochen) und Preis.
nonisolated struct UhrSiriGerichtZeile: Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    /// „2,90 €“; leer ohne Preis.
    let preis: String

    /// Höchstens so viele Zeilen, wie die Karte hat (die Kappung steckt schon in `SiriMensaKarte.gerichte`).
    static func zeilen(_ karte: SiriMensaKarte) -> [UhrSiriGerichtZeile] {
        karte.gerichte.map { UhrSiriGerichtZeile(id: $0.id, name: SiriSprache.kurz($0.name), preis: SiriSprache.preis($0.preis) ?? "") }
    }
}
