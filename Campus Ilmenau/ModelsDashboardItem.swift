//
//  DashboardItem.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct DashboardItem: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
    let destination: AnyView
    
    init(title: String, color: Color, destination: some View) {
        self.title = title
        self.color = color
        self.destination = AnyView(destination)
    }
}
