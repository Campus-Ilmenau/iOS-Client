//
//  MensaView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

/// Verdrahtet die Oberfläche (`MensaScreen`) mit dem `MensaService` und dem Filter.
struct MensaView: View {
    @StateObject private var mensaService = MensaService()
    @State private var days = MensaFormatting.workdays(from: .now)
    @State private var selectedDayIndex = 0
    /// Die zuletzt gewählte Mensa bleibt erhalten. Eine Einstellung „Mensa auf der Startseite“ gibt es noch nicht, Start ist Mensa Ehrenberg.
    @SceneStorage("mensaSelectedVenue") private var storedVenue = MensaVenue.mensaEhrenberg.rawValue
    @State private var mealtime: MensaMealtime = .lunch
    @State private var loadState: MensaLoadState = .loading
    @State private var loadTask: Task<Void, Never>?

    @State private var showFilterSheet = false
    @State private var filter = MensaFilterStore.load()

    private var selectedVenue: Binding<MensaVenue> {
        Binding(
            get: { MensaVenue(rawValue: storedVenue) ?? .mensaEhrenberg },
            set: { storedVenue = $0.rawValue }
        )
    }

    var body: some View {
        MensaScreen(
            days: days,
            selectedDayIndex: $selectedDayIndex,
            selectedVenue: selectedVenue,
            mealtime: $mealtime,
            loadState: loadState,
            allMeals: mensaService.meals,
            filter: $filter,
            canteens: mensaService.canteens,
            onRetry: { load(days[selectedDayIndex]) },
            onOpenFilter: { showFilterSheet = true }
        )
        .sheet(isPresented: $showFilterSheet) {
            MensaFilterSheet(
                filter: $filter,
                availableAllergens: MensaFilter.availableAllergens(in: mensaService.meals, keeping: filter.excludedAllergens)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .onChange(of: filter) { _, newValue in
            MensaFilterStore.save(newValue)
        }
        .onChange(of: selectedDayIndex) { _, newIndex in
            load(days[newIndex])
        }
        .task {
            load(days[selectedDayIndex])
            // Öffnungszeiten für den Status-Chip; ohne sie fehlt der Chip einfach.
            try? await mensaService.fetchCanteens()
        }
    }

    /// Lädt den Tag. Ein neuer Aufruf bricht den vorigen ab, damit keine ältere Antwort eine neuere überholt.
    private func load(_ day: Date) {
        loadTask?.cancel()
        loadState = .loading
        loadTask = Task {
            do {
                try await mensaService.fetchMeals(date: day)
                guard !Task.isCancelled else { return }
                loadState = .loaded
            } catch {
                if Task.isCancelled || (error as? URLError)?.code == .cancelled { return }
                loadState = .failed
            }
        }
    }
}

#Preview {
    NavigationStack {
        MensaView()
    }
}
