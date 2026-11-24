import SwiftUI
import AppIntents

/// Zustand des Bibliothekskontos für die Anzeige in „Mehr“.
enum MehrKonto: Equatable {
    /// Mit Benutzernummer, soweit bekannt (sie steht nur im Speicher und fehlt z. B. nach einem Neustart).
    case angemeldet(benutzernummer: String?)
    case abgemeldet
}

/// „Mehr und Einstellungen“ (Personen-Button auf Heute). Verdrahtet die Oberfläche (`MehrScreen`) mit dem
/// PAIA-Service, dem Login-Sheet und dem Katalog. Nach `Mehr.dc.html`.
///
/// Ab 700 pt Breite der Ansicht (iPad) stehen die Bereiche links und das Untermenü rechts (`MehrPad`, nach `PadMehr.dc.html`),
/// darunter gilt die iPhone-Ansicht. Beide zeigen dieselben Einstellungen unter denselben Schlüsseln.
struct MehrView: View {
    /// Beschriftung von „‹ …“ oben links (iPad-Anordnung), wenn die Seite nicht als Eintrag der Seitenleiste dasteht, sondern
    /// aus „Heute“ kommt. Ohne Titel gibt es kein Zurück.
    var zurueckTitel: String?
    /// Was „‹ …“ tut; ohne Angabe schließt es die Seite im Stapel.
    var onZurueck: (() -> Void)?

    @ObservedObject private var service = PAIAService.shared
    /// Nur für die Öffnungszeiten unter „Mensa auf der Startseite“ (iPad-Anordnung).
    @StateObject private var mensaService = MensaService()
    @State private var zeigtLogin = false
    @State private var zeigtKatalog = false
    @State private var bereich = MehrBereich.standard

    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(\.dismiss) private var dismiss
    /// Wo das System die Tabs zeigt. Der Eintrag „Mehr & Einstellungen“ der Seitenleiste ist kein `TabInhalt`, meldet die
    /// Platzierung also selbst; sonst bliebe der Router bei geschlossener Seitenleiste auf „sichtbar“ (⌘, und Links
    /// öffneten dann den Eintrag statt der Seite in „Heute“).
    @Environment(\.tabBarPlacement) private var platzierung

    init(zurueckTitel: String? = nil, onZurueck: (() -> Void)? = nil) {
        self.zurueckTitel = zurueckTitel
        self.onZurueck = onZurueck
    }

    private var konto: MehrKonto {
        service.isAuthenticated ? .angemeldet(benutzernummer: service.lastUsername) : .abgemeldet
    }

    var body: some View {
        PadRasterMessung { raster in
            if raster.istPad {
                padSeite(raster)
            } else {
                MehrScreen(
                    konto: konto,
                    onAnmelden: { zeigtLogin = true },
                    // Verwirft Token und Sitzung im Speicher
                    onAbmelden: { service.logout() }
                )
            }
        }
        .sheet(isPresented: $zeigtLogin) {
            PAIALoginSheet(service: service, onSuccess: {
                zeigtLogin = false
            }, onOpenCatalog: {
                // Wie in der Bibliothek: Sheet schließen und den Katalog ohne Anmeldung öffnen
                zeigtLogin = false
                if let router, router.padHuelleAktiv {
                    router.zeigeKatalogSuche()
                } else {
                    zeigtKatalog = true
                }
            })
            // iPad: Form Sheet (ca. 540 breit) wie in der Bibliothek, auf dem iPhone unverändert.
            .formularBlatt(pad: UIDevice.current.userInterfaceIdiom == .pad)
        }
        .modifier(MehrKatalogImStapel(aktiv: router?.padHuelleAktiv != true, istOffen: $zeigtKatalog))
        .onAppear(perform: uebernehmeWunsch)
        .onChange(of: router?.mehrBereich) { _, _ in uebernehmeWunsch() }
        .onChange(of: platzierung, initial: true) { _, neu in
            guard let router, router.padHuelleAktiv else { return }
            router.seitenleisteSichtbar = (neu == .sidebar)
        }
    }

    private func padSeite(_ raster: PadRaster) -> some View {
        MehrPad(
            konto: konto,
            raster: raster,
            bereich: $bereich,
            onAnmelden: { zeigtLogin = true },
            onAbmelden: { service.logout() },
            oeffnungszeiten: oeffnungszeiten
        )
        .task { try? await mensaService.fetchCanteens() }
        // Die Navigationsleiste bleibt für „‹ Heute“; der Titel steht groß in der Liste.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .toolbar {
            if let zurueckTitel {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let onZurueck { onZurueck() } else { dismiss() }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left").font(.body.weight(.semibold))
                            Text(zurueckTitel)
                        }
                        .foregroundStyle(Color(.accent))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Zurück zu \(zurueckTitel)")
                }
            }
        }
    }

    /// Heutige Öffnungszeiten je Mensa für die Unterzeile („11:00–14:00 Uhr“); die Cafeteria Ehrenberg nennt das Abendessen.
    private var oeffnungszeiten: [MensaVenue: String] {
        var ergebnis: [MensaVenue: String] = [:]
        for venue in MensaVenue.allCases {
            guard let mensa = mensaService.canteens.first(where: { venue.matches(canteenName: $0.name) }) else { continue }
            let heute = MensaOpeningHours.todayText(for: mensa.openingHours, now: .now)
            guard heute != "heute geschlossen" else {
                ergebnis[venue] = LocalizedStringResource("Heute geschlossen").inAppSprache
                continue
            }
            ergebnis[venue] = venue.hasMealtimes
                ? heute + " · " + LocalizedStringResource("Abendessen ab \(HeuteUhr.uhrzeit(minuten: HeuteModel.abendessenBeginn))").inAppSprache
                : heute
        }
        return ergebnis
    }

    /// Ein Bereich aus dem Link (`mehr?bereich=`) oder von einem Sprung wird gewählt.
    private func uebernehmeWunsch() {
        guard let wunsch = router?.mehrBereich else { return }
        router?.mehrBereich = nil
        bereich = wunsch
    }
}

