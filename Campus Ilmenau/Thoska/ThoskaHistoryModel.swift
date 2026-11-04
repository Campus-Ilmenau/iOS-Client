import Foundation

/// Eine Auslesung, wie sie die Verlauf-Ansicht braucht (unabhängig von SwiftData, damit sie sich testen lässt).
struct ThoskaReading: Equatable {
    let date: Date
    let balance: Double
    let lastTransaction: Double
}

enum ThoskaHistoryRange: CaseIterable, Hashable {
    case twoWeeks
    case threeMonths

    func startDate(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .twoWeeks: calendar.date(byAdding: .day, value: -14, to: now) ?? now
        case .threeMonths: calendar.date(byAdding: .month, value: -3, to: now) ?? now
        }
    }
}

struct ThoskaHistoryEntry: Identifiable, Equatable {
    let id: Int
    let date: Date
    let balance: Double
    let lastTransaction: Double
    /// Das Guthaben ist gegenüber der vorherigen Auslesung gestiegen: Die Karte wurde aufgeladen.
    let isTopUp: Bool
}

struct ThoskaChartBar: Identifiable, Equatable {
    let id: Int
    let date: Date
    let balance: Double
    let isTopUp: Bool
}

/// Auswertung der Auslesungen einer Karte für einen Zeitraum.
struct ThoskaHistorySummary: Equatable {
    /// Auslesungen im Zeitraum, älteste zuerst.
    let entries: [ThoskaHistoryEntry]
    /// Ausgaben aus den Guthaben-Unterschieden aufeinanderfolgender Auslesungen im Zeitraum, ohne Aufladungen.
    let spent: Double
    /// Ein Balken pro Auslesung, bei 3 Monaten einer pro Woche (mit dem letzten Stand der Woche).
    let bars: [ThoskaChartBar]

    /// Rundungsrauschen der Kartenwerte (Tausendstel) soll keine Aufladung ergeben.
    private static let tolerance = 0.005

    init(readings: [ThoskaReading], range: ThoskaHistoryRange, now: Date = .now, calendar: Calendar = .current) {
        let sorted = readings.sorted { $0.date < $1.date }
        let start = range.startDate(from: now, calendar: calendar)

        // Aufladung gegenüber dem Vorgänger, auch wenn dieser vor dem Zeitraum liegt.
        var all: [ThoskaHistoryEntry] = []
        for (index, reading) in sorted.enumerated() {
            let isTopUp = index > 0 && reading.balance > sorted[index - 1].balance + Self.tolerance
            all.append(ThoskaHistoryEntry(
                id: index,
                date: reading.date,
                balance: reading.balance,
                lastTransaction: reading.lastTransaction,
                isTopUp: isTopUp
            ))
        }
        let entries = all.filter { $0.date >= start && $0.date <= now }
        self.entries = entries

        var spent = 0.0
        for (previous, current) in zip(entries, entries.dropFirst()) where current.balance < previous.balance {
            spent += previous.balance - current.balance
        }
        self.spent = spent

        switch range {
        case .twoWeeks:
            bars = entries.map { ThoskaChartBar(id: $0.id, date: $0.date, balance: $0.balance, isTopUp: $0.isTopUp) }
        case .threeMonths:
            let grouped = Dictionary(grouping: entries) { entry in
                calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start ?? entry.date
            }
            bars = grouped.keys.sorted().enumerated().compactMap { offset, weekStart in
                guard let last = grouped[weekStart]?.max(by: { $0.date < $1.date }) else { return nil }
                let hasTopUp = grouped[weekStart]?.contains(where: \.isTopUp) ?? false
                return ThoskaChartBar(id: offset, date: weekStart, balance: last.balance, isTopUp: hasTopUp)
            }
        }
    }
}
