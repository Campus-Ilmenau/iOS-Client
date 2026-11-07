import SwiftUI

// Bild-Karten zum Teilen nach `Uebergabe.md`, Kapitel „Teilen“ → „Bild-Karten“, Artboard `TeilenKarte.dc.html`.
// Alle Maße sind feste Punkte: Das Bild sieht auf jedem Gerät gleich aus, egal ob Hell/Dunkel oder Textgröße.

/// Darstellung des Bildes: hell (Speiseplan, Gericht) oder nachtblau (Veranstaltung), unabhängig vom Gerät.
enum ShareCardStyle {
    case light
    case night
}

/// Rahmen des Bildes: 360 pt breit, Höhe nach Inhalt (mindestens 450 pt), Verlauf als Hintergrund, 16 pt Rand,
/// darin die Karte. Fester Modus und feste Schriftgröße.
struct ShareCardView<Content: View>: View {
    static var width: CGFloat { 360 }
    static var minHeight: CGFloat { 450 }

    private let style: ShareCardStyle
    private let content: Content

    init(style: ShareCardStyle = .light, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
        .frame(width: Self.width)
        .frame(minHeight: Self.minHeight, alignment: .top)
        .background { ShareCardBackdrop(style: style) }
        .dynamicTypeSize(.large)
        .environment(\.colorScheme, style == .night ? .dark : .light)
    }
}

/// Ein elliptischer Schein: ein runder Verlauf mit Radius 1, auf die beiden Radien gestreckt. `widthFactor` und
/// `heightFactor` sind die Radien als Anteil von Breite und Höhe der umgebenden Fläche (CSS: Größe × Stopp-Position).
struct ShareGlow: View {
    let color: Color
    let anchor: UnitPoint
    let widthFactor: CGFloat
    let heightFactor: CGFloat

    var body: some View {
        GeometryReader { proxy in
            RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: 1)
                .frame(width: 2, height: 2)
                .scaleEffect(x: widthFactor * proxy.size.width, y: heightFactor * proxy.size.height)
                .position(x: proxy.size.width * anchor.x, y: proxy.size.height * anchor.y)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

/// Verlauf. Hell: Orange oben rechts und Blau unten links auf hellem Blau (Palette: orange.200, blue.200, blue.100).
/// Nachtblau: dasselbe mit orange.900 und blue.900 auf `background` (blue.950).
private struct ShareCardBackdrop: View {
    let style: ShareCardStyle

    var body: some View {
        ZStack {
            switch style {
            case .light:
                Color(.shareBackdrop)
                // CSS: radial-gradient(120% 60% at 90% 0%, orange.200 0, transparent 60%)
                ShareGlow(color: Color(.shareGlowOrange), anchor: UnitPoint(x: 0.9, y: 0), widthFactor: 1.2 * 0.6, heightFactor: 0.6 * 0.6)
                // CSS: radial-gradient(110% 60% at 0% 100%, blue.200 0, transparent 65%)
                ShareGlow(color: Color(.shareGlowBlue), anchor: UnitPoint(x: 0, y: 1), widthFactor: 1.1 * 0.65, heightFactor: 0.6 * 0.65)
            case .night:
                Color(.background)
                // CSS: radial-gradient(90% 50% at 90% 0%, orange.900 0, transparent 70%)
                ShareGlow(color: Color(.shareNightGlowOrange), anchor: UnitPoint(x: 0.9, y: 0), widthFactor: 0.9 * 0.7, heightFactor: 0.5 * 0.7)
                // CSS: radial-gradient(110% 60% at 0% 100%, blue.900 0, transparent 65%)
                ShareGlow(color: Color(.surfaceSecondary), anchor: UnitPoint(x: 0, y: 1), widthFactor: 1.1 * 0.65, heightFactor: 0.6 * 0.65)
            }
        }
    }
}

// MARK: - Bausteine

/// Die weiße Karte: `surface`, Ecken 22, feiner Schatten.
private struct ShareCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.surface))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color(.brandNight).opacity(0.06), radius: 1, x: 0, y: 1)
    }
}

private extension View {
    func shareCardSurface() -> some View { modifier(ShareCardSurface()) }

    /// Trennlinie oben, 1 pt `separator`; bei der ersten Zeile einer Liste `hidden`.
    func shareTopRule(hidden: Bool = false) -> some View {
        overlay(alignment: .top) {
            if !hidden { Rectangle().fill(Color(.separator)).frame(height: 1) }
        }
    }
}

