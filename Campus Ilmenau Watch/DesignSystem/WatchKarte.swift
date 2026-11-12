import SwiftUI

/// Fläche für eine Gruppe von Inhalten: `surface` (Dark), Ecken 14, Innenabstand 9/11. Auf der Uhr gilt immer Dark;
/// die Farben kommen aus den Assets.
struct WatchKarte<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.watchSurface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview("Karte") {
    WatchKarte {
        VStack(alignment: .leading, spacing: 2) {
            Text("Mensa").font(.callout.weight(.semibold))
            Text("Ehrenberg · bis 14:00").font(.footnote).foregroundStyle(Color(.watchText2))
        }
    }
    .padding(8)
    .containerBackground(Color(.watchBackground), for: .navigation)
}
