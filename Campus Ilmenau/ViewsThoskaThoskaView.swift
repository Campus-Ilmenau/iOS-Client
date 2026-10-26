//
//  ThoskaView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct ThoskaView: View {
    var body: some View {
        VStack {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("Thoska Guthaben")
                .font(.title)
                .padding()
            Text("Hier kommt das Guthaben")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Thoska")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        ThoskaView()
    }
}