/// Chip auf dem Bild: 11 pt Semibold, 8/2 pt Innenabstand. Grün und Blau sind Flächen mit eigener Schriftfarbe.
private struct ShareChip: View {
    let title: String
    let variant: Chip.Variant

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(background, in: Capsule())
    }

    private var background: Color {
        switch variant {
        case .green: Color(.green)
        case .blue: Color(.blue)
        default: Color(.surfaceSecondary)
        }
    }

    private var foreground: Color {
        switch variant {
        case .green: Color(.onGreen)
        case .blue: Color(.onBlue)
        default: Color(.textSecondary)
        }
    }
}

private struct ShareChips: View {
    let chips: [MensaChipItem]
    let strings: ShareStrings

    var body: some View {
        ChipFlowLayout(spacing: 4) {
            ForEach(chips, id: \.self) { chip in
                ShareChip(title: chip.shareTitle(strings), variant: chip.variant)
            }
        }
    }
}

/// Marke: Ziege (`brandOrange`), „Campus Ilmenau“ und die Webadresse. Bei Speiseplan und Gericht ist sie die letzte Zeile
/// in der weißen Karte (Trennlinie darüber), bei der Veranstaltung die Fußzeile auf dem Nachtblau unter der Karte.
struct ShareBrandFooter: View {
    enum Placement {
        /// Letzte Zeile in der Karte, 12/18/14 pt Innenabstand, Trennlinie oben.
        case inCard
        /// Fußzeile auf dem Hintergrund, 2/4/0 pt Innenabstand.
        case onBackground
    }

    var placement: Placement = .inCard

    var body: some View {
        switch placement {
        case .inCard:
            line
                .padding(EdgeInsets(top: 12, leading: 18, bottom: 14, trailing: 18))
                .shareTopRule()
        case .onBackground:
            line
                .padding(EdgeInsets(top: 2, leading: 4, bottom: 0, trailing: 4))
        }
    }

    private var line: some View {
        HStack(spacing: 8) {
            Image("SymbolWhite")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color(.brandOrange))
                .accessibilityHidden(true)
            Text("Campus Ilmenau")
                .font(.custom("PlusJakartaSans-ExtraBold", fixedSize: 15))
                .tracking(-0.15)
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
            // Eine längere Domain schrumpft leicht, statt die Karte über den Rand zu schieben.
            Text(ShareBranding.domain)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color(.textSecondary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Speiseplan

/// Speiseplan einer Mensa an einem Tag, aufgebaut wie das große Mensa-Widget: blauer Kopf mit grünem Band, eine Zeile je
/// Gericht (alle, Namen brechen um), Hinweis, Marke.
struct SharePlanCard: View {
    let share: MensaPlanShare

    private var strings: ShareStrings { ShareStrings(locale: share.locale) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(spacing: 0) {
                ForEach(Array(share.meals.enumerated()), id: \.offset) { index, meal in
                    row(meal)
                        .padding(.vertical, 11)
                        .shareTopRule(hidden: index == 0)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 2)

            Text(note)
                .font(.system(size: 12))
                .foregroundStyle(Color(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 10, leading: 18, bottom: 14, trailing: 18))
                .shareTopRule()
            ShareBrandFooter()
        }
        .shareCardSurface()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ShareDate.full(share.day, locale: share.locale))
                .font(.system(size: 11.5, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.46)
                .opacity(0.9)
            Text(share.venue.displayName)
                .display(size: 23, relativeTo: .title)
                .lineSpacing(0)
                .padding(.top, 3)
                .padding(.trailing, 56)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: 13))
                .opacity(0.88)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(.onBlue))
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 15, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color(.blue)
                UnitPolygon(points: [CGPoint(x: 0.8, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0.66, y: 1)])
                    .fill(Color(.green))
            }
        }
    }

    /// „Mittagsangebot · 11:00–14:00 Uhr“, beim Abendessen der Cafeteria „Abendessen in der Cafeteria · 16:30–19:30 Uhr“.
    private var subtitle: String {
        let offer: String
        switch share.mealtime {
        case .lunch: offer = strings("share.plan.lunch")
        case .dinner: offer = strings(share.venue.hasMealtimes ? "share.card.dinnerCafeteria" : "share.plan.dinner")
        }
        return [offer, share.hours.map { strings("share.hours", $0) }].compactMap { $0 }.joined(separator: " · ")
    }

    private var note: String {
        let group: String
        switch share.priceGroup {
        case .studierende: group = strings("share.plan.prices.students")
        case .bedienstete: group = strings("share.plan.prices.staff")
        case .gaeste: group = strings("share.plan.prices.guests")
        }
        return "\(group) · \(strings("share.card.disclaimer"))"
    }

    private func row(_ meal: MensaMeal) -> some View {
        let chips = meal.listChips
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(meal.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineSpacing(1)
                    .foregroundStyle(Color(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                if let description = ShareText.clean(meal.description) {
                    Text(description)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color(.textSecondary))
                        .padding(.top, 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !chips.isEmpty {
                    ShareChips(chips: chips, strings: strings)
                        .padding(.top, 5)
                }
            }
            Spacer(minLength: 0)
            Text(meal.price.formatted(for: share.priceGroup, locale: share.locale))
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color(.textPrimary))
                .fixedSize()
        }
    }
}

