import SwiftUI
import AppIntents

// Die Karten unter den Siri-Antworten (`Siri.dc.html`). Sie zeigen etwas mehr als der gesprochene Satz (Preise, Chips),
// aber nichts Neues. Karte und Zeilen sind `Button(intent: OeffneZielIntent(...))`: Sie öffnen die App am Ziel und
// gehen damit denselben Weg wie die Steuerelemente. Farben nur aus den Assets, Light und Dark schalten automatisch.

// MARK: - Mensa heute, Abendessen

/// Die Karte zu „Mensa heute“ und „Abendessen“. Ohne Karte (kein Plan, keine Daten) zeichnet sie nichts.
struct SiriMensaAntwortView: View {
    let karte: SiriMensaKarte?

    var body: some View {
        if let karte {
            SiriMensaKarteView(karte: karte)
        }
    }
}

struct SiriMensaKarteView: View {
    let karte: SiriMensaKarte

    @Environment(\.dynamicTypeSize) private var schriftgroesse

    var body: some View {
        VStack(spacing: 0) {
            Button(intent: OeffneZielIntent(url: karte.kopfLink)) { kopf }
                .buttonStyle(.plain)
            if !karte.gerichte.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(karte.gerichte.enumerated()), id: \.element.id) { index, gericht in
                        if index > 0 { Rectangle().fill(Color(.separator)).frame(height: 0.5) }
                        Button(intent: OeffneZielIntent(url: gericht.link)) { zeile(gericht) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
            Button(intent: OeffneZielIntent(url: karte.kopfLink)) { fuss }
                .buttonStyle(.plain)
        }
    }

    // Kopf: Blau mit grünem Band, Kicker, Name in Jakarta ExtraBold 19, ggf. Filterzeile.
    private var kopf: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(karte.kicker)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.4)
                .opacity(0.9)
            Text(karte.titel)
                .display(size: 19, relativeTo: .title3)
            if let filterzeile = karte.filterzeile {
                Label(filterzeile, systemImage: "line.3.horizontal.decrease")
                    .font(.caption)
                    .opacity(0.9)
                    .padding(.top, 1)
            }
        }
        .foregroundStyle(Color(.onBlue))
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Bei sehr großer Schrift nimmt der Text die ganze Breite ein; dann entfällt das Band (Kontrast).
            if schriftgroesse.isAccessibilitySize {
                Color(.blue)
            } else {
                DiagonalBands(.hero, height: nil) { EmptyView() }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // Gericht: Name 15 Semibold (2 Zeilen), Chips, rechts der Preis der eigenen Preisgruppe.
    private func zeile(_ gericht: MensaWidgetAnzeige.Zeile) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(gericht.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(schriftgroesse.isAccessibilitySize ? nil : 2)
                if !gericht.chips.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(gericht.chips, id: \.self) { chip in
                            Chip(LocalizedStringKey(chip.titel), variant: chip.art.variante)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Text(gericht.preis)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color(.textPrimary))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 9)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // Fuß: „+3 weitere Gerichte“ links, „Speiseplan ›“ in accent (ein Link, kein Button).
    private var fuss: some View {
        HStack {
            Text(karte.fuss)
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
            Spacer(minLength: 8)
            Text("Speiseplan ›", tableName: "Siri")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.accent))
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Öffnet den Speiseplan", tableName: "Siri"))
    }
}

private extension WidgetChip.Art {
    var variante: Chip.Variant {
        switch self {
        case .gruen: .green
        case .blau: .blue
        case .neutral: .neutral
        }
    }
}

// MARK: - Mensa offen?

struct SiriOffenAntwortView: View {
    let karte: SiriOffenKarte?

    var body: some View {
        if let karte {
            SiriOffenKarteView(karte: karte)
        }
    }
}

/// Die Antwort steht vorn (Jakarta ExtraBold 25), darunter die Liste aller vier Mensen. Die ganze Karte öffnet
/// die Öffnungszeiten.
struct SiriOffenKarteView: View {
    let karte: SiriOffenKarte

