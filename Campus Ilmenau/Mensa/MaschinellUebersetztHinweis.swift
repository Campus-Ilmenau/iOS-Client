import SwiftUI

/// Dezenter Hinweis unter dem Titel eines Gerichts, dessen Text maschinell übersetzt wurde (`MensaMeal.translated`).
/// Er steht einmal je Gericht, nicht neben jedem Wort. Allergene kommen nie aus dem übersetzten Text, sondern aus den Kürzeln.
struct MaschinellUebersetztHinweis: View {
    var body: some View {
        Label {
            Text("Maschinell übersetzt")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(Color(.textSecondary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Maschinell übersetzt")
        .accessibilityHint("Der Titel wurde automatisch aus dem Deutschen übersetzt. Allergene und Zusatzstoffe stehen getrennt und stammen nicht aus dem Text.")
    }
}

#Preview("Hinweis – Light") {
    MaschinellUebersetztHinweis().padding().background(Color(.background)).preferredColorScheme(.light)
}

#Preview("Hinweis – Dark") {
    MaschinellUebersetztHinweis().padding().background(Color(.background)).preferredColorScheme(.dark)
}
