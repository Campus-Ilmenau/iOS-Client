import SwiftUI

// Die Merkliste auf dem iPad (ab 700 pt Breite der Ansicht): Liste links, Titel rechts, kein Push.
// Nach `PadMerkliste.dc.html`; Daten und Regeln wie `BibMerkliste` (Abschnitte Offen und Gefunden, Sortierung, Toasts,
// Widerrufen, Leeren, Fehlerfälle). Die Aktionen liegen in `BibMerklisteView`, diese Ansicht zeigt nur und meldet.

/// Welcher Titel rechts steht. Reine Regeln ohne Oberfläche, damit sie sich prüfen lassen.
enum MerklisteAuswahlRegel {
    /// Beim Öffnen: der erste offene Titel, sonst (alles gefunden) der erste gefundene.
    static func anfang(offen: [String], gefunden: [String]) -> String? {
        offen.first ?? gefunden.first
    }

    /// Bleibt die Auswahl gültig, gilt sie weiter; sonst (nichts gewählt, Titel von der Uhr entfernt …) der Anfang.
    static func korrigiere(aktuell: String?, offen: [String], gefunden: [String]) -> String? {
        if let aktuell, offen.contains(aktuell) || gefunden.contains(aktuell) { return aktuell }
        return anfang(offen: offen, gefunden: gefunden)
    }

    /// Der Titel unter `id` im selben Abschnitt, sonst der darüber.
    static func nachbar(von id: String, in abschnitt: [String]) -> String? {
        guard let index = abschnitt.firstIndex(of: id) else { return nil }
        if index + 1 < abschnitt.count { return abschnitt[index + 1] }
        return index > 0 ? abschnitt[index - 1] : nil
    }

    /// Nach dem Entfernen von `id` (die Listen sind die vor dem Entfernen): der Nachbar im selben Abschnitt, sonst der
    /// Anfang des Rests; `nil`, wenn nichts übrig bleibt.
    static func nachEntfernen(_ id: String, offen: [String], gefunden: [String]) -> String? {
        let abschnitt = offen.contains(id) ? offen : gefunden
        return nachbar(von: id, in: abschnitt)
            ?? anfang(offen: offen.filter { $0 != id }, gefunden: gefunden.filter { $0 != id })
    }

    /// Nach dem Abhaken oder Zurücknehmen von `id` (die Listen sind die vor der Änderung): der Nachbar im Abschnitt, aus
    /// dem der Titel wandert. Ist er allein dort, bleibt er gewählt und steht im anderen Abschnitt.
    static func nachAbhaken(_ id: String, offen: [String], gefunden: [String]) -> String {
        nachbar(von: id, in: offen.contains(id) ? offen : gefunden) ?? id
    }
}

/// Liste links (440 bzw. 360 pt) und Titel rechts (max. 640, zentriert), getrennt durch `separator`.
struct BibMerklistePad<LeerKarte: View>: View {
    let offen: [GemerkterTitel]
    let gefunden: [GemerkterTitel]
    let status: BibMerklisteStatus
    let zusammenfassung: String
    let raster: PadRaster
    let gewaehlteID: String?
    let service: LibraryCatalogService
    let coverLoader: LibraryCoverLoader
    let onWahl: (GemerkterTitel) -> Void
    /// Kreis links in der Zeile, Wischen nach links und Kontextmenü: abhaken bzw. zurücknehmen.
    let onGefunden: (Bool, GemerkterTitel) -> Void
    let onEntfernen: (GemerkterTitel) -> Void
    let onLeeren: () -> Void
    /// Das Feld „Im Katalog suchen“: öffnet den Katalog mit Fokus im Suchfeld.
    let onKatalogSuche: () -> Void
    let onAktualisieren: () async -> Void
    /// Die Karte „Noch nichts gemerkt“ der leeren Liste (wie auf dem iPhone, mit den Rändern des iPads).
    let leerKarte: LeerKarte
    /// Vorschauen setzen hier fertige Titel-Modelle ein (ohne Netz); sonst entsteht das Modell aus dem Eintrag.
    var vorschauTitel: (@MainActor (GemerkterTitel) -> LibraryTitleModel)?

    private let rand = EventsRand.pad
    /// Die Liste hat den Tastaturfokus: ↑/↓ wechseln die Auswahl (wie bei Veranstaltungen und im Katalog).
    @FocusState private var listeFokus: Bool

