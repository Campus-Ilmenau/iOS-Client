//
//  ViewsBibliothekPAIALoanItemRow.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 27.10.26.
//

import SwiftUI

/// Karte einer laufenden Ausleihe: Titel, Signatur, Fälligkeits-Chip, Zeitleiste und Fußzeile mit „Verlängern“.
///
/// Nach links wischen verlängert die Leihfrist. Die Aktion wird erst beim
/// Loslassen ausgewertet (nicht während des Ziehens) — wer über den Button
/// hinauszieht und ohne loszulassen wieder zurückschiebt, löst nichts aus.
/// Haptisches Feedback markiert beim Ziehen das Erreichen des Buttons sowie
/// der Schwelle, ab der ein Loslassen die Verlängerung auslöst.
/// Ist das Medium laut Server nicht verlängerbar, gibt es weder Wischen noch Button.
struct PAIALoanItemRow: View {
    let item: PAIALoanItem
    var now: Date = .now
    var onRenew: () -> Void
    /// Tippen auf die Karte öffnet die Details des Mediums. `nil`, wenn der Titel im Katalog nicht auffindbar ist.
    var onOpen: (() -> Void)?

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

    private var info: BibliothekLoanInfo { BibliothekLoanInfo(item: item, now: now) }
    private var canRenew: Bool { item.canBeRenewed }
    private var currentOffset: CGFloat { min(0, committedOffset + dragTranslation) }

    private var chipVariant: Chip.Variant {
        switch info.urgency {
        case .normal: .neutral
        case .soon: .warning
        case .urgent: .dangerSoft
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if canRenew {
                renewBackground
                    .opacity(currentOffset < 0 ? 1 : 0)
            }

            front
                .offset(x: currentOffset)
                .simultaneousGesture(dragGesture)
                .modifier(OpenDetailsModifier(onOpen: onOpen, isRevealed: committedOffset < 0) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { committedOffset = 0 }
                })
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .alert("Leihfrist verlängern?", isPresented: $showRenewConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Verlängern") { onRenew() }
        } message: {
            Text("Möchtest du die Leihfrist für „\(item.displayTitle)“ verlängern?")
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

    /// Fläche hinter der Karte. Für VoiceOver versteckt, dort gibt es den Button in der Fußzeile.
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
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Color(.onButtonPrimary))
                .frame(width: SwipeMetrics.actionWidth)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.buttonPrimary))
        .accessibilityHidden(true)
    }

    private var front: some View {
        VStack(alignment: .leading, spacing: 0) {
            PAIAItemTitleRow(
                title: item.displayTitle,
                signature: item.signature,
                chipText: info.dueText,
                chipVariant: chipVariant
            )

            if info.days != nil {
                PAIALoanTimelineView(info: info)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
            } else {
                Spacer().frame(height: 10)
            }

            HStack(spacing: 8) {
                Text(info.metaText)
                    .font(.caption)
                    .foregroundStyle(Color(.textTertiary))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if canRenew {
                    SecondaryButton("Verlängern", compact: true) {
                        showRenewConfirmation = true
                    }
                }
            }
            .frame(minHeight: 36)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.surface))
    }
}

/// Tippen öffnet die Details. Ist gerade die Fläche „Verlängern“ aufgewischt, schließt das Tippen sie nur wieder.
private struct OpenDetailsModifier: ViewModifier {
    let onOpen: (() -> Void)?
    let isRevealed: Bool
    let close: () -> Void

    func body(content: Content) -> some View {
        if let onOpen {
            content
                .contentShape(Rectangle())
                .onTapGesture {
                    if isRevealed { close() } else { onOpen() }
                }
                .accessibilityAction(named: "Details öffnen", onOpen)
        } else {
            content
        }
    }
}
