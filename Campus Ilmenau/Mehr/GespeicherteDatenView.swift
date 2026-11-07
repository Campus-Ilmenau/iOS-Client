import SwiftUI
import SwiftData

/// „Gespeicherte Daten“ unter „Mehr“: zeigt alles, was die App auf diesem Gerät ablegt, und nennt auch,
/// was bewusst nur im Speicher bleibt. Die Ansicht liest nur und ändert nichts.
struct GespeicherteDatenView: View {
    @Query(sort: \ThoskaBalanceRecord.scannedAt) private var auslesungen: [ThoskaBalanceRecord]
    @Query private var kartenNamen: [ThoskaCardName]

    @Environment(\.merkliste) private var merkliste
    @Environment(\.eventsMerkStore) private var eventsMerkStore

    @AppStorage(AppDarstellung.schluessel) private var darstellung = AppDarstellung.system
    @AppStorage(HeuteMensaSpeicher.schluessel, store: AppGroup.defaults) private var heuteMensa = MensaVenue.mensaEhrenberg
    @AppStorage(MensaPriceGroup.storageKey, store: AppGroup.defaults) private var preisgruppe = MensaPriceGroup.studierende

    /// Werte, die nicht beobachtbar sind, werden beim Öffnen gelesen.
    @State private var mensaFilter = MensaFilter()
    @State private var ausgeblendeteHinweise = 0
    @State private var zwischenspeicher: Int = 0

