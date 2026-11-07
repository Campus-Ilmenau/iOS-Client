import SwiftUI

/// Kurze Bestätigung: `buttonPrimary`-Hintergrund, Häkchen, Semibold.
/// Optional mit einer Aktion rechts („Widerrufen“, „Anzeigen“).
struct Toast: View {
    private let message: LocalizedStringKey
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    init(_ message: LocalizedStringKey, actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .bold))
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.bold))
                        .underline()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .foregroundStyle(Color(.onButtonPrimary))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.buttonPrimary), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color(.brandNight).opacity(0.3), radius: 15, x: 0, y: 12)
        .accessibilityElement(children: (actionTitle == nil || action == nil) ? .combine : .contain)
    }
}

private struct ToastTimerKey: Hashable {
    let isPresented: Bool
    let token: Int
}

private struct ToastModifier: ViewModifier {
    let message: LocalizedStringKey
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?
    @Binding var isPresented: Bool
    let duration: Duration
    /// Ändert sich der Wert, während der Toast steht (neue Meldung), beginnt die Anzeigedauer neu.
    let token: Int

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    Toast(message, actionTitle: actionTitle) {
                        action?()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented)
            .task(id: ToastTimerKey(isPresented: isPresented, token: token)) {
                guard isPresented else { return }
                try? await Task.sleep(for: duration)
                if !Task.isCancelled {
                    isPresented = false
                }
            }
    }
}

extension View {
    /// Blendet unten einen Toast ein und nach 2,4 s wieder aus.
    /// Auf den Inhalt oberhalb der TabBar anwenden, damit der Toast darüber schwebt.
    func toast(_ message: LocalizedStringKey, isPresented: Binding<Bool>, duration: Duration = .milliseconds(2400)) -> some View {
        modifier(ToastModifier(message: message, actionTitle: nil, action: nil, isPresented: isPresented, duration: duration, token: 0))
    }

    /// Wie `toast(_:isPresented:duration:)`, mit einer Aktion rechts. Die Aktion schließt den Toast nicht von selbst.
    func toast(
        _ message: LocalizedStringKey,
        actionTitle: LocalizedStringKey?,
        action: @escaping () -> Void,
        isPresented: Binding<Bool>,
        duration: Duration = .milliseconds(2400),
        token: Int = 0
    ) -> some View {
        modifier(ToastModifier(message: message, actionTitle: actionTitle, action: action, isPresented: isPresented, duration: duration, token: token))
    }
}

private struct ToastPreview: View {
    @State private var showsToast = false

    var body: some View {
        VStack(spacing: 24) {
            Toast("Im Kalender eingetragen")
                .padding(.horizontal, 16)

            SecondaryButton("Zum Kalender hinzufügen", systemImage: "calendar") {
                showsToast = true
            }
            .padding(.horizontal, 16)

            Text("Der Button blendet den Toast unten für 2,4 s ein.")
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.background))
        .toast("Im Kalender eingetragen", isPresented: $showsToast)
    }
}

#Preview("Toast – Light") {
    ToastPreview().preferredColorScheme(.light)
}

#Preview("Toast – Dark") {
    ToastPreview().preferredColorScheme(.dark)
}