    var body: some View {
        Button(intent: OeffneZielIntent(url: karte.link)) {
            VStack(alignment: .leading, spacing: 0) {
                Text(karte.gross)
                    .display(size: 25, relativeTo: .title)
                    .foregroundStyle(Color(.textPrimary))
                    .padding(.horizontal, 4)
                Text(karte.klein)
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                ForEach(karte.zeilen) { zeile in
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                    SiriOffenZeileView(zeile: zeile)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SiriOffenZeileView: View {
    let zeile: SiriOffenKarte.Zeile

    /// Für VoiceOver: „Cafeteria Nanoteria, offen, bis 15:00, noch 25 Min.“
    private var sprechtext: String {
        let zustand = zeile.offen ? String(localized: "offen", table: "Siri") : String(localized: "zu", table: "Siri")
        return ([zeile.name, zustand, zeile.stat] + (zeile.chip.map { [$0] } ?? [])).joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 9) {
            // Punkt: Grün ist hier eine Fläche, kein Text. Zu: grau.
            Circle()
                .fill(zeile.offen ? Color(.green) : Color(.textTertiary))
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
            Text(zeile.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.textPrimary))
            Spacer(minLength: 8)
            Text(zeile.stat)
                .font(.footnote)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color(.textSecondary))
            if let chip = zeile.chip {
                Chip(LocalizedStringKey(chip), variant: .green)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 9)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: sprechtext))
    }
}

// MARK: - Heute Abend

/// Die Karte zu „Was ist heute Abend los?“. Ohne Karte (keine Daten) zeichnet sie nichts.
struct SiriAbendAntwortView: View {
    let karte: SiriAbendKarte?

    var body: some View {
        if let karte {
            SiriAbendKarteView(karte: karte)
        }
    }
}

/// Immer nachtblau wie das kleine Abend-Widget: im hellen Modus `brandNight`, im dunklen `surfaceSecondary`, damit sie
/// sich vom Hintergrund abhebt. Der Inhalt rechnet mit den Farben des dunklen Modus, auch bei hellem System.
/// Zeile → Event-Detail, Kopf und Fuß → „Heute Abend“.
struct SiriAbendKarteView: View {
    let karte: SiriAbendKarte

    @Environment(\.colorScheme) private var farbschema

    var body: some View {
        VStack(spacing: 0) {
            Button(intent: OeffneZielIntent(url: karte.kopfLink)) { kopf }
                .buttonStyle(.plain)
            if let leerText = karte.leerText {
                leer(leerText)
            }
            ForEach(karte.zeilen) { zeile in
                Rectangle().fill(Color(.separator)).frame(height: 0.5)
                Button(intent: OeffneZielIntent(url: zeile.link)) { SiriAbendZeileView(zeile: zeile) }
                    .buttonStyle(.plain)
            }
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
            Button(intent: OeffneZielIntent(url: karte.kopfLink)) { fuss }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .environment(\.colorScheme, .dark)
        .background(farbschema == .dark ? Color(.surfaceSecondary) : Color(.brandNight))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // Kopf: Mond in accent, „Heute Abend“ in Jakarta ExtraBold 16, rechts das Datum.
    private var kopf: some View {
        HStack(spacing: 7) {
            Image(systemName: "moon.fill")
                .font(.subheadline)
                .foregroundStyle(Color(.accent))
                .accessibilityHidden(true)
            Text(karte.titel)
                .display(size: 16, relativeTo: .headline)
                .foregroundStyle(Color(.textPrimary))
            Spacer(minLength: 8)
            Text(karte.datum)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func leer(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nichts eingetragen", tableName: "Siri")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(.textPrimary))
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    // Fuß: „+1 weitere heute“ links, „Alle ›“ in accent (ein Link, kein Button).
    private var fuss: some View {
        HStack {
            Text(karte.fuss)
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
            Spacer(minLength: 8)
            Text("Alle ›", tableName: "Siri")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.accent))
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Zeigt alle Veranstaltungen heute Abend", tableName: "Siri"))
    }
}

/// Uhrzeit, Titel (durchgestrichen bei Absage), Ort, Chip „Läuft gerade“ oder „Fällt aus“, Stern für Gemerktes.
private struct SiriAbendZeileView: View {
    let zeile: AbendWidgetAnzeige.Zeile

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(zeile.zeit)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(zeile.abgesagt ? Color(.textTertiary) : Color(.textPrimary))
                // Mindestens 44 pt wie im Mockup, bei größerer Schrift breiter, nie umgebrochen („19:0 / 0“).
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(zeile.titel)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(zeile.abgesagt)
                        .foregroundStyle(zeile.abgesagt ? Color(.textTertiary) : Color(.textPrimary))
                    if zeile.gemerkt {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(.accent))
                            .accessibilityLabel(Text("Gemerkt", tableName: "Siri"))
                    }
                }
                if !zeile.ort.isEmpty {
                    Text(zeile.ort)
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                }
            }
            Spacer(minLength: 8)
            if zeile.abgesagt {
                Chip(LocalizedStringKey(String(localized: "Fällt aus", table: "Siri")), variant: .dangerSoft)
            } else if zeile.laeuft {
                Chip(LocalizedStringKey(String(localized: "Läuft gerade", table: "Siri")), variant: .green)
            }
        }
        .padding(.vertical, 9)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Katalogsuche

/// Die Karte zu „Suche im Katalog“. Ohne Karte (Katalog nicht erreichbar) zeichnet sie nichts.
struct SiriKatalogAntwortView: View {
    let karte: SiriKatalogKarte?

