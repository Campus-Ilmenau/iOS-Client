//
//  ContentView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 02.09.26.
//

import SwiftUI
import Combine

struct ContentView: View {
    @State private var currentDate = Date()
    
    // Timer für automatische Datum-Aktualisierung
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    // Dashboard-Kacheln
    private let dashboardItems: [DashboardItem] = [
        DashboardItem(
            title: "Mensa Essen",
            color: .orange,
            destination: MensaView()
        ),
        DashboardItem(
            title: "Thoska Guthaben",
            color: .blue,
            destination: ThoskaView()
        ),
        DashboardItem(
            title: "Stundenplan",
            color: .green,
            destination: StundenplanView()
        ),
        DashboardItem(
            title: "Bibliothek",
            color: .purple,
            destination: BibliothekView()
        ),
        DashboardItem(
            title: "Campus Karte",
            color: .red,
            destination: CampusMapView()
        ),
        DashboardItem(
            title: "ÖPNV",
            color: .teal,
            destination: OEPNVView()
        )
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header mit Begrüßung
                    VStack(spacing: 8) {
                        Text(greeting)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Adaptives Grid mit Kacheln
                    LazyVGrid(
                        columns: gridColumns,
                        spacing: 16
                    ) {
                        ForEach(dashboardItems) { item in
                            NavigationLink(destination: item.destination) {
                                DashboardTile(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
        }
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }
    
    // Adaptives Grid: iPhone 2 Spalten, iPad mehr
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]
    }
    
    // Tagesabhängige Begrüßung
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        
        switch hour {
        case 0..<6:
            return "Hallo Nachteule"
        case 6..<12:
            return "Moin!"
        case 12..<18:
            return "Guten Tag"
        case 18..<22:
            return "Guten Abend"
        default:
            return "Hallo Nachteule"
        }
    }
    
    // Formatiertes Datum: "Montag der 26. Okt. 2026"
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE 'der' dd. MMM yyyy"
        return formatter.string(from: currentDate)
    }
}

#Preview {
    ContentView()
}
