//
//  BibliothekView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct BibliothekView: View {
    @StateObject private var service = PAIAService.shared
    @State private var showLoginSheet = false
    @State private var showNotificationsSheet = false

    var body: some View {
        content
            .navigationTitle("Bibliothek")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if service.isAuthenticated {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        notificationsButton
                        Button("Abmelden", role: .destructive) {
                            service.logout()
                        }
                    }
                }
            }
            .onAppear {
                if !service.isAuthenticated {
                    showLoginSheet = true
                }
            }
            .onChange(of: service.isAuthenticated) { _, isAuthenticated in
                if !isAuthenticated {
                    showLoginSheet = true
                }
            }
            .sheet(isPresented: $showLoginSheet) {
                PAIALoginSheet(service: service) {
                    showLoginSheet = false
                    Task { await loadData() }
                }
            }
            .sheet(isPresented: $showNotificationsSheet) {
                PAIANotificationsView(service: service)
            }
    }

    private var notificationsButton: some View {
        Button {
            showNotificationsSheet = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                if !service.notifications.isEmpty {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if service.isAuthenticated {
            loanList
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)
            Text("Bibliothek")
                .font(.title)
            Text("Melde dich an, um deine ausgeliehenen Medien zu sehen.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Anmelden") {
                showLoginSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var loanList: some View {
        List {
            if let errorMessage = service.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if service.items.isEmpty && !service.isLoading {
                ContentUnavailableView(
                    "Keine ausgeliehenen Medien",
                    systemImage: "books.vertical",
                    description: Text("Du hast aktuell keine Medien ausgeliehen, vorgemerkt oder bestellt.")
                )
            } else {
                ForEach(service.items) { item in
                    PAIALoanItemRow(item: item) {
                        Task { await renew(item) }
                    }
                }
            }
        }
        .overlay {
            if service.isLoading && service.items.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await loadData()
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        try? await service.fetchItems()
        try? await service.fetchNotifications()
    }

    private func renew(_ item: PAIALoanItem) async {
        try? await service.renew(item)
    }
}

#Preview {
    NavigationStack {
        BibliothekView()
    }
}
