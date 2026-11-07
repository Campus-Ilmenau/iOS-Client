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
    /// Wunsch von der Startseite („Ganzer Speiseplan“): wechselt auf diese Mensa.
    @Environment(AppRouter.self) private var router: AppRouter?
    @State private var zeigtOeffnungszeiten = false
    /// Gericht aus einem Deeplink, das nach dem Laden des Tages geöffnet wird.
    @State private var wartendesGericht: String?
    /// ID des Gerichts, dessen Detail gerade offen ist.
    @State private var geoeffnetesGericht: String?

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
        .onAppear { uebernehmeMensaWunsch() }
        .onChange(of: router?.mensaWunsch) { _, _ in uebernehmeMensaWunsch() }
        .onChange(of: router?.mensaOeffnungszeiten) { _, _ in uebernehmeMensaWunsch() }
        .onChange(of: router?.gerichtWunsch) { _, _ in uebernehmeMensaWunsch() }
        .onChange(of: loadState) { _, neu in
            if neu != .loading { oeffneWartendesGericht() }
        }
        .navigationDestination(isPresented: $zeigtOeffnungszeiten) {
            MensaOpeningHoursView(canteens: mensaService.canteens)
        }
        .navigationDestination(item: $geoeffnetesGericht) { id in
            if let meal = mensaService.meals.first(where: { $0.id == id }) {
                MensaMealDetailView(meal: meal, canteens: mensaService.canteens)
            }
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
            WidgetSync.shared.speichereOeffnungszeiten(mensaService.canteens)
        }
    }

    private func uebernehmeMensaWunsch() {
        if let wunsch = router?.mensaWunsch {
            storedVenue = wunsch.rawValue
            router?.mensaWunsch = nil
        }
        if router?.mensaOeffnungszeiten == true {
            router?.mensaOeffnungszeiten = false
            zeigtOeffnungszeiten = true
        }
        if let wunsch = router?.gerichtWunsch {
            router?.gerichtWunsch = nil
            geoeffnetesGericht = nil
            wartendesGericht = wunsch.id
            // Die IDs der API gelten nur für einen Tag: Der Link nennt den Tag, sonst gilt heute.
            let index = wunsch.tag.flatMap(tagIndex) ?? 0
            if index != selectedDayIndex {
                selectedDayIndex = index
            } else if loadState != .loading {
                oeffneWartendesGericht()
            }
        }
    }

    /// Stelle des Tages `yyyy-MM-dd` in der Tagesleiste; `nil`, wenn er dort nicht vorkommt (z. B. Wochenende).
    private func tagIndex(_ tag: String) -> Int? {
        let teile = tag.split(separator: "-").compactMap { Int($0) }
        guard teile.count == 3,
              let datum = Calendar.current.date(from: DateComponents(year: teile[0], month: teile[1], day: teile[2]))
        else { return nil }
        return days.firstIndex { Calendar.current.isDate($0, inSameDayAs: datum) }
    }

    /// Öffnet das Gericht aus dem Link, sobald der Tag geladen ist. Findet es sich nicht (nicht mehr auf dem Plan),
    /// bleibt der Speiseplan der Mensa stehen.
    private func oeffneWartendesGericht() {
        guard let id = wartendesGericht else { return }
        wartendesGericht = nil
        guard loadState == .loaded, let meal = mensaService.meals.first(where: { $0.id == id }) else { return }
        if let venue = MensaVenue.allCases.first(where: { $0.matches(canteenName: meal.canteenName) }) {
            storedVenue = venue.rawValue
        }
        geoeffnetesGericht = id
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
                // Auch hier geladene Pläne sind für die Widgets neu.
                WidgetSync.shared.speichereSpeiseplan(tag: day, speiseplan: mensaService.meals)
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