/// Der Katalog im Stapel von „Mehr“ (iPhone, nach „Anmelden › Katalog ohne Anmeldung“). In der iPad-Hülle öffnet der Router
/// den Katalog; dort bliebe die Anweisung ohne eigenen Navigationsstapel „fehlplatziert“ und SwiftUI meldet das im Log.
private struct MehrKatalogImStapel: ViewModifier {
    let aktiv: Bool
    @Binding var istOffen: Bool

    func body(content: Content) -> some View {
        if aktiv {
            content.navigationDestination(isPresented: $istOffen) {
                LibraryCatalogView(autofocus: true)
            }
        } else {
            content
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
    private let sprache = AppSprache.gemeinsam
    @AppStorage(HeuteMensaSpeicher.schluessel, store: AppGroup.defaults) private var heuteMensa = MensaVenue.mensaEhrenberg
    @AppStorage(MensaPriceGroup.storageKey, store: AppGroup.defaults) private var preisgruppe = MensaPriceGroup.studierende

    @Environment(\.openURL) private var openURL
    @State private var iconWahl = AlternativeAppIcons.aktuell

    var body: some View {
        List {
            titel
            darstellungAbschnitt
            mensaAbschnitt
            kontoAbschnitt
            siriAbschnitt
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

    /// „Siri & Kurzbefehle“: Link in die Kurzbefehle-App, die Sätze zum Nachlesen und der Hinweis zum HomePod.
    private var siriAbschnitt: some View {
        Section {
            // Das System beschriftet den Link selbst und öffnet die Kurzbefehle bei Campus Ilmenau.
            ShortcutsLink()
                // Der Link bringt seine eigene Fläche mit: oben und unten Luft, damit sie nicht an der Zelle klebt.
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityHint(Text("Öffnet die Kurzbefehle von Campus Ilmenau", tableName: "Siri"))
            NavigationLink {
                SiriFragenView()
            } label: {
                Text("Was du Siri fragen kannst", tableName: "Siri")
                    .frame(minHeight: 44, alignment: .leading)
            }
        } header: {
            kopf(Text("Siri & Kurzbefehle", tableName: "Siri"))
        } footer: {
            Text("Geht auch auf dem HomePod, wenn „Persönliche Anfragen“ in der Home-App an ist.", tableName: "Siri")
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
        }
        .listRowBackground(Color(.surface))
        .listRowSeparatorTint(Color(.separator))
        .foregroundStyle(Color(.textPrimary))
    }

    private var allgemeinAbschnitt: some View {
        Section {
            // Sprache: Automatisch folgt dem Gerät (Deutsch oder Englisch, sonst Deutsch); sonst gilt die Wahl, sofort.
            Menu {
                ForEach(SpracheWahl.allCases) { wahl in
                    Button {
                        sprache.waehle(wahl)
                    } label: {
                        if wahl == sprache.auswahl {
                            Label { wahl.titel } icon: { Image(systemName: "checkmark") }
                        } else {
                            wahl.titel
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Sprache")
                        .foregroundStyle(Color(.textPrimary))
                    Spacer(minLength: 12)
                    sprachwert.foregroundStyle(Color(.textSecondary))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.textTertiary))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Sprache")
            .accessibilityValue(sprachwert)

            // App-Icon: Tippen öffnet ein Menü mit Automatisch, Hell und Dunkel; rechts steht das aktuelle Icon.
            if AlternativeAppIcons.istVerfuegbar {
                Menu {
                    ForEach(AppIconWahl.allCases) { wahl in
                        Button {
                            waehleIcon(wahl)
                        } label: {
                            if wahl == iconWahl {
                                Label(wahl.titel, systemImage: "checkmark")
                            } else {
                                Text(wahl.titel)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("App-Icon")
                            .foregroundStyle(Color(.textPrimary))
                        Spacer(minLength: 12)
                        AppIconBild(wahl: iconWahl, groesse: 30, radius: 7)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(.textTertiary))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("App-Icon")
                .accessibilityValue(Text(iconWahl.titel))
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
        kopf(Text(text))
    }

    /// Wie `kopf(_:)`, für Texte aus einer anderen Tabelle (Siri).
    private func kopf(_ text: Text) -> some View {
        text
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

    /// Setzt das Icon. Schlägt es fehl, springt die Auswahl zurück auf das, was iOS meldet.
    private func waehleIcon(_ wahl: AppIconWahl) {
        iconWahl = wahl
        Task {
            await AlternativeAppIcons.waehle(wahl)
            iconWahl = AlternativeAppIcons.aktuell
        }
    }

    // MARK: - Werte

    /// Rechts in der Zeile: „Automatisch · Deutsch“ oder der Name der gewählten Sprache.
    private var sprachwert: Text {
        let name = Text(verbatim: sprache.aktuell == .de ? "Deutsch" : "English")
        return sprache.auswahl == .automatisch ? Text("Automatisch · \(name)") : name
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
