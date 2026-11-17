import SwiftUI

/// Die Mensa-Ansicht auf dem iPad (Breite ab 700 pt): alle Mensen nebeneinander statt Leiste und Wischen. Ab 1150 pt
/// vier Spalten, darunter zwei mit 28 pt Zeilenabstand. Daten, Filterregeln, Texte, Chips, Preisgruppe und Teilen-Inhalte
/// sind die der iPhone-Ansicht (`MensaScreen`); hier ändert sich nur die Anordnung.
///
/// Kopf mit Filtern und Tagesleiste stehen fest, die Mensen scrollen darunter in einer `ScrollView`. Jede Zeile von Mensen ist eine `Section` mit angepinntem Kopf, der die Köpfe aller ihrer
/// Spalten trägt: Sie bleiben beim Scrollen unter der schwebenden Tab-Leiste stehen (Hintergrund `background`), auch wenn
/// eine Spalte kürzer ist als die anderen.
/// Nach `Uebergabe.md`, „iPad“ → „Mensa“, Artboards `PadMensa` und `PadMensaFilter`.
struct MensaPadScreen: View {
    let days: [Date]
    @Binding var selectedDayIndex: Int
    /// Die zuletzt gewählte oder per Link gewünschte Mensa: Die Ansicht scrollt zu ihrer Spalte.
    @Binding var selectedVenue: MensaVenue
    @Binding var mealtime: MensaMealtime
    let loadState: MensaLoadState
    /// Alle Gerichte des Tages, vor dem Filter.
    let allMeals: [MensaMeal]
    @Binding var filter: MensaFilter
    let canteens: [Canteen]
    var now: Date = .now
    /// Spalten: 2 oder 4 (siehe `PadRaster.mensaSpalten`).
    var spalten = 4
    let onRetry: () -> Void
    @Binding var zeigtFilter: Bool
    /// Tippen auf ein Gericht: Das Sheet mit dem Gericht (kein Push, die Spalten bleiben stehen).
    let onOpenMeal: (MensaMeal) -> Void
    /// Der Siri-Tipp oben im Speiseplan, wenn er gezeigt werden soll.
    var tipp: AnyView?

    @State private var loader: LoadingGate
    @Environment(\.padRaster) private var raster
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(MensaPriceGroup.storageKey, store: AppGroup.defaults) private var priceGroup: MensaPriceGroup = .studierende

    init(
        days: [Date],
        selectedDayIndex: Binding<Int>,
        selectedVenue: Binding<MensaVenue>,
        mealtime: Binding<MensaMealtime>,
        loadState: MensaLoadState,
        allMeals: [MensaMeal],
        filter: Binding<MensaFilter>,
        canteens: [Canteen],
        now: Date = .now,
        spalten: Int = 4,
        onRetry: @escaping () -> Void,
        zeigtFilter: Binding<Bool>,
        onOpenMeal: @escaping (MensaMeal) -> Void,
        tipp: AnyView? = nil
    ) {
        self.days = days
        self._selectedDayIndex = selectedDayIndex
        self._selectedVenue = selectedVenue
        self._mealtime = mealtime
        self.loadState = loadState
        self.allMeals = allMeals
        self._filter = filter
        self.canteens = canteens
        self.now = now
        self.spalten = spalten
        self.onRetry = onRetry
        self._zeigtFilter = zeigtFilter
        self.onOpenMeal = onOpenMeal
        self.tipp = tipp
        self._loader = State(initialValue: LoadingGate(isLoading: loadState == .loading))
    }

    private var selectedDay: Date { days.indices.contains(selectedDayIndex) ? days[selectedDayIndex] : now }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Titel, Filter und Tagesleiste bleiben stehen; nur die Mensen darunter scrollen.
            VStack(alignment: .leading, spacing: 0) {
                kopf
                if let zusammenfassung = filter.summary { zusatzfilter(zusammenfassung) }
                if let tipp {
                    tipp.padding(.top, 8)
                }
                tagesleiste
            }
            .padding(.horizontal, raster.rand)

