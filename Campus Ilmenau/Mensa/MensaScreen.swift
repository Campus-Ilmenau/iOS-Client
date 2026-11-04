import SwiftUI

/// Oberfläche der Ansicht „Mensa“ ohne eigene Datenhaltung: feststehender Kopf, Namensleiste, Tagesleiste
/// und darunter eine Seite pro Mensa zum horizontalen Wischen.
///
/// Das Wischen nutzt `ScrollView(.horizontal)` mit `.paging` und `.scrollPosition(id:)` statt `TabView(.page)`:
/// Die Scroll-Position liefert den Fortschritt, mit dem die Markierung der Namensleiste dem Finger folgt,
/// das Gummiband an den Rändern und die Richtungserkennung zwischen Wischen und vertikalem Scrollen
/// sind die des Systems, und ein Tipp wird vom Scrollen automatisch abgebrochen.
struct MensaScreen: View {
    let days: [Date]
    @Binding var selectedDayIndex: Int
    @Binding var selectedVenue: MensaVenue
    @Binding var mealtime: MensaMealtime
    let loadState: MensaLoadState
    /// Alle Gerichte des Tages, vor dem Filter.
    let allMeals: [MensaMeal]
    @Binding var filter: MensaFilter
    let canteens: [Canteen]
    var now: Date = .now
    let onRetry: () -> Void
    let onOpenFilter: () -> Void

