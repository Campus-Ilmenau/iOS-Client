import SwiftUI

/// Neutraler Button der Uhr: 44 pt hoch, Kapsel, Text und Symbol in `onButtonSecondary`. Der Akzent ist für Titel,
/// Kicker und Symbole da, nie für Buttons.
struct WatchButton: View {
    private let titel: LocalizedStringKey
    private let systemImage: String?
    private let aktion: () -> Void

    init(_ titel: LocalizedStringKey, systemImage: String? = nil, aktion: @escaping () -> Void) {
        self.titel = titel
        self.systemImage = systemImage
        self.aktion = aktion
    }

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).accessibilityHidden(true)
                }
                Text(titel)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color(.onWatchButton))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color(.watchButton), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Button") {
    VStack(spacing: 6) {
        WatchButton("Andere Mensa", systemImage: "arrow.triangle.2.circlepath") {}
        WatchButton("Neu laden") {}
    }
    .padding(8)
    .containerBackground(Color(.watchBackground), for: .navigation)
}
