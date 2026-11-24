import Foundation

/// Ein Satz oder Satzteil für Siri aus dem Katalog (Tabelle „Shared“, Schlüssel `siri.…`). Der Schlüssel steht im
/// Aufruf, die Werte in `Shared/Shared.xcstrings`; Platzhalter (`%@`, `%lld`) füllt die Interpolation, im Katalog
/// lässt sich mit `%2$@` umstellen, wenn die Wortfolge einer Sprache es braucht.
nonisolated func siriText(_ schluessel: String.LocalizationValue) -> String {
    LocalizedStringResource(schluessel, table: "Shared").inAppSprache
}

/// Bausteine für die gesprochenen Sätze von Siri: Uhrzeiten, Orte, Zahlwörter und die Gerichteliste.
/// Der Satz muss allein reichen (AirPods, CarPlay), darum steht hier alles als fertiger Text.
/// Ohne SwiftUI, damit die Watch-App es später nutzen kann.
nonisolated enum SiriSprache {
    /// Deutsch: 660 → „11 Uhr“, 990 → „16:30 Uhr“. Englisch: „11 am“, „4:30 pm“.
    static func uhr(_ minuten: Int) -> String {
        let stunde = minuten / 60
        let minute = minuten % 60
        let englisch = AppLanguage.current == .en
        let angezeigt = englisch ? (stunde % 12 == 0 ? 12 : stunde % 12) : stunde
        let zusatz = englisch ? (stunde % 24 < 12 ? "am" : "pm") : ""
        if minute == 0 { return siriText("siri.uhr.voll \(angezeigt) \(zusatz)") }
        return siriText("siri.uhr.minuten \(angezeigt) \(String(format: "%02d", minute)) \(zusatz)")
    }

    /// „a“, „a und b“, „a, b und c“ (englisch „a, b and c“).
    static func aufzaehlung(_ teile: [String]) -> String {
        switch teile.count {
        case 0: ""
        case 1: teile[0]
        default: teile.dropLast().joined(separator: ", ") + siriText("siri.und") + teile[teile.count - 1]
        }
    }

    /// „zwei“ für Zahlen bis drei, sonst die Ziffer.
    static func zahl(_ n: Int) -> String {
        switch n {
        case 1: siriText("siri.zahl.eins")
        case 2: siriText("siri.zahl.zwei")
        case 3: siriText("siri.zahl.drei")
        default: String(n)
        }
    }

    /// Lange Namen werden für die Sprache bis zum ersten Komma oder „mit“ („with“) gekürzt:
    /// „Linsen-Dal mit Basmatireis“ → „Linsen-Dal“.
    static func kurz(_ name: String) -> String {
        var ende = name.endIndex
        for trenner in [",", " mit ", " with "] {
            if let bereich = name.range(of: trenner), bereich.lowerBound < ende { ende = bereich.lowerBound }
        }
        let gekuerzt = name[..<ende].trimmingCharacters(in: .whitespaces)
        return gekuerzt.isEmpty ? name : gekuerzt
    }

    /// „2,90 €“ mit gewöhnlichem Leerzeichen; `nil` bei fehlendem Preis („–“).
    static func preis(_ text: String) -> String? {
        text == "–" ? nil : text.replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    /// „Linsen-Dal für 2,90 €, Hähnchenschnitzel und Pasta Arrabbiata“: höchstens 3 Gerichte, nur beim ersten der Preis.
    static func gerichte(_ zeilen: [MensaWidgetAnzeige.Zeile]) -> String {
        let namen = zeilen.prefix(MensaWidgetPhasen.maxZeilen).enumerated().map { index, zeile in
            let name = kurz(zeile.name)
            if index == 0, let preis = preis(zeile.preis) { return siriText("siri.gericht.fuerPreis \(name) \(preis)") }
            return name
        }
        return aufzaehlung(namen)
    }

    /// Nur die Namen, ohne Preis („Morgen Mittag in Ehrenberg: Linsen-Dal.“).
    static func namen(_ zeilen: [MensaWidgetAnzeige.Zeile]) -> String {
        aufzaehlung(zeilen.prefix(MensaWidgetPhasen.maxZeilen).map { kurz($0.name) })
    }

    /// Wie viele Gerichte, im Singular richtig: „1 Gericht“, „3 Gerichte“ („1 dish“, „3 dishes“).
    static func gerichteAnzahl(_ n: Int) -> String {
        siriText("siri.gerichteAnzahl \(n)")
    }

    /// Satzanfang groß („die Nanoteria“ → „Die Nanoteria“).
    static func satzanfang(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    /// „Morgen“ oder der Wochentag („Montag“) für einen Berliner Tag, vom `jetzt` aus gesehen.
    static func tagwort(_ datum: Date, jetzt: Date) -> String {
        let morgen = EventKalender.tag(jetzt, plus: 1)
        return HeuteUhr.istGleicherTag(datum, morgen) ? siriText("siri.tag.morgen") : EventKalender.lokal(datum) { $0.weekday(.wide) }
    }

    /// Ist `wort` das, was `tagwort` für morgen liefert?
    static func istMorgen(_ datum: Date, jetzt: Date) -> Bool {
        HeuteUhr.istGleicherTag(datum, EventKalender.tag(jetzt, plus: 1))
    }
}

extension MensaVenue {
    /// „in Ehrenberg“, „in der Cafeteria Ehrenberg“: der Ort im Satz. Er nennt immer den Namen, damit man eine
    /// falsche Wahl sofort hört. Englisch: „at Ehrenberg“.
    nonisolated var sprechOrt: String {
        switch self {
        case .mensaEhrenberg: siriText("siri.ort.in.mensaEhrenberg")
        case .cafeteriaEhrenberg: siriText("siri.ort.in.cafeteriaEhrenberg")
        case .nanoteria: siriText("siri.ort.in.nanoteria")
        case .roentgenbau: siriText("siri.ort.in.roentgenbau")
        }
    }

    /// „Ehrenberg“, „die Cafeteria Ehrenberg“: der Ort als Satzgegenstand („… hat seit 14 Uhr zu“).
    nonisolated var sprechSubjekt: String {
        switch self {
        case .mensaEhrenberg: siriText("siri.ort.subjekt.mensaEhrenberg")
        case .cafeteriaEhrenberg: siriText("siri.ort.subjekt.cafeteriaEhrenberg")
        case .nanoteria: siriText("siri.ort.subjekt.nanoteria")
        case .roentgenbau: siriText("siri.ort.subjekt.roentgenbau")
        }
    }

    /// Kurzform in einer Aufzählung der Cafeterien: „die Nanoteria, Röntgenbau und Ehrenberg“.
    nonisolated var sprechInGruppe: String {
        switch self {
        case .cafeteriaEhrenberg: siriText("siri.ort.gruppe.cafeteriaEhrenberg")
        case .nanoteria: siriText("siri.ort.gruppe.nanoteria")
        default: shortName
        }
    }
}
