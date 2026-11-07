import SwiftUI

/// Gemeinsame Gestalt der Buttons: Höhe 50, Ecken 12, Semibold 16.
/// `compact` ist die kleine Variante in Karten: 36 pt hoch, Ecken 10, Semibold 14, so breit wie der Titel.
/// Die Tippfläche bleibt dabei 44 pt hoch.
private struct DesignButton: View {
    let title: LocalizedStringKey
    let systemImage: String?
    /// Symbol hinter dem Titel, z. B. ↗ bei Links, die eine Seite im Browser öffnen.
    var trailingSystemImage: String?
    var isLoading = false
    var compact = false
    /// `.destructive` bei kritischen Aktionen, damit auch das System sie so behandelt.
    var role: ButtonRole?
    let background: Color
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.footnote.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .font(compact ? .subheadline.weight(.semibold) : .callout.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 14 : 0)
            .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 36 : 50)
            .background(background, in: RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous))
            .padding(.vertical, compact ? 4 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Dimmt den Button beim Drücken bzw. wenn er deaktiviert ist.
private struct PressableButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

/// Hauptbutton, neutral (`buttonPrimary`). Mit `isLoading` steht ein Ladekreis vor dem Titel.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var trailingSystemImage: String?
    var isLoading: Bool

    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        trailingSystemImage: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailingSystemImage = trailingSystemImage
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        DesignButton(
            title: title,
            systemImage: systemImage,
            trailingSystemImage: trailingSystemImage,
            isLoading: isLoading,
            background: Color(.buttonPrimary),
            foreground: Color(.onButtonPrimary),
            action: action
        )
    }
}

/// Nebenbutton, neutral (`buttonSecondary`). `compact` ist die kleine Variante für Karten (36 pt).
struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var trailingSystemImage: String?
    var compact: Bool
    var isLoading: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        trailingSystemImage: String? = nil,
        compact: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailingSystemImage = trailingSystemImage
        self.compact = compact
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        DesignButton(
            title: title,
            systemImage: systemImage,
            trailingSystemImage: trailingSystemImage,
            isLoading: isLoading,
            compact: compact,
            background: Color(.buttonSecondary),
            foreground: Color(.onButtonSecondary),
            action: action
        )
    }
}

/// Nur für kritische Aktionen (Abmelden, Löschen, Stornieren).
struct DestructiveButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        DesignButton(
            title: title,
            systemImage: systemImage,
            role: .destructive,
            background: Color(.buttonDestructive),
            foreground: Color(.onButtonDestructive),
            action: action
        )
    }
}

/// Zurückhaltende Variante für kritische Aktionen, die ohne Rückfrage ausgeführt werden (Abmelden): `dangerSoft`/`danger`.
struct SoftDestructiveButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        DesignButton(
            title: title,
            systemImage: systemImage,
            role: .destructive,
            background: Color(.dangerSoft),
            foreground: Color(.danger),
            action: action
        )
    }
}

private struct ButtonsPreview: View {
    var body: some View {
        VStack(spacing: 10) {
            PrimaryButton("Als Favorit merken") {}
            PrimaryButton("Thoska auslesen", systemImage: "wave.3.right") {}
            PrimaryButton("Anmelden") {}
                .disabled(true)

            SecondaryButton("Öffnungszeiten der Mensa") {}
            SecondaryButton("Zum Kalender hinzufügen", systemImage: "calendar") {}
            SecondaryButton("Abbrechen") {}
                .disabled(true)

            SecondaryButton("Verlängern", compact: true) {}
            DestructiveButton("Abmelden") {}
            SoftDestructiveButton("Abmelden") {}
            DestructiveButton("Löschen", systemImage: "trash") {}
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.background))
    }
}

#Preview("Buttons – Light") {
    ButtonsPreview().preferredColorScheme(.light)
}

#Preview("Buttons – Dark") {
    ButtonsPreview().preferredColorScheme(.dark)
}
