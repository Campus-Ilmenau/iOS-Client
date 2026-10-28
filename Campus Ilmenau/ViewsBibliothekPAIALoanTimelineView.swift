//
//  ViewsBibliothekPAIALoanTimelineView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 28.10.26.
//

import SwiftUI

/// Kleine Fortschritts-Timeline für eine laufende Ausleihe (Standardlaufzeit
/// 3 Wochen pro Leihperiode). Die Farbe zeigt die Dringlichkeit: Schwarz bei
/// ausreichend Zeit, Orange ab 5 Tagen und Rot ab 3 Tagen vor Fälligkeit.
///
/// Am Anfang der Linie steht ein Punkt-Cluster: ein Punkt für die
/// Erstausleihe plus ein weiterer pro Verlängerung, eng mit kleinem Abstand
/// aneinandergereiht. Der Fortschritt wird nur zwischen dem letzten
/// Cluster-Punkt (Start der aktuellen Leihperiode) und dem End-Punkt
/// (Fälligkeit) angezeigt.
struct PAIALoanTimelineView: View {
    let item: PAIALoanItem

    private static let loanDuration: TimeInterval = 21 * 24 * 60 * 60
    private static let clusterDotSpacing: CGFloat = 9
    private static let dotDiameter: CGFloat = 6

    private var endDate: Date? { item.endtime }

    /// Start der aktuellen Leihperiode — bei jeder Verlängerung verschiebt
    /// sich dieser Zeitpunkt, da nur die neue Fälligkeit bekannt ist.
    private var currentPeriodStart: Date {
        endDate?.addingTimeInterval(-Self.loanDuration) ?? Date()
    }

    private var progress: Double {
        guard let endDate else { return 0 }
        let total = endDate.timeIntervalSince(currentPeriodStart)
        guard total > 0 else { return 1 }
        let elapsed = Date().timeIntervalSince(currentPeriodStart)
        return min(max(elapsed / total, 0), 1)
    }

    private var daysRemaining: Int? {
        guard let endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: endDate).day
    }

    private var urgencyColor: Color {
        guard let daysRemaining else { return .black }
        if daysRemaining <= 3 { return .red }
        if daysRemaining <= 5 { return .orange }
        return .black
    }

    /// Erstausleihe + eine Verlängerung = ein weiterer Punkt im Cluster.
    private var startDotCount: Int { (item.renewals ?? 0) + 1 }

    private var lastClusterDotX: CGFloat {
        CGFloat(startDotCount - 1) * Self.clusterDotSpacing
    }

    private var endDotColor: Color {
        progress >= 1 ? urgencyColor : Color(.systemGray4)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 4)

                // Zwischen den Cluster-Punkten liegt immer vollständig vergangene
                // Zeit (frühere Leihperioden) — dieser Abschnitt ist immer gefüllt.
                Capsule()
                    .fill(urgencyColor)
                    .frame(width: lastClusterDotX, height: 4)

                Capsule()
                    .fill(urgencyColor)
                    .frame(width: fillWidth(totalWidth: geometry.size.width), height: 4)
                    .offset(x: lastClusterDotX)

                ForEach(0..<startDotCount, id: \.self) { index in
                    Circle()
                        .fill(urgencyColor)
                        .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                        .position(x: CGFloat(index) * Self.clusterDotSpacing, y: 3)
                }

                Circle()
                    .fill(endDotColor)
                    .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                    .position(x: geometry.size.width, y: 3)
            }
            .frame(height: 6)
        }
        .frame(height: 6)
    }

    private func fillWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, (totalWidth - lastClusterDotX) * progress)
    }
}

#Preview {
    VStack(spacing: 24) {
        PAIALoanTimelineView(item: .preview(daysRemaining: 14, renewals: 0))
        PAIALoanTimelineView(item: .preview(daysRemaining: 14, renewals: 1))
        PAIALoanTimelineView(item: .preview(daysRemaining: 4, renewals: 2))
        PAIALoanTimelineView(item: .preview(daysRemaining: 2, renewals: 0))
    }
    .padding()
}

private extension PAIALoanItem {
    static func preview(daysRemaining: Int, renewals: Int) -> PAIALoanItem {
        PAIALoanItem(
            item: "preview",
            edition: nil,
            about: "Vorschau",
            label: nil,
            queue: nil,
            renewals: renewals,
            reminder: 0,
            starttime: .now.addingTimeInterval(-21 * 86400 + Double(daysRemaining) * 86400),
            endtime: .now.addingTimeInterval(Double(daysRemaining) * 86400),
            cancancel: false,
            canrenew: true,
            storage: nil,
            storageid: nil,
            comment: nil,
            status: .held
        )
    }
}
