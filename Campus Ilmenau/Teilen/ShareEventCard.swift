import SwiftUI

// Bild einer Veranstaltung nach `Uebergabe.md`, Kapitel „Teilen“ → „Veranstaltung“, Artboard `TeilenKarte.dc.html`:
// eine Eintrittskarte auf Nachtblau, ohne Diagonalbänder, ohne Plakat, ohne Logo des Veranstalters.

/// Form der Eintrittskarte: abgerundetes Rechteck (Ecken 22) mit zwei echten halbrunden Kerben (Ø 22) am linken und
/// rechten Rand auf Höhe `notchY`. Die Kerben sind aus der Fläche geschnitten, dort scheint der Hintergrund durch.
struct TicketShape: Shape {
    static let cornerRadius: CGFloat = 22
    static let notchDiameter: CGFloat = 22

    var notchY: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = Self.notchDiameter / 2
        var notches = Path()
        notches.addEllipse(in: CGRect(x: rect.minX - radius, y: notchY - radius, width: Self.notchDiameter, height: Self.notchDiameter))
        notches.addEllipse(in: CGRect(x: rect.maxX - radius, y: notchY - radius, width: Self.notchDiameter, height: Self.notchDiameter))
        return Path(roundedRect: rect, cornerRadius: Self.cornerRadius, style: .continuous).subtracting(notches)
    }
}

/// Gestrichelte Linie (2 pt) des Abrisses, 20 pt vom linken und rechten Rand entfernt.
private struct TearLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 20, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 20, y: rect.midY))
        return path
    }
}

/// Die Höhe der Abrisszeile, damit die Kerben genau dort sitzen, wo die Zeile liegt.
private struct TicketCutKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// Chip über dem Veranstalter: 11 pt Semibold, 8/2 pt Innenabstand.
private struct TicketStatusChip: View {
    let title: String
    let background: Color
    let foreground: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(background, in: Capsule())
    }
}

/// Die Eintrittskarte: oben Veranstalter, Titel, Beginn und Datum, dann der Abriss, unten Ort und Beschreibung.
/// Abgesagt und unbestätigt haben einen Chip und einen Kasten; fehlende Angaben entfallen.
struct ShareEventTicket: View {
    let share: EventShare

    private var event: CampusEvent { share.event }
    private var locale: Locale { share.locale }
    private var strings: ShareStrings { ShareStrings(locale: locale) }
    private var isCancelled: Bool { event.status == .abgesagt }

