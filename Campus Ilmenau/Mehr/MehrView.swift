import SwiftUI

/// Zustand des Bibliothekskontos für die Anzeige in „Mehr“.
enum MehrKonto: Equatable {
    /// Mit Benutzernummer, soweit bekannt (sie steht nur im Speicher und fehlt z. B. nach einem Neustart).
    case angemeldet(benutzernummer: String?)
    case abgemeldet
}

/// „Mehr und Einstellungen“ (Personen-Button auf Heute). Verdrahtet die Oberfläche (`MehrScreen`) mit dem
/// PAIA-Service, dem Login-Sheet und dem Katalog. Nach `Mehr.dc.html`.
struct MehrView: View {
    @ObservedObject private var service = PAIAService.shared
    @State private var zeigtLogin = false
    @State private var zeigtKatalog = false

    var body: some View {
        MehrScreen(
            konto: service.isAuthenticated ? .angemeldet(benutzernummer: service.lastUsername) : .abgemeldet,
            onAnmelden: { zeigtLogin = true },
            // Verwirft Token und Sitzung im Speicher
            onAbmelden: { service.logout() }
        )
        .sheet(isPresented: $zeigtLogin) {
            PAIALoginSheet(service: service, onSuccess: {
                zeigtLogin = false
            }, onOpenCatalog: {
                // Wie in der Bibliothek: Sheet schließen und den Katalog ohne Anmeldung öffnen
                zeigtLogin = false
                zeigtKatalog = true
            })
        }
        .navigationDestination(isPresented: $zeigtKatalog) {
            LibraryCatalogView(autofocus: true)
        }
    }
}

/// Die Oberfläche von „Mehr“ ohne eigene Logik für das Konto, damit sie sich in Previews in jedem Zustand zeigen lässt.
///
/// Die Einstellungen liegen jeweils unter dem Schlüssel, den auch der Rest der App benutzt, es wird nichts doppelt
/// gespeichert: Darstellung (`AppDarstellung`), Mensa auf der Startseite (`HeuteMensaSpeicher`) und Preisgruppe
/// (`MensaPriceGroup`).
struct MehrScreen: View {
    let konto: MehrKonto
    let onAnmelden: () -> Void
    let onAbmelden: () -> Void

    @AppStorage(AppDarstellung.schluessel) private var darstellung = AppDarstellung.system
    @AppStorage(HeuteMensaSpeicher.schluessel) private var heuteMensa = MensaVenue.mensaEhrenberg
    @AppStorage(MensaPriceGroup.storageKey) private var preisgruppe = MensaPriceGroup.studierende

    @Environment(\.openURL) private var openURL
    @State private var aktuellesIcon = AlternativeAppIcons.aktuell

    var body: some View {
        List {
            titel
            darstellungAbschnitt
            mensaAbschnitt
            kontoAbschnitt
            allgemeinAbschnitt
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.background))
        .listSectionSpacing(.compact)
        // Die Navigationsleiste bleibt für den Zurück-Pfeil; der Titel steht groß in der Liste
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Teile

    private var titel: some View {
        Section {
            Text("Mehr")
                .display(size: 34, relativeTo: .largeTitle)
                .tracking(-0.7)
                .foregroundStyle(Color(.textPrimary))
                .accessibilityAddTraits(.isHeader)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
        }
    }

    private var darstellungAbschnitt: some View {
        Section {
            SegmentedControl(
                selection: $darstellung,
                options: AppDarstellung.allCases.map { (value: $0, title: $0.titel) }
            )
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Darstellung")
            .listRowBackground(Color(.surface))
        } header: {
            kopf("Darstellung")
        }
    }

    private var mensaAbschnitt: some View {
        Section {
            Picker("Mensa auf der Startseite", selection: $heuteMensa) {
                ForEach(MensaVenue.allCases) { venue in
                    Text(venue.displayName).tag(venue)
                }
            }
            Picker("Preisgruppe", selection: $preisgruppe) {
                ForEach(MensaPriceGroup.allCases) { gruppe in
                    Text(gruppe.title).tag(gruppe)
                }
            }
            NavigationLink("Öffnungszeiten") {
                MensaOpeningHoursView()
            }
        } header: {
            kopf("Mensa")
        }
        .listRowBackground(Color(.surface))
        .listRowSeparatorTint(Color(.separator))
        .foregroundStyle(Color(.textPrimary))
    }

