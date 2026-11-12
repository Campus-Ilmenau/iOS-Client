import SwiftUI

/// Kapsel mit kurzer Aussage, 12 pt Semibold. Grün und Blau sind Flächen mit eigener Schriftfarbe (`onGreen`, `onBlue`).
struct Chip: View {
    enum Variant: CaseIterable {
        case green
        case blue
        case warning
        case accentSoft
        case dangerSoft
        case neutral

        fileprivate var background: Color {
            switch self {
            case .green: Color(.green)
            case .blue: Color(.blue)
            case .warning: Color(.warningFill)
            case .accentSoft: Color(.accentSoft)
            case .dangerSoft: Color(.dangerSoft)
            case .neutral: Color(.surfaceSecondary)
            }
        }

        fileprivate var foreground: Color {
            switch self {
            case .green: Color(.onGreen)
            case .blue: Color(.onBlue)
            case .warning: Color(.onWarningFill)
            case .accentSoft: Color(.accent)
            case .dangerSoft: Color(.danger)
            case .neutral: Color(.textSecondary)
            }
        }
    }

    private let title: LocalizedStringKey
    private let variant: Variant
    private let systemImage: String?

    init(_ title: LocalizedStringKey, variant: Variant = .neutral, systemImage: String? = nil) {
        self.title = title
        self.variant = variant
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.heavy))
                    .accessibilityHidden(true)
            }
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(variant.foreground)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(variant.background, in: Capsule())
    }
}

private struct ChipPreview: View {
    private let samples: [(LocalizedStringKey, Chip.Variant)] = [
        ("Vegan", .green),
        ("Regional", .blue),
        ("Nur noch wenige", .warning),
        ("Tagesangebot", .accentSoft),
        ("Geschlossen", .dangerSoft),
        ("Vegetarisch", .neutral)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                Chip(sample.0, variant: sample.1)
            }
            HStack(spacing: 6) {
                Chip("Vegan", variant: .green)
                Chip("Regional", variant: .blue)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.background))
    }
}

#Preview("Chip – Light") {
    ChipPreview().preferredColorScheme(.light)
}

#Preview("Chip – Dark") {
    ChipPreview().preferredColorScheme(.dark)
}
