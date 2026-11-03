import SwiftUI

/// Vorschau aller Farb-Assets (Light und Dark) und der Markenschrift.
private struct DesignFoundationPreview: View {
    private struct Swatch: Identifiable {
        let name: String
        let color: Color
        var id: String { name }
    }

    private struct SwatchGroup: Identifiable {
        let title: String
        let swatches: [Swatch]
        var id: String { title }
    }

    private let groups: [SwatchGroup] = [
        SwatchGroup(title: "Flächen", swatches: [
            Swatch(name: "background", color: Color(.background)),
            Swatch(name: "surface", color: Color(.surface)),
            Swatch(name: "surfaceSecondary", color: Color(.surfaceSecondary)),
            Swatch(name: "separator", color: Color(.separator))
        ]),
        SwatchGroup(title: "Text", swatches: [
            Swatch(name: "textPrimary", color: Color(.textPrimary)),
            Swatch(name: "textSecondary", color: Color(.textSecondary)),
            Swatch(name: "textTertiary", color: Color(.textTertiary))
        ]),
        SwatchGroup(title: "Ilm-Orange", swatches: [
            Swatch(name: "accent", color: Color(.accent)),
            Swatch(name: "accentSoft", color: Color(.accentSoft))
        ]),
        SwatchGroup(title: "Grün & Blau", swatches: [
            Swatch(name: "green", color: Color(.green)),
            Swatch(name: "onGreen", color: Color(.onGreen)),
            Swatch(name: "greenSoft", color: Color(.greenSoft)),
            Swatch(name: "blue", color: Color(.blue)),
            Swatch(name: "onBlue", color: Color(.onBlue)),
            Swatch(name: "blueSoft", color: Color(.blueSoft))
        ]),
        SwatchGroup(title: "Buttons", swatches: [
            Swatch(name: "buttonPrimary", color: Color(.buttonPrimary)),
            Swatch(name: "onButtonPrimary", color: Color(.onButtonPrimary)),
            Swatch(name: "buttonSecondary", color: Color(.buttonSecondary)),
            Swatch(name: "onButtonSecondary", color: Color(.onButtonSecondary)),
            Swatch(name: "buttonDestructive", color: Color(.buttonDestructive)),
            Swatch(name: "onButtonDestructive", color: Color(.onButtonDestructive))
        ]),
        SwatchGroup(title: "Status", swatches: [
            Swatch(name: "warning", color: Color(.warning)),
            Swatch(name: "warningFill", color: Color(.warningFill)),
            Swatch(name: "onWarningFill", color: Color(.onWarningFill)),
            Swatch(name: "warningSoft", color: Color(.warningSoft)),
            Swatch(name: "danger", color: Color(.danger)),
            Swatch(name: "dangerSoft", color: Color(.dangerSoft))
        ]),
        SwatchGroup(title: "Marke", swatches: [
            Swatch(name: "brandOrange", color: Color(.brandOrange)),
            Swatch(name: "brandYellow", color: Color(.brandYellow)),
            Swatch(name: "brandNight", color: Color(.brandNight)),
            Swatch(name: "brandDusk", color: Color(.brandDusk))
        ])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mensa")
                        .display(size: 34, relativeTo: .largeTitle)
                    Text("12,48 €")
                        .display(size: 26, relativeTo: .title)
                    Text("Oberfläche in SF Pro mit Dynamic Type")
                        .font(.body)
                        .foregroundStyle(Color(.textSecondary))
                }

                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.headline)
                            .foregroundStyle(Color(.textPrimary))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                            ForEach(group.swatches) { swatch in
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(swatch.color)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.separator), lineWidth: 1)
                                        )
                                    Text(swatch.name)
                                        .font(.caption)
                                        .foregroundStyle(Color(.textPrimary))
                                    Spacer(minLength: 0)
                                }
                                .padding(8)
                                .background(Color(.surface), in: RoundedRectangle(cornerRadius: 12))
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

#Preview("Light") {
    DesignFoundationPreview()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DesignFoundationPreview()
        .preferredColorScheme(.dark)
}
