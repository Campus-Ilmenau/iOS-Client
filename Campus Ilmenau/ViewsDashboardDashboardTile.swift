//
//  DashboardTile.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct DashboardTile: View {
    let item: DashboardItem
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Hintergrund
                RoundedRectangle(cornerRadius: 16)
                    .fill(item.color.gradient)
                
                // Titel oben rechts
                Text(item.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(12)
                    .multilineTextAlignment(.trailing)
            }
        }
        .aspectRatio(1.618, contentMode: .fit) // Goldener Schnitt (Breite > Höhe)
        .shadow(color: item.color.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
