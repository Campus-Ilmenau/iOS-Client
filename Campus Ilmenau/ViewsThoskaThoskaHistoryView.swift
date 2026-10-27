//
//  ThoskaHistoryView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 27.10.26.
//

import SwiftUI
import Charts

/// Zeigt die Entwicklung des Guthabens über die Zeit, getrennt nach Karte.
/// Wird unterhalb der Kartenansicht eingeblendet, sobald der Nutzer nach unten scrollt.
struct ThoskaHistoryView: View {
    let records: [ThoskaBalanceRecord]
    let cardNames: [ThoskaCardName]
    let onRename: (_ cardId: String, _ newName: String) -> Void

    @State private var renamingCardId: String?
    @State private var renameText = ""

    private var nameLookup: [String: String] {
        Dictionary(uniqueKeysWithValues: cardNames.map { ($0.cardId, $0.name) })
    }

    private var groupedByCard: [CardHistory] {
        Dictionary(grouping: records, by: \.cardId)
            .map { cardId, records in
                CardHistory(
                    cardId: cardId,
                    name: nameLookup[cardId] ?? cardId,
                    records: records.sorted { $0.scannedAt < $1.scannedAt }
                )
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Guthaben-Verlauf", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)

            if records.isEmpty {
                ContentUnavailableView(
                    "Noch keine Daten",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Aktiviere die Aufzeichnung und bestätige nach dem Scannen, dass der Datensatz übernommen werden soll.")
                )
                .frame(maxWidth: .infinity)
            } else {
                chart
                VStack(spacing: 10) {
                    ForEach(groupedByCard) { card in
                        CardHistorySummaryRow(card: card) {
                            renameText = card.name
                            renamingCardId = card.cardId
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert(
            "Karte umbenennen",
            isPresented: Binding(
                get: { renamingCardId != nil },
                set: { isPresented in if !isPresented { renamingCardId = nil } }
            )
        ) {
            TextField("Name der Karte", text: $renameText)
            Button("Speichern") {
                if let cardId = renamingCardId {
                    onRename(cardId, renameText)
                }
                renamingCardId = nil
            }
            Button("Abbrechen", role: .cancel) {
                renamingCardId = nil
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(groupedByCard) { card in
                ForEach(card.records) { record in
                    LineMark(
                        x: .value("Datum", record.scannedAt),
                        y: .value("Guthaben", record.balance)
                    )
                    .foregroundStyle(by: .value("Karte", card.name))
                    .symbol(by: .value("Karte", card.name))
                }
            }
        }
        .chartYAxisLabel("Guthaben (€)")
        .frame(height: 220)
    }
}

private struct CardHistory: Identifiable {
    let cardId: String
    let name: String
    let records: [ThoskaBalanceRecord]

    var id: String { cardId }
}

private struct CardHistorySummaryRow: View {
    fileprivate let card: CardHistory
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(card.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let last = card.records.last {
                    Text(String(format: "%.2f €", last.balance))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScrollView {
        ThoskaHistoryView(
            records: [
                ThoskaBalanceRecord(cardId: "04a1b2c3d4", balance: 20.00, lastTransaction: 3.20, scannedAt: .now.addingTimeInterval(-86400 * 3)),
                ThoskaBalanceRecord(cardId: "04a1b2c3d4", balance: 15.48, lastTransaction: 3.20, scannedAt: .now.addingTimeInterval(-86400)),
                ThoskaBalanceRecord(cardId: "04a1b2c3d4", balance: 12.10, lastTransaction: 3.38, scannedAt: .now),
                ThoskaBalanceRecord(cardId: "aa11bb22cc", balance: 8.00, lastTransaction: 2.50, scannedAt: .now.addingTimeInterval(-86400 * 2)),
                ThoskaBalanceRecord(cardId: "aa11bb22cc", balance: 5.60, lastTransaction: 2.40, scannedAt: .now)
            ],
            cardNames: [ThoskaCardName(cardId: "04a1b2c3d4", name: "Meine Karte")],
            onRename: { _, _ in }
        )
    }
}
