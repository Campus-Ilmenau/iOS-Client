//
//  ThoskaView.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import SwiftUI
import SwiftData
import CoreNFC

/// Verdrahtet die Oberfläche mit dem NFC-Reader und legt bei jedem erfolgreichen Auslesen einen Verlaufseintrag an.
/// Die Auslese-Logik liegt unverändert in `ThoskaCardReader`.
struct ThoskaView: View {
    @StateObject private var reader = ThoskaCardReader()
    @Environment(\.modelContext) private var modelContext
    @Query private var cardNames: [ThoskaCardName]
    /// Bleibt nach dem ersten erfolgreichen Auslesen sichtbar, bis die Ansicht verlassen wird.
    @State private var showsConfirmation = false
    /// Wunsch aus dem Link `campusilmenau://thoska/auslesen`: Auslesen sofort starten.
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ThoskaScreen(
            balance: reader.balance,
            cardName: reader.balance.flatMap { ThoskaCardNaming.customName(for: $0.cardId, names: cardNames) },
            onRenameCard: { cardId, name in
                ThoskaCardNaming.rename(cardId: cardId, to: name, names: cardNames, context: modelContext)
            },
            showsConfirmation: showsConfirmation,
            isScanning: reader.isScanning,
            isNFCAvailable: NFCTagReaderSession.readingAvailable,
            errorMessage: reader.errorMessage,
            onScan: { reader.scan() }
        )
        .onChange(of: reader.balance?.scannedAt) { _, newValue in
            guard newValue != nil, let balance = reader.balance else { return }
            showsConfirmation = true
            // Jedes erfolgreiche Auslesen landet im Verlauf. Die Daten bleiben nur auf dem Gerät.
            modelContext.insert(ThoskaBalanceRecord(balance))
        }
        .onAppear { startetAuslesenAufWunsch() }
        .onChange(of: router?.thoskaAuslesen) { _, _ in startetAuslesenAufWunsch() }
        .onChange(of: scenePhase) { _, _ in startetAuslesenAufWunsch() }
    }

    /// Startet das NFC-Sheet, wenn ein Link es wünscht. Die Sitzung braucht eine aktive App; bei einem Kaltstart
    /// über den Link wartet der Wunsch, bis die Szene aktiv ist.
    private func startetAuslesenAufWunsch() {
        guard router?.thoskaAuslesen == true, scenePhase == .active else { return }
        router?.thoskaAuslesen = false
        reader.scan()
    }
}

