//
//  SplashView.swift
//  Campus Ilmenau
//

import SwiftUI

struct SplashView: View {
    var scale: CGFloat
    var opacity: Double

    // Entspricht dem Farbverlauf des App-Icons, damit der Übergang vom
    // statischen System-Launch-Screen nahtlos wirkt.
    private let backgroundTop = Color(red: 0.98, green: 0.47, blue: 0.04)
    private let backgroundBottom = Color(red: 1.0, green: 0.73, blue: 0.0)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [backgroundTop, backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Image("LaunchGoat")
                .resizable()
                .scaledToFit()
                .frame(width: 220)
                .scaleEffect(scale)
        }
        .opacity(opacity)
    }
}

#Preview {
    SplashView(scale: 1, opacity: 1)
}
