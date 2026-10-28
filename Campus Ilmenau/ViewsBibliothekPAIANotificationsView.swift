//
//  ViewsBibliothekPAIANotificationsView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 28.10.26.
//

import SwiftUI

/// Listet die Benachrichtigungen aus dem PAIA-Nutzerkonto auf
/// (z. B. Mahnungen, Bereitstellungen, abgelaufene Vormerkungen).
struct PAIANotificationsView: View {
    @ObservedObject var service: PAIAService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if service.notifications.isEmpty && !service.isLoading {
                    ContentUnavailableView(
                        "Keine Benachrichtigungen",
                        systemImage: "bell.slash",
                        description: Text("Du hast aktuell keine neuen Benachrichtigungen aus der Bibliothek.")
                    )
                } else {
                    List(service.notifications.sorted { $0.date > $1.date }) { notification in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.about)
                                .font(.subheadline)
                            Text(notification.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .refreshable {
                        try? await service.fetchNotifications()
                    }
                }
            }
            .overlay {
                if service.isLoading && service.notifications.isEmpty {
                    ProgressView()
                }
            }
            .navigationTitle("Benachrichtigungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .task {
                try? await service.fetchNotifications()
            }
        }
    }
}

#Preview {
    PAIANotificationsView(service: PAIAService())
}