            ScrollViewReader { proxy in
                ScrollView {
                    inhalt
                        .padding(.horizontal, raster.rand)
                        .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
                // Ein Link zu einer Mensa oder einem Gericht: zur Spalte scrollen.
                .onChange(of: selectedVenue) { _, venue in
                    let zeile = zeilen.first { $0.contains(venue) }?.first ?? venue
                    withAnimation(.snappy) { proxy.scrollTo(zeile, anchor: .top) }
                }
            }
        }
        .background(Color(.background))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: loadState == .loading, initial: true) { _, isLoading in
            loader.setLoading(isLoading)
        }
    }

    // MARK: - Kopf

    private var kopf: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Mensa")
                .display(size: raster.seitentitel(telefon: 34), relativeTo: .largeTitle)
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 16)
            HStack(spacing: 8) {
                ForEach(MensaDiet.allCases, id: \.self) { diet in
                    ernaehrungskapsel(diet)
                }
            }
            filterKnopf
            NavigationLink {
                MensaOpeningHoursView(canteens: canteens)
            } label: {
                Image(systemName: "clock")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(.textPrimary))
                    .frame(width: 44, height: 44)
                    .background(Color(.surfaceSecondary), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .hoverEffect()
            .accessibilityLabel("Öffnungszeiten")
        }
        .padding(.top, 4)
    }

    /// Alle / Vegetarisch / Vegan: 36 hoch, aktiv `buttonPrimary`.
    private func ernaehrungskapsel(_ diet: MensaDiet) -> some View {
        let isSelected = filter.diet == diet
        let title: LocalizedStringKey = switch diet {
        case .alle: "Alle"
        case .vegetarisch: "Vegetarisch"
        case .vegan: "Vegan"
        }
        return Button {
            filter.diet = diet
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color(.onButtonPrimary) : Color(.textSecondary))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(isSelected ? Color(.buttonPrimary) : Color(.surfaceSecondary), in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Runder Filter-Knopf (44 pt) mit Zähler-Badge. Das Popover (`MensaFilterPopover`) hängt an ihm.
    private var filterKnopf: some View {
        let count = filter.extraCount
        return Button { zeigtFilter = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(count > 0 ? Color(.onButtonPrimary) : Color(.textPrimary))
                    .frame(width: 44, height: 44)
                    .background(count > 0 ? Color(.buttonPrimary) : Color(.surfaceSecondary), in: Circle())
                if count > 0 {
                    FilterCountBadge(count: count)
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityLabel(count > 0 ? "Filter, \(count) aktiv" : "Filter")
        .popover(isPresented: $zeigtFilter) {
            MensaFilterPopover(
                filter: $filter,
                allergens: MensaFilter.allergens(onDay: allMeals, keeping: filter.excludedAllergens)
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    /// Ist ein Zusatzfilter aktiv: rechtsbündig „Nur Bio · ohne Milch“ und „Ändern“.
    private func zusatzfilter(_ zusammenfassung: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Spacer(minLength: 0)
            Text(zusammenfassung)
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
            Button { zeigtFilter = true } label: {
                Text("Ändern")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.accent))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tagesleiste

    /// Alle Werktage in einer Reihe, Kacheln 56 × 64, vor jedem Montag 12 pt mehr. Ist die Reihe breiter als die Ansicht
    /// (Seitenleiste offen, Hochformat), scrollt sie waagerecht.
    private var tagesleiste: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(days.indices, id: \.self) { index in
                    tageskachel(index)
                        .padding(.leading, wocheBeginnt(index) ? 12 : 0)
                }
            }
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollClipDisabled()
    }

    private func wocheBeginnt(_ index: Int) -> Bool {
        Calendar.current.component(.weekday, from: days[index]) == 2 && index > 0
    }

    /// Maße der Tageskachel wachsen mit der Schrift (56 × 64 bei normaler Größe), sonst wird „Heute“ abgeschnitten.
    @ScaledMetric(relativeTo: .title3) private var kachelBreite: CGFloat = 56
    @ScaledMetric(relativeTo: .title3) private var kachelHoehe: CGFloat = 64

    private func tageskachel(_ index: Int) -> some View {
        let day = days[index]
        let isSelected = index == selectedDayIndex
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let startsWeek = wocheBeginnt(index)
        return Button {
            withAnimation(.snappy(duration: 0.2)) { selectedDayIndex = index }
        } label: {
            VStack(spacing: 2) {
                Text(isToday ? "Heute" : MensaFormatting.weekdayShort(day))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color(.onButtonPrimary) : (startsWeek ? Color(.textTertiary) : Color(.textPrimary)))
                Text(day.formatted(.dateTime.day()))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? Color(.onButtonPrimary) : Color(.textPrimary))
            }
            .frame(width: kachelBreite, height: kachelHoehe)
            .background(
                isSelected ? Color(.buttonPrimary) : Color(.surface),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityLabel((isToday ? "Heute, " : "") + MensaFormatting.spokenDay(day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var inhalt: some View {
        if loader.isActive {
            // Erstes Laden: wie auf dem iPhone nur die Ziege, mittig im freien Bereich.
            GoatLoadingBlock(message: "Speiseplan wird geladen …", gate: loader)
                .frame(maxWidth: .infinity, minHeight: 360)
        } else if loadState == .failed {
            // Ladefehler: eine Karte mittig statt der Spalten (Texte wie auf dem iPhone).
            meldung(
                title: "Speiseplan konnte nicht geladen werden",
                text: "Prüfe deine Internetverbindung.",
                buttonTitle: "Erneut versuchen",
                action: onRetry
            )
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Eine Zeile je `spalten` Mensen. Jede Zeile ist eine Section mit angepinntem Kopf, der alle Spaltenköpfe
                // der Zeile trägt: Sie bleiben unter der Tab-Leiste stehen, bis die Zeile zu Ende ist, auch bei kurzen Spalten.
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(zeilen, id: \.first) { zeile in
                        Section {
                            HStack(alignment: .top, spacing: PadRaster.kartenAbstand) {
                                ForEach(zeile) { venue in
                                    karten(venue).frame(width: spaltenbreite, alignment: .top)
                                }
                            }
                            // Zeilenabstand 28 pt
                            .padding(.bottom, 28)
                        } header: {
                            HStack(alignment: .top, spacing: PadRaster.kartenAbstand) {
                                ForEach(zeile) { venue in
                                    spaltenkopf(venue, gerichte: meals(for: venue).count)
                                        .frame(width: spaltenbreite, alignment: .leading)
                                }
                            }
                            .padding(.bottom, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.background))
                            .id(zeile.first)
                        }
                    }
                }
                Text("Preise für \(priceGroup.title). Die anderen Preise in den Details.")
                    .font(.caption)
                    .foregroundStyle(Color(.textSecondary))
                    .padding(.horizontal, 2)
                    .padding(.top, 20)
            }
        }
    }

    /// Die Mensen, auf Zeilen zu je `spalten` verteilt (vier Spalten: eine Zeile, zwei Spalten: zwei Zeilen).
    private var zeilen: [[MensaVenue]] {
        let alle = MensaVenue.allCases
        return stride(from: 0, to: alle.count, by: spalten).map { Array(alle[$0..<min($0 + spalten, alle.count)]) }
    }

    /// Breite einer Spalte: die Breite der Ansicht ohne Ränder, geteilt durch die Spalten, minus der Abstände.
    private var spaltenbreite: CGFloat {
        let nutz = max(0, raster.breite - 2 * raster.rand)
        return max(0, (nutz - PadRaster.kartenAbstand * CGFloat(spalten - 1)) / CGFloat(spalten))
    }

    // MARK: - Spalte

    /// Die Gerichte einer Mensa als Karten (der Kopf steht im angepinnten Kopf der Zeile).
    private func karten(_ venue: MensaVenue) -> some View {
        let gerichte = meals(for: venue)
        return VStack(alignment: .leading, spacing: 10) {
            if !gerichte.isEmpty {
                ForEach(gerichte) { meal in
                    Button { onOpenMeal(meal) } label: {
                        MensaMealCard(meal: meal, breit: true)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect()
                    .contextMenu {
                        let share = MensaMealShare(meal: meal, priceGroup: priceGroup)
                        ShareLink(item: share.text, subject: Text(share.title)) {
                            Label("Als Text teilen", systemImage: "text.alignleft")
                        }
                    }
                }
            } else if !meals(for: venue, filtered: false).isEmpty {
                // Der Filter blendet in dieser Spalte alles aus; die anderen Spalten bleiben gefüllt.
                meldung(
                    title: "Nichts passt zu deinem Filter",
                    text: "\(istHeute ? "Heute" : "An diesem Tag") gibt es hier nichts, was zu \(filter.activeDescription) passt.",
                    buttonTitle: "Filter zurücksetzen",
                    action: { filter = MensaFilter() }
                )
            } else {
                Card {
                    Text(istHeute ? "Heute nichts in dieser Mensa – morgen wieder." : "An diesem Tag nichts in dieser Mensa.")
                        .font(.body)
                        .foregroundStyle(Color(.textSecondary))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
        }
    }

    private var istHeute: Bool { Calendar.current.isDate(selectedDay, inSameDayAs: now) }

    /// Mensa-Name 17 Bold, darunter „Heute · Mittag“ (mit Filter „· 2 passend“ / „· keins passend“), Status-Chip, rechts
    /// Teilen-Knopf (36). Bei der Cafeteria Ehrenberg das Segment Mittag / Abendessen; nur diese Spalte wechselt.
    private func spaltenkopf(_ venue: MensaVenue, gerichte: Int) -> some View {
        let status = MensaStatus.chip(for: venue, canteens: canteens, day: selectedDay, mealtime: mealtime, now: now)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(venue.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(untertitel(venue, gerichte: gerichte))
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                teilenKnopf(venue)
            }
            if let status {
                Chip(LocalizedStringKey(status.text), variant: status.variant)
            }
            if venue.hasMealtimes {
                SegmentedControl(
                    selection: $mealtime,
                    options: [(.lunch, "Mittag"), (.dinner, "Abendessen")]
                )
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    private func untertitel(_ venue: MensaVenue, gerichte: Int) -> String {
        var text = MensaFormatting.dayLabel(selectedDay, now: now)
        if venue.hasMealtimes { text += mealtime == .dinner ? " · Abendessen" : " · Mittag" }
        if filter.isActive, loadState == .loaded {
            text += gerichte == 0 ? " · keins passend" : " · \(gerichte) passend"
        }
        return text
    }

    // MARK: - Teilen

    /// Das gezeigte Angebot dieser Mensa (ohne Filter, mit dem Preis der eigenen Preisgruppe), wie auf dem iPhone.
    private func planShare(_ venue: MensaVenue) -> MensaPlanShare {
        let zeit: MensaMealtime = venue.hasMealtimes ? mealtime : .lunch
        let hours = canteens.first { venue.matches(canteenName: $0.name) }?.openingHours ?? []
        return MensaPlanShare(
            venue: venue,
            day: selectedDay,
            mealtime: zeit,
            allMeals: allMeals,
            priceGroup: priceGroup,
            hours: MensaPlanShare.hours(for: zeit, day: selectedDay, openingHours: hours)
        )
    }

    /// Menü am Knopf mit „Als Bild teilen“ / „Als Text teilen“. Das Menü ist der Anker des Teilen-Blatts, sonst stürzt es
    /// auf dem iPad ab. Ohne Angebot, beim Laden und bei einem Ladefehler ist er deaktiviert.
    private func teilenKnopf(_ venue: MensaVenue) -> some View {
        let share = planShare(venue)
        return ShareMenuButton(
            content: share,
            caption: share.menuCaption(now: now),
            isEnabled: loadState == .loaded && !share.meals.isEmpty
        ) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(.textPrimary))
                .frame(width: 36, height: 36)
                .background(Color(.surfaceSecondary), in: Circle())
                .contentShape(Circle())
        }
        .hoverEffect()
        .accessibilityLabel("Speiseplan teilen")
    }

    // MARK: - Gerichte

    /// Gerichte einer Mensa; bei der Cafeteria Ehrenberg nach Mittag oder Abendessen.
    private func meals(for venue: MensaVenue, filtered: Bool = true) -> [MensaMeal] {
        let source = filtered ? filter.apply(to: allMeals) : allMeals
        return source.filter { meal in
            guard venue.matches(canteenName: meal.canteenName) else { return false }
            guard venue.hasMealtimes else { return true }
            return (mealtime == .dinner) == MensaMealtime.isDinner(meal)
        }
    }

    private func meldung(title: LocalizedStringKey, text: LocalizedStringKey, buttonTitle: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Card {
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(.textPrimary))
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(.body)
                    .foregroundStyle(Color(.textSecondary))
                    .multilineTextAlignment(.center)
                SecondaryButton(buttonTitle, action: action)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }
}
