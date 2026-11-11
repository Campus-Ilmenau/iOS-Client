import AppIntents

/// Die Mensa in einem Siri-Satz. Ein Satz darf nur `AppEnum`/`AppEntity` als Parameter haben, darum die vier
/// `MensaVenue` plus ein fünfter Wert „Cafeteria“ ohne Ort. Was er bedeutet, entscheidet der Intent.
/// Die Namen sind kurz und gut sprechbar, denn Siri liest die Auswahl vor („Cafeteria Ehrenberg, Nanoteria oder
/// Röntgenbau?“), auch auf dem HomePod.
/// Die Rohwerte werden gespeichert: nicht umbenennen, nicht umsortieren.
enum MensaOrt: String, AppEnum, CaseIterable {
    case mensaEhrenberg
    case cafeteriaEhrenberg
    case nanoteria
    case roentgenbau
    /// „Cafeteria“ ohne Ortsangabe.
    case cafeteria

    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: LocalizedStringResource("Mensa", table: "Siri")) }

    static var caseDisplayRepresentations: [MensaOrt: DisplayRepresentation] {
        [
            .mensaEhrenberg: DisplayRepresentation(title: LocalizedStringResource("Mensa Ehrenberg", table: "Siri"), synonyms: [LocalizedStringResource("Ehrenberg", table: "Siri")]),
            .cafeteriaEhrenberg: DisplayRepresentation(title: LocalizedStringResource("Cafeteria Ehrenberg", table: "Siri")),
            .nanoteria: DisplayRepresentation(title: LocalizedStringResource("Nanoteria", table: "Siri"), synonyms: [LocalizedStringResource("Cafeteria Nanoteria", table: "Siri")]),
            .roentgenbau: DisplayRepresentation(title: LocalizedStringResource("Röntgenbau", table: "Siri"), synonyms: [LocalizedStringResource("Cafeteria Röntgenbau", table: "Siri")]),
            .cafeteria: DisplayRepresentation(title: LocalizedStringResource("Cafeteria", table: "Siri"), synonyms: [LocalizedStringResource("Cafete", table: "Siri")]),
        ]
    }

    /// Die Mensa der App; `nil` bei „Cafeteria“ ohne Ort.
    var venue: MensaVenue? {
        switch self {
        case .mensaEhrenberg: .mensaEhrenberg
        case .cafeteriaEhrenberg: .cafeteriaEhrenberg
        case .nanoteria: .nanoteria
        case .roentgenbau: .roentgenbau
        case .cafeteria: nil
        }
    }

    init(_ venue: MensaVenue) {
        switch venue {
        case .mensaEhrenberg: self = .mensaEhrenberg
        case .cafeteriaEhrenberg: self = .cafeteriaEhrenberg
        case .nanoteria: self = .nanoteria
        case .roentgenbau: self = .roentgenbau
        }
    }
}
