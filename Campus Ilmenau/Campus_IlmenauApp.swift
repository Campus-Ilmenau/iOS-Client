//
//  Campus_IlmenauApp.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 02.09.26.
//

import SwiftUI
import SwiftData

@main
struct Campus_IlmenauApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [ThoskaBalanceRecord.self, ThoskaCardName.self])
    }
}

private struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = true
    @State private var splashScale: CGFloat = 1
    @State private var goatOpacity: Double = 1
    @State private var backgroundFade: Double = 0
    @State private var hasStartedSplashAnimation = false

    var body: some View {
        ZStack {
            ContentView()

            if showSplash {
                SplashView(scale: splashScale, goatOpacity: goatOpacity, backgroundFade: backgroundFade)
            }
        }
        .onAppear {
            // onAppear statt .task: iOS wendet den Dark-Mode-Trait beim Kaltstart
            // teils verzögert an, was ein .task sonst abbricht und neu startet –
            // zwei überlappende Animationsläufe sorgten dann für Bildfehler.
            // DispatchQueue-Timer laufen unabhängig davon weiter, und der Guard
            // verhindert einen doppelten Start.
            guard !hasStartedSplashAnimation else { return }
            hasStartedSplashAnimation = true
            runSplashAnimation()
        }
    }

    private func runSplashAnimation() {
        guard !reduceMotion else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dissolveIntoAppBackground(duration: 0.25)
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeIn(duration: 0.55)) {
                splashScale = 24
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                dissolveIntoAppBackground(duration: 0.4)
            }
        }
    }

    // Überblendet erst zur echten (hell/dunkel-adaptiven) App-Hintergrundfarbe,
    // bevor das Splash-Overlay entfernt wird. So liegt beim Entfernen bereits
    // dieselbe Farbe wie im echten Content darunter – kein harter Sprung von
    // Orange auf Schwarz im Dark Mode.
    private func dissolveIntoAppBackground(duration: Double) {
        withAnimation(.easeOut(duration: duration)) {
            goatOpacity = 0
            backgroundFade = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            showSplash = false
        }
    }
}
