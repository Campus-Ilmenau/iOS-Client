import SwiftUI
import SwiftData
import Charts
import Accessibility

/// Verlauf der Thoska-Auslesungen: Ausgaben, Balkendiagramm und Liste. Die Daten liegen nur auf dem Gerät (SwiftData).
struct ThoskaHistoryView: View {
    @Query(sort: \ThoskaBalanceRecord.scannedAt) private var records: [ThoskaBalanceRecord]
    @Query private var cardNames: [ThoskaCardName]
    @Environment(\.modelContext) private var modelContext

    /// Gewählte Karte; ohne Wahl zählt die zuletzt ausgelesene.
    @State private var selectedCardId: String?

    /// Karten, zuletzt ausgelesene zuerst.
    private var cards: [ThoskaCardOption] {
        var latest: [String: Date] = [:]
        for record in records { latest[record.cardId] = max(latest[record.cardId] ?? .distantPast, record.scannedAt) }
        return latest.sorted { $0.value > $1.value }
            .map { ThoskaCardNaming.option(for: $0.key, names: cardNames) }
    }

    private var effectiveCardId: String? {
        if let selectedCardId, cards.contains(where: { $0.id == selectedCardId }) { return selectedCardId }
        return cards.first?.id
    }

    private var readings: [ThoskaReading] {
        records
            .filter { $0.cardId == effectiveCardId }
            .map { ThoskaReading(date: $0.scannedAt, balance: $0.balance, lastTransaction: $0.lastTransaction) }
    }

    var body: some View {
        ThoskaHistoryContent(
            readings: readings,
            cards: cards,
            selectedCardId: effectiveCardId,
            onSelectCard: { selectedCardId = $0 },
            onRenameCard: { cardId, name in
                ThoskaCardNaming.rename(cardId: cardId, to: name, names: cardNames, context: modelContext)
            }
        )
    }
}

/// Oberfläche ohne eigene Datenhaltung, damit sie sich in Previews mit Beispieldaten zeigen lässt.
struct ThoskaHistoryContent: View {
    let readings: [ThoskaReading]
    let cards: [ThoskaCardOption]
    let selectedCardId: String?
    var now: Date = .now
    let onSelectCard: (String) -> Void
    let onRenameCard: (_ cardId: String, _ name: String) -> Void

