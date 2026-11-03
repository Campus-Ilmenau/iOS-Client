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
            .foregroundStyle(badgeForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .clipShape(Capsule())
    }
    
    private var badgeForeground: Color {
        switch text.lowercased() {
        case "vegan":
            return Color(.onGreen)
        case "vegetarisch":
            return Color(.textPrimary)
        default:
            return Color(.onBlue)
        }
    }

    private var badgeColor: Color {
        switch text.lowercased() {
        case "vegan":
            return Color(.green)
        case "vegetarisch":
            return Color(.greenSoft)
        case "bio":
            return Color(.brandDusk)
        default:
            return Color(.blue)
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
