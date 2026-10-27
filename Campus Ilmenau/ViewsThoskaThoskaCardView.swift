//
//  ThoskaCardView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI
import CoreMotion

/// Visuelle Nachbildung der physischen Thoska-Karte der TU Ilmenau.
struct ThoskaCardView: View {
    let balance: ThoskaBalance?

    @StateObject private var tilt = DeviceTiltObserver()

    var body: some View {
        HStack(spacing: 0) {
            sideStripe
            mainContent
        }
        .frame(width: 300, height: 189)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 10)
        .rotation3DEffect(.degrees(tilt.pitchDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(tilt.rollDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .animation(.easeOut(duration: 0.15), value: tilt.rollDegrees)
        .animation(.easeOut(duration: 0.15), value: tilt.pitchDegrees)
        .onAppear { tilt.start() }
        .onDisappear { tilt.stop() }
    }

    // MARK: - Linker Streifen mit "thoska+"

    private var sideStripe: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.58, blue: 0.14), Color(red: 0.99, green: 0.82, blue: 0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
            Text("thoska+")
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize()
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 38)
    }

    // MARK: - Weißer Hauptbereich

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle()
                .fill(Color(red: 0.96, green: 0.76, blue: 0.2))
                .frame(height: 4)
                .padding(.top, 6)

            photoAndId
                .padding(.horizontal, 10)
                .padding(.top, 10)

            Spacer(minLength: 4)

            footer
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .background(Color.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("Studienausweis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0.2, green: 0.32, blue: 0.56))

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("TECHNISCHE UNIVERSITÄT")
                    .font(.system(size: 6.5, weight: .semibold))
                HStack(spacing: 4) {
                    Image(systemName: "infinity")
                        .font(.system(size: 13, weight: .bold))
                    Text("ILMENAU")
                        .font(.system(size: 12, weight: .heavy))
                }
            }
            .foregroundStyle(Color(red: 0.1, green: 0.25, blue: 0.58))
        }
        .padding([.top, .horizontal], 10)
    }

    private var photoAndId: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 46, height: 58)
                .overlay(
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color(.systemGray3))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Karten-ID")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text(balance?.cardId.uppercased() ?? "–")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(balance != nil ? "Guthaben" : "Semesterticket")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.1, green: 0.25, blue: 0.58))
            Text(footerSubtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.1, green: 0.25, blue: 0.58).opacity(0.75))
        }
    }

    private var footerSubtitle: String {
        guard let balance else { return "noch nicht gescannt" }
        return String(format: "%.2f €", balance.balance)
    }
}

/// Liest Geräteneigung (Pitch/Roll) via CoreMotion, um der Karte einen leichten
/// Perspektiv-Wobble beim Schwenken des iPhones zu geben.
@MainActor
final class DeviceTiltObserver: ObservableObject {
    @Published private(set) var pitchDegrees: Double = 0
    @Published private(set) var rollDegrees: Double = 0

    private let motionManager = CMMotionManager()
    private let maxTiltDegrees: Double = 10

    func start() {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            Task { @MainActor in
                self.pitchDegrees = self.clamped(motion.attitude.pitch)
                self.rollDegrees = self.clamped(motion.attitude.roll)
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func clamped(_ radians: Double) -> Double {
        let degrees = radians * 180 / .pi * 0.5
        return min(max(degrees, -maxTiltDegrees), maxTiltDegrees)
    }
}

#Preview {
    VStack(spacing: 32) {
        ThoskaCardView(balance: nil)
        ThoskaCardView(
            balance: ThoskaBalance(cardId: "04a1b2c3d4", balance: 15.48, lastTransaction: 3.20, scannedAt: Date())
        )
    }
    .padding()
}