    var body: some View {
        VStack(spacing: 0) {
            top
            tear
            bottom
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: TicketShape.cornerRadius, style: .continuous))
        .backgroundPreferenceValue(TicketCutKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    TicketShape(notchY: proxy[anchor].midY)
                        .fill(Color(.surface))
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                }
            }
        }
    }

    // MARK: Oberer Teil

    private var top: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let chip = statusChip {
                chip.padding(.bottom, 10)
            }

            HStack(spacing: 6) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 13))
                Text(organizer)
                    .font(.system(size: 11.5, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.69)
                    .lineLimit(1)
            }
            // Schrift auf Nachtblau, kein Button: `accent` ist im Dunklen hell genug.
            .foregroundStyle(Color(.accent))

            Text(event.titel)
                .display(size: 31, relativeTo: .title)
                .lineSpacing(-3)
                .strikethrough(isCancelled)
                .opacity(isCancelled ? 0.85 : 1)
                .foregroundStyle(Color(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(start)
                    .display(size: 46, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                if !until.isEmpty {
                    Text(until)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(.textSecondary))
                        .lineLimit(1)
                }
            }
            .padding(.top, 18)

            Text(share.dateText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            if let note = statusNote {
                Text(note.text)
                    .font(.system(size: 13, weight: note.isAlert ? .semibold : .medium))
                    .foregroundStyle(note.isAlert ? Color(.danger) : Color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        note.isAlert ? Color(.dangerSoft) : Color(.surfaceSecondary),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .padding(.top, 14)
            }
        }
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 18, trailing: 20))
        .frame(maxWidth: .infinity, alignment: .leading)
        // Weicher oranger Schein oben rechts: orange.500 mit 28 %, läuft bis zur Kartenmitte aus
        // (CSS: radial-gradient(120% 90% at 100% 0%, … 0, transparent 60%)).
        .background {
            ShareGlow(color: Color(.brandOrange).opacity(0.28), anchor: UnitPoint(x: 1, y: 0), widthFactor: 1.2 * 0.6, heightFactor: 0.9 * 0.6)
        }
    }

    /// Veranstalter, sonst die Kategorie („Veranstaltung“, „Frist“).
    private var organizer: String {
        ShareText.clean(event.veranstalter) ?? ShareText.clean(event.kategorie) ?? strings("share.card.event.fallbackOrganizer")
    }

    /// Beginn groß: „21:00“, ganztägig „Ganztägig“.
    private var start: String {
        event.ganztaegig ? strings("share.card.event.allDay") : EventZeitFormatter.uhrzeit(event.beginn)
    }

    /// Daneben „bis 03:00 Uhr“, ohne Ende nur „Uhr“, ganztägig nichts.
    private var until: String {
        if event.ganztaegig { return "" }
        if let end = event.ende, end > event.beginn, !event.istMehrtaegig {
            return strings("share.card.event.until", EventZeitFormatter.uhrzeit(end))
        }
        return strings("share.card.event.noEnd")
    }

    private var statusChip: TicketStatusChip? {
        switch event.status {
        case .abgesagt:
            TicketStatusChip(title: strings("share.card.event.cancelledChip"), background: Color(.dangerSoft), foreground: Color(.danger))
        case .unbestaetigt:
            // Weiße Fläche mit dunkler Schrift, wie im Artboard.
            TicketStatusChip(title: strings("share.card.event.tentativeChip"), background: Color(.textPrimary).opacity(0.92), foreground: Color(.brandNight))
        case .findetStatt:
            nil
        }
    }

    private var statusNote: (text: String, isAlert: Bool)? {
        switch event.status {
        case .abgesagt: (strings("share.card.event.cancelledNote"), true)
        case .unbestaetigt: (strings("share.card.event.tentativeNote"), false)
        case .findetStatt: nil
        }
    }

    // MARK: Abriss

    private var tear: some View {
        Color.clear
            .frame(height: TicketShape.notchDiameter)
            .overlay {
                TearLine().stroke(Color(.separator), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            }
            .anchorPreference(key: TicketCutKey.self, value: .bounds) { $0 }
    }

    // MARK: Unterer Teil

    private var bottom: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let place {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(.textTertiary))
                        .frame(width: 18)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(place.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(.textPrimary))
                            .fixedSize(horizontal: false, vertical: true)
                        if let address = place.address {
                            Text(address)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color(.textSecondary))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if let description {
                Text(description)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color(.textSecondary))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, place == nil ? 0 : 12)
            }
        }
        .padding(EdgeInsets(top: 4, leading: 20, bottom: 18, trailing: 20))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var place: (name: String, address: String?)? {
        let name = ShareText.clean(event.ort)
        let address = ShareText.clean(event.adresse)
        guard let primary = name ?? address else { return nil }
        return (primary, name == nil ? nil : address)
    }

    /// Abgesagt: keine Beschreibung. Absätze werden zu einem Fließtext (die Karte zeigt höchstens drei Zeilen).
    private var description: String? {
        guard !isCancelled, let text = ShareText.clean(event.beschreibung) else { return nil }
        return text.replacingOccurrences(of: "\\s*\\n\\s*", with: " ", options: .regularExpression)
    }
}

// MARK: - Anbindung an den Inhalt

extension EventShare: ShareImageContent {
    /// Immer nachtblau; die Marke steht als Fußzeile auf dem Nachtblau unter der Karte, ganz unten im Bild.
    var card: some View {
        ShareCardView(style: .night) {
            ShareEventTicket(share: self)
            Spacer(minLength: 0)
            ShareBrandFooter(placement: .onBackground)
                .padding(.top, 12)
        }
    }

    /// „Halloween-Party.png“
    var imageFileName: String {
        let name = ShareFileName.slug(event.titel)
        return (name.isEmpty ? "Veranstaltung" : name) + ".png"
    }
}
