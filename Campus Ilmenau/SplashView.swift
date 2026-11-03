//
//  SplashView.swift
//  Campus Ilmenau
//

import SwiftUI

struct SplashView: View {
    var scale: CGFloat
    var goatOpacity: Double
    var backgroundFade: Double

    // Entspricht dem Farbverlauf des App-Icons, damit der Übergang vom
    // statischen System-Launch-Screen nahtlos wirkt.
    private let brandTop = Color(.brandOrange)
    private let brandBottom = Color(.brandYellow)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [brandTop, brandBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Blendet am Ende zur echten (hell/dunkel-adaptiven) App-Hintergrundfarbe
            // über, bevor das Overlay entfernt wird – sonst springt die Farbe im
            // Dark Mode hart von Orange auf Schwarz.
            Color(.background)
                .ignoresSafeArea()
                .opacity(backgroundFade)

            Image("LaunchGoat")
                .resizable()
                .scaledToFit()
                .frame(width: 220)
                .scaleEffect(scale)
                .opacity(goatOpacity)
        }
    }
}

#Preview {
    SplashView(scale: 1, goatOpacity: 1, backgroundFade: 0)
}
