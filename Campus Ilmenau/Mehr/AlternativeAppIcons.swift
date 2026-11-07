import UIKit

/// Alternative App-Icons laut Info.plist (`CFBundleIcons › CFBundleAlternateIcons`). Hell, Dunkel und Getönt des
/// Haupticons wechselt das System selbst, das sind keine Alternativen. Ohne Alternativen zeigt „Mehr“ keine Zeile.
@MainActor
enum AlternativeAppIcons {
    /// Namen der Alternativen, sortiert.
    static var namen: [String] {
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let alternativen = icons?["CFBundleAlternateIcons"] as? [String: Any]
        return alternativen?.keys.sorted() ?? []
    }

    static var istVerfuegbar: Bool {
        UIApplication.shared.supportsAlternateIcons && !namen.isEmpty
    }

    /// `nil` ist das Haupticon.
    static var aktuell: String? { UIApplication.shared.alternateIconName }

    static func waehle(_ name: String?) async {
        try? await UIApplication.shared.setAlternateIconName(name)
    }
}
