import Foundation

/// Die vier Mensen, die als Seiten erscheinen. Sie sind fest und verschwinden nie, auch wenn sie keine Gerichte haben.
/// Die Zuordnung läuft über den Namen, den die Mensa-API liefert (`canteen.name`).
nonisolated enum MensaVenue: String, CaseIterable, Identifiable, Hashable {
    case mensaEhrenberg
    case cafeteriaEhrenberg
    case nanoteria
    case roentgenbau

    var id: String { rawValue }

    /// Name in der API.
    var apiName: String {
        switch self {
        case .mensaEhrenberg: "Mensa Ehrenberg"
        case .cafeteriaEhrenberg: "Cafeteria Mensa Ehrenberg"
        case .nanoteria: "Cafeteria NANOteria"
        case .roentgenbau: "Cafeteria Röntgenbau"
        }
    }

    /// Name auf der Seite und für VoiceOver.
    var displayName: String {
        switch self {
        case .mensaEhrenberg: "Mensa Ehrenberg"
        case .cafeteriaEhrenberg: "Cafeteria Ehrenberg"
        case .nanoteria: "Cafeteria Nanoteria"
        case .roentgenbau: "Cafeteria Röntgenbau"
        }
    }

    /// Kurzname in der Namensleiste.
    var shortName: String {
        switch self {
        case .mensaEhrenberg: "Ehrenberg"
        case .cafeteriaEhrenberg: "Cafeteria Ehrenberg"
        case .nanoteria: "Nanoteria"
        case .roentgenbau: "Röntgenbau"
        }
    }

    /// Nur die Cafeteria Ehrenberg bietet Mittag und Abendessen an.
    var hasMealtimes: Bool { self == .cafeteriaEhrenberg }

    func matches(canteenName: String) -> Bool {
        canteenName.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(apiName) == .orderedSame
    }
}

nonisolated enum MensaMealtime: Hashable {
    case lunch
    case dinner

    /// Das Gericht gehört zum Abendessen, wenn die Gruppe der API „Abendessen“ heißt.
    static func isDinner(_ meal: MensaMeal) -> Bool {
        meal.category.localizedCaseInsensitiveContains("abend")
    }
}
