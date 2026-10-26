//
//  BadgeView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI

struct BadgeView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .clipShape(Capsule())
    }
    
    private var badgeColor: Color {
        switch text.lowercased() {
        case "vegan":
            return .green
        case "vegetarisch":
            return .mint
        case "bio":
            return .brown
        default:
            return .blue
        }
    }
}

#Preview {
    HStack {
        BadgeView(text: "Vegan")
        BadgeView(text: "Vegetarisch")
        BadgeView(text: "Bio")
    }
}
