//
//  ViewsBibliothekPAIANotificationsView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 28.10.26.
//

import SwiftUI

/// Art einer Mitteilung der Bibliothek. PAIA liefert dafür kein eigenes Feld, nur den Text (`about`).
/// Die Art wird deshalb aus Schlüsselwörtern im Text abgeleitet; passt keines, bleibt es „Mitteilung“.
enum PAIANotificationKind: Equatable {
    case reminder
    case provided
    case holdExpired
    case other

    init(about: String) {
        let text = about.lowercased()
        // Reihenfolge zählt: „nicht abgeholt“ enthält weder „bereit“ noch „überfällig“, aber „Vormerkung“ allein
        // sagt nichts, daher zuerst die eindeutigen Formulierungen.
        if text.contains("nicht abgeholt") || (text.contains("vormerkung") && text.contains("abgelaufen")) {
            self = .holdExpired
        } else if text.contains("überfällig") || text.contains("ueberfaellig") || text.contains("mahnung")
                    || text.contains("mahngebühr") || text.contains("erinnerung") {
            self = .reminder
        } else if text.contains("bereit") || text.contains("abholung") || text.contains("abholen")
                    || text.contains("bereitgestellt") {
            self = .provided
        } else {
            self = .other
        }
    }

    var title: String {
        switch self {
        case .reminder: "Mahnung"
        case .provided: "Bereitstellung"
        case .holdExpired: "Vormerkung abgelaufen"
        case .other: "Mitteilung"
        }
    }
}

extension PAIANotification {
    var kind: PAIANotificationKind { PAIANotificationKind(about: about) }

    /// Datum wie im Mockup: „28.10.2026“.
    var dateText: String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(Locale(identifier: "de_DE")))
    }
}

/// Mitteilungen der Bibliothek als Sheet von der Glocke (Detents medium/large). Lädt beim Öffnen und per Ziehen neu.
struct PAIANotificationsView: View {
    @ObservedObject var service: PAIAService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PAIANotificationsContent(
            notifications: service.notifications,
            isLoading: service.isLoading,
            onDone: { dismiss() },
            onRefresh: { try? await service.fetchNotifications() }
        )
        .task {
            try? await service.fetchNotifications()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Oberfläche des Sheets nach `BibAusleihen.dc.html` (Mitteilungen), ohne Service für die Previews.
struct PAIANotificationsContent: View {
    let notifications: [PAIANotification]
    let isLoading: Bool
    let onDone: () -> Void
    let onRefresh: () async -> Void

    private var sorted: [PAIANotification] { notifications.sorted { $0.date > $1.date } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if sorted.isEmpty {
                    if !isLoading {
                        emptyState
                    }
                } else {
                    list
                }
            }
            .refreshable { await onRefresh() }
            .overlay {
                if isLoading && notifications.isEmpty {
                    ProgressView()
                }
            }
            .background(Color(.background))
            .navigationTitle("Mitteilungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig", action: onDone)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(.accent))
                }
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 10) {
            Card(verticalPadding: 0, horizontalPadding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, notification in
                        row(notification)
                        if index < sorted.count - 1 {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 1)
                        }
                    }
                }
            }
            Text("Mitteilungen kommen von der Bibliothek. Zum Aktualisieren nach unten ziehen.")
                .font(.caption)
                .foregroundStyle(Color(.textTertiary))
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 34)
    }

    private func row(_ notification: PAIANotification) -> some View {
        let kind = notification.kind
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "book")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconForeground(kind))
                .frame(width: 32, height: 32)
                .background(iconBackground(kind), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                Text(notification.about)
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
                Text(notification.dateText)
                    .font(.caption)
                    .foregroundStyle(Color(.textTertiary))
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func iconBackground(_ kind: PAIANotificationKind) -> Color {
        switch kind {
        case .provided: Color(.green)
        case .reminder: Color(.dangerSoft)
        case .holdExpired, .other: Color(.surfaceSecondary)
        }
    }

    private func iconForeground(_ kind: PAIANotificationKind) -> Color {
        switch kind {
        case .provided: Color(.onGreen)
        case .reminder: Color(.danger)
        case .holdExpired, .other: Color(.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Keine Mitteilungen")
                .font(.headline)
                .foregroundStyle(Color(.textPrimary))
            Text("Mahnungen und abholbereite Vormerkungen erscheinen hier.")
                .foregroundStyle(Color(.textSecondary))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 36)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

private enum NotificationSamples {
    static func notification(_ about: String, daysAgo: Int, id: String) -> PAIANotification {
        PAIANotification(
            id: id,
            about: about,
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
            item: nil,
            url: nil
        )
    }

    static let all: [PAIANotification] = [
        notification("„Statistik kompakt“ wurde nicht abgeholt.", daysAgo: 15, id: "3"),
        notification("„Regelungstechnik 1“ liegt zur Abholung bereit.", daysAgo: 1, id: "1"),
        notification("„Einführung in die Informatik“ ist überfällig. Bitte gib das Medium zurück.", daysAgo: 1, id: "2"),
        notification("Die Bibliothek hat am Freitag geschlossen.", daysAgo: 30, id: "4")
    ]
}

#Preview("Mitteilungen – Light") {
    PAIANotificationsContent(notifications: NotificationSamples.all, isLoading: false, onDone: {}, onRefresh: {})
        .preferredColorScheme(.light)
}

#Preview("Mitteilungen – Dark") {
    PAIANotificationsContent(notifications: NotificationSamples.all, isLoading: false, onDone: {}, onRefresh: {})
        .preferredColorScheme(.dark)
}

#Preview("Keine Mitteilungen – Light") {
    PAIANotificationsContent(notifications: [], isLoading: false, onDone: {}, onRefresh: {})
        .preferredColorScheme(.light)
}

#Preview("Keine Mitteilungen – Dark") {
    PAIANotificationsContent(notifications: [], isLoading: false, onDone: {}, onRefresh: {})
        .preferredColorScheme(.dark)
}
