import Foundation

/// Bausteine für die gesprochenen Sätze von Siri: Uhrzeiten, Orte, Zahlwörter und die Gerichteliste.
/// Der Satz muss allein reichen (AirPods, CarPlay), darum steht hier alles als fertiger Text.
/// Ohne SwiftUI, damit die Watch-App es später nutzen kann.
nonisolated enum SiriSprache {
    /// 660 → „11 Uhr“, 990 → „16:30 Uhr“.
    static func uhr(_ minuten: Int) -> String {
        minuten % 60 == 0 ? "\(minuten / 60) Uhr" : "\(minuten / 60):\(String(format: "%02d", minuten % 60)) Uhr"
    }

    /// „a“, „a und b“, „a, b und c“.
    static func aufzaehlung(_ teile: [String]) -> String {
        switch teile.count {
        case 0: ""
        case 1: teile[0]
        default: teile.dropLast().joined(separator: ", ") + " und " + teile[teile.count - 1]
        }
    }

    /// „zwei“ für Zahlen bis drei, sonst die Ziffer.
    static func zahl(_ n: Int) -> String {
        switch n {
        case 1: "ein"
        case 2: "zwei"
        case 3: "drei"
        default: String(n)
        }
    }

    /// Lange Namen werden für die Sprache bis zum ersten Komma oder „mit“ gekürzt:
    /// „Linsen-Dal mit Basmatireis“ → „Linsen-Dal“.
    static func kurz(_ name: String) -> String {
        var ende = name.endIndex
        for trenner in [",", " mit "] {
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
            if index == 0, let preis = preis(zeile.preis) { return "\(name) für \(preis)" }
            return name
        }
        return aufzaehlung(namen)
    }

    /// Nur die Namen, ohne Preis („Morgen Mittag in Ehrenberg: Linsen-Dal.“).
    static func namen(_ zeilen: [MensaWidgetAnzeige.Zeile]) -> String {
        aufzaehlung(zeilen.prefix(MensaWidgetPhasen.maxZeilen).map { kurz($0.name) })
    }

    /// Wie viele Gerichte oder wie viele Minuten, im Singular richtig: „1 Gericht“, „3 Gerichte“.
    static func gerichteAnzahl(_ n: Int) -> String {
        n == 1 ? "1 Gericht" : "\(n) Gerichte"
    }

    /// Satzanfang groß („die Nanoteria“ → „Die Nanoteria“).
    static func satzanfang(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    /// „Morgen“ oder der Wochentag („Montag“) für einen Berliner Tag, vom `jetzt` aus gesehen.
    static func tagwort(_ datum: Date, jetzt: Date) -> String {
        let morgen = EventKalender.tag(jetzt, plus: 1)
        return HeuteUhr.istGleicherTag(datum, morgen) ? "Morgen" : EventKalender.format(datum, "EEEE")
    }
}

extension MensaVenue {
    /// „in Ehrenberg“, „in der Cafeteria Ehrenberg“: der Ort im Satz. Er nennt immer den Namen, damit man eine
    /// falsche Wahl sofort hört.
    nonisolated var sprechOrt: String {
        switch self {
        case .mensaEhrenberg: "in Ehrenberg"
        case .cafeteriaEhrenberg: "in der Cafeteria Ehrenberg"
        case .nanoteria: "in der Nanoteria"
        case .roentgenbau: "in der Cafeteria Röntgenbau"
        }
    }

    /// „Ehrenberg“, „die Cafeteria Ehrenberg“: der Ort als Satzgegenstand („… hat seit 14 Uhr zu“).
    nonisolated var sprechSubjekt: String {
        switch self {
        case .mensaEhrenberg: "Ehrenberg"
        case .cafeteriaEhrenberg: "die Cafeteria Ehrenberg"
        case .nanoteria: "die Nanoteria"
        case .roentgenbau: "die Cafeteria Röntgenbau"
        }
    }

    /// Kurzform in einer Aufzählung der Cafeterien: „die Nanoteria, Röntgenbau und Ehrenberg“.
    nonisolated var sprechInGruppe: String {
        switch self {
        case .cafeteriaEhrenberg: "Ehrenberg"
        case .nanoteria: "die Nanoteria"
        default: shortName
        }
    }
}
