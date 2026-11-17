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

    /// Bild für die Auswahl (64 pt) aus den Icon-Dateien der Info.plist; `nil`, wenn die Datei nicht als Bild ladbar ist.
    static func vorschau(_ name: String?) -> UIImage? {
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let eintrag: [String: Any]?
        if let name {
            eintrag = (icons?["CFBundleAlternateIcons"] as? [String: Any])?[name] as? [String: Any]
        } else {
            eintrag = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        }
        guard let datei = (eintrag?["CFBundleIconFiles"] as? [String])?.last else { return nil }
        return UIImage(named: datei)
    }

    static func waehle(_ name: String?) async {
        try? await UIApplication.shared.setAlternateIconName(name)
    }
}
