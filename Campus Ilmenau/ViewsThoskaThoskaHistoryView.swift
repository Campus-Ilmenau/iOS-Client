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

    private var groupedByCard: [CardHistory] {
        Dictionary(grouping: records, by: \.cardId)
            .map { cardId, records in
                CardHistory(cardId: cardId, records: records.sorted { $0.scannedAt < $1.scannedAt })
            }
            .sorted { $0.cardId < $1.cardId }
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
                        CardHistorySummaryRow(card: card)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chart: some View {
        Chart {
            ForEach(groupedByCard) { card in
                ForEach(card.records) { record in
                    LineMark(
                        x: .value("Datum", record.scannedAt),
                        y: .value("Guthaben", record.balance)
                    )
                    .foregroundStyle(by: .value("Karte", card.displayName))
                    .symbol(by: .value("Karte", card.displayName))
                }
            }
        }
        .chartYAxisLabel("Guthaben (€)")
        .frame(height: 220)
    }
}

private struct CardHistory: Identifiable {
    let cardId: String
    let records: [ThoskaBalanceRecord]

    var id: String { cardId }
    var displayName: String { "Karte \(cardId.uppercased().suffix(6))" }
}

private struct CardHistorySummaryRow: View {
    fileprivate let card: CardHistory

    var body: some View {
        HStack {
            Text(card.displayName)
                .font(.subheadline.weight(.semibold))
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
}

#Preview {
    ScrollView {
        ThoskaHistoryView(records: [
            ThoskaBalanceRecord(cardId: "04a1b2c3d4", balance: 20.00, lastTransaction: 3.20, scannedAt: .now.addingTimeInterval(-86400 * 3)),
            ThoskaBalanceRecord(cardId: "04a1b2c3d4", balance: 15.48, lastTransaction: 3.20, scannedAt: .now.addingTimeInterval(-86400)),
            ThoskaBalanceRecord(cardId: "04a1b2c3d4", balance: 12.10, lastTransaction: 3.38, scannedAt: .now),
            ThoskaBalanceRecord(cardId: "aa11bb22cc", balance: 8.00, lastTransaction: 2.50, scannedAt: .now.addingTimeInterval(-86400 * 2)),
            ThoskaBalanceRecord(cardId: "aa11bb22cc", balance: 5.60, lastTransaction: 2.40, scannedAt: .now)
        ])
    }
}
