import SwiftUI

/// Neutraler Schalter für Einstellungen: an = `buttonPrimary`, aus = `surfaceSecondary`. Kein Rot, kein Grün.
/// Der Schaltknopf bleibt auch im Dark Mode sichtbar (an: Farbe der Fläche, aus: Weiß).
/// Die ganze Zeile ist tippbar, VoiceOver liest sie als Schalter.
struct NeutralToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 8)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? Color(.buttonPrimary) : Color(.surfaceSecondary))
                    Circle()
                        .fill(configuration.isOn ? Color(.surface) : Color(.onBlue))
                        .shadow(color: Color(.brandNight).opacity(0.2), radius: 2, x: 0, y: 2)
                        .padding(2)
                }
                .frame(width: 51, height: 31)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Ein" : "Aus")
        .accessibilityAddTraits(.isToggle)
    }
}

private struct NeutralTogglePreview: View {
    @State private var first = true
    @State private var second = false

    var body: some View {
        Card {
            VStack(spacing: 0) {
                Toggle("Nur Bio", isOn: $first)
                    .frame(minHeight: 52)
                Rectangle().fill(Color(.separator)).frame(height: 1)
                Toggle("Ohne Gluten", isOn: $second)
                    .frame(minHeight: 52)
            }
        }
        .toggleStyle(NeutralToggleStyle())
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.background))
    }
}

#Preview("NeutralToggle – Light") {
    NeutralTogglePreview().preferredColorScheme(.light)
}

#Preview("NeutralToggle – Dark") {
    NeutralTogglePreview().preferredColorScheme(.dark)
}
