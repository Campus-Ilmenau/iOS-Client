import SwiftUI

/// „Was du Siri fragen kannst“ in „Mehr“: die Sätze der App Shortcuts, nur als Text. Antippen spielt nichts ab.
/// Die Sätze müssen zu denen in `CampusShortcuts` und `AppShortcuts.xcstrings` passen; hier steht „Campus Ilmenau“
/// für den App-Namen (kürzer geht auch „Campus“).
struct SiriFragenView: View {
    struct Abschnitt: Identifiable {
        let titel: LocalizedStringResource
        let symbol: String
        let saetze: [LocalizedStringResource]
        var id: String { symbol }
    }

    /// Reihenfolge, Titel und Symbole wie in der Kurzbefehle-App. Die Texte stehen in der Tabelle `Siri.xcstrings`,
    /// damit sich die Oberfläche der App durch Übersetzungen für Siri nicht ändert.
    static let abschnitte: [Abschnitt] = [
        Abschnitt(titel: LocalizedStringResource("Mensa heute", table: "Siri"), symbol: "fork.knife", saetze: [
            LocalizedStringResource("„Was gibt’s heute in der Mensa bei Campus Ilmenau?“", table: "Siri"),
            LocalizedStringResource("„Was gibt’s zu essen in der Nanoteria bei Campus Ilmenau?“", table: "Siri"),
            LocalizedStringResource("„Was gibt’s heute Vegetarisches bei Campus Ilmenau?“", table: "Siri")
        ]),
        Abschnitt(titel: LocalizedStringResource("Hat die Mensa offen?", table: "Siri"), symbol: "clock", saetze: [
            LocalizedStringResource("„Hat die Mensa bei Campus Ilmenau offen?“", table: "Siri"),
            LocalizedStringResource("„Welche Mensa hat bei Campus Ilmenau offen?“", table: "Siri")
        ]),
        Abschnitt(titel: LocalizedStringResource("Abendessen", table: "Siri"), symbol: "fork.knife.circle", saetze: [
            LocalizedStringResource("„Gibt es heute Abendessen bei Campus Ilmenau?“", table: "Siri")
        ]),
        Abschnitt(titel: LocalizedStringResource("Heute Abend", table: "Siri"), symbol: "moon.fill", saetze: [
            LocalizedStringResource("„Was ist heute Abend los bei Campus Ilmenau?“", table: "Siri")
        ]),
        Abschnitt(titel: LocalizedStringResource("Im Katalog suchen", table: "Siri"), symbol: "text.magnifyingglass", saetze: [
            LocalizedStringResource("„Suche im Katalog von Campus Ilmenau“", table: "Siri")
        ]),
        Abschnitt(titel: LocalizedStringResource("Merkliste", table: "Siri"), symbol: "bookmark", saetze: [
            LocalizedStringResource("„Was steht auf meiner Merkliste bei Campus Ilmenau?“", table: "Siri")
        ]),
        Abschnitt(titel: LocalizedStringResource("Thoska auslesen", table: "Siri"), symbol: "wave.3.right", saetze: [
            LocalizedStringResource("„Lies meine Thoska mit Campus Ilmenau aus“", table: "Siri")
        ])
    ]

    var body: some View {
        List {
            ForEach(Self.abschnitte) { abschnitt in
                Section {
                    ForEach(Array(abschnitt.saetze.enumerated()), id: \.offset) { _, satz in
                        Text(satz)
                            .foregroundStyle(Color(.textPrimary))
                            .padding(.vertical, 4)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                } header: {
                    Label {
                        Text(abschnitt.titel)
                    } icon: {
                        Image(systemName: abschnitt.symbol)
                    }
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(Color(.textTertiary))
                }
            }
            .listRowBackground(Color(.surface))
            .listRowSeparatorTint(Color(.separator))

            Section {
                EmptyView()
            } footer: {
                Text("Statt „Campus Ilmenau“ geht auch „Campus“. Die Sätze gehen sofort, ohne Einrichtung. „Thoska auslesen“ geht nur auf dem iPhone.", tableName: "Siri")
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.background))
        .listSectionSpacing(.compact)
        .navigationTitle(Text("Was du Siri fragen kannst", tableName: "Siri"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Siri fragen – Light") {
    NavigationStack { SiriFragenView() }
        .preferredColorScheme(.light)
}

#Preview("Siri fragen – Dark") {
    NavigationStack { SiriFragenView() }
        .preferredColorScheme(.dark)
}
