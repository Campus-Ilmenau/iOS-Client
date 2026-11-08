import SwiftUI
import WidgetKit

// MARK: - Previews

extension AbendEintrag {
    /// Ein Eintrag der Vorschau.
    fileprivate static func vorschau(_ szenario: AbendWidgetVorschau.Szenario, getoent: Bool = false) -> AbendEintrag {
        AbendEintrag(date: .now, anzeige: AbendWidgetVorschau.anzeige(szenario), getoentVorschau: getoent)
    }
}

// Die echten Widget-Previews: je Größe die vier Zustände als Zeitleiste. Hell und dunkel sowie Dynamic Type
// (auch „X Large“, wo eine Zeile weniger erscheint) schaltet die Preview-Leiste (Varianten).

#Preview("Abend klein", as: .systemSmall) {
    AbendWidget()
} timeline: {
    for szenario in AbendWidgetVorschau.Szenario.allCases { AbendEintrag.vorschau(szenario) }
}

#Preview("Abend mittel", as: .systemMedium) {
    AbendWidget()
} timeline: {
    for szenario in AbendWidgetVorschau.Szenario.allCases { AbendEintrag.vorschau(szenario) }
}

#Preview("Abend groß", as: .systemLarge) {
    AbendWidget()
} timeline: {
    for szenario in AbendWidgetVorschau.Szenario.allCases { AbendEintrag.vorschau(szenario) }
}

// Getönt / Klar: Ohne Tönung des Systems zeigen diese Previews nur, was wegfällt (Nachtfläche, Chip-Flächen).

#Preview("Abend getönt klein", as: .systemSmall) {
    AbendWidget()
} timeline: {
    for szenario in AbendWidgetVorschau.Szenario.allCases { AbendEintrag.vorschau(szenario, getoent: true) }
}

#Preview("Abend getönt mittel", as: .systemMedium) {
    AbendWidget()
} timeline: {
    for szenario in AbendWidgetVorschau.Szenario.allCases { AbendEintrag.vorschau(szenario, getoent: true) }
}

#Preview("Abend getönt groß", as: .systemLarge) {
    AbendWidget()
} timeline: {
    for szenario in AbendWidgetVorschau.Szenario.allCases { AbendEintrag.vorschau(szenario, getoent: true) }
}

// Sperrbildschirm: Zeile, Rechteck und Kreis, je mit den vier Zuständen (18:30, 19:40, 23:50, leer).

#Preview("Abend Zeile", as: .accessoryInline) {
    AbendWidget()
} timeline: {
    for szenario in AbendWidgetVorschau.Szenario.allCases { AbendEintrag.vorschau(szenario) }
}

#Preview("Abend Rechteck", as: .accessoryRectangular) {
    AbendWidget()
} timeline: {
    for szenario in AbendWidgetVorschau.Szenario.allCases { AbendEintrag.vorschau(szenario) }
}

#Preview("Abend Kreis", as: .accessoryCircular) {
    AbendWidget()
} timeline: {
    for szenario in AbendWidgetVorschau.Szenario.allCases { AbendEintrag.vorschau(szenario) }
}