    private var alle: [GemerkterTitel] { offen + gefunden }

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
    }

    // MARK: Links

    private var linkeSpalte: some View {
        VStack(spacing: 0) {
            kopf
            if alle.isEmpty {
                ScrollView { leerKarte }
            } else {
                liste
            }
        }
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Merkliste")
                .display(size: 34, relativeTo: .largeTitle)
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityAddTraits(.isHeader)
            Text(zusammenfassung)
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .padding(.top, 2)
                .padding(.bottom, 12)
            suchfeld
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, rand.links)
        .padding(.trailing, rand.rechts)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    /// „Im Katalog suchen“ wie in der Bibliothek (44 hoch), hier über die ganze Spalte.
    private var suchfeld: some View {
        Button(action: onKatalogSuche) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Im Katalog suchen")
                    .font(.callout)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color(.textSecondary))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    private var liste: some View {
        ScrollViewReader { proxy in
            listeInhalt
                .modifier(PadListenTasten(aktiv: true, fokus: $listeFokus) { schritt in
                    waehleNachbar(schritt, proxy: proxy)
                })
        }
    }

    /// ↑/↓: der vorige bzw. nächste Titel in der Reihenfolge der Liste (erst Offen, dann Gefunden), an den Enden bleibt es stehen.
    private func waehleNachbar(_ schritt: Int, proxy: ScrollViewProxy) {
        guard !alle.isEmpty else { return }
        let aktuell = alle.firstIndex { $0.id == gewaehlteID } ?? (schritt > 0 ? -1 : alle.count)
        let neu = min(max(aktuell + schritt, 0), alle.count - 1)
        onWahl(alle[neu])
        withAnimation { proxy.scrollTo(alle[neu].id) }
    }

    private var listeInhalt: some View {
        List {
            ForEach(offen) { zeile($0) }

            if !gefunden.isEmpty {
                Text("Gefunden · \(gefunden.count)")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .foregroundStyle(Color(.textSecondary))
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .listZeile(links: rand.links + 2, rechts: rand.rechts + 2)
                ForEach(gefunden) { zeile($0) }
            }

            Text("Kreis tippen oder nach links wischen: gefunden. Nach rechts wischen: entfernen. Mit Maus oder Trackpad auch per Kontextmenü. Die Merkliste liegt nur auf diesem Gerät, eine Anmeldung ist nicht nötig.")
                .font(.caption)
                .foregroundStyle(Color(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
                .listZeile(links: rand.links + 4, rechts: rand.rechts + 4)

            SoftDestructiveButton("Merkliste leeren", action: onLeeren)
                .padding(.top, 4)
                .listZeile(links: rand.links, rechts: rand.rechts, unten: 28)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await onAktualisieren() }
    }

    /// Eine Karte: Kreis (44 pt) hakt ab, der Rest wählt den Titel rechts. Wischen wie auf dem iPhone.
    private func zeile(_ eintrag: GemerkterTitel) -> some View {
        let gewaehlt = eintrag.id == gewaehlteID
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 4) {
            abhakKreis(eintrag)
            Button {
                onWahl(eintrag)
                // Danach gehen die Pfeiltasten.
                listeFokus = true
            } label: {
                BibMerklisteZeile(
                    eintrag: eintrag,
                    status: status.status(for: eintrag.id),
                    exemplar: status.exemplar(for: eintrag.id),
                    pad: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(gewaehlt ? .isSelected : [])
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(Color(.surface), in: form)
        .overlay {
            if gewaehlt { form.strokeBorder(Color(.accent), lineWidth: 2) }
        }
        .contentShape(.hoverEffect, form)
        .hoverEffect()
        .contextMenu {
            Button {
                onGefunden(!eintrag.istGefunden, eintrag)
            } label: {
                if eintrag.istGefunden {
                    Label("Nicht gefunden", systemImage: "arrow.uturn.backward")
                } else {
                    Label("Gefunden", systemImage: "checkmark")
                }
            }
            Button(role: .destructive) {
                onEntfernen(eintrag)
            } label: {
                Label("Entfernen", systemImage: "trash")
            }
        }
        .listZeile(links: rand.links, rechts: rand.rechts)
        .id(eintrag.id)
        // Wischen bleibt wie auf dem iPhone: nach rechts „Entfernen“, nach links „Gefunden“.
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onEntfernen(eintrag)
            } label: {
                Label("Entfernen", systemImage: "trash")
            }
            .tint(Color(.swipeDelete))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if eintrag.istGefunden {
                Button {
                    onGefunden(false, eintrag)
                } label: {
                    Label("Nicht gefunden", systemImage: "arrow.uturn.backward")
                }
                .tint(Color(.swipeNeutral))
            } else {
                Button {
                    onGefunden(true, eintrag)
                } label: {
                    Label("Gefunden", systemImage: "checkmark")
                }
                .tint(Color(.swipeFound))
            }
        }
    }

    /// Wie auf der Uhr: leer mit Rand `textTertiary`, abgehakt `green` mit Häkchen. 24 pt sichtbar, 44 pt Tippfläche.
    private func abhakKreis(_ eintrag: GemerkterTitel) -> some View {
        let an = eintrag.istGefunden
        return Button {
            onGefunden(!an, eintrag)
        } label: {
            ZStack {
                Circle().fill(an ? Color(.green) : Color.clear)
                Circle().strokeBorder(an ? Color(.green) : Color(.textTertiary), lineWidth: 2)
                if an {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color(.onGreen))
                }
            }
            .frame(width: 24, height: 24)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(an ? "Gefunden" : "Nicht gefunden")
        .accessibilityHint(an ? "Haken entfernen" : "Als gefunden abhaken")
    }

    // MARK: Rechts

    @ViewBuilder
    private var rechteSeite: some View {
        if let id = gewaehlteID, let eintrag = alle.first(where: { $0.id == id }) {
            Group {
                if let vorschauTitel {
                    KatalogTitelPadDetail(
                        model: vorschauTitel(eintrag), onMerkliste: {}, ladet: false, origin: .merkliste,
                        onEntfernen: { onEntfernen(eintrag) }
                    )
                } else {
                    KatalogTitelPadDetail(
                        media: eintrag.alsMedia,
                        searchId: nil,
                        service: service,
                        coverLoader: coverLoader,
                        onMerkliste: {},
                        origin: .merkliste,
                        onEntfernen: { onEntfernen(eintrag) }
                    )
                }
            }
            .id(eintrag.id)
        } else {
            // Leere Liste: rechts nichts außer dem Hintergrund.
            Color.clear
        }
    }
}

private extension View {
    /// Zeile der Liste ohne Trenner und Hintergrund; die Ränder setzt die Zeile selbst.
    func listZeile(links: CGFloat, rechts: CGFloat, unten: CGFloat = 5) -> some View {
        listRowInsets(EdgeInsets(top: 5, leading: links, bottom: unten, trailing: rechts))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
