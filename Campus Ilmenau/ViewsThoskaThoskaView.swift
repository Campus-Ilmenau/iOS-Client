//
//  ThoskaView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct ThoskaView: View {
    @StateObject private var reader = ThoskaCardReader()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ThoskaCardView(balance: reader.balance)

            if let balance = reader.balance {
                VStack(spacing: 8) {
                    Text(String(format: "%.2f €", balance.balance))
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(balanceColor)

                    Text("Letzte Buchung: \(String(format: "%.2f €", balance.lastTransaction))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(balance.scannedAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Noch kein Guthaben ausgelesen")
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = reader.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button {
                reader.scan()
            } label: {
                Label(reader.isScanning ? "Scanne..." : "Karte scannen", systemImage: "wave.3.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(reader.isScanning)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Thoska")
        .navigationBarTitleDisplayMode(.large)
    }

    private var balanceColor: Color {
        guard let euro = reader.balance?.balance else { return .blue }
        switch euro {
        case ..<2: return .red
        case 2..<5: return .orange
        default: return .green
        }
    }
}

#Preview {
    NavigationStack {
        ThoskaView()
    }
}
