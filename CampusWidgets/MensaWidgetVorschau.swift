import SwiftUI
import WidgetKit

// MARK: - Previews

extension MensaEintrag {
    /// Ein Eintrag der Vorschau; das mittlere Widget bekommt Knopf und Punkte, außer bei fester Mensa.
    fileprivate static func vorschau(
        _ szenario: MensaWidgetVorschau.Szenario, fest: Bool = false, getoent: Bool = false, filter: MensaFilter? = nil
    ) -> MensaEintrag {
        MensaEintrag(
            date: .now,
            anzeige: MensaWidgetVorschau.anzeige(szenario, filter: filter),
            wechsel: fest ? nil : MensaWechsel(venue: szenario.mensa),
            getoentVorschau: getoent
        )
    }
}

// Die echten Widget-Previews: alle sieben Zustände als Zeitleiste. Hell und dunkel, Dynamic Type (auch „X Large“,
// wo ein Gericht weniger erscheint) und die Größe schaltet die Preview-Leiste (Varianten).

#Preview("Widget klein", as: .systemSmall) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario) }
}

#Preview("Widget mittel", as: .systemMedium) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario) }
}

#Preview("Widget groß", as: .systemLarge) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario) }
}

#Preview("Widget mittel, feste Mensa (ohne Knopf)", as: .systemMedium) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario, fest: true) }
}

// Getönt / Klar: Ohne Tönung des Systems zeigen diese Previews nur, was wegfällt (Bänder, Chip-Flächen).

#Preview("Getönt klein", as: .systemSmall) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario, getoent: true) }
}

#Preview("Getönt mittel", as: .systemMedium) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario, getoent: true) }
}

#Preview("Getönt groß", as: .systemLarge) {
    MensaWidget()
} timeline: {
    for szenario in MensaWidgetVorschau.Szenario.allCases { MensaEintrag.vorschau(szenario, getoent: true) }
}

// Filter aus der App (Schalter „Filter aus der App anwenden“): mit Filter um 11:45, und „nichts passt“ in allen Größen.

#Preview("Mit Filter mittel", as: .systemMedium) {
    MensaWidget()
} timeline: {
    MensaEintrag.vorschau(.mittag, filter: MensaWidgetVorschau.filterVeganOhneMilch)
}

#Preview("Mit Filter groß", as: .systemLarge) {
    MensaWidget()
} timeline: {
    MensaEintrag.vorschau(.mittag, filter: MensaWidgetVorschau.filterVeganOhneMilch)
}

#Preview("Nichts passt klein", as: .systemSmall) {
    MensaWidget()
} timeline: {
    MensaEintrag.vorschau(.mittag, filter: MensaWidgetVorschau.filterNichtsPasst)
}

#Preview("Nichts passt mittel", as: .systemMedium) {
    MensaWidget()
} timeline: {
    MensaEintrag.vorschau(.mittag, filter: MensaWidgetVorschau.filterNichtsPasst)
}

#Preview("Nichts passt groß", as: .systemLarge) {
    MensaWidget()
} timeline: {
    MensaEintrag.vorschau(.mittag, filter: MensaWidgetVorschau.filterNichtsPasst)
}
