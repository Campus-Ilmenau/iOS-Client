//
//  ThoskaView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI
import SwiftData

struct ThoskaView: View {
    @StateObject private var reader = ThoskaCardReader()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ThoskaBalanceRecord.scannedAt) private var historyRecords: [ThoskaBalanceRecord]
    @Query private var cardNames: [ThoskaCardName]

    @AppStorage("thoskaHistoryTrackingEnabled") private var isHistoryTrackingEnabled = false
    @State private var pendingBalance: ThoskaBalance?
    @State private var showSaveConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scanSection
                    .frame(minHeight: UIScreen.main.bounds.height * 0.82)

                Divider()

                ThoskaHistoryView(records: historyRecords, cardNames: cardNames, onRename: renameCard)
            }
        }
        .navigationTitle("Thoska")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: reader.balance?.scannedAt) { _, newValue in
            guard newValue != nil, isHistoryTrackingEnabled, let balance = reader.balance else { return }
            pendingBalance = balance
            showSaveConfirmation = true
        }
        .alert("Datensatz übernehmen?", isPresented: $showSaveConfirmation, presenting: pendingBalance) { balance in
            Button("Ja") { save(balance) }
            Button("Nein", role: .cancel) { }
        } message: { balance in
            Text("Soll das ausgelesene Guthaben von \(String(format: "%.2f €", balance.balance)) in die Verlaufs-Auswertung aufgenommen werden?")
        }
    }

    private var scanSection: some View {
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

            Toggle(isOn: $isHistoryTrackingEnabled) {
                Label("Verlauf aufzeichnen", systemImage: "chart.line.uptrend.xyaxis")
            }
            .padding(.horizontal)

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
    }

    private func save(_ balance: ThoskaBalance) {
        modelContext.insert(ThoskaBalanceRecord(balance))

        if !cardNames.contains(where: { $0.cardId == balance.cardId }) {
            modelContext.insert(ThoskaCardName(cardId: balance.cardId, name: balance.cardId))
        }
    }

    private func renameCard(cardId: String, newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let existing = cardNames.first(where: { $0.cardId == cardId }) {
            existing.name = trimmedName
        } else {
            modelContext.insert(ThoskaCardName(cardId: cardId, name: trimmedName))
        }
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
    .modelContainer(for: [ThoskaBalanceRecord.self, ThoskaCardName.self], inMemory: true)
}
