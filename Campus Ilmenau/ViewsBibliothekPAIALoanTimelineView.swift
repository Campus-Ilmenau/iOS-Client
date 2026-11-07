//
//  ViewsBibliothekPAIALoanTimelineView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 28.10.26.
//

import SwiftUI

/// Zeitleiste einer laufenden Ausleihe (Standard-Leihfrist 3 Wochen pro Periode).
///
/// Links ein Punkt für die Erstausleihe und je einer pro Verlängerung, dann der Strich mit dem Fortschritt
/// der aktuellen Leihperiode, rechts der Fälligkeitspunkt (bei überfällig gefüllt).
/// Strich und Fälligkeitspunkt haben die Farbe der Dringlichkeit, die Startpunkte bleiben `textTertiary`.
struct PAIALoanTimelineView: View {
    let info: BibliothekLoanInfo

    private var tint: Color {
        switch info.urgency {
        case .normal: Color(.textSecondary)
        case .soon: Color(.warningFill)
        case .urgent: Color(.danger)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0...info.renewals, id: \.self) { _ in
                    Circle()
                        .fill(Color(.textTertiary))
                        .frame(width: 6, height: 6)
                }
            }

            Capsule()
                .fill(Color(.surfaceSecondary))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * info.progress)
                    }
                }

            Circle()
                .strokeBorder(tint, lineWidth: 2)
                .background(Circle().fill(info.isOverdue ? tint : .clear))
                .frame(width: 10, height: 10)
        }
        .frame(height: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(info.timelineLabel)
        .accessibilityAddTraits(.isImage)
    }
}
