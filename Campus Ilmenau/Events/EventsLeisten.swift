import SwiftUI

/// Kopf der Ansicht: Titel in Font.display 34, Unterzeile und die runde Filter-Taste (44 pt).
/// Bei „Vergangene“ steht darüber „‹ Kommende“.
struct EventsKopf: View {
    let titel: LocalizedStringKey
    let unterzeile: String
    let filterAnzahl: Int
    var zurueckTitel: LocalizedStringKey?
    var onZurueck: (() -> Void)?
    let onFilter: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let zurueckTitel, let onZurueck {
                    Button(action: onZurueck) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.body.weight(.semibold))
                            Text(zurueckTitel)
                        }
                        .foregroundStyle(Color(.accent))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Text(titel)
                    .display(size: 34, relativeTo: .largeTitle)
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityAddTraits(.isHeader)
                Text(unterzeile)
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            filterTaste
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    /// Runde Taste. Ist im Sheet etwas gesetzt, ist sie gefüllt (`buttonPrimary`) und zeigt die Zahl in `accent`.
    private var filterTaste: some View {
        Button(action: onFilter) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(filterAnzahl > 0 ? Color(.onButtonPrimary) : Color(.textPrimary))
                    .frame(width: 44, height: 44)
                    .background(filterAnzahl > 0 ? Color(.buttonPrimary) : Color(.surfaceSecondary), in: Circle())
                if filterAnzahl > 0 {
                    FilterCountBadge(count: filterAnzahl)
                        .offset(x: 2, y: -2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filterAnzahl > 0 ? "Filter, \(filterAnzahl) aktiv" : "Filter")
    }
}

/// Tagesleiste, 56 pt hoch: „Ab heute“, „Heute“, „Morgen“, „Sa 31“ … für 14 Tage.
/// Ein kleiner Punkt unter dem Tag zeigt, dass etwas stattfindet.
struct EventsTagesleiste: View {
    let tage: [Date]
    let gewaehlterTag: Date?
    let tageMitEvents: Set<Date>
    let jetzt: Date
    let onWahl: (Date?) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                taste(tag: nil)
                ForEach(tage, id: \.self) { tag in
                    taste(tag: tag)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tag")
    }

    private func taste(tag: Date?) -> some View {
        let gewaehlt = tag == gewaehlterTag
        let hatEvents = tag.map(tageMitEvents.contains) ?? false
        let formatter = EventZeitFormatter(jetzt: jetzt)
        let heute = EventKalender.tagesbeginn(jetzt)

        return Button {
            onWahl(tag)
        } label: {
            VStack(spacing: 1) {
                Text(oben(tag: tag, heute: heute))
                    .font(tag == nil ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                if let tag, tag >= EventKalender.tag(heute, plus: 2) {
                    Text(EventKalender.format(tag, "d"))
                        .display(size: 18, relativeTo: .headline)
                }
                Circle()
                    .fill(gewaehlt ? Color(.onButtonPrimary) : Color(.accent))
                    .frame(width: 4, height: 4)
                    .opacity(hatEvents ? 1 : 0)
            }
            .foregroundStyle(gewaehlt ? Color(.onButtonPrimary) : Color(.textPrimary))
            .padding(.horizontal, 10)
            .frame(minWidth: 52, minHeight: 56)
            .background(
                gewaehlt ? Color(.buttonPrimary) : Color(.surface),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            tag.map { formatter.abschnittstitel(fuer: $0) + (hatEvents ? ", mit Veranstaltungen" : "") }
                ?? "Alles ab heute"
        )
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    private func oben(tag: Date?, heute: Date) -> String {
        guard let tag else { return "Ab heute" }
        if tag == heute { return "Heute" }
        if tag == EventKalender.tag(heute, plus: 1) { return "Morgen" }
        return EventKalender.format(tag, "EEE").replacingOccurrences(of: ".", with: "")
    }
}

/// Chipleiste: „Heute Abend“, „Gemerkt“, Trenner und je Veranstalter ein Chip mit der Zahl kommender Veranstaltungen.
struct EventsChipleiste: View {
    let auswahl: EventsAuswahl
    let veranstalter: [Veranstalter]
    let onHeuteAbend: () -> Void
    let onGemerkt: () -> Void
    let onVeranstalter: (Veranstalter) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                pille("Heute Abend", systemImage: "moon", aktiv: auswahl.heuteAbend, action: onHeuteAbend)
                pille("Gemerkt", systemImage: "star.fill", aktiv: auswahl.nurGemerkt, action: onGemerkt)
                if !veranstalter.isEmpty {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1, height: 26)
                        .padding(.horizontal, 2)
                        .accessibilityHidden(true)
                }
                ForEach(veranstalter) { eintrag in
                    pille(
                        eintrag.name,
                        zahl: eintrag.anzahlKommende,
                        aktiv: auswahl.veranstalterID == eintrag.id
                    ) {
                        onVeranstalter(eintrag)
                    }
                    .accessibilityLabel("\(eintrag.name), \(eintrag.anzahlKommende) kommende")
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func pille(
        _ titel: String,
        systemImage: String? = nil,
        zahl: Int? = nil,
        aktiv: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(titel)
                    .font(.subheadline.weight(.semibold))
                if let zahl {
                    Text("\(zahl)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(aktiv ? Color(.onButtonPrimary).opacity(0.7) : Color(.textTertiary))
                }
            }
            .lineLimit(1)
            .foregroundStyle(aktiv ? Color(.onButtonPrimary) : Color(.textPrimary))
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(aktiv ? Color(.buttonPrimary) : Color(.surface), in: Capsule())
            .overlay(Capsule().strokeBorder(aktiv ? Color(.buttonPrimary) : Color(.separator), lineWidth: 1))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }
}
