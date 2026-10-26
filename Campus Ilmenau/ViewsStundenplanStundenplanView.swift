//
//  StundenplanView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct StundenplanView: View {
    var body: some View {
        VStack {
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("Stundenplan")
                .font(.title)
                .padding()
            Text("Hier kommt der Stundenplan")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Stundenplan")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        StundenplanView()
    }
}
