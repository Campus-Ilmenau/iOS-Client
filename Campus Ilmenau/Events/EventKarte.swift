import SwiftUI

/// Karte einer Veranstaltung in der Liste: ohne Bild und Logo, nur Text.
/// Tippen öffnet das Detail, der Stern rechts merkt die Veranstaltung. Für VoiceOver ist die Karte ein Element,
/// „Merken“ bzw. „Gemerkt“ ist eine zusätzliche Aktion.
struct EventKarte: View {
    let event: CampusEvent
    /// Tag, unter dem die Karte steht; mehrtägige, die vorher begonnen haben, „laufen seit“.
    let bezugstag: Date
    let jetzt: Date

    @Environment(\.eventsMerkStore) private var merkStore

    private var formatter: EventZeitFormatter { EventZeitFormatter(jetzt: jetzt) }
    private var gemerkt: Bool { merkStore.istGemerkt(event.id) }
    private var abgesagt: Bool { event.status == .abgesagt }

    var body: some View {
        NavigationLink(value: EventsRoute.detail(event)) {
            Card(verticalPadding: 12, horizontalPadding: 0) {
                inhalt
                    .padding(.leading, 16)
                    // Platz für den Stern (44 pt) und den Rand rechts.
                    .padding(.trailing, 52)
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            sternTaste
                .padding(.top, 4)
                .padding(.trailing, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprachtext)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: gemerkt ? "Nicht mehr merken" : "Merken") { umschalten() }
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatter.zeitzeile(event, bezugstag: bezugstag))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
            Text(event.titel)
                .font(.callout.weight(.semibold))
                .foregroundStyle(abgesagt ? Color(.textTertiary) : Color(.textPrimary))
                .strikethrough(abgesagt)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let ortZeile {
                Text(ortZeile)
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
                    .lineLimit(1)
            }
            if !chips.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        Chip(chip.titel, variant: chip.variante)
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// „Ort · Veranstalter“; fehlende Teile entfallen, der Veranstalter auch, wenn er dem Ort gleicht.
    private var ortZeile: String? {
        let teile = [event.ort, event.veranstalterAnzeigen].compactMap { $0 }.filter { !$0.isEmpty }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    /// Chips nur bei Abweichung. „Veranstaltung“ bekommt keinen.
    private var chips: [(titel: LocalizedStringKey, variante: Chip.Variant)] {
        var liste: [(titel: LocalizedStringKey, variante: Chip.Variant)] = []
        switch event.status {
        case .abgesagt: liste.append(("Fällt aus", .dangerSoft))
        case .unbestaetigt: liste.append(("Noch nicht bestätigt", .neutral))
        case .findetStatt: break
        }
        if event.istFrist { liste.append(("Frist", .blue)) }
        return liste
    }

    private var sprachtext: String {
        var teile = [event.titel, formatter.zeitzeile(event, bezugstag: bezugstag)]
        if let ortZeile { teile.append(ortZeile) }
        switch event.status {
        case .abgesagt: teile.append("fällt aus")
        case .unbestaetigt: teile.append("noch nicht bestätigt")
        case .findetStatt: break
        }
        if event.istFrist { teile.append("Frist") }
        if gemerkt { teile.append("gemerkt") }
        return teile.joined(separator: ", ")
    }

    private var sternTaste: some View {
        Button(action: umschalten) {
            Image(systemName: gemerkt ? "star.fill" : "star")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(gemerkt ? Color(.accent) : Color(.textTertiary))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: gemerkt)
        // Für VoiceOver liegt „Merken“ als Aktion an der Karte.
        .accessibilityHidden(true)
    }

    private func umschalten() {
        merkStore.umschalten(event.id)
    }
}

/// Ziele im Navigationsstapel der Veranstaltungen.
enum EventsRoute: Hashable {
    case detail(CampusEvent)
    case vergangene
}
