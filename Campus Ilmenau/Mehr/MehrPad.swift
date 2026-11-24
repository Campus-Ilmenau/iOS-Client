import SwiftUI
import AppIntents

// „Mehr & Einstellungen“ auf dem iPad (ab 700 pt Breite der Ansicht): Bereiche links, Untermenü rechts, kein Push.
// Nach `PadMehr.dc.html` (Varianten `PadMehrKonto`, `PadMehrDarstellung`). Es sind dieselben Einstellungen wie in `MehrScreen`
// auf dem iPhone, unter denselben Schlüsseln (`AppDarstellung`, `HeuteMensaSpeicher`, `MensaPriceGroup`); neue Speicherorte
// gibt es nicht. Die Aktionen (Login, Wechsel in andere Tabs) melden sich über Closures bzw. den Router.

/// Version der App für „Über die App“: „1.0 (12)“.
enum MehrAppVersion {
    static var text: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

/// Thoska gibt es nur mit NFC. Auf dem iPad (kein NFC) kommt sie in „Mehr“ nirgends vor: weder im Thoska-Verlauf unter
/// „Gespeicherte Daten“ noch bei den Sätzen für Siri. Das iPhone bleibt unverändert, auch im Simulator ohne NFC.
enum ThoskaInMehr {
    static var sichtbar: Bool {
        NFCVerfuegbarkeit.vorhanden || UIDevice.current.userInterfaceIdiom != .pad
    }
}

/// Bereiche links (440 bzw. 360 pt), Untermenü rechts (max. 640, zentriert), getrennt durch `separator`.
struct MehrPad: View {
    let konto: MehrKonto
    let raster: PadRaster
    @Binding var bereich: MehrBereich
    let onAnmelden: () -> Void
    let onAbmelden: () -> Void
    /// Heutige Öffnungszeiten je Mensa als Unterzeile („11:00–14:00 Uhr“). Fehlen sie (noch), steht keine Unterzeile.
    var oeffnungszeiten: [MensaVenue: String] = [:]
    /// Die Adressen stehen noch nicht fest (`AppLinks`): Ohne Adresse zeigt „Über die App“ die Zeile nicht.
    var datenschutz: URL? = AppLinks.datenschutz
    var impressum: URL? = AppLinks.impressum
    /// Vorschauen setzen den Filter fest; sonst wird er beim Erscheinen aus dem Speicher gelesen.
    var filterVorgabe: MensaFilter?

    @AppStorage(AppDarstellung.schluessel) private var darstellung = AppDarstellung.system
    private let appSprache = AppSprache.gemeinsam
    @AppStorage(HeuteMensaSpeicher.schluessel, store: AppGroup.defaults) private var heuteMensa = MensaVenue.mensaEhrenberg
    @AppStorage(MensaPriceGroup.storageKey, store: AppGroup.defaults) private var preisgruppe = MensaPriceGroup.studierende

    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var listeFokus: Bool
    @State private var iconWahl = AlternativeAppIcons.aktuell
    @State private var filter = MensaFilterStore.load()
    @State private var browser: LibraryExternalLink?
    @State private var zeigtSiri = false
    @State private var zeigtDaten = false

    private let rand = EventsRand.pad

    var body: some View {
        HStack(spacing: 0) {
            linkeSpalte
                .frame(width: raster.listenbreite)
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
                .accessibilityHidden(true)
            rechteSeite
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.background))
        .onAppear(perform: werteNeuLesen)
        .onChange(of: scenePhase) { _, neu in
            if neu == .active { werteNeuLesen() }
        }
        .sheet(item: $browser) { link in
            LibrarySafariView(url: link.url)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $zeigtSiri) {
            blatt { SiriFragenView() }
        }
        .sheet(isPresented: $zeigtDaten) {
            blatt { GespeicherteDatenView() }
        }
    }

