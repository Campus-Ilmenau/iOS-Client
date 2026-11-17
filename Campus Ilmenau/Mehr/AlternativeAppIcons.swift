import SwiftUI
import UIKit
import OSLog

/// Die Wahl des App-Icons: Automatisch (das Haupticon `AppIcon`, iOS wechselt Hell, Dunkel und Getönt selbst) oder ein festes
/// Icon über `setAlternateIconName`. Die Asset-Sets `AppIconHell` und `AppIconDunkel` stehen in
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` des App-Targets; Getönt geht in beiden weiter.
enum AppIconWahl: CaseIterable, Identifiable, Hashable {
    case automatisch
    case hell
    case dunkel

    var id: Self { self }

    /// Name des Asset-Sets; `nil` ist das Haupticon.
    var alternativName: String? {
        switch self {
        case .automatisch: nil
        case .hell: "AppIconHell"
        case .dunkel: "AppIconDunkel"
        }
    }

    init(alternativName: String?) {
        self = Self.allCases.first { $0.alternativName == alternativName } ?? .automatisch
    }

    var titel: LocalizedStringKey {
        switch self {
        case .automatisch: "Automatisch"
        case .hell: "Hell"
        case .dunkel: "Dunkel"
        }
    }

    /// Bild für die Auswahl (64 pt, 3×). „Automatisch“ zeigt das Icon, das iOS im gerade gültigen Stil nimmt.
    func vorschau(stil: ColorScheme) -> ImageResource {
        switch self {
        case .hell: .appIconVorschauHell
        case .dunkel: .appIconVorschauDunkel
        case .automatisch: stil == .dark ? .appIconVorschauDunkel : .appIconVorschauHell
        }
    }
}

/// Liest und setzt das App-Icon. Der Wert kommt immer aus `alternateIconName`; die App speichert nichts selbst.
@MainActor
enum AlternativeAppIcons {
    private static let protokoll = Logger(subsystem: "de.kai-gothe.Campus-Ilmenau", category: "AppIcon")

    static var istVerfuegbar: Bool { UIApplication.shared.supportsAlternateIcons }

    static var aktuell: AppIconWahl { AppIconWahl(alternativName: UIApplication.shared.alternateIconName) }

    /// Setzt das Icon; iOS zeigt danach selbst seinen Hinweis. Ein Fehler wird nur protokolliert, `false` heißt: Die Auswahl
    /// bleibt beim bisherigen Icon.
    @discardableResult
    static func waehle(_ wahl: AppIconWahl) async -> Bool {
        do {
            try await UIApplication.shared.setAlternateIconName(wahl.alternativName)
            return true
        } catch {
            protokoll.error("App-Icon \(wahl.alternativName ?? "Automatisch", privacy: .public) nicht gesetzt: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}

/// Das Icon zu einer Wahl, abgerundet wie auf dem Home-Bildschirm (nur zum Zeigen, für VoiceOver ausgeblendet).
struct AppIconBild: View {
    let wahl: AppIconWahl
    let groesse: CGFloat
    let radius: CGFloat

    @Environment(\.colorScheme) private var stil

    var body: some View {
        Image(wahl.vorschau(stil: stil))
            .resizable()
            .scaledToFill()
            .frame(width: groesse, height: groesse)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}