    var body: some View {
        if let karte {
            SiriKatalogKarteView(karte: karte)
        }
    }
}

/// Kicker „Katalog der UB“, Trefferzahl, die ersten 3 Treffer mit Status-Chip. Treffer → Titel, Kopf und Fuß → die Suche.
struct SiriKatalogKarteView: View {
    let karte: SiriKatalogKarte

    var body: some View {
        VStack(spacing: 0) {
            Button(intent: OeffneZielIntent(url: karte.alleLink)) { kopf }
                .buttonStyle(.plain)
            ForEach(karte.treffer) { treffer in
                Rectangle().fill(Color(.separator)).frame(height: 0.5)
                Button(intent: OeffneZielIntent(url: treffer.link)) { SiriKatalogTrefferView(treffer: treffer) }
                    .buttonStyle(.plain)
            }
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
            Button(intent: OeffneZielIntent(url: karte.alleLink)) { fuss }
                .buttonStyle(.plain)
        }
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(karte.kicker)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(Color(.accent))
            Text(karte.titel)
                .display(size: 18, relativeTo: .title3)
                .foregroundStyle(Color(.textPrimary))
            Text(karte.untertitel)
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // Fuß: „Ohne Anmeldung“ links, „Alle Treffer ›“ in accent (ein Link, kein Button).
    private var fuss: some View {
        HStack {
            Text(karte.fuss)
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
            Spacer(minLength: 8)
            Text("Alle Treffer ›", tableName: "Siri")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.accent))
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Öffnet die Suche im Katalog", tableName: "Siri"))
    }
}

/// Titel (2 Zeilen), „Autor · Jahr · Art“ und, wenn er rechtzeitig kam, der Status-Chip wie in der Suche.
private struct SiriKatalogTrefferView: View {
    let treffer: SiriKatalogTreffer

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(treffer.titel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(2)
            if !treffer.meta.isEmpty {
                Text(treffer.meta)
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
            }
            if let status = treffer.status {
                Chip(LocalizedStringKey(status.chipText), variant: status.art.chipVariante)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private extension SiriKatalogStatus.Art {
    /// Wie in der Suche: Ausleihbar und Online grün, Nur vor Ort blau, Ausgeliehen neutral.
    var chipVariante: Chip.Variant {
        switch self {
        case .ausleihbar, .online: .green
        case .nurVorOrt: .blue
        case .ausgeliehen: .neutral
        }
    }
}

// MARK: - Merkliste

/// Die Karte zu „Merkliste“. Leer oder ohne Stand zeichnet sie nichts, dann sagt Siri alles.
struct SiriMerklisteAntwortView: View {
    let karte: SiriMerklisteKarte?

    var body: some View {
        if let karte {
            SiriMerklisteKarteView(karte: karte)
        }
    }
}

/// „3 Titel im Regal“, nach Standort gruppiert, je Titel die Signatur in Monospace. Die ganze Karte öffnet die Merkliste.
struct SiriMerklisteKarteView: View {
    let karte: SiriMerklisteKarte

    var body: some View {
        Button(intent: OeffneZielIntent(url: karte.link)) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bibliothek", tableName: "Siri")
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .foregroundStyle(Color(.accent))
                    Text(karte.titel)
                        .display(size: 18, relativeTo: .title3)
                        .foregroundStyle(Color(.textPrimary))
                    Text(karte.untertitel)
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                ForEach(karte.standorte) { standort in
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                    HStack(alignment: .firstTextBaseline) {
                        Text(standort.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(.textPrimary))
                        Spacer(minLength: 8)
                        Text("\(standort.anzahl) Titel", tableName: "Siri")
                            .font(.caption)
                            .foregroundStyle(Color(.textSecondary))
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    ForEach(standort.titel) { zeile in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(zeile.titel)
                                .font(.footnote)
                                .foregroundStyle(Color(.textPrimary))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if let signatur = zeile.signatur {
                                Text(signatur)
                                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(Color(.textSecondary))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .frame(minHeight: 28)
                        .accessibilityElement(children: .combine)
                    }
                }

                Rectangle().fill(Color(.separator)).frame(height: 0.5).padding(.top, 4)
                HStack {
                    Text(karte.fuss)
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                    Spacer(minLength: 8)
                    Text("Merkliste ›", tableName: "Siri")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.accent))
                }
                .padding(.horizontal, 4)
                .frame(minHeight: 44)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
