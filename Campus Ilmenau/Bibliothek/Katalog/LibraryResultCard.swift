import SwiftUI

extension LibraryAvailabilityStatus {
    /// Farbe des Badges nach `Uebergabe.md`: Ausleihbar und Online grün, Nur vor Ort blau, sonst neutral.
    var chipVariant: Chip.Variant {
        switch self {
        case .available, .online: .green
        case .referenceOnly: .blue
        case .onLoan, .unknown: .neutral
        }
    }
}

extension LibraryMediaType {
    /// Symbol im Platzhalter des Covers.
    var placeholderSymbol: String {
        switch self {
        case .printBook: "book"
        case .ebook: "ipad"
        case .journal: "newspaper"
        case .other: "doc"
        }
    }
}

/// Karte eines Treffers: Cover oder Platzhalter, Titel, Untertitel, „Personen · Jahr · Medienart“, Status-Badge
/// und bei Treffern aus dem Gesamtkatalog der Chip „Gesamtkatalog“.
struct LibraryResultCard: View {
    let media: LibraryMedia
    /// `nil`, solange die Verfügbarkeit noch lädt (grauer Platzhalter).
    let availability: LibraryAvailability?
    let fromCatalog: Bool
    /// Wird für die Hervorhebung im Ausschnitt gebraucht.
    let searchText: String
    let model: LibrarySearchModel

    private var statusText: String? {
        availability.map { $0.status.displayText(dueDate: $0.earliestDueDate) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LibraryCoverView(media: media, model: model)

            VStack(alignment: .leading, spacing: 0) {
                Text(media.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let subtitle = media.trimmedSubtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                        .lineLimit(1)
                        .padding(.top, 1)
                }

                Text(media.metaLine)
                    .font(.caption)
                    .foregroundStyle(Color(.textTertiary))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 3)

                chips
                    .padding(.top, 8)

                if let snippet = media.match?.snippet, !snippet.isEmpty {
                    LibrarySnippetView(match: media.match, snippet: snippet, searchText: searchText)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(media.title), \(statusText ?? "Verfügbarkeit wird geladen")")
    }

    private var chips: some View {
        ChipFlowLayout(spacing: 6) {
            if let availability {
                Chip(
                    LocalizedStringKey(availability.status.displayText(dueDate: availability.earliestDueDate)),
                    variant: availability.status.chipVariant
                )
            } else {
                LibrarySkeletonPill()
                    .accessibilityLabel("Verfügbarkeit wird geladen")
            }
            if fromCatalog {
                Chip("Gesamtkatalog", variant: .neutral)
            }
        }
    }
}

/// Cover 48 × 68 oder Platzhalter mit Symbol je Medienart (der Normalfall, es gibt nur wenige Cover).
struct LibraryCoverView: View {
    let media: LibraryMedia
    let model: LibrarySearchModel

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.surfaceSecondary)
                Image(systemName: media.mediaType.placeholderSymbol)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color(.textTertiary))
            }
        }
        .frame(width: 48, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .accessibilityHidden(true)
        .task(id: media.id) {
            guard media.cover.status == .found || media.cover.status == .pending else { return }
            image = await model.coverImage(for: media)
        }
    }
}

/// Grauer Platzhalter für den Status, bis die Verfügbarkeit da ist. Pulsiert, außer bei „Bewegung reduzieren“.
struct LibrarySkeletonPill: View {
    var width: CGFloat = 78
    var height: CGFloat = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        Capsule()
            .fill(Color(.surfaceSecondary))
            .frame(width: width, height: height)
            .opacity(dimmed ? 0.5 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { dimmed = true }
            }
    }
}

/// Karte aus grauen Flächen, während gesucht wird.
struct LibrarySkeletonCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(.surfaceSecondary))
                .frame(width: 48, height: 68)
            VStack(alignment: .leading, spacing: 8) {
                LibrarySkeletonPill(width: 200, height: 20)
                LibrarySkeletonPill(width: 120, height: 14)
                LibrarySkeletonPill()
            }
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Grauer Ausschnitt der Inhaltssuche: „Im Inhaltsverzeichnis … **Treffer** …“.
struct LibrarySnippetView: View {
    let match: LibraryMatch?
    let snippet: String
    let searchText: String

    private var label: String {
        if match?.isInTableOfContents == true { return "Im Inhaltsverzeichnis" }
        if match?.isInBlurb == true { return "Im Klappentext" }
        return "Im Text"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(.textTertiary))
            Text(Self.highlighted(snippet, term: searchText))
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Hebt das Suchwort im Ausschnitt fett hervor (ohne auf Groß- und Kleinschreibung zu achten).
    static func highlighted(_ snippet: String, term: String) -> AttributedString {
        var attributed = AttributedString(snippet)
        let words = term.split(whereSeparator: \.isWhitespace).map(String.init).filter { $0.count > 1 }
        for word in words {
            var searchStart = attributed.startIndex
            while let range = attributed[searchStart...].range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) {
                attributed[range].font = .footnote.bold()
                attributed[range].foregroundColor = Color(.textPrimary)
                searchStart = range.upperBound
            }
        }
        return attributed
    }
}
