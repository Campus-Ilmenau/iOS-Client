//
//  MensaView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct MensaView: View {
    @StateObject private var mensaService = MensaService()
    @State private var currentCanteenIndex = 0
    @State private var dragOffset: CGSize = .zero
    
    // Gruppiere Meals nach Mensa
    private var mealsByCanteen: [(canteen: String, meals: [MensaMeal])] {
        let grouped = Dictionary(grouping: mensaService.meals, by: { $0.canteenName })
        return grouped.map { (canteen: $0.key, meals: $0.value) }
            .sorted { $0.canteen < $1.canteen }
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Header mit Datum
                VStack(spacing: 4) {
                    Text("Speiseplan")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(todayFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                // Mensen-Indikatoren
                if !mealsByCanteen.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(mealsByCanteen.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == currentCanteenIndex ? Color.orange : Color.gray.opacity(0.3))
                                .frame(height: 4)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                
                // Swipeable Mensa Cards
                if mensaService.isLoading {
                    ProgressView("Lade Speiseplan...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !mealsByCanteen.isEmpty {
                    ZStack {
                        ForEach(mealsByCanteen.indices, id: \.self) { index in
                            if shouldShowCard(at: index) {
                                MensaCard(
                                    canteenName: mealsByCanteen[index].canteen,
                                    meals: mealsByCanteen[index].meals
                                )
                                .offset(x: offsetFor(index: index))
                                .scaleEffect(scaleFor(index: index))
                                .opacity(opacityFor(index: index))
                                .zIndex(zIndexFor(index: index))
                                .gesture(
                                    index == currentCanteenIndex ?
                                    DragGesture()
                                        .onChanged { value in
                                            dragOffset = value.translation
                                        }
                                        .onEnded { value in
                                            handleSwipe(value.translation)
                                        }
                                    : nil
                                )
                            }
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentCanteenIndex)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Keine Gerichte verfügbar")
                            .font(.headline)
                        Text("Versuchen Sie es später erneut")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Mensa")
        .navigationBarTitleDisplayMode(.large)
        .task {
            do {
                try await mensaService.fetchTodaysMeals()
            } catch {
                print("Fehler beim Laden: \(error)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func shouldShowCard(at index: Int) -> Bool {
        // Zeige aktuelle Karte und die daneben
        abs(index - currentCanteenIndex) <= 1
    }
    
    private func offsetFor(index: Int) -> CGFloat {
        if index == currentCanteenIndex {
            return dragOffset.width
        } else if index == currentCanteenIndex + 1 {
            // Nächste Karte rechts
            return UIScreen.main.bounds.width * 0.9 + dragOffset.width
        } else if index == currentCanteenIndex - 1 {
            // Vorherige Karte links
            return -UIScreen.main.bounds.width * 0.9 + dragOffset.width
        }
        return 0
    }
    
    private func scaleFor(index: Int) -> CGFloat {
        if index == currentCanteenIndex {
            let scale = 1.0 - abs(dragOffset.width) / 2000
            return max(0.9, scale)
        }
        return 0.9
    }
    
    private func opacityFor(index: Int) -> Double {
        if index == currentCanteenIndex {
            return 1.0
        } else if index == currentCanteenIndex + 1 || index == currentCanteenIndex - 1 {
            return 0.5
        }
        return 0
    }
    
    private func zIndexFor(index: Int) -> Double {
        if index == currentCanteenIndex {
            return 10
        }
        return Double(-abs(index - currentCanteenIndex))
    }
    
    private func handleSwipe(_ translation: CGSize) {
        let threshold: CGFloat = 100
        
        if translation.width < -threshold && currentCanteenIndex < mealsByCanteen.count - 1 {
            // Swipe nach links → nächste Mensa
            currentCanteenIndex += 1
        } else if translation.width > threshold && currentCanteenIndex > 0 {
            // Swipe nach rechts → vorherige Mensa
            currentCanteenIndex -= 1
        }
        
        dragOffset = .zero
    }
    
    private var todayFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, dd. MMMM yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - Mensa Card

struct MensaCard: View {
    let canteenName: String
    let meals: [MensaMeal]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header mit Mensa-Name
            VStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                
                Text(canteenName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.1), Color.orange.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Gerichte-Liste
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(meals) { meal in
                        MensaMealCard(meal: meal)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        MensaView()
    }
}