// MARK: - Gericht

/// Ein Gericht mit allen Angaben: Kopf mit Diagonalbändern wie in der Gericht-Ansicht, die eigene Preisgruppe groß,
/// dann die übrigen Zeilen. Felder ohne Daten entfallen.
struct ShareMealCard: View {
    let share: MensaMealShare

    private var strings: ShareStrings { ShareStrings(locale: share.locale) }
    private var meal: MensaMeal { share.meal }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            details(of: meal)
            Text(strings("share.card.mealDisclaimer"))
                .font(.system(size: 12))
                .foregroundStyle(Color(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 10, leading: 18, bottom: 14, trailing: 18))
                .shareTopRule()
            ShareBrandFooter()
        }
        .shareCardSurface()
    }

    /// 104 pt hoch: Grün hinten, Blau vorn, der Kicker in Weiß.
    private var head: some View {
        ZStack(alignment: .topLeading) {
            Color(.surface)
            UnitPolygon(points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 1)])
                .fill(Color(.green))
            UnitPolygon(points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 0.26), CGPoint(x: 0, y: 0.78)])
                .fill(Color(.blue))
            Text(share.kicker)
                .font(.system(size: 11.5, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.46)
                .foregroundStyle(Color(.onBlue))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .padding(.top, 16)
        }
        .frame(height: 104)
    }

    private func details(of meal: MensaMeal) -> some View {
        let chips = meal.detailChips
        return VStack(alignment: .leading, spacing: 0) {
            Text(meal.name)
                .display(size: 25, relativeTo: .title)
                .lineSpacing(-2)
                .foregroundStyle(Color(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
            if let description = ShareText.clean(meal.description) {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(.textSecondary))
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !chips.isEmpty {
                ShareChips(chips: chips, strings: strings)
                    .padding(.top, 10)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(share.priceGroup.shareName(strings))
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.textTertiary))
                Spacer(minLength: 12)
                Text(meal.price.formatted(for: share.priceGroup, locale: share.locale))
                    .display(size: 36, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
            }
            .padding(.top, 14)
            .padding(.bottom, 8)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 12) {
                    Text(line.label)
                        .foregroundStyle(Color(.textSecondary))
                        .fixedSize()
                    Spacer(minLength: 0)
                    Text(line.value)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Color(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 13.5))
                .padding(.vertical, 10)
                .shareTopRule()
            }
        }
        .padding(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
    }

    /// Die anderen Preisgruppen (in der Reihenfolge Studierende, Bedienstete, Gäste), Allergene, Zusatzstoffe, Umwelt.
    private var lines: [(label: String, value: String)] {
        var result: [(String, String)] = MensaPriceGroup.allCases
            .filter { $0 != share.priceGroup }
            .map { ($0.shareName(strings), meal.price.formatted(for: $0, locale: share.locale)) }
        if !meal.uniqueAllergies.isEmpty {
            result.append((strings("share.card.allergens"), meal.uniqueAllergies.joined(separator: ", ")))
        }
        if !meal.uniqueAdditives.isEmpty {
            result.append((strings("share.card.additives"), meal.uniqueAdditives.joined(separator: ", ")))
        }
        if let co2 = meal.co2GramPerPortion {
            result.append((strings("share.card.environment"), strings("share.meal.co2", co2.formatted(.number.precision(.fractionLength(0)).locale(share.locale)))))
        }
        return result
    }
}

// MARK: - Anbindung an die Inhalte

extension MensaPlanShare: ShareImageContent {
    var card: some View {
        ShareCardView { SharePlanCard(share: self) }
    }

    /// „Mensa-Ehrenberg-2026-10-29.png“, beim Abendessen mit „-Abendessen“.
    var imageFileName: String {
        var name = "\(ShareFileName.slug(venue.displayName))-\(ShareFileName.isoDay(day))"
        if mealtime == .dinner { name += "-" + ShareFileName.slug(ShareStrings(locale: locale)("share.plan.dinner")) }
        return name + ".png"
    }
}

extension MensaMealShare: ShareImageContent {
    var card: some View {
        ShareCardView { ShareMealCard(share: self) }
    }

    /// „Linsen-Dal.png“
    var imageFileName: String {
        (ShareFileName.slug(meal.name).isEmpty ? "Gericht" : ShareFileName.slug(meal.name)) + ".png"
    }
}