    /// Siri-Sätze und „Gespeicherte Daten“ sind Listen mit eigenem Titel; hier öffnen sie als Form Sheet statt als Push.
    private func blatt<Inhalt: View>(@ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        NavigationStack {
            inhalt()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            zeigtSiri = false
                            zeigtDaten = false
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .tint(Color(.accent))
        .presentationSizing(.form)
    }

    private func werteNeuLesen() {
        // Der Filter wird im Mensa-Tab geändert und liegt nicht in einem beobachtbaren Speicher.
        filter = filterVorgabe ?? MensaFilterStore.load()
        iconWahl = AlternativeAppIcons.aktuell
    }

    // MARK: - Links

    private var linkeSpalte: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Mehr")
                    .display(size: 34, relativeTo: .largeTitle)
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                    .accessibilityAddTraits(.isHeader)

                kontoKarte
                    .padding(.bottom, 22)

                gruppe

                Text("Campus Ilmenau · Version \(MehrAppVersion.text)")
                    .font(.caption)
                    .foregroundStyle(Color(.textSecondary))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
            }
            .padding(.leading, rand.links)
            .padding(.trailing, rand.rechts)
            .padding(.bottom, 28)
        }
        // Pfeiltasten ↑/↓ wechseln den Bereich, solange die Liste den Tastaturfokus hat.
        .modifier(PadListenTasten(aktiv: true, fokus: $listeFokus) { schritt in
            bereich = bereich.nachbar(schritt)
        })
    }

    private var kontoKarte: some View {
        let gewaehlt = bereich == .konto
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            bereich = .konto
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color(.onBlue))
                    .frame(width: 48, height: 48)
                    .background(Color(.blue), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Bibliothekskonto")
                        .font(.headline)
                        .foregroundStyle(Color(.textPrimary))
                    kontoZeile
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color(.textTertiary))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.surface), in: form)
            .overlay {
                if gewaehlt { form.strokeBorder(Color(.accent), lineWidth: 2) }
            }
            .contentShape(.hoverEffect, form)
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    /// „Angemeldet · 0001234567“, „Angemeldet“ (die Nummer steht nur im Speicher und fehlt z. B. nach einem Neustart) oder
    /// „Nicht angemeldet“.
    private var kontoZeile: Text {
        switch konto {
        case .angemeldet(let nummer):
            if let nummer { Text("Angemeldet · \(nummer)") } else { Text("Angemeldet") }
        case .abgemeldet:
            Text("Nicht angemeldet")
        }
    }

    private var gruppe: some View {
        VStack(spacing: 0) {
            ForEach(Array(MehrBereich.gruppe.enumerated()), id: \.element) { index, eintrag in
                bereichsZeile(eintrag)
                // Keine Trennlinie an der gewählten Zeile, wie im Artboard.
                if index < MehrBereich.gruppe.count - 1,
                   eintrag != bereich, MehrBereich.gruppe[index + 1] != bereich {
                    Rectangle().fill(Color(.separator)).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 6)
        .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func bereichsZeile(_ eintrag: MehrBereich) -> some View {
        let gewaehlt = bereich == eintrag
        let form = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Button {
            bereich = eintrag
        } label: {
            HStack(spacing: 12) {
                kachel(eintrag)
                Text(eintrag.titel)
                    .foregroundStyle(Color(gewaehlt ? .accent : .textPrimary))
                    .fontWeight(gewaehlt ? .semibold : .regular)
                    .lineLimit(1)
                    // Der Name bricht nie um; der lange Wert („Cafeteria Ehrenberg · Studierende“) wird dafür kleiner.
                    .layoutPriority(2)
                Spacer(minLength: 0)
                wert(eintrag)
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color(gewaehlt ? .accent : .textTertiary))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(gewaehlt ? Color(.accentSoft) : Color.clear, in: form)
            // Die ganze Zeile ist tippbar, auch zwischen Name und Wert.
            .contentShape(form)
            .contentShape(.hoverEffect, form)
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    /// Symbol-Kachel 30 pt: Blau und Grün nur als Fläche, sonst `surfaceSecondary`.
    private func kachel(_ eintrag: MehrBereich) -> some View {
        let (flaeche, symbol): (Color, Color) = switch eintrag.kachel {
        case .blau: (Color(.blue), Color(.onBlue))
        case .gruen: (Color(.green), Color(.onGreen))
        case .neutral: (Color(.surfaceSecondary), Color(.textPrimary))
        }
        return Image(systemName: eintrag.symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(symbol)
            .frame(width: 30, height: 30)
            .background(flaeche, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }

    /// Der aktuelle Wert rechts in der Zeile.
    @ViewBuilder
    private func wert(_ eintrag: MehrBereich) -> some View {
        switch eintrag {
        case .darstellung: Text(darstellung.titel)
        case .mensa: Text(verbatim: "\(heuteMensa.shortName) · \(preisgruppe.title)")
        case .sprache: Text(verbatim: appSprache.aktuell == .de ? "Deutsch" : "English")
        case .ueber: Text("Version \(MehrAppVersion.text)")
        case .konto: EmptyView()
        }
    }

    // MARK: - Rechts

    private var rechteSeite: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(bereich.titel)
                    .display(size: 30, relativeTo: .largeTitle)
                    .foregroundStyle(Color(.textPrimary))
                    .padding(.top, 10)
                    .padding(.horizontal, 2)
                    .accessibilityAddTraits(.isHeader)

                switch bereich {
                case .darstellung: darstellungInhalt
                case .mensa: mensaInhalt
                case .konto: kontoInhalt
                case .sprache: spracheInhalt
                case .ueber: ueberInhalt
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 6)
            .padding(.bottom, 32)
        }
        .id(bereich)
    }

    // MARK: Darstellung

    private var darstellungInhalt: some View {
        VStack(alignment: .leading, spacing: 0) {
            ueberschrift("Erscheinungsbild")
            MehrBox(innen: 16, vertikal: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(AppDarstellung.allCases) { eintrag in
                        themaKachel(eintrag)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Erscheinungsbild")
            }
            erklaerung("„System“ folgt der Einstellung des iPad. Der Dark Mode ist Nachtblau, nicht Schwarz.")

            if AlternativeAppIcons.istVerfuegbar {
                ueberschrift("App-Icon")
                MehrBox(innen: 16, vertikal: 16) {
                    HStack(alignment: .top, spacing: 28) {
                        ForEach(AppIconWahl.allCases) { wahl in
                            iconAuswahl(wahl)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("App-Icon")
                }
            }
        }
    }

    /// Vorschau-Kachel 110 hoch: die Hälften zeigen den Stil in Hell bzw. Dunkel. Rand 3 pt `accent` bei Auswahl.
    private func themaKachel(_ eintrag: AppDarstellung) -> some View {
        let gewaehlt = darstellung == eintrag
        let (links, rechts): (Bool, Bool) = switch eintrag {
        case .system: (true, false)
        case .hell: (true, true)
        case .dunkel: (false, false)
        }
        let form = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            darstellung = eintrag
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    MehrVorschauHaelfte(hell: links)
                    MehrVorschauHaelfte(hell: rechts)
                }
                .frame(height: 110)
                .clipShape(form)
                .overlay { form.strokeBorder(Color(gewaehlt ? .accent : .separator), lineWidth: gewaehlt ? 3 : 2) }
                .contentShape(.hoverEffect, form)
                Text(eintrag.titel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityLabel(eintrag.titel)
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    /// App-Icon 64 pt (`setAlternateIconName`), Rand 3 pt `accent` bei Auswahl. Schlägt das Setzen fehl, springt die Auswahl
    /// auf das zurück, was iOS meldet.
    private func iconAuswahl(_ wahl: AppIconWahl) -> some View {
        let gewaehlt = iconWahl == wahl
        let form = RoundedRectangle(cornerRadius: 15, style: .continuous)
        return Button {
            iconWahl = wahl
            Task {
                await AlternativeAppIcons.waehle(wahl)
                iconWahl = AlternativeAppIcons.aktuell
            }
        } label: {
            VStack(spacing: 8) {
                AppIconBild(wahl: wahl, groesse: 64, radius: 15)
                    .overlay { form.strokeBorder(Color(gewaehlt ? .accent : .separator), lineWidth: gewaehlt ? 3 : 1) }
                    .contentShape(.hoverEffect, form)
                Text(wahl.titel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(.textPrimary))
            }
            .frame(minWidth: 64)
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityLabel(wahl.titel)
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    // MARK: Mensa

    private var mensaInhalt: some View {
        VStack(alignment: .leading, spacing: 0) {
            ueberschrift("Mensa auf der Startseite")
            MehrBox {
                ForEach(MensaVenue.allCases) { venue in
                    option(
                        Text(venue.displayName),
                        info: oeffnungszeiten[venue].map { Text(verbatim: $0) },
                        gewaehlt: heuteMensa == venue
                    ) { heuteMensa = venue }
                }
            }
            erklaerung("Gilt für die Jetzt-Karte und »Als Nächstes« auf Heute, für das Widget und für Siri.")

            ueberschrift("Preisgruppe")
            MehrBox {
                ForEach(MensaPriceGroup.allCases) { gruppe in
                    option(Text(verbatim: gruppe.title), gewaehlt: preisgruppe == gruppe) { preisgruppe = gruppe }
                }
            }
            erklaerung("Diese Preise zeigt der Speiseplan zuerst. Die anderen stehen beim Gericht.")

            ueberschrift("Mehr zur Mensa")
            MehrBox {
                navZeile(Text("Öffnungszeiten")) { router?.zeigeOeffnungszeiten() }
                navZeile(
                    Text("Filter für Ernährung und Allergene"),
                    info: filter.isActive ? Text(verbatim: filter.activeDescription) : Text("Kein Filter aktiv")
                ) { router?.zeigeMensaFilter() }
            }
        }
    }

    // MARK: Bibliothekskonto

    @ViewBuilder
    private var kontoInhalt: some View {
        switch konto {
        case .angemeldet(let nummer):
            VStack(alignment: .leading, spacing: 0) {
                ueberschrift("Angemeldet")
                MehrBox {
                    if let nummer {
                        HStack {
                            Text("Benutzernummer")
                                .foregroundStyle(Color(.textPrimary))
                            Spacer(minLength: 12)
                            Text(verbatim: nummer)
                                .monospacedDigit()
                                .foregroundStyle(Color(.textSecondary))
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .accessibilityElement(children: .combine)
                    }
                    navZeile(Text("Ausleihen und Vormerkungen")) { router?.waehle(.ausleihen) }
                    // „Erinnerungen“ gibt es noch nicht: eine Zeile ohne Aktion, bis die Funktion kommt.
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Erinnerungen")
                                .foregroundStyle(Color(.textSecondary))
                            Text("Kommt später")
                                .font(.footnote)
                                .foregroundStyle(Color(.textSecondary))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
                erklaerung("Du bleibst angemeldet, bis du die App beendest. Zugangsdaten speichert die App nicht.")
                DestructiveButton("Abmelden", action: onAbmelden)
                    .frame(maxWidth: 360)
                    .padding(.top, 22)
            }
        case .abgemeldet:
            VStack(alignment: .leading, spacing: 14) {
                Text("Nicht angemeldet. Deine Zugangsdaten wurden vom Gerät gelöscht.")
                    .foregroundStyle(Color(.textSecondary))
                PrimaryButton("Anmelden", action: onAnmelden)
                    .frame(maxWidth: 320)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 14)
        }
    }

    // MARK: Sprache

    private var spracheInhalt: some View {
        VStack(alignment: .leading, spacing: 0) {
            ueberschrift("Sprache der App")
            MehrBox {
                ForEach(SpracheWahl.allCases) { wahl in
                    option(
                        wahl.titel,
                        info: wahl == .automatisch
                            ? Text("Sprache des iPad: \(Text(verbatim: appSprache.geraet == .de ? "Deutsch" : "English"))") : nil,
                        gewaehlt: wahl == appSprache.auswahl
                    ) {
                        appSprache.waehle(wahl)
                    }
                }
            }
            erklaerung("Speisepläne und Veranstaltungen kommen so, wie sie eingetragen sind – meist auf Deutsch.")
        }
    }

    // MARK: Über die App

    private var ueberInhalt: some View {
        VStack(alignment: .leading, spacing: 0) {
            if datenschutz != nil || impressum != nil {
                ueberschrift("Rechtliches")
                MehrBox {
                    if let datenschutz {
                        navZeile(Text("Datenschutz")) { browser = LibraryExternalLink(url: datenschutz) }
                    }
                    if let impressum {
                        navZeile(Text("Impressum")) { browser = LibraryExternalLink(url: impressum) }
                    }
                }
            }

            ueberschrift("App")
            MehrBox {
                HStack {
                    Text("Version").foregroundStyle(Color(.textPrimary))
                    Spacer(minLength: 12)
                    Text(verbatim: MehrAppVersion.text).foregroundStyle(Color(.textSecondary))
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .accessibilityElement(children: .combine)
            }

            // Beides gibt es auch auf dem iPhone unter „Mehr“; das Artboard des iPads nennt es nicht.
            ueberschrift(Text("Siri & Kurzbefehle", tableName: "Siri"))
            MehrBox {
                ShortcutsLink()
                    // Der Link bringt seine eigene Fläche mit: oben und unten Luft, damit sie nicht an der Zelle klebt.
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .accessibilityHint(Text("Öffnet die Kurzbefehle von Campus Ilmenau", tableName: "Siri"))
                navZeile(Text("Was du Siri fragen kannst", tableName: "Siri")) { zeigtSiri = true }
            }

            ueberschrift("Auf diesem Gerät")
            MehrBox {
                navZeile(Text("Gespeicherte Daten")) { zeigtDaten = true }
            }
        }
    }

    // MARK: - Bausteine

    private func ueberschrift(_ text: LocalizedStringKey) -> some View {
        ueberschrift(Text(text))
    }

    /// 13 Semibold, Großbuchstaben, `textSecondary` (auf `background` nicht `textTertiary`).
    private func ueberschrift(_ text: Text) -> some View {
        text
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.65)
            .foregroundStyle(Color(.textSecondary))
            .padding(.top, 22)
            .padding(.bottom, 8)
            .padding(.horizontal, 6)
            .accessibilityAddTraits(.isHeader)
    }

    private func erklaerung(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color(.textSecondary))
            .padding(.top, 8)
            .padding(.horizontal, 6)
    }

    /// Eine Auswahl mit Häkchen (`accent`) rechts; die Unterzeile steht in `textSecondary`.
    private func option(_ titel: Text, info: Text? = nil, gewaehlt: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    titel.foregroundStyle(Color(.textPrimary))
                    if let info {
                        info.font(.footnote).foregroundStyle(Color(.textSecondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(.accent))
                    .frame(width: 22)
                    .opacity(gewaehlt ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    /// Zeile mit Chevron rechts, die etwas öffnet.
    private func navZeile(_ titel: Text, info: Text? = nil, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    titel.foregroundStyle(Color(.textPrimary))
                    if let info {
                        info.font(.footnote).foregroundStyle(Color(.textSecondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color(.textTertiary))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

// MARK: - Baugruppen

/// Fläche `surface`, Ecken 16, die Zeilen durch `separator` getrennt.
private struct MehrBox<Inhalt: View>: View {
    var innen: CGFloat = 16
    var vertikal: CGFloat = 0
    @ViewBuilder let inhalt: Inhalt

    var body: some View {
        Group(subviews: inhalt) { zeilen in
            VStack(spacing: 0) {
                ForEach(zeilen.indices, id: \.self) { index in
                    zeilen[index]
                    if index < zeilen.count - 1 {
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                    }
                }
            }
        }
        .padding(.horizontal, innen)
        .padding(.vertical, vertikal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Eine Hälfte der Vorschau-Kachel: Hintergrund, `accent` und `separator` immer im Hell- bzw. Dunkel-Wert der Assets, egal
/// in welchem Stil die App gerade läuft.
private struct MehrVorschauHaelfte: View {
    let hell: Bool

    private func farbe(_ ressource: ColorResource) -> Color {
        let stil: UIUserInterfaceStyle = hell ? .light : .dark
        return Color(uiColor: UIColor(resource: ressource).resolvedColor(with: UITraitCollection(userInterfaceStyle: stil)))
    }

    var body: some View {
        GeometryReader { proxy in
            let breite = proxy.size.width - 24
            VStack(alignment: .leading, spacing: 6) {
                balken(farbe(.accent), breite: breite * 0.5)
                balken(farbe(.separator), breite: breite)
                balken(farbe(.separator), breite: breite * 0.7)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(farbe(.background))
        .accessibilityHidden(true)
    }

    private func balken(_ farbe: Color, breite: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(farbe)
            .frame(width: max(breite, 0), height: 8)
    }
}
