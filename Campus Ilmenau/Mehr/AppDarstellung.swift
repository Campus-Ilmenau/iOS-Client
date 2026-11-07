import SwiftUI

/// Darstellung der ganzen App: dem System folgen, immer hell oder immer dunkel.
/// Gespeichert unter `schluessel` (`@AppStorage`), angewendet in `Campus_IlmenauApp` mit `preferredColorScheme`.
enum AppDarstellung: String, CaseIterable, Identifiable {
    case system
    case hell
    case dunkel

    static let schluessel = "darstellung"

    var id: String { rawValue }

    /// `nil` heißt: dem System folgen.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .hell: .light
        case .dunkel: .dark
        }
    }

    var titel: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .hell: "Hell"
        case .dunkel: "Dunkel"
        }
    }
}
