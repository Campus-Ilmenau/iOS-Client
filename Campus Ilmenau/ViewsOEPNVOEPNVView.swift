//
//  OEPNVView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct OEPNVView: View {
    var body: some View {
        VStack {
            Image(systemName: "bus.fill")
                .font(.system(size: 60))
                .foregroundStyle(.teal)
            Text("ÖPNV")
                .font(.title)
                .padding()
            Text("Hier kommen die Verbindungen")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("ÖPNV")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        OEPNVView()
    }
}
