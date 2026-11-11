import AppIntents

/// Die Ernährungsform in einem Siri-Satz („Was gibt’s vegetarisch in der Mensa?“).
/// Die Rohwerte werden gespeichert: nicht umbenennen, nicht umsortieren.
enum Ernaehrung: String, AppEnum, CaseIterable {
    case vegetarisch
    case vegan

    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: LocalizedStringResource("Ernährung", table: "Siri")) }

    static var caseDisplayRepresentations: [Ernaehrung: DisplayRepresentation] {
        [
            .vegetarisch: DisplayRepresentation(
                title: LocalizedStringResource("Vegetarisch", table: "Siri"),
                synonyms: [LocalizedStringResource("Vegetarisches", table: "Siri"), LocalizedStringResource("vegetarisch", table: "Siri"), LocalizedStringResource("ohne Fleisch", table: "Siri"), LocalizedStringResource("fleischlos", table: "Siri")]
            ),
            .vegan: DisplayRepresentation(title: LocalizedStringResource("Vegan", table: "Siri"), synonyms: [LocalizedStringResource("Veganes", table: "Siri"), LocalizedStringResource("vegan", table: "Siri")]),
        ]
    }
}
