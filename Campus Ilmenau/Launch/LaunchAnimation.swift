import SwiftUI

extension View {
    /// Legt die Start-Animation „Durch die Ziege“ über die Ansicht.
    /// Der Binding steht beim Start auf `true`; am Ende der Animation setzt ihn das Modifier auf `false`
    /// und entfernt die Wand komplett. Wieder auf `true` gesetzt, läuft die Animation erneut.
    func launchAnimation(isPresented: Binding<Bool>) -> some View {
        modifier(LaunchAnimationModifier(isPresented: isPresented))
    }
}

/// Skaliert die Startansicht von 1,08 auf 1,0, solange die Wand wegfliegt.
private struct LaunchContentEffect: ViewModifier, Animatable {
    var progress: Double
    var isActive: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.scaleEffect(isActive ? LaunchTimeline.contentScale(at: progress) : 1)
    }
}

private struct LaunchAnimationModifier: ViewModifier {
    @Binding var isPresented: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0
    @State private var wallOpacity: Double = 1
    @State private var isRunning = false

    func body(content: Content) -> some View {
        content
            .modifier(LaunchContentEffect(progress: progress, isActive: isPresented && !reduceMotion))
            .overlay {
                if isPresented {
                    LaunchWall(progress: progress)
                        .opacity(wallOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            // onAppear statt .task: iOS wendet den Dark-Mode-Trait beim Kaltstart teils verzögert an.
            // Ein .task würde dabei abgebrochen und neu gestartet, der Guard verhindert doppelte Läufe.
            .onAppear { startIfNeeded() }
            .onChange(of: isPresented) { _, newValue in
                if newValue { startIfNeeded() }
            }
    }

    private func startIfNeeded() {
        guard isPresented, !isRunning else { return }
        isRunning = true

        // Erster Lauf: progress steht schon auf 0 und der erste Frame ist gezeichnet.
        // Wiederholung: erst zurücksetzen und einen Frame zeichnen lassen, dann abspielen.
        if progress == 0 && wallOpacity == 1 {
            play()
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                progress = 0
                wallOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { play() }
        }
    }

    private func play() {
        if reduceMotion {
            // Bewegung reduzieren: erster Frame, dann kurz überblenden.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.25)) {
                    wallOpacity = 0
                } completion: {
                    finish()
                }
            }
        } else {
            withAnimation(.linear(duration: LaunchTimeline.duration)) {
                progress = 1
            } completion: {
                finish()
            }
        }
    }

    /// Wand vollständig entfernen, damit nichts die Bedienung blockiert.
    private func finish() {
        isPresented = false
        isRunning = false
    }
}

// MARK: - Previews

/// Startansicht mit Wiederholen-Taste (Debug) und Zeitregler.
private struct LaunchAnimationPreview: View {
    @State private var isPresented = true
    @State private var scrubbing = false
    @State private var scrubProgress: Double = 0.5

    var body: some View {
        ZStack {
            if scrubbing {
                ContentView()
                    .modifier(LaunchContentEffect(progress: scrubProgress, isActive: true))
                    .overlay {
                        LaunchWall(progress: scrubProgress)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
            } else {
                ContentView()
                    .launchAnimation(isPresented: $isPresented)
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if scrubbing {
                    Slider(value: $scrubProgress, in: 0...1)
                }
                HStack {
                    Button("Wiederholen") {
                        scrubbing = false
                        isPresented = true
                    }
                    Button(scrubbing ? "Abspielen" : "Zeitregler") {
                        scrubbing.toggle()
                        if !scrubbing { isPresented = true }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }
}

#Preview("Start – Light") {
    LaunchAnimationPreview().preferredColorScheme(.light)
}

#Preview("Start – Dark") {
    LaunchAnimationPreview().preferredColorScheme(.dark)
}
