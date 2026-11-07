import Foundation

/// Phase des Tages. Sie bestimmt, was die Jetzt-Karte zeigt.
enum Tagesphase: String, CaseIterable, Sendable {
    /// bis 10:30
    case morgen
    /// 10:30–14:00
    case mittag
    /// 14:00–16:30
    case nachmittag
    /// 16:30–19:30
    case abend
    /// ab 19:30
    case nacht

    /// Minuten seit Mitternacht, ab denen die nächste Phase gilt.
    static let grenzen: [Int] = [10 * 60 + 30, 14 * 60, 16 * 60 + 30, 19 * 60 + 30]

    init(_ datum: Date) {
        switch HeuteUhr.minuten(datum) {
        case ..<Self.grenzen[0]: self = .morgen
        case ..<Self.grenzen[1]: self = .mittag
        case ..<Self.grenzen[2]: self = .nachmittag
        case ..<Self.grenzen[3]: self = .abend
        default: self = .nacht
        }
    }

    /// Überschrift der Jetzt-Karte.
    var ueberschrift: String {
        switch self {
        case .morgen: "Heute"
        case .mittag, .abend, .nacht: "Jetzt"
        case .nachmittag: "Gleich"
        }
    }

    /// Nächster Zeitpunkt, an dem sich Phase oder Begrüßung ändern: die Phasengrenzen, 11, 14 und 18 Uhr, Mitternacht.
    static func naechsterWechsel(nach datum: Date) -> Date {
        let festeZeiten = (grenzen + Begruessung.grenzen).sorted()
        let jetzt = HeuteUhr.minuten(datum)
        if let naechste = festeZeiten.first(where: { $0 > jetzt }) {
            return HeuteUhr.datum(am: datum, minuten: naechste)
        }
        return EventKalender.tag(datum, plus: 1)
    }
}

/// Begrüßung nach Uhrzeit: bis 11 Uhr „Guten Morgen“, bis 14 „Mahlzeit!“, bis 18 „Hallo!“, danach „Guten Abend“.
enum Begruessung: Equatable, Sendable {
    case gutenMorgen
    case mahlzeit
    case hallo
    case gutenAbend

    /// Minuten seit Mitternacht, ab denen die nächste Begrüßung gilt.
    static let grenzen: [Int] = [11 * 60, 14 * 60, 18 * 60]

    init(_ datum: Date) {
        switch HeuteUhr.minuten(datum) {
        case ..<Self.grenzen[0]: self = .gutenMorgen
        case ..<Self.grenzen[1]: self = .mahlzeit
        case ..<Self.grenzen[2]: self = .hallo
        default: self = .gutenAbend
        }
    }

    var text: String {
        switch self {
        case .gutenMorgen: "Guten Morgen"
        case .mahlzeit: "Mahlzeit!"
        case .hallo: "Hallo!"
        case .gutenAbend: "Guten Abend"
        }
    }
}
