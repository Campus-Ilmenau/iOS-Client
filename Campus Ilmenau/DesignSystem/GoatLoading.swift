import SwiftUI

/// Zeiten der Ladeanzeige (Übergabe, Abschnitt „Ladeanimation“).
struct LoadingTiming: Sendable {
    /// Erst danach erscheint die Ziege; schnelle Antworten zeigen gar nichts.
    var delay: Duration = .milliseconds(400)
    /// So lange bleibt die Ziege mindestens stehen, wenn sie einmal da war.
    var minimumVisible: Duration = .milliseconds(600)
    /// Ein- und Ausblenden der Deckkraft.
    var fade: Duration = .milliseconds(200)
    /// Ab hier kommt die zweite Zeile „Das dauert länger als sonst.“.
    var slowAfter: Duration = .seconds(8)

    static let standard = LoadingTiming()

    var fadeSeconds: Double {
        Double(fade.components.seconds) + Double(fade.components.attoseconds) / 1e18
    }
}

/// Zeitverhalten der Ziege beim ersten Laden. Die Ansicht meldet nur, ob geladen wird (`setLoading`);
/// der Gate sagt, ob der Ladebereich den Inhalt ersetzt (`isActive`), ob die Ziege sichtbar ist (`isVisible`)
/// und ob der Hinweis für langes Laden erscheint (`isSlow`).
///
/// Ablauf: 0 s Laden beginnt (`isActive`, noch unsichtbar) → 0,4 s einblenden → mindestens 0,6 s stehen lassen →
/// 0,2 s ausblenden → `isActive` endet und der Inhalt kommt. Ab 8 s `isSlow`.
/// Kommt die Antwort vor 0,4 s, wird die Ziege nie sichtbar und der Inhalt sofort gezeigt.
@MainActor
@Observable
final class LoadingGate {
    private(set) var isActive: Bool
    private(set) var isVisible = false
    private(set) var isSlow = false

    let timing: LoadingTiming

    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var isLoading = false
    /// Die Antwort kam, die Ziege steht aber noch ihre Mindestdauer.
    @ObservationIgnored private var finishPending = false
    @ObservationIgnored private var minimumElapsed = false
    /// Verzögerung und Hinweis, Mindestdauer und Ausblenden laufen als getrennte Timer.
    @ObservationIgnored private var loadingTask: Task<Void, Never>?
    @ObservationIgnored private var minimumTask: Task<Void, Never>?
    @ObservationIgnored private var fadeTask: Task<Void, Never>?

    /// `isLoading` legt nur den Anfangszustand fest, damit die Ansicht nicht kurz leeren Inhalt zeigt.
    /// Gestartet wird erst mit `setLoading(true)` (z. B. `onChange(of:initial:)`).
    /// Die Uhr ist austauschbar, damit Tests die Zeit selbst steuern können.
    init(isLoading: Bool = false, timing: LoadingTiming = .standard, clock: any Clock<Duration> = ContinuousClock()) {
        self.isActive = isLoading
        self.timing = timing
        self.clock = clock
    }

    func setLoading(_ loading: Bool) {
        if loading {
            guard !isLoading else { return }
            isLoading = true
            cancelAll()
            isActive = true
            isVisible = false
            isSlow = false
            finishPending = false
            minimumElapsed = false
            loadingTask = Task { await self.runLoading() }
        } else {
            guard isLoading else { return }
            isLoading = false
            loadingTask?.cancel()
            if !isVisible {
                // Die Ziege war nie zu sehen: der Inhalt kommt sofort.
                cancelAll()
                deactivate()
            } else if minimumElapsed {
                fadeOut()
            } else {
                // Der Mindestdauer-Timer läuft schon und blendet danach aus.
                finishPending = true
            }
        }
    }

    private func cancelAll() {
        loadingTask?.cancel()
        minimumTask?.cancel()
        fadeTask?.cancel()
    }

