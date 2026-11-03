import SwiftUI

/// Fläche für zusammengehörige Inhalte: `surface`, Ecken 16, Innenabstand 14/16.
/// Karten liegen flach, ohne Schatten.
struct Card<Content: View>: View {
    private let verticalPadding: CGFloat
    private let horizontalPadding: CGFloat
    private let content: Content

    init(
        verticalPadding: CGFloat = 14,
        horizontalPadding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CardPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Linsen-Dal mit Basmatireis")
                            .display(size: 26, relativeTo: .title)
                            .foregroundStyle(Color(.textPrimary))
                        Text("Rote Linsen, Kokosmilch, Tomate, frischer Koriander")
                            .foregroundStyle(Color(.textSecondary))
                    }
                }

                // Zeilenkarte mit engem vertikalem Innenabstand (Allergene, Infozeilen)
                Card(verticalPadding: 4) {
                    VStack(spacing: 0) {
                        ForEach(["Sellerie", "Senf", "Mit Antioxidationsmittel"], id: \.self) { name in
                            HStack {
                                Text(name)
                                Spacer()
                                Text("(i)").foregroundStyle(Color(.textTertiary))
                            }
                            .padding(.vertical, 11)
                            .foregroundStyle(Color(.textPrimary))
                            if name != "Mit Antioxidationsmittel" {
                                Rectangle().fill(Color(.separator)).frame(height: 1)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.background))
    }
}

#Preview("Card – Light") {
    CardPreview().preferredColorScheme(.light)
}

#Preview("Card – Dark") {
    CardPreview().preferredColorScheme(.dark)
}