/// Die Oberfläche der Ansicht „Thoska“ ohne eigene Logik, damit sie sich in Previews in jedem Zustand zeigen lässt.
struct ThoskaScreen: View {
    let balance: ThoskaBalance?
    var cardName: String?
    var onRenameCard: (_ cardId: String, _ name: String) -> Void = { _, _ in }
    let showsConfirmation: Bool
    let isScanning: Bool
    let isNFCAvailable: Bool
    let errorMessage: String?
    let onScan: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var renamingCardId: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                ThoskaBalanceCard(balanceText: balanceText, accessibilityText: cardAccessibilityText, cardName: cardName)
                infoCard
                renameButton
                if showsConfirmation {
                    confirmationCard
                }
                // Bei den größten Schriftgrößen würde ein fester Fuß den Bildschirm füllen: dann scrollt er mit.
                if dynamicTypeSize.isAccessibilitySize {
                    footer
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !dynamicTypeSize.isAccessibilitySize {
                footer
            }
        }
        .background(Color(.background))
        // Vorläufig: Die Navigationsleiste bleibt für den Zurück-Pfeil, bis die TabBar die Navigation übernimmt.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Teile

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("Thoska")
                .display(size: 34, relativeTo: .largeTitle)
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            NavigationLink {
                ThoskaHistoryView()
            } label: {
                Text("Verlauf")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.accent))
                    .frame(minHeight: 44)
            }
        }
        .padding(.top, 4)
    }

    private var infoCard: some View {
        Card {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                infoColumn(title: "Zuletzt ausgelesen", value: lastReadText)
                infoColumn(title: "Letzte Buchung", value: lastTransactionText)
            }
        }
    }

    /// Erst nach dem Auslesen, denn der Name hängt an der Karten-ID.
    @ViewBuilder
    private var renameButton: some View {
        if let balance {
            Button {
                renamingCardId = balance.cardId
            } label: {
                Text(cardName == nil ? "Karte benennen" : "Karte umbenennen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.accent))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 2)
            }
            .thoskaRenameAlert(
                renamingCardId: $renamingCardId,
                currentName: { _ in cardName },
                onSave: onRenameCard
            )
        }
    }

    private func infoColumn(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color(.textTertiary))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.textPrimary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var confirmationCard: some View {
        Card(fill: Color(.green)) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .accessibilityHidden(true)
                Text("Guthaben aktualisiert")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Color(.onGreen))
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Text("Halte deine Thoska an die Oberseite deines iPhones. Das Guthaben wird nur auf deinem Gerät gespeichert.")
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            PrimaryButton("Thoska auslesen", systemImage: "wave.3.right", action: onScan)
                .disabled(!isNFCAvailable || isScanning)

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.background))
    }

    // MARK: - Texte

    private var balanceText: String {
        balance.map { ThoskaFormatting.euro($0.balance) } ?? "–,– €"
    }

    private var cardAccessibilityText: String {
        balance.map { "Thoska-Guthaben \(ThoskaFormatting.spokenEuro($0.balance))" + (cardName.map { ", Karte \($0)" } ?? "") }
            ?? "Thoska-Guthaben noch nicht ausgelesen"
    }

    private var lastReadText: String {
        balance.map { ThoskaFormatting.lastRead($0.scannedAt) } ?? "Noch nicht ausgelesen"
    }

    private var lastTransactionText: String {
        balance.map { ThoskaFormatting.euro($0.lastTransaction) } ?? "–"
    }

    /// Ohne NFC steht hier der Grund, sonst die Meldung des Readers (Karte nicht erkannt usw.).
    private var statusMessage: String? {
        isNFCAvailable ? errorMessage : ThoskaCardReaderError.nfcNotAvailable.localizedDescription
    }
}

// MARK: - Previews

private extension ThoskaBalance {
    static func sample(scannedAt: Date = .now.addingTimeInterval(-3600)) -> ThoskaBalance {
        ThoskaBalance(cardId: "04a1b2c3d4", balance: 12.40, lastTransaction: 2.90, scannedAt: scannedAt)
    }
}

private struct ThoskaScreenPreview: View {
    var balance: ThoskaBalance? = .sample()
    var cardName: String?
    var showsConfirmation = false
    var isNFCAvailable = true
    var errorMessage: String?

    var body: some View {
        NavigationStack {
            ThoskaScreen(
                balance: balance,
                cardName: cardName,
                showsConfirmation: showsConfirmation,
                isScanning: false,
                isNFCAvailable: isNFCAvailable,
                errorMessage: errorMessage,
                onScan: {}
            )
        }
        .modelContainer(for: [ThoskaBalanceRecord.self, ThoskaCardName.self], inMemory: true)
    }
}

#Preview("Light") {
    ThoskaScreenPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    ThoskaScreenPreview().preferredColorScheme(.dark)
}

#Preview("Mit Kartenname") {
    ThoskaScreenPreview(cardName: "Mensakarte")
}

#Preview("Leer") {
    ThoskaScreenPreview(balance: nil)
}

#Preview("Nach dem Auslesen") {
    ThoskaScreenPreview(balance: .sample(scannedAt: .now), showsConfirmation: true)
}

#Preview("Fehler") {
    ThoskaScreenPreview(errorMessage: "Dieser Kartentyp wird nicht unterstützt.")
}

#Preview("Ohne NFC") {
    ThoskaScreenPreview(balance: nil, isNFCAvailable: false)
}

#Preview("Große Schrift") {
    ThoskaScreenPreview(showsConfirmation: true)
        .dynamicTypeSize(.xxxLarge)
}

#Preview("Größte Schrift (AX5)") {
    ThoskaScreenPreview(showsConfirmation: true)
        .dynamicTypeSize(.accessibility5)
}
