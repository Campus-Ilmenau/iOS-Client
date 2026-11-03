import SwiftUI

/// Die fünf Tabs der App. „Mehr“ ist kein Tab, sondern der Personen-Button oben rechts auf „Heute“.
enum AppTab: CaseIterable, Identifiable {
    case heute
    case mensa
    case thoska
    case bibliothek
    case events

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .heute: "Heute"
        case .mensa: "Mensa"
        case .thoska: "Thoska"
        case .bibliothek: "Bibliothek"
        case .events: "Events"
        }
    }

    var systemImage: String {
        switch self {
        case .heute: "sun.max"
        case .mensa: "fork.knife"
        case .thoska: "wave.3.right"
        case .bibliothek: "book"
        case .events: "calendar"
        }
    }
}

/// Tab-Leiste im Stil des Designs: aktiver Tab in `accent`, sonst `textTertiary`,
/// Hintergrund `surface` leicht durchscheinend, oben eine Trennlinie.
struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 22))
                            .frame(height: 26)
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? Color(.accent) : Color(.textTertiary))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.top, 6)
        .background(alignment: .top) {
            Color(.surface)
                .opacity(0.9)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(.separator)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

private struct TabBarPreview: View {
    @State private var selection: AppTab = .heute

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Tab: \(String(describing: selection))")
                .foregroundStyle(Color(.textSecondary))
            Spacer()
            TabBar(selection: $selection)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.background))
    }
}

#Preview("TabBar – Light") {
    TabBarPreview().preferredColorScheme(.light)
}

#Preview("TabBar – Dark") {
    TabBarPreview().preferredColorScheme(.dark)
}
