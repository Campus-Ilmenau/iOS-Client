import SwiftUI

/// Karte einer Veranstaltung in der Liste: ohne Bild und Logo, nur Text.
/// Tippen öffnet das Detail, der Stern rechts merkt die Veranstaltung. Für VoiceOver ist die Karte ein Element,
/// „Merken“ bzw. „Gemerkt“ ist eine zusätzliche Aktion.
struct EventKarte: View {
    let event: CampusEvent
    /// Tag, unter dem die Karte steht; mehrtägige, die vorher begonnen haben, „laufen seit“.
    let bezugstag: Date
    let jetzt: Date
    /// iPad: Die Karte wählt die Veranstaltung rechts aus (kein Push), der Titel darf umbrechen, und die gewählte
    /// bekommt einen 2-pt-Rand in `accent`. Ohne `onWahl` gilt das Verhalten des iPhones.
    var onWahl: (() -> Void)?
    var gewaehlt = false

    @Environment(\.eventsMerkStore) private var merkStore

    private var formatter: EventZeitFormatter { EventZeitFormatter(jetzt: jetzt) }
    private var gemerkt: Bool { merkStore.istGemerkt(event.id) }
    private var abgesagt: Bool { event.status == .abgesagt }

    var body: some View {
        verweis
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                sternTaste
                    .padding(.top, 4)
                    .padding(.trailing, 4)
            }
            .overlay {
                if gewaehlt {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(.accent), lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(sprachtext)
            .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(named: gemerkt ? "Nicht mehr merken" : "Merken") { umschalten() }
    }

    /// iPhone: Verweis auf das Detail im Stapel. iPad: Taste, die die Auswahl setzt.
    @ViewBuilder
    private var verweis: some View {
        if let onWahl {
            Button(action: onWahl) { flaeche }
        } else {
            NavigationLink(value: EventsRoute.detail(event)) { flaeche }
        }
    }

    private var flaeche: some View {
        Card(verticalPadding: 12, horizontalPadding: 0) {
            inhalt
                .padding(.leading, 16)
                // Platz für den Stern (44 pt) und den Rand rechts.
                .padding(.trailing, 52)
        }
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
                .lineLimit(onWahl == nil ? 2 : nil)
                .multilineTextAlignment(.leading)
            if let ortZeile {
                Text(ortZeile)
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
                    .lineLimit(onWahl == nil ? 1 : nil)
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
        case .abgesagt: teile.append(LocalizedStringResource("fällt aus").inAppSprache)
        case .unbestaetigt: teile.append(LocalizedStringResource("noch nicht bestätigt").inAppSprache)
        case .findetStatt: break
        }
        if event.istFrist { teile.append(LocalizedStringResource("Frist").inAppSprache) }
        if gemerkt { teile.append(LocalizedStringResource("gemerkt").inAppSprache) }
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
        // Für VoiceOver liegt „Merken“ als Aktion an der Karte.
        .accessibilityHidden(true)
    }

    private func umschalten() {
        // Haptik direkt in der Aktion statt über `sensoryFeedback`: Im Filter „Gemerkt“ verschwindet
        // die Karte beim Entfernen, und ein Feedback auf der entfernten View stürzt ab.
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        merkStore.umschalten(event.id)
    }
}

/// Ziele im Navigationsstapel der Veranstaltungen.
enum EventsRoute: Hashable {
    case detail(CampusEvent)
    /// Detail nur mit ID (Deeplink aus dem Widget): Die Ansicht lädt die Veranstaltung selbst.
    case detailID(String)
    case vergangene
}
