import SwiftUI

/// Öffnungszeiten der vier Mensen: heutige Zeit mit Status-Chip, Tipp klappt die Wochenzeiten auf.
/// Ohne übergebene Mensen lädt die Ansicht sie selbst.
struct MensaOpeningHoursView: View {
    var canteens: [Canteen] = []

    @StateObject private var service = MensaService()
    @State private var openVenue: MensaVenue? = .mensaEhrenberg
    @State private var loadFailed = false

    private var allCanteens: [Canteen] { canteens.isEmpty ? service.canteens : canteens }

    var body: some View {
        // Der Status ändert sich mit der Uhrzeit: jede Minute neu berechnen.
        TimelineView(.everyMinute) { context in
            MensaOpeningHoursContent(
                canteens: allCanteens,
                openVenue: $openVenue,
                loadFailed: loadFailed,
                now: context.date
            )
        }
        .task {
            guard canteens.isEmpty else { return }
            do {
                try await service.fetchCanteens()
            } catch {
                loadFailed = true
            }
        }
    }
}

struct MensaOpeningHoursContent: View {
    let canteens: [Canteen]
    @Binding var openVenue: MensaVenue?
    var loadFailed = false
    let now: Date

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Öffnungszeiten")
                    .display(size: 28, relativeTo: .title)
                    .foregroundStyle(Color(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 4)

                Text("Heute, \(now.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "de_DE"))))")
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
                    .padding(.horizontal, 2)
                    .padding(.bottom, 4)

                ForEach(MensaVenue.allCases) { venue in
                    venueCard(venue)
                }

                if canteens.isEmpty {
                    Text(loadFailed ? "Öffnungszeiten konnten nicht geladen werden." : "Öffnungszeiten werden geladen …")
                        .font(.footnote)
                        .foregroundStyle(Color(.textSecondary))
                        .padding(.horizontal, 2)
                }

                Text("In der vorlesungsfreien Zeit gelten verkürzte Zeiten.")
                    .font(.caption)
                    .foregroundStyle(Color(.textTertiary))
                    .padding(.horizontal, 2)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.background))
        // Zurück-Pfeil des Systems (behält die Wischgeste), in accent.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(Color(.accent))
    }

    // MARK: - Mensa

    private func venueCard(_ venue: MensaVenue) -> some View {
        let hours = canteens.first { venue.matches(canteenName: $0.name) }?.openingHours ?? []
        let isOpen = openVenue == venue
        return Button {
            withAnimation(.snappy(duration: 0.25)) { openVenue = isOpen ? nil : venue }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                header(venue, hours: hours)
                if isOpen {
                    weekHours(venue, hours: hours)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.surface), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOpen ? "aufgeklappt" : "zugeklappt")
        .accessibilityHint(isOpen ? "Wochenzeiten ausblenden" : "Wochenzeiten anzeigen")
    }

    private func header(_ venue: MensaVenue, hours: [OpeningHour]) -> some View {
        let titles = VStack(alignment: .leading, spacing: 2) {
            Text(venue.displayName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color(.textPrimary))
            Text(todayLine(venue, hours: hours))
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
        }
        let chip = statusChip(hours: hours)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                titles.frame(maxWidth: .infinity, alignment: .leading)
                if let chip { chip.fixedSize() }
            }
            VStack(alignment: .leading, spacing: 8) {
                titles
                if let chip { chip }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func todayLine(_ venue: MensaVenue, hours: [OpeningHour]) -> String {
        guard !hours.isEmpty else { return "–" }
        let line = MensaOpeningHours.todayText(for: hours, now: now)
        return venue.hasMealtimes ? line + " · Mittag und Abendessen" : line
    }

    private func statusChip(hours: [OpeningHour]) -> Chip? {
        guard !hours.isEmpty else { return nil }
        switch MensaOpeningHours.state(for: hours, now: now) {
        case .open: return Chip("Geöffnet", variant: .green)
        case .closingSoon: return Chip("Gleich zu", variant: .warning)
        case .closed: return Chip("Geschlossen", variant: .dangerSoft)
        }
    }

    private func weekHours(_ venue: MensaVenue, hours: [OpeningHour]) -> some View {
        var rows = MensaOpeningHours.weekRows(for: hours)
        if venue.hasMealtimes, let dinner = MensaOpeningHours.dinnerText(for: hours) {
            rows.append(("Abendessen", dinner))
        }
        return VStack(spacing: 12) {
            Rectangle().fill(Color(.separator)).frame(height: 1)
            VStack(spacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.label)
                            .foregroundStyle(Color(.textSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.value)
                            .foregroundStyle(Color(.textPrimary))
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - Previews

private enum HoursPreviewData {
    static func canteen(_ id: Int, _ name: String, weekday: (String, String), friday: (String, String)?, saturday: (String, String)? = nil) -> Canteen {
        var hours = ["mon", "tue", "wed", "thu"].map { OpeningHour(weekday: $0, opensAt: weekday.0, closesAt: weekday.1) }
        hours.append(OpeningHour(weekday: "fri", opensAt: (friday ?? weekday).0, closesAt: (friday ?? weekday).1))
        if let saturday { hours.append(OpeningHour(weekday: "sat", opensAt: saturday.0, closesAt: saturday.1)) }
        return Canteen(rscId: id, name: name, hasMenu: true, city: "Ilmenau", address: nil, openingHours: hours)
    }

    static let canteens: [Canteen] = [
        canteen(46, "Mensa Ehrenberg", weekday: ("11:00", "14:00"), friday: ("11:00", "14:00")),
        canteen(53, "Cafeteria Mensa Ehrenberg", weekday: ("08:00", "20:00"), friday: ("08:00", "19:30"), saturday: ("11:30", "14:00")),
        canteen(55, "Cafeteria NANOteria", weekday: ("11:00", "14:00"), friday: nil),
        canteen(57, "Cafeteria Röntgenbau", weekday: ("10:30", "14:00"), friday: nil)
    ]

    /// Mittwoch, 4. November 2026, zur gewünschten Uhrzeit.
    static func wednesday(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: hour, minute: minute)) ?? .now
    }
}

private struct HoursPreview: View {
    let now: Date
    @State private var open: MensaVenue? = .cafeteriaEhrenberg

    var body: some View {
        NavigationStack {
            MensaOpeningHoursContent(canteens: HoursPreviewData.canteens, openVenue: $open, now: now)
        }
    }
}

#Preview("Öffnungszeiten – Light") {
    HoursPreview(now: HoursPreviewData.wednesday(hour: 12, minute: 15)).preferredColorScheme(.light)
}

#Preview("Öffnungszeiten – Dark") {
    HoursPreview(now: HoursPreviewData.wednesday(hour: 13, minute: 45)).preferredColorScheme(.dark)
}

#Preview("Öffnungszeiten – Abends") {
    HoursPreview(now: HoursPreviewData.wednesday(hour: 20, minute: 30))
}

#Preview("Öffnungszeiten – Große Schrift") {
    HoursPreview(now: HoursPreviewData.wednesday(hour: 12, minute: 15))
        .dynamicTypeSize(.xxxLarge)
}
