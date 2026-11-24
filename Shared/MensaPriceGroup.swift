import Foundation

/// Preisgruppe, deren Preis in der Liste und im Detail groß steht. Die Einstellung steht unter „Mehr“, Vorgabe ist
/// „Studierende“. Gespeichert wird sie in der App Group (`AppGroup.defaults`, Schlüssel `mensaPriceGroup`),
/// damit die Widgets dieselben Preise zeigen.
nonisolated enum MensaPriceGroup: String, CaseIterable, Identifiable {
    case studierende
    case bedienstete
    case gaeste

    static let storageKey = AppGroup.preisgruppeSchluessel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studierende: String(localized: "Studierende", table: "Shared")
        case .bedienstete: String(localized: "Bedienstete", table: "Shared")
        case .gaeste: String(localized: "Gäste", table: "Shared")
        }
    }
}