    @State private var range: ThoskaHistoryRange
    @State private var renamingCardId: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        readings: [ThoskaReading],
        cards: [ThoskaCardOption] = [],
        selectedCardId: String? = nil,
        now: Date = .now,
        initialRange: ThoskaHistoryRange = .twoWeeks,
        onSelectCard: @escaping (String) -> Void = { _ in },
        onRenameCard: @escaping (String, String) -> Void = { _, _ in }
    ) {
        self.readings = readings
        self.cards = cards
        self.selectedCardId = selectedCardId
        self.now = now
        self.onSelectCard = onSelectCard
        self.onRenameCard = onRenameCard
        self._range = State(initialValue: initialRange)
    }

    private var summary: ThoskaHistorySummary {
        ThoskaHistorySummary(readings: readings, range: range, now: now)
    }

    var body: some View {
        let summary = summary
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Verlauf")
                    .display(size: 28, relativeTo: .title)
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 4)

                if let selected = cards.first(where: { $0.id == selectedCardId }) {
                    cardMenu(selected: selected)
                }

                SegmentedControl(
                    selection: $range,
                    options: [(.twoWeeks, "2 Wochen"), (.threeMonths, "3 Monate")]
                )

                if summary.entries.isEmpty {
                    emptyState
                } else {
                    spentCard(summary)

                    Text("Ausgelesen")
                        .font(.body.bold())
                        .foregroundStyle(Color(.textPrimary))
                        .padding(.horizontal, 2)
                        .padding(.top, 6)
                        .accessibilityAddTraits(.isHeader)

                    readingsCard(summary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.background))
        // Zurück-Pfeil des Systems (behält die Wischgeste), in accent.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(Color(.accent))
    }

    // MARK: - Karte wählen und benennen

    /// Bei mehreren Karten wechselt das Menü die Karte, immer kann die gewählte benannt werden.
    private func cardMenu(selected: ThoskaCardOption) -> some View {
        Menu {
            if cards.count > 1 {
                ForEach(cards) { card in
                    Button {
                        onSelectCard(card.id)
                    } label: {
                        if card.id == selected.id {
                            Label(card.displayName, systemImage: "checkmark")
                        } else {
                            Text(card.displayName)
                        }
                    }
                }
                Divider()
            }
            Button {
                renamingCardId = selected.id
            } label: {
                Label("Karte benennen", systemImage: "pencil")
            }
        } label: {
            HStack(spacing: 6) {
                Text(selected.displayName)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .accessibilityHidden(true)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color(.accent))
            .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityLabel("Karte: \(selected.displayName)")
        .accessibilityHint(cards.count > 1 ? "Karte wechseln oder benennen" : "Karte benennen")
        .thoskaRenameAlert(
            renamingCardId: $renamingCardId,
            currentName: { id in cards.first(where: { $0.id == id })?.customName },
            onSave: onRenameCard
        )
    }

    // MARK: - Ausgaben und Diagramm

    private func spentCard(_ summary: ThoskaHistorySummary) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text("Ausgegeben im Zeitraum")
                    .font(.footnote)
                    .foregroundStyle(Color(.textTertiary))
                Text(ThoskaFormatting.euro(summary.spent))
                    .display(size: 32, relativeTo: .title)
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 2)

                ThoskaBalanceChart(bars: summary.bars, summary: chartSummary(summary))
                    .padding(.top, 14)

                legend
                    .padding(.top, 10)
            }
        }
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { legendItem("Guthaben", color: Color(.blue)); legendItem("Aufgeladen", color: Color(.green)) }
            VStack(alignment: .leading, spacing: 6) { legendItem("Guthaben", color: Color(.blue)); legendItem("Aufgeladen", color: Color(.green)) }
        }
        .accessibilityHidden(true)
    }

    private func legendItem(_ title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color(.textSecondary))
        }
    }

    private func chartSummary(_ summary: ThoskaHistorySummary) -> String {
        guard let first = summary.entries.first, let last = summary.entries.last else { return "" }
        let topUps = summary.entries.filter(\.isTopUp).count
        var text = "\(summary.entries.count) Auslesungen. Guthaben von \(ThoskaFormatting.spokenEuro(first.balance)) auf \(ThoskaFormatting.spokenEuro(last.balance)). Ausgegeben \(ThoskaFormatting.spokenEuro(summary.spent))."
        text += topUps == 0 ? " Keine Aufladung." : " \(topUps)-mal aufgeladen."
        return text
    }

    // MARK: - Liste

    private func readingsCard(_ summary: ThoskaHistorySummary) -> some View {
        let entries = Array(summary.entries.reversed())
        return Card(verticalPadding: 2) {
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    row(entry)
                    if index < entries.count - 1 {
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                    }
                }
            }
        }
    }

    private func row(_ entry: ThoskaHistoryEntry) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 0) {
                Text(ThoskaFormatting.lastRead(entry.date, now: now))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                Text(note(for: entry))
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(ThoskaFormatting.euro(entry.balance))
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.textPrimary))
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func note(for entry: ThoskaHistoryEntry) -> String {
        entry.isTopUp
            ? "Aufgeladen \(ThoskaFormatting.plusEuro(entry.lastTransaction))"
            : "Letzte Buchung \(ThoskaFormatting.minusEuro(entry.lastTransaction))"
    }

    // MARK: - Leerer Zustand

    private var emptyState: some View {
        Card {
            VStack(spacing: 8) {
                Text("Noch keine Auslesungen in diesem Zeitraum")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .multilineTextAlignment(.center)
                Button {
                    dismiss()
                } label: {
                    Text("Thoska auslesen")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(.accent))
                        .frame(minHeight: 44)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Diagramm

/// Balken mit dem Guthaben, grün bei Aufladung. Ohne Achsen und Raster, 120 pt hoch.
private struct ThoskaBalanceChart: View {
    let bars: [ThoskaChartBar]
    let summary: String

    /// Mindestens so viele Plätze, damit einzelne Balken nicht über die ganze Breite laufen; neue rechts.
    private static let minimumSlots = 6

    private struct Slot: Identifiable {
        let id: String
        let bar: ThoskaChartBar?
    }

    private var slots: [Slot] {
        let padding = max(0, Self.minimumSlots - bars.count)
        let empty = (0..<padding).map { Slot(id: "leer-\($0)", bar: nil) }
        return empty + bars.map { Slot(id: "bar-\($0.id)", bar: $0) }
    }

    private var maxBalance: Double { max(bars.map(\.balance).max() ?? 0, 1) }

    var body: some View {
        let slots = slots
        Chart(slots) { slot in
            if let bar = slot.bar {
                BarMark(
                    x: .value("Auslesung", slot.id),
                    // Mindesthöhe, damit auch ein leeres Guthaben als Balken sichtbar bleibt.
                    y: .value("Guthaben", max(bar.balance, maxBalance * 0.03)),
                    width: .ratio(0.78)
                )
                .foregroundStyle(bar.isTopUp ? Color(.green) : Color(.blue))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 4))
            }
        }
        .chartXScale(domain: slots.map(\.id))
        .chartYScale(domain: 0...maxBalance)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 120)
        .accessibilityChartDescriptor(ThoskaChartDescriptor(bars: bars, summary: summary))
    }
}