    /// Einblenden nach der Verzögerung; ab dann läuft die Mindestdauer, später kommt der Hinweis.
    private func runLoading() async {
        guard await pause(timing.delay) else { return }
        isVisible = true
        minimumTask = Task { await self.runMinimum() }
        guard await pause(timing.slowAfter - timing.delay) else { return }
        isSlow = true
    }

    private func runMinimum() async {
        guard await pause(timing.minimumVisible) else { return }
        minimumElapsed = true
        if finishPending { fadeOut() }
    }

    private func fadeOut() {
        finishPending = false
        isVisible = false
        fadeTask = Task {
            guard await self.pause(self.timing.fade) else { return }
            self.deactivate()
        }
    }

    private func deactivate() {
        isActive = false
        isVisible = false
        isSlow = false
    }

    /// `false`, wenn der Ablauf inzwischen durch einen neuen Zustand ersetzt wurde.
    private func pause(_ duration: Duration) async -> Bool {
        do {
            try await clock.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

/// Ladebereich für Ansichten ohne Daten: Ziege (96 pt) mittig im freien Bereich, darunter der Text.
/// Füllt den verfügbaren Platz; die Ansicht lässt Kopf, Leisten und Filter darüber stehen.
struct GoatLoadingBlock: View {
    let message: LocalizedStringKey
    let gate: LoadingGate

    var body: some View {
        VStack(spacing: 14) {
            GoatLoader(size: 96)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
            if gate.isSlow {
                Text("Das dauert länger als sonst.")
                    .font(.footnote)
                    .foregroundStyle(Color(.textTertiary))
                    .padding(.top, -8)
                    .transition(.opacity)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(gate.isVisible ? 1 : 0)
        .animation(.easeInOut(duration: gate.timing.fadeSeconds), value: gate.isVisible)
        .animation(.easeInOut(duration: gate.timing.fadeSeconds), value: gate.isSlow)
        // Ein Element: der Text darunter ist das Label, die Ziege selbst ist für VoiceOver unsichtbar.
        .accessibilityElement(children: .combine)
        .accessibilityHidden(!gate.isVisible)
    }
}

/// Nachladen am Listenende: kleine Ziege (28 pt) statt eines Ladekreises.
struct GoatLoadingFooter: View {
    /// Mindesthöhe, damit nichts springt, wenn sie einen Button (50 pt) ersetzt.
    var minHeight: CGFloat = 44

    var body: some View {
        GoatLoader(size: 28)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Lädt")
    }
}

// MARK: - Previews

/// Spielt eine künstlich verzögerte Antwort ab: 0,2 s (nichts zu sehen), 2 s (Ziege) und 10 s (mit Hinweis).
private struct GoatLoadingDemo: View {
    @State private var gate = LoadingGate()
    @State private var isLoading = false
    @State private var delay = 2.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach([0.2, 2, 10], id: \.self) { seconds in
                    Button("\(seconds.formatted()) s") {
                        delay = seconds
                        Task {
                            isLoading = true
                            try? await Task.sleep(for: .seconds(seconds))
                            isLoading = false
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            ZStack {
                if gate.isActive {
                    GoatLoadingBlock(message: "Speiseplan wird geladen …", gate: gate)
                } else {
                    Text("Daten da").foregroundStyle(Color(.textPrimary))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.background))
        .onChange(of: isLoading) { _, loading in gate.setLoading(loading) }
    }
}

#Preview("Ladezeit 0,2 / 2 / 10 s – Hell") {
    GoatLoadingDemo().preferredColorScheme(.light)
}

#Preview("Ladezeit – Dunkel") {
    GoatLoadingDemo().preferredColorScheme(.dark)
}

#Preview("Ladebereich, lang (Hinweis)") {
    struct Slow: View {
        @State private var gate = LoadingGate(isLoading: true, timing: .init(delay: .zero, slowAfter: .milliseconds(1)))
        var body: some View {
            GoatLoadingBlock(message: "Ausleihen werden geladen …", gate: gate)
                .background(Color(.background))
                .onAppear { gate.setLoading(true) }
        }
    }
    return Slow()
}
