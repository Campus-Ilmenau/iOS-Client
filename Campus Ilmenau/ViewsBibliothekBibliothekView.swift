//
//  BibliothekView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct BibliothekView: View {
    var body: some View {
        VStack {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)
            Text("Bibliothek")
                .font(.title)
                .padding()
            Text("Hier kommt die Bibliothekssuche")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Bibliothek")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        BibliothekView()
    }
}