/// Beschreibung des Diagramms für VoiceOver (Audiograph und Zusammenfassung in Worten).
private struct ThoskaChartDescriptor: AXChartDescriptorRepresentable {
    let bars: [ThoskaChartBar]
    let summary: String

    private var labels: [String] {
        bars.enumerated().map { index, bar in
            "\(index + 1). \(ThoskaFormatting.lastRead(bar.date))"
        }
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = labels
        let maxBalance = max(bars.map(\.balance).max() ?? 0, 1)
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Auslesung", categoryOrder: labels)
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Guthaben",
            range: 0...maxBalance,
            gridlinePositions: []
        ) { ThoskaFormatting.spokenEuro($0) }
        let series = AXDataSeriesDescriptor(
            name: "Guthaben",
            isContinuous: false,
            dataPoints: zip(labels, bars).map { label, bar in
                AXDataPoint(x: label, y: bar.balance, additionalValues: [], label: bar.isTopUp ? "aufgeladen" : nil)
            }
        )
        return AXChartDescriptor(
            title: "Guthaben-Verlauf",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}

// MARK: - Previews

private enum PreviewData {
    /// Werte und Aufladungen aus dem Mockup.
    private static let short: [Double] = [18.2, 15.3, 12.5, 12.5, 9.7, 6.8, 26.8, 24.0, 21.2, 21.2, 18.4, 15.5, 12.7, 12.4]
    private static let long: [Double] = [30, 22, 14, 6, 26, 18, 10, 24, 16, 8, 28, 12.4]

    static func twoWeeks(now: Date) -> [ThoskaReading] {
        short.enumerated().map { index, balance in
            let daysAgo = Double(short.count - 1 - index)
            let previous = index > 0 ? short[index - 1] : balance + 2.9
            return ThoskaReading(
                date: now.addingTimeInterval(-daysAgo * 86400 - 3600),
                balance: balance,
                lastTransaction: balance > previous ? 20 : max(previous - balance, 2.8)
            )
        }
    }

    static func threeMonths(now: Date) -> [ThoskaReading] {
        long.enumerated().map { index, balance in
            let weeksAgo = Double(long.count - 1 - index)
            let previous = index > 0 ? long[index - 1] : balance + 2.9
            return ThoskaReading(
                date: now.addingTimeInterval(-weeksAgo * 7 * 86400 - 3600),
                balance: balance,
                lastTransaction: balance > previous ? 20 : max(previous - balance, 2.8)
            )
        }
    }
}

private struct HistoryPreview: View {
    var readings: (Date) -> [ThoskaReading]
    var range: ThoskaHistoryRange = .twoWeeks
    var cards: [ThoskaCardOption] = [
        ThoskaCardOption(id: "04a1b2c3d4", displayName: "Mensakarte", customName: "Mensakarte"),
        ThoskaCardOption(id: "aa11bb22cc", displayName: "Karte …22CC", customName: nil)
    ]
    private let now = Date.now

    var body: some View {
        NavigationStack {
            ThoskaHistoryContent(
                readings: readings(now),
                cards: cards,
                selectedCardId: cards.first?.id,
                now: now,
                initialRange: range
            )
        }
    }
}

#Preview("2 Wochen – Light") {
    HistoryPreview(readings: PreviewData.twoWeeks).preferredColorScheme(.light)
}

#Preview("2 Wochen – Dark") {
    HistoryPreview(readings: PreviewData.twoWeeks).preferredColorScheme(.dark)
}

#Preview("3 Monate – Light") {
    HistoryPreview(readings: PreviewData.threeMonths, range: .threeMonths).preferredColorScheme(.light)
}

#Preview("3 Monate – Dark") {
    HistoryPreview(readings: PreviewData.threeMonths, range: .threeMonths).preferredColorScheme(.dark)
}

#Preview("Leer – Light") {
    HistoryPreview(readings: { _ in [] }, cards: []).preferredColorScheme(.light)
}

#Preview("Leer – Dark") {
    HistoryPreview(readings: { _ in [] }, cards: []).preferredColorScheme(.dark)
}

#Preview("Große Schrift") {
    HistoryPreview(readings: PreviewData.twoWeeks)
        .dynamicTypeSize(.xxxLarge)
}
