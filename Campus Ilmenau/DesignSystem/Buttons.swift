import SwiftUI

/// Gemeinsame Gestalt der drei Buttons: Höhe 50, Ecken 12, Semibold 16.
private struct DesignButton: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let background: Color
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

/// Hauptbutton, neutral (`buttonPrimary`).
struct PrimaryButton: View {
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
            background: Color(.buttonPrimary),
            foreground: Color(.onButtonPrimary),
            action: action
        )
    }
}

/// Nebenbutton, neutral (`buttonSecondary`).
struct SecondaryButton: View {
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
            background: Color(.buttonDestructive),
            foreground: Color(.onButtonDestructive),
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

            DestructiveButton("Abmelden") {}
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
