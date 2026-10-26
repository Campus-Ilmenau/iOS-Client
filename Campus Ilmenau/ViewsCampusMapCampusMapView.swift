//
//  CampusMapView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct CampusMapView: View {
    var body: some View {
        VStack {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("Campus Karte")
                .font(.title)
                .padding()
            Text("Hier kommt die Karte")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Campus Karte")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        CampusMapView()
    }
}