    var body: some View {
        List {
            titel
            thoskaAbschnitt
            merklisteAbschnitt
            eventsAbschnitt
            einstellungenAbschnitt
            zwischenspeicherAbschnitt
            nurImSpeicherAbschnitt
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.background))
        .listSectionSpacing(.compact)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear(perform: lesen)
    }

    // MARK: - Abschnitte

    private var titel: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gespeicherte Daten")
                    .display(size: 30, relativeTo: .largeTitle)
                    .tracking(-0.6)
                    .foregroundStyle(Color(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                Text("Das legt die App auf diesem Gerät ab. Nichts davon wird an uns gesendet oder in einer Cloud gesichert. Löschst du die App, ist alles weg.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
        }
    }

    private var thoskaAbschnitt: some View {
        Section {
            if auslesungen.isEmpty {
                leer("Keine Auslesungen gespeichert.")
            } else {
                ForEach(karten, id: \.cardId) { karte in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ThoskaCardNaming.option(for: karte.cardId, names: kartenNamen).displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(.textPrimary))
                        Text("\(karte.anzahl) Auslesungen, \(datum(karte.erste)) bis \(datum(karte.letzte))")
                            .font(.subheadline)
                            .foregroundStyle(Color(.textSecondary))
                        Text("Je Auslesung: Guthaben, letzte Buchung, Zeitpunkt. Zuletzt \(karte.letzterStand.formatted(.currency(code: "EUR"))).")
                            .font(.footnote)
                            .foregroundStyle(Color(.textTertiary))
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            kopf("Thoska-Verlauf")
        } footer: {
            fuss("Jedes Mal, wenn du die Thoska ausliest, merkt sich die App den Stand für den Verlauf. Dazu die Namen, die du Karten gegeben hast (\(kartenNamen.count)).")
        }
        .listRowBackground(Color(.surface))
    }

    private var merklisteAbschnitt: some View {
        Section {
            if merkliste.eintraege.isEmpty {
                leer("Keine Titel gemerkt.")
            } else {
                ForEach(merkliste.eintraege) { eintrag in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(eintrag.anzeigeTitel)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(.textPrimary))
                        if !eintrag.untertitel.isEmpty {
                            Text(eintrag.untertitel)
                                .font(.subheadline)
                                .foregroundStyle(Color(.textSecondary))
                        }
                        Text("Gemerkt am \(datum(eintrag.gemerktAm))")
                            .font(.footnote)
                            .foregroundStyle(Color(.textTertiary))
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            kopf("Merkliste Bibliothek")
        } footer: {
            fuss("Titel, Personen, Jahr, Medienart und Cover-Adresse der gemerkten Titel. Die Verfügbarkeit wird nicht gespeichert.")
        }
        .listRowBackground(Color(.surface))
    }

    private var eventsAbschnitt: some View {
        Section {
            zeile("Gemerkte Veranstaltungen", wert: Text("\(eventsMerkStore.ids.count)"))
        } header: {
            kopf("Merkliste Veranstaltungen")
        } footer: {
            fuss("Gespeichert werden nur die Kennungen der Veranstaltungen, keine Titel oder Termine.")
        }
        .listRowBackground(Color(.surface))
    }

    private var einstellungenAbschnitt: some View {
        Section {
            zeile("Darstellung", wert: Text(darstellung.titel))
            zeile("Mensa auf der Startseite", wert: Text(heuteMensa.displayName))
            zeile("Preisgruppe", wert: Text(preisgruppe.title))
            zeile(
                "Mensa-Filter",
                wert: Text(mensaFilter.isActive ? filterText : String(localized: "Aus"))
            )
            zeile("Ausgeblendete Hinweise", wert: Text("\(ausgeblendeteHinweise)"))
        } header: {
            kopf("Einstellungen")
        } footer: {
            fuss("Was du in der App eingestellt oder weggetippt hast.")
        }
        .listRowBackground(Color(.surface))
    }

    private var zwischenspeicherAbschnitt: some View {
        Section {
            zeile("Zwischengespeicherte Antworten", wert: Text(Self.groesse(zwischenspeicher)))
        } header: {
            kopf("Zwischenspeicher")
        } footer: {
            fuss("Das System hält zuletzt geladene Antworten von Mensa, Bibliothek und Veranstaltungen vor, damit es schneller geht. Es räumt sie selbst auf und iOS kann sie jederzeit löschen.")
        }
        .listRowBackground(Color(.surface))
    }

    private var nurImSpeicherAbschnitt: some View {
        Section {
            hinweis("Bibliothekskonto", "Benutzernummer, Passwort und Sitzung bleiben nur im Arbeitsspeicher. Nach dem Beenden der App sind sie weg.")
            hinweis("Kamera", "Beim Scannen der Benutzernummer werden keine Bilder gespeichert.")
            hinweis("Kalender", "Beim Eintragen schreibt das System den Termin. Die App liest deine Termine nicht.")
        } header: {
            kopf("Wird nicht gespeichert")
        }
        .listRowBackground(Color(.surface))
    }

    // MARK: - Werte

    private struct KartenUebersicht {
        let cardId: String
        let anzahl: Int
        let erste: Date
        let letzte: Date
        let letzterStand: Double
    }

    /// Die Auslesungen je Karte, die zuletzt benutzte zuerst.
    private var karten: [KartenUebersicht] {
        Dictionary(grouping: auslesungen, by: \.cardId)
            .compactMap { id, eintraege -> KartenUebersicht? in
                let sortiert = eintraege.sorted { $0.scannedAt < $1.scannedAt }
                guard let erste = sortiert.first, let letzte = sortiert.last else { return nil }
                return KartenUebersicht(
                    cardId: id,
                    anzahl: sortiert.count,
                    erste: erste.scannedAt,
                    letzte: letzte.scannedAt,
                    letzterStand: letzte.balance
                )
            }
            .sorted { $0.letzte > $1.letzte }
    }

    private var filterText: String {
        mensaFilter.activeDescription.isEmpty ? String(localized: "Aus") : mensaFilter.activeDescription
    }

    private func lesen() {
        mensaFilter = MensaFilterStore.load()
        ausgeblendeteHinweise = HinweiseAusblendSpeicher().ids.count
        zwischenspeicher = URLCache.shared.currentDiskUsage
    }

    private func datum(_ datum: Date) -> String {
        datum.formatted(date: .abbreviated, time: .omitted)
    }

    private static func groesse(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    // MARK: - Bausteine

    private func kopf(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Color(.textTertiary))
    }

    private func fuss(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color(.textTertiary))
    }

    private func leer(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .foregroundStyle(Color(.textSecondary))
            .frame(minHeight: 44, alignment: .leading)
    }

    private func zeile(_ titel: LocalizedStringKey, wert: Text) -> some View {
        HStack(spacing: 12) {
            Text(titel).foregroundStyle(Color(.textPrimary))
            Spacer(minLength: 12)
            wert.foregroundStyle(Color(.textSecondary)).multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func hinweis(_ titel: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.body.weight(.semibold)).foregroundStyle(Color(.textPrimary))
            Text(text).font(.subheadline).foregroundStyle(Color(.textSecondary))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Gespeicherte Daten – Light") {
    NavigationStack { GespeicherteDatenView() }
        .modelContainer(for: [ThoskaBalanceRecord.self, ThoskaCardName.self], inMemory: true)
        .preferredColorScheme(.light)
}

#Preview("Gespeicherte Daten – Dark") {
    NavigationStack { GespeicherteDatenView() }
        .modelContainer(for: [ThoskaBalanceRecord.self, ThoskaCardName.self], inMemory: true)
        .preferredColorScheme(.dark)
}
