import SwiftUI

/// Titel (höchstens 2 Zeilen) und Signatur links, Chip rechts. Bei großer Schrift rutscht der Chip unter den Titel.
struct PAIAItemTitleRow: View {
    let title: String
    let signature: String?
    let chipText: String?
    let chipVariant: Chip.Variant

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(2)
            if let signature {
                Text(signature)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Color(.textTertiary))
            }
        }
    }

    var body: some View {
        if dynamicTypeSize >= .xxLarge {
            VStack(alignment: .leading, spacing: 8) {
                titleBlock
                chip
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 10) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                chip
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var chip: some View {
        if let chipText {
            Chip(LocalizedStringKey(chipText), variant: chipVariant)
        }
    }
}

/// Karte für Vormerkungen, Bestellungen und Bereitstellungen: Titel, Signatur, Status-Chip und,
/// wenn der Server Daten dazu liefert, eine Zusatzzeile.
struct PAIAHoldCard: View {
    let item: PAIALoanItem
    /// Tippen öffnet die Details des Mediums. `nil`, wenn der Titel im Katalog nicht auffindbar ist.
    var onOpen: (() -> Void)?

    var body: some View {
        let info = BibliothekHoldInfo(item: item)
        Card {
            VStack(alignment: .leading, spacing: 8) {
                PAIAItemTitleRow(
                    title: item.displayTitle,
                    signature: item.signature,
                    chipText: info.statusText,
                    chipVariant: info.variant
                )
                if let detail = info.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color(.textTertiary))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(onOpen == nil ? [] : .isButton)
        .accessibilityHint(onOpen == nil ? "" : "Öffnet die Details des Mediums")
    }
}
