//
//  Campus_IlmenauApp.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 02.09.26.
//

import SwiftUI
import SwiftData

@main
struct Campus_IlmenauApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ThoskaBalanceRecord.self, ThoskaCardName.self])
    }
}