    @State private var pagerPosition: MensaVenue?
    @State private var pageProgress: CGFloat
    @State private var tabFrames: [MensaVenue: CGRect] = [:]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        onRetry: @escaping () -> Void,
        onOpenFilter: @escaping () -> Void
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
        self.onRetry = onRetry
        self.onOpenFilter = onOpenFilter
        self._pagerPosition = State(initialValue: selectedVenue.wrappedValue)
        self._pageProgress = State(initialValue: CGFloat(MensaVenue.allCases.firstIndex(of: selectedVenue.wrappedValue) ?? 0))
    }

    private var selectedDay: Date { days.indices.contains(selectedDayIndex) ? days[selectedDayIndex] : now }

    var body: some View {
        VStack(spacing: 0) {
            header
            venueStrip
            dayStrip
            filterBar
            pager
        }
        .background(Color(.background))
        // Die Navigationsleiste bleibt vorerst für Zurück-Pfeil und Filter-Taste, bis die TabBar die Navigation übernimmt.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Kopf

    private var header: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text("Mensa")
                .display(size: 34, relativeTo: .largeTitle)
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            NavigationLink {
                MensaOpeningHoursView(canteens: canteens)
            } label: {
                Image(systemName: "clock")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(.textPrimary))
                    .frame(width: 44, height: 44)
                    .background(Color(.surfaceSecondary), in: Circle())
            }
            .accessibilityLabel("Öffnungszeiten")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Namensleiste

    private var venueStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(MensaVenue.allCases) { venue in
                        venueTab(venue).id(venue)
                    }
                }
                .coordinateSpace(name: "venueStrip")
                .onPreferenceChange(VenueTabFrameKey.self) { tabFrames = $0 }
                .overlay(alignment: .bottomLeading) { underline }
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.hidden)
            .padding(.top, 6)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Mensa wählen")
            .accessibilityAddTraits(.isTabBar)
            .onChange(of: selectedVenue) { _, venue in
                withAnimation(.snappy) { proxy.scrollTo(venue, anchor: .center) }
            }
        }
    }

    private func venueTab(_ venue: MensaVenue) -> some View {
        let isSelected = venue == selectedVenue
        let count = filter.isActive ? pageMeals(for: venue).count : nil
        return Button {
            selectedVenue = venue
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(venue.shortName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let count, loadState == .loaded {
                    Text(count == 0 ? "keins passend" : "\(count) passend")
                        .font(.caption2)
                        .foregroundStyle(Color(.textTertiary))
                }
            }
            .foregroundStyle(isSelected ? Color(.textPrimary) : Color(.textTertiary))
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 9)
            .frame(minHeight: 44, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: VenueTabFrameKey.self,
                    value: [venue: proxy.frame(in: .named("venueStrip"))]
                )
            }
        )
        .accessibilityLabel(venue.displayName + (count.map { $0 == 0 ? ", keins passend" : ", \($0) passend" } ?? ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 3 pt in accent unter dem aktiven Namen; beim Wischen wandert sie mit.
    @ViewBuilder
    private var underline: some View {
        let venues = MensaVenue.allCases
        let clamped = min(max(pageProgress, 0), CGFloat(venues.count - 1))
        let lower = Int(clamped.rounded(.down))
        let upper = min(lower + 1, venues.count - 1)
        let fraction = clamped - CGFloat(lower)
        if let a = tabFrames[venues[lower]], let b = tabFrames[venues[upper]] {
            Rectangle()
                .fill(Color(.accent))
                .frame(width: a.width + (b.width - a.width) * fraction, height: 3)
                .offset(x: a.minX + (b.minX - a.minX) * fraction)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Tagesleiste

    private var dayStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(days.indices, id: \.self) { index in
                    dayButton(index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func dayButton(_ index: Int) -> some View {
        let day = days[index]
        let isSelected = index == selectedDayIndex
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let startsWeek = Calendar.current.component(.weekday, from: day) == 2 && index > 0
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
            .padding(.horizontal, 4)
            .frame(minWidth: 52, minHeight: 64)
            .background(
                isSelected ? Color(.buttonPrimary) : Color(.surface),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel((isToday ? "Heute, " : "") + MensaFormatting.spokenDay(day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Filter

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(MensaDiet.allCases, id: \.self) { diet in
                            dietPill(diet)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                filterButton
            }

            if let summary = filter.summary {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: onOpenFilter) {
                        Text("Ändern")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(.accent))
                            .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func dietPill(_ diet: MensaDiet) -> some View {
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
                .padding(.vertical, 9)
                .background(isSelected ? Color(.buttonPrimary) : Color(.surfaceSecondary), in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Runde Taste (36 pt, Tippfläche 44 pt). Sind „Nur Bio“ oder Allergene gesetzt, ist sie gefüllt und zeigt die Anzahl.
    private var filterButton: some View {
        let count = filter.extraCount
        return Button(action: onOpenFilter) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(count > 0 ? Color(.onButtonPrimary) : Color(.textPrimary))
                    .frame(width: 36, height: 36)
                    .background(count > 0 ? Color(.buttonPrimary) : Color(.surfaceSecondary), in: Circle())
                if count > 0 {
                    FilterCountBadge(count: count)
                        .offset(x: 3, y: -3)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count > 0 ? "Filter, \(count) aktiv" : "Filter")
    }

    // MARK: - Seiten

    private var pager: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(MensaVenue.allCases) { venue in
                    MensaVenuePage(
                        venue: venue,
                        day: selectedDay,
                        now: now,
                        mealtime: $mealtime,
                        loadState: loadState,
                        meals: pageMeals(for: venue),
                        hasMealsBeforeFilter: !pageMeals(for: venue, filtered: false).isEmpty,
                        canteens: canteens,
                        filterDescription: filter.activeDescription,
                        onRetry: onRetry,
                        onResetFilter: { filter = MensaFilter() }
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(venue)
                    // Nur die sichtbare Seite ist für VoiceOver da; gewechselt wird über die Namensleiste.
                    .accessibilityHidden(venue != selectedVenue)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pagerPosition)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x / max(geometry.containerSize.width, 1)
        } action: { _, progress in
            pageProgress = progress
        }
        // Die Startseite (zuletzt gewählte Mensa) muss nach dem ersten Layout gesetzt werden, sonst steht der Pager vorn.
        .task {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                pagerPosition = nil
            }
            try? await Task.sleep(for: .milliseconds(50))
            withTransaction(transaction) {
                pagerPosition = selectedVenue
            }
        }
        .onChange(of: pagerPosition) { _, venue in
            if let venue, venue != selectedVenue { selectedVenue = venue }
        }
        .onChange(of: selectedVenue) { _, venue in
            if pagerPosition != venue {
                withAnimation(.snappy) { pagerPosition = venue }
            }
        }
    }

    /// Gerichte einer Mensa; bei der Cafeteria Ehrenberg nach Mittag oder Abendessen.
    private func pageMeals(for venue: MensaVenue, filtered: Bool = true) -> [MensaMeal] {
        let source = filtered ? filter.apply(to: allMeals) : allMeals
        return source.filter { meal in
            guard venue.matches(canteenName: meal.canteenName) else { return false }
            guard venue.hasMealtimes else { return true }
            return (mealtime == .dinner) == MensaMealtime.isDinner(meal)
        }
    }
}

/// Zahl in `accent` an der Filter-Taste. Im Dark Mode ist `accent` hell, deshalb steht dort dunkle Schrift darauf.
private struct FilterCountBadge: View {
    let count: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(colorScheme == .dark ? Color(.brandNight) : Color(.onBlue))
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Color(.accent), in: Capsule())
            .accessibilityHidden(true)
    }
}

private struct VenueTabFrameKey: PreferenceKey {
    static var defaultValue: [MensaVenue: CGRect] = [:]
    static func reduce(value: inout [MensaVenue: CGRect], nextValue: () -> [MensaVenue: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Seite einer Mensa

private struct MensaVenuePage: View {
    let venue: MensaVenue
    let day: Date
    let now: Date
    @Binding var mealtime: MensaMealtime
    let loadState: MensaLoadState
    let meals: [MensaMeal]
    /// Es gibt Gerichte, aber der Filter blendet sie aus.
    let hasMealsBeforeFilter: Bool
    let canteens: [Canteen]
    let filterDescription: String
    let onRetry: () -> Void
    let onResetFilter: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(MensaPriceGroup.storageKey) private var priceGroup: MensaPriceGroup = .studierende

    private var isToday: Bool { Calendar.current.isDate(day, inSameDayAs: now) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                pageHeader
                    .padding(.bottom, 12)

                if venue.hasMealtimes {
                    SegmentedControl(
                        selection: $mealtime,
                        options: [(.lunch, "Mittag"), (.dinner, "Abendessen")]
                    )
                    .padding(.bottom, 12)
                }

                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var pageHeader: some View {
        let status = MensaStatus.chip(for: venue, canteens: canteens, day: day, mealtime: mealtime, now: now)
        let title = VStack(alignment: .leading, spacing: 0) {
            Text(venue.displayName)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(.textPrimary))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
        }
        // Passt der Chip nicht mehr neben den Namen (große Schrift), rutscht er darunter.
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                title.lineLimit(1).fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 8)
                if let status { Chip(LocalizedStringKey(status.text), variant: status.variant).fixedSize() }
            }
            VStack(alignment: .leading, spacing: 8) {
                title
                if let status { Chip(LocalizedStringKey(status.text), variant: status.variant) }
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let dayText = MensaFormatting.dayLabel(day, now: now)
        guard venue.hasMealtimes else { return dayText }
        return dayText + (mealtime == .dinner ? " · Abendessen" : " · Mittag")
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView("Speiseplan wird geladen …")
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
        case .failed:
            messageCard(
                title: "Speiseplan konnte nicht geladen werden",
                text: "Prüfe deine Internetverbindung.",
                buttonTitle: "Erneut versuchen",
                action: onRetry
            )
        case .loaded:
            if !meals.isEmpty {
                mealList
            } else if hasMealsBeforeFilter {
                messageCard(
                    title: "Nichts passt zu deinem Filter",
                    text: "\(isToday ? "Heute" : "An diesem Tag") gibt es hier nichts, was zu \(filterDescription) passt.",
                    buttonTitle: "Filter zurücksetzen",
                    action: onResetFilter
                )
            } else {
                Card {
                    Text(isToday ? "Heute nichts in dieser Mensa – morgen wieder." : "An diesem Tag nichts in dieser Mensa.")
                        .font(.body)
                        .foregroundStyle(Color(.textSecondary))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
        }
    }

    private var mealList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 10) {
                ForEach(meals) { meal in
                    // Push statt Sheet. Ein Wisch zwischen den Mensen löst keinen Tipp aus: Das Scrollen bricht ihn ab.
                    NavigationLink {
                        MensaMealDetailView(meal: meal, canteens: canteens)
                    } label: {
                        MensaMealCard(meal: meal)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Preise für \(priceGroup.title). Die anderen Preise in den Details.")
                .font(.caption)
                .foregroundStyle(Color(.textTertiary))
                .padding(.horizontal, 2)
                .padding(.top, 14)
        }
    }

    private func messageCard(title: LocalizedStringKey, text: LocalizedStringKey, buttonTitle: LocalizedStringKey, action: @escaping () -> Void) -> some View {
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