    @ViewBuilder
    private var kontoAbschnitt: some View {
        Section {
            switch konto {
            case .angemeldet(let nummer):
                VStack(alignment: .leading, spacing: 12) {
                    // Die Benutzernummer steht nur im Speicher und fehlt z. B. nach einem Neustart der App
                    Text(nummer.map { "Angemeldet als \($0)" } ?? "Angemeldet")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(.textPrimary))
                    DestructiveButton("Abmelden", action: onAbmelden)
                }
                .padding(.vertical, 6)
            case .abgemeldet:
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nicht angemeldet. Deine Zugangsdaten wurden vom Gerät gelöscht.")
                        .font(.body)
                        .foregroundStyle(Color(.textSecondary))
                    PrimaryButton("Anmelden", action: onAnmelden)
                }
                .padding(.vertical, 6)
            }
        } header: {
            kopf("Bibliothekskonto")
        }
        .listRowBackground(Color(.surface))
    }

    private var allgemeinAbschnitt: some View {
        Section {
            // Die Sprache stellt man in den Einstellungen des Systems ein, dort pro App
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                zeile("Sprache", wert: sprachname, symbol: "arrow.up.forward")
            }
            .accessibilityHint("Öffnet die Einstellungen")

            if AlternativeAppIcons.istVerfuegbar {
                Menu {
                    Button("Standard") { waehleIcon(nil) }
                    ForEach(AlternativeAppIcons.namen, id: \.self) { name in
                        Button(name) { waehleIcon(name) }
                    }
                } label: {
                    zeile("App-Icon", wert: aktuellesIcon ?? "Standard", symbol: "chevron.up.chevron.down")
                }
            }

            NavigationLink {
                GespeicherteDatenView()
            } label: {
                Text("Gespeicherte Daten")
                    .frame(minHeight: 44, alignment: .leading)
            }

            if let url = AppLinks.datenschutz {
                Link(destination: url) { zeile("Datenschutz", symbol: "chevron.right") }
            }
            if let url = AppLinks.impressum {
                Link(destination: url) { zeile("Impressum", symbol: "chevron.right") }
            }
        } header: {
            kopf("Allgemein")
        } footer: {
            Text("Campus Ilmenau · Version \(Self.version) (\(Self.build))")
                .font(.caption)
                .foregroundStyle(Color(.textTertiary))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
        }
        .listRowBackground(Color(.surface))
        .listRowSeparatorTint(Color(.separator))
        .foregroundStyle(Color(.textPrimary))
    }

    // MARK: - Bausteine

    private func kopf(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Color(.textTertiary))
    }

    /// Zeile mit Wert und kleinem Symbol rechts. Der ganze Bereich ist tippbar.
    private func zeile(_ titel: LocalizedStringKey, wert: String? = nil, symbol: String) -> some View {
        HStack(spacing: 6) {
            Text(titel)
                .foregroundStyle(Color(.textPrimary))
            Spacer(minLength: 12)
            if let wert {
                Text(wert).foregroundStyle(Color(.textSecondary))
            }
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.textTertiary))
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func waehleIcon(_ name: String?) {
        aktuellesIcon = name
        Task { await AlternativeAppIcons.waehle(name) }
    }

    // MARK: - Werte

    /// Bevorzugte Sprache des Geräts („Deutsch“). Solange die App nur deutsche Texte hat und keine Übersetzungen
    /// eingetragen sind, sagt `Bundle.main.preferredLocalizations` nichts Brauchbares (Entwicklungssprache ist `en`).
    private var sprachname: String {
        let code = Locale.preferredLanguages.first.flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "de"
        return Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    private static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }
}

// MARK: - Previews

#Preview("Mehr – angemeldet – Light") {
    NavigationStack {
        MehrScreen(konto: .angemeldet(benutzernummer: "0001234567"), onAnmelden: {}, onAbmelden: {})
    }
    .preferredColorScheme(.light)
}

#Preview("Mehr – angemeldet – Dark") {
    NavigationStack {
        MehrScreen(konto: .angemeldet(benutzernummer: "0001234567"), onAnmelden: {}, onAbmelden: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Mehr – abgemeldet – Light") {
    NavigationStack {
        MehrScreen(konto: .abgemeldet, onAnmelden: {}, onAbmelden: {})
    }
    .preferredColorScheme(.light)
}

#Preview("Mehr – abgemeldet – Dark") {
    NavigationStack {
        MehrScreen(konto: .abgemeldet, onAnmelden: {}, onAbmelden: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Mehr – große Schrift") {
    NavigationStack {
        MehrScreen(konto: .angemeldet(benutzernummer: "0001234567"), onAnmelden: {}, onAbmelden: {})
    }
    .dynamicTypeSize(.accessibility2)
}
