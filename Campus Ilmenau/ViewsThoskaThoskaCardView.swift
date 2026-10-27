//
//  ThoskaCardView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI
import Combine
import CoreMotion

/// Visuelle Nachbildung der physischen Thoska-Karte der TU Ilmenau.
struct ThoskaCardView: View {
    let balance: ThoskaBalance?

    @StateObject private var tilt = DeviceTiltObserver()
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var isFlipped = false

    private let maxDragTiltDegrees: Double = 16

    var body: some View {
        ZStack {
            frontFace
                .opacity(isFlipped ? 0 : 1)
            backFace
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .frame(width: 300, height: 189)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 10)
        .rotation3DEffect(.degrees(pitchDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(rollDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .animation(.easeOut(duration: 0.15), value: tilt.rollDegrees)
        .animation(.easeOut(duration: 0.15), value: tilt.pitchDegrees)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dragTranslation)
        .animation(.spring(response: 0.8, dampingFraction: 0.75), value: isFlipped)
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
        )
        .onTapGesture(count: 2) {
            isFlipped = false
        }
        .onAppear { tilt.start() }
        .onDisappear { tilt.stop() }
        .onChange(of: balance?.scannedAt) { _, newValue in
            if newValue != nil {
                isFlipped = true
            }
        }
    }

    /// Kombiniert den Neigungssensor-Wert mit dem Beitrag einer Finger-Wisch-Geste über die Karte.
    private var pitchDegrees: Double {
        tilt.pitchDegrees - clamp(Double(dragTranslation.height) / 6, max: maxDragTiltDegrees)
    }

    private var rollDegrees: Double {
        let flip = isFlipped ? 180.0 : 0.0
        let wobble = tilt.rollDegrees + clamp(Double(dragTranslation.width) / 6, max: maxDragTiltDegrees)
        return flip + wobble
    }

    private func clamp(_ value: Double, max: Double) -> Double {
        Swift.min(Swift.max(value, -max), max)
    }

    // MARK: - Vorderseite

    private var frontFace: some View {
        HStack(spacing: 0) {
            sideStripe
            mainContent
        }
    }

    // MARK: - Rückseite mit Guthaben

    private var backFace: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.85))
                .frame(height: 28)

            VStack(spacing: 8) {
                Spacer(minLength: 4)

                Text("Guthaben")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.2, green: 0.32, blue: 0.56))

                Text(balance.map { String(format: "%.2f €", $0.balance) } ?? "–")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(backBalanceColor)

                if let balance {
                    VStack(spacing: 2) {
                        Text("Letzte Buchung: \(String(format: "%.2f €", balance.lastTransaction))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("Karten-ID \(balance.cardId.uppercased())")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 4)

                barcode
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white)
    }

    private var barcode: some View {
        HStack(spacing: 2) {
            ForEach(0..<28, id: \.self) { index in
                Rectangle()
                    .fill(Color.black)
                    .frame(width: index % 3 == 0 ? 2 : 1, height: 22)
            }
        }
    }

    private var backBalanceColor: Color {
        guard let euro = balance?.balance else { return .blue }
        switch euro {
        case ..<2: return .red
        case 2..<5: return .orange
        default: return .green
        }
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
