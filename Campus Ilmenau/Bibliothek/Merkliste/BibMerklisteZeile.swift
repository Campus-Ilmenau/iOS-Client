import SwiftUI

extension LibraryAvailabilityStatus {
    /// Kurzer Text im Status-Chip der Listen: Ausleihbar, Online, Ausgeliehen, Nur vor Ort, Unbekannt.
    var chipText: String {
        switch self {
        case .available: "Ausleihbar"
        case .onLoan: "Ausgeliehen"
        case .referenceOnly: "Nur vor Ort"
        case .online: "Online"
        case .unknown: "Unbekannt"
        }
    }
}

/// Zeile der Merkliste: Cover oder Platzhalter, Titel, „Personen · Jahr“, Status-Chip und Medienart.
/// Den Chevron zeichnet der `NavigationLink` der Liste.
struct BibMerklisteZeile: View {
    let eintrag: GemerkterTitel
    /// `nil`, solange der Status noch lädt (Chip „…“).
    let status: LibraryAvailabilityStatus?
    /// Signatur und Standort, sobald die Verfügbarkeit geladen ist.
    var exemplar: BibMerklisteExemplar?
    /// „Lageplan“: öffnet den Plan des Standorts.
    var onLageplan: (URL) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cover

            VStack(alignment: .leading, spacing: 0) {
                Text(eintrag.anzeigeTitel)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !eintrag.untertitel.isEmpty {
                    Text(eintrag.untertitel)
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                        .lineLimit(1)
                        .padding(.top, 1)
                }

                // Bei großer Schrift darf Chip und Medienart untereinander stehen.
                ChipFlowLayout(spacing: 8) {
                    statusChip
                    Text(eintrag.mediaType.displayName)
                        .font(.caption)
                        .foregroundStyle(Color(.textTertiary))
                }
                .padding(.top, 6)

                if let exemplar {
                    exemplarZeilen(exemplar)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        // Die Zeile ist ein Element; der Lageplan bleibt über eine eigene Aktion erreichbar.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityActions {
            if let plan = exemplar?.lageplan {
                Button("Lageplan öffnen") { onLageplan(plan) }
            }
        }
    }

    /// „Signatur …“ und „Standort …“ mit dem Button zum Lageplan.
    private func exemplarZeilen(_ exemplar: BibMerklisteExemplar) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let signatur = exemplar.signatur {
                angabe("Signatur", wert: signatur, nichtProportional: true)
            }
            if let standort = exemplar.standort {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    angabe("Standort", wert: standort, zusatz: exemplar.weitere > 0 ? "+\(exemplar.weitere)" : nil)
                    if let plan = exemplar.lageplan {
                        Spacer(minLength: 0)
                        lageplanButton(plan)
                    }
                }
            }
        }
    }

    /// „Signatur  ST 130 R434“: blasse Bezeichnung, danach der Wert. Läuft bei Bedarf in die nächste Zeile.
    private func angabe(_ name: String, wert: String, nichtProportional: Bool = false, zusatz: String? = nil) -> some View {
        let bezeichnung = Text(name + "  ").foregroundStyle(Color(.textTertiary))
        let wertText = Text(wert)
            .font(nichtProportional ? .system(.footnote, design: .monospaced).weight(.semibold) : .footnote)
            .foregroundStyle(Color(.textPrimary))
        let zusatzText = Text(zusatz.map { "  " + $0 } ?? "").foregroundStyle(Color(.textTertiary))
        return Text("\(bezeichnung)\(wertText)\(zusatzText)")
            .font(.footnote)
            .multilineTextAlignment(.leading)
    }

    private func lageplanButton(_ plan: URL) -> some View {
        Button {
            onLageplan(plan)
        } label: {
            HStack(spacing: 3) {
                Text("Lageplan")
                Image(systemName: "map").font(.caption2.weight(.bold))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(.accent))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        // Im Listeneintrag tippt man sonst die ganze Zeile
        .buttonStyle(.borderless)
        .padding(.vertical, -14)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusChip: some View {
        if let status {
            Chip(LocalizedStringKey(status.chipText), variant: status.chipVariant)
        } else {
            Chip("…", variant: .neutral)
        }
    }

    private var accessibilityText: String {
        var parts: [String] = [
            eintrag.anzeigeTitel,
            eintrag.untertitel,
            status?.chipText ?? "Verfügbarkeit wird geladen",
            eintrag.mediaType.displayName
        ]
        if let signatur = exemplar?.signatur { parts.append("Signatur \(signatur)") }
        if let standort = exemplar?.standort {
            let weitere = exemplar?.weitere ?? 0
            parts.append(weitere > 0 ? "Standort \(standort), und \(weitere) weitere Exemplare" : "Standort \(standort)")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// 44 × 62 mit Ecken 4; ohne Cover ein Platzhalter mit Buchsymbol.
    private var cover: some View {
        AsyncImage(url: eintrag.coverURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                ZStack {
                    Color(.surfaceSecondary)
                    Image(systemName: eintrag.mediaType.placeholderSymbol)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color(.textTertiary))
                }
            }
        }
        .frame(width: 44, height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .accessibilityHidden(true)
    }
}
