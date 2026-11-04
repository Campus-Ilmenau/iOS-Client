import SwiftUI

/// Segment-Control im Stil des Designs: Hintergrund `surfaceSecondary`, Ecken 10, die Auswahl liegt auf `surface`.
struct SegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: LocalizedStringKey)]

    @Namespace private var selectionNamespace

    init(selection: Binding<Value>, options: [(value: Value, title: LocalizedStringKey)]) {
        self._selection = selection
        self.options = options
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = option.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isSelected ? Color(.textPrimary) : Color(.textSecondary))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .padding(.horizontal, 4)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(.surface))
                                    .shadow(color: Color(.brandNight).opacity(0.12), radius: 1.5, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SegmentedControlPreview: View {
    @State private var range = 0

    var body: some View {
        VStack(spacing: 24) {
            SegmentedControl(selection: $range, options: [(0, "2 Wochen"), (1, "3 Monate")])
            SegmentedControl(selection: $range, options: [(0, "Studierende"), (1, "Bedienstete"), (2, "Gäste")])
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.background))
    }
}

#Preview("SegmentedControl – Light") {
    SegmentedControlPreview().preferredColorScheme(.light)
}

#Preview("SegmentedControl – Dark") {
    SegmentedControlPreview().preferredColorScheme(.dark)
}
