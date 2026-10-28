//
//  ViewsBibliothekPAIALoanItemRow.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 27.10.26.
//

import SwiftUI

/// Zeigt ein einzelnes ausgeliehenes, vorgemerktes oder bestelltes Medium an.
/// Bei laufenden Ausleihen (`status == .held`) wird eine kleine Fortschritts-
/// Timeline bis zur Fälligkeit angezeigt.
///
/// Nach links wischen verlängert die Leihfrist. Die Aktion wird erst beim
/// Loslassen ausgewertet (nicht während des Ziehens) — wer über den Button
/// hinauszieht und ohne loszulassen wieder zurückschiebt, löst nichts aus.
/// Haptisches Feedback markiert beim Ziehen das Erreichen des Buttons sowie
/// der Schwelle, ab der ein Loslassen die Verlängerung auslöst.
struct PAIALoanItemRow: View {
    let item: PAIALoanItem
    var onRenew: () -> Void

    private enum SwipeMetrics {
        static let actionWidth: CGFloat = 100
        static let triggerThreshold: CGFloat = 220
    }

    @State private var committedOffset: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var hasCrossedRevealThreshold = false
    @State private var hasCrossedTriggerThreshold = false
    @State private var revealHapticTick = false
    @State private var triggerHapticTick = false
    @State private var showRenewConfirmation = false

    private var canRenew: Bool { item.canrenew != false }
    private var mediaTitle: String { item.about ?? item.label ?? "dieses Medium" }
    private var currentOffset: CGFloat { min(0, committedOffset + dragTranslation) }

    var body: some View {
        ZStack(alignment: .trailing) {
            renewBackground

            rowContent
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .offset(x: currentOffset)
                .simultaneousGesture(dragGesture)
        }
        .listRowInsets(EdgeInsets())
        .alert("Leihfrist verlängern?", isPresented: $showRenewConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Verlängern") { onRenew() }
        } message: {
            Text("Möchtest du die Leihfrist für „\(mediaTitle)“ verlängern?")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: revealHapticTick)
        .sensoryFeedback(.impact(weight: .heavy), trigger: triggerHapticTick)
    }

    // MARK: - Swipe Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard canRenew, abs(value.translation.width) >= abs(value.translation.height) else { return }
                dragTranslation = value.translation.width
                updateHapticFlags()
            }
            .onEnded { value in
                guard canRenew, abs(value.translation.width) >= abs(value.translation.height) else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragTranslation = 0 }
                    return
                }

                let finalOffset = committedOffset + value.translation.width
                let shouldTrigger = finalOffset <= -SwipeMetrics.triggerThreshold
                let shouldReveal = finalOffset <= -SwipeMetrics.actionWidth / 2

                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dragTranslation = 0
                    committedOffset = (shouldReveal && !shouldTrigger) ? -SwipeMetrics.actionWidth : 0
                }

                hasCrossedRevealThreshold = false
                hasCrossedTriggerThreshold = false

                if shouldTrigger {
                    showRenewConfirmation = true
                }
            }
    }

    private func updateHapticFlags() {
        let offset = committedOffset + dragTranslation
        let crossedReveal = offset <= -SwipeMetrics.actionWidth
        let crossedTrigger = offset <= -SwipeMetrics.triggerThreshold

        if crossedReveal != hasCrossedRevealThreshold {
            hasCrossedRevealThreshold = crossedReveal
            revealHapticTick.toggle()
        }
        if crossedTrigger != hasCrossedTriggerThreshold {
            hasCrossedTriggerThreshold = crossedTrigger
            triggerHapticTick.toggle()
        }
    }

    // MARK: - Subviews

    private var renewBackground: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { committedOffset = 0 }
                showRenewConfirmation = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                    Text("Verlängern")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(width: SwipeMetrics.actionWidth)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue)
        .opacity(canRenew ? 1 : 0)
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.about ?? item.label ?? "Unbekanntes Medium")
                        .font(.headline)
                        .lineLimit(2)

                    if let label = item.label, item.about != nil {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                statusBadge
            }

            if item.status == .held, item.endtime != nil {
                VStack(alignment: .leading, spacing: 6) {
                    PAIALoanTimelineView(item: item)

                    HStack {
                        if let renewals = item.renewals, renewals > 0 {
                            Text("\(renewals)x verlängert")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let endtime = item.endtime {
                            Text("Fällig: \(endtime, style: .date)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isOverdue(endtime) ? .red : .secondary)
                        }
                    }
                }
            } else if let endtime = item.endtime {
                Text("Fällig: \(endtime, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusBadge: some View {
        Text(item.status.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch item.status {
        case .held:
            return isOverdue(item.endtime) ? .red : .blue
        case .provided:
            return .green
        case .reserved, .ordered:
            return .orange
        case .rejected:
            return .red
        case .none:
            return .gray
        }
    }

    private func isOverdue(_ date: Date?) -> Bool {
        guard let date else { return false }
        return date < Date()
    }
}

#Preview {
    List {
        PAIALoanItemRow(item: PAIALoanItem(
            item: "1",
            edition: nil,
            about: "Swift Programming Language",
            label: "ST 230 A123",
            queue: nil,
            renewals: 1,
            reminder: 0,
            starttime: .now.addingTimeInterval(-86400 * 16),
            endtime: .now.addingTimeInterval(86400 * 5),
            cancancel: false,
            canrenew: true,
            storage: nil,
            storageid: nil,
            comment: nil,
            status: .held
        ), onRenew: {})
        PAIALoanItemRow(item: PAIALoanItem(
            item: "2",
            edition: nil,
            about: "Overdue Book",
            label: "ST 100 B456",
            queue: nil,
            renewals: 0,
            reminder: 1,
            starttime: .now.addingTimeInterval(-86400 * 23),
            endtime: .now.addingTimeInterval(-86400 * 2),
            cancancel: false,
            canrenew: false,
            storage: nil,
            storageid: nil,
            comment: nil,
            status: .held
        ), onRenew: {})
    }
}
