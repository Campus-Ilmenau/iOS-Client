import Foundation

// Teilen-Texte für Mensa nach `Uebergabe.md`, Kapitel „Teilen“ → „Texte“.

extension MensaMealPrice {
    /// „2,90 €“ in der Sprache `locale`; `nil` bei fehlendem Preis (im Text entfällt er).
    func shareText(for group: MensaPriceGroup, locale: Locale) -> String? {
        let value: Double?
        switch group {
        case .studierende: value = student
        case .bedienstete: value = staff
        case .gaeste: value = guest
        }
        guard value != nil else { return nil }
        return ShareText.plainSpaces(Self.format(value, currency: currency, locale: locale))
    }

    /// Wie `shareText`, aber ein fehlender Preis ist „–“ (auf dem Bild bleibt die Zeile stehen).
    func formatted(for group: MensaPriceGroup, locale: Locale) -> String {
        shareText(for: group, locale: locale) ?? "–"
    }
}

extension MensaPriceGroup {
    /// Reihenfolge der Gruppen mit der eigenen zuerst.
    func ownFirst() -> [MensaPriceGroup] {
        [self] + MensaPriceGroup.allCases.filter { $0 != self }
    }

    func shareName(_ strings: ShareStrings) -> String {
        switch self {
        case .studierende: strings("share.group.students")
        case .bedienstete: strings("share.group.staff")
        case .gaeste: strings("share.group.guests")
        }
    }
}

extension MensaChipItem {
    /// Chip-Titel der Liste in der Sprache des Textes. Weitere Kategorien der API bleiben, wie sie sind.
    func shareTitle(_ strings: ShareStrings) -> String {
        switch title {
        case "Vegan": strings("share.tag.vegan")
        case "Vegetarisch": strings("share.tag.vegetarian")
        case "Bio": strings("share.tag.organic")
        case "Regional": strings("share.tag.regional")
        default: title
        }
    }
}

// MARK: - Speiseplan einer Mensa an einem Tag

/// Das gerade gezeigte Angebot einer Mensa: alle Gerichte, **ohne** Filter (die sind persönlich), mit dem Preis der
/// eigenen Preisgruppe.
struct MensaPlanShare: ShareContent {
    let venue: MensaVenue
    let day: Date
    let mealtime: MensaMealtime
    let meals: [MensaMeal]
    let priceGroup: MensaPriceGroup
    /// Feste Zeit, z. B. „11:00–14:00“; ohne Angabe steht nur „Mittagsangebot“ bzw. „Abendessen“.
    let hours: String?
    let locale: Locale

    /// - Parameter allMeals: Alle Gerichte des Tages; die Auswahl für Mensa und Mittag/Abendessen trifft der Aufruf hier
    ///   wie der Speiseplan, nur ohne Filter.
    init(
        venue: MensaVenue,
        day: Date,
        mealtime: MensaMealtime = .lunch,
        allMeals: [MensaMeal],
        priceGroup: MensaPriceGroup,
        hours: String? = nil,
        locale: Locale = ShareStrings.appLocale
    ) {
        self.venue = venue
        self.day = day
        self.mealtime = mealtime
        self.priceGroup = priceGroup
        self.hours = hours
        self.locale = locale
        meals = allMeals.filter { meal in
            guard venue.matches(canteenName: meal.canteenName) else { return false }
            guard venue.hasMealtimes else { return true }
            return (mealtime == .dinner) == MensaMealtime.isDinner(meal)
        }
    }

    var title: String {
        "\(venue.displayName) · \(ShareDate.short(day, locale: locale))"
    }

    var text: String {
        let strings = ShareStrings(locale: locale)
        let offer = strings(mealtime == .dinner ? "share.plan.dinner" : "share.plan.lunch")
        let offerLine = [offer, hours.map { strings("share.hours", $0) }].compactMap { $0 }.joined(separator: ", ")
        let header = ["\(venue.displayName) · \(ShareDate.full(day, locale: locale))", offerLine]

        let lines = meals.map { meal -> String in
            var line = "• \(meal.name)"
            if let price = meal.price.shareText(for: priceGroup, locale: locale) { line += " – \(price)" }
            let tags = meal.listChips.map { $0.shareTitle(strings).lowercased(with: locale) }
            if !tags.isEmpty { line += " (\(tags.joined(separator: ", ")))" }
            return line
        }

        let priceNote: String
        switch priceGroup {
        case .studierende: priceNote = strings("share.plan.prices.students")
        case .bedienstete: priceNote = strings("share.plan.prices.staff")
        case .gaeste: priceNote = strings("share.plan.prices.guests")
        }
        return ShareText.compose([header, lines, [priceNote]], locale: locale)
    }

    /// Zeit des Angebots aus den Öffnungszeiten der API: Mittag wie geöffnet, Abendessen ab 16:30 bis Ende der Öffnung.
    static func hours(
        for mealtime: MensaMealtime,
        day: Date,
        openingHours: [OpeningHour],
        calendar: Calendar = .current
    ) -> String? {
        let keys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        let key = keys[max(0, min(6, calendar.component(.weekday, from: day) - 1))]
        guard let today = openingHours.first(where: { $0.weekday.lowercased() == key }) else { return nil }
        switch mealtime {
        case .lunch:
            return "\(today.opensAt)–\(today.closesAt)"
        case .dinner:
            let start = HeuteModel.abendessenBeginn
            return String(format: "%d:%02d–%@", start / 60, start % 60, today.closesAt)
        }
    }
}

// MARK: - Ein Gericht

/// Ein Gericht mit allen Angaben: alle drei Preisgruppen (die eigene zuerst), Allergene, Zusatzstoffe, CO₂.
struct MensaMealShare: ShareContent {
    let meal: MensaMeal
    let priceGroup: MensaPriceGroup
    let locale: Locale

    init(meal: MensaMeal, priceGroup: MensaPriceGroup, locale: Locale = ShareStrings.appLocale) {
        self.meal = meal
        self.priceGroup = priceGroup
        self.locale = locale
    }

    var venueName: String {
        MensaVenue.allCases.first { $0.matches(canteenName: meal.canteenName) }?.displayName ?? meal.canteenName
    }

    /// „Mensa Ehrenberg · Essen 1 · Do 29. Okt.“
    var kicker: String {
        let category = ShareText.clean(meal.category) ?? ShareStrings(locale: locale)("share.meal.fallbackCategory")
        return "\(venueName) · \(category) · \(ShareDate.short(meal.date, locale: locale))"
    }

    var title: String {
        "\(meal.name) · \(venueName)"
    }

    var text: String {
        let strings = ShareStrings(locale: locale)
        let head = [
            meal.name,
            ShareText.clean(meal.description) ?? "",
            kicker,
            meal.detailChips.map { $0.shareTitle(strings) }.joined(separator: " · ")
        ]

        let prices = priceGroup.ownFirst().compactMap { group -> String? in
            meal.price.shareText(for: group, locale: locale).map { "\(group.shareName(strings)) \($0)" }
        }.joined(separator: " · ")

        var details = [prices]
        if !meal.uniqueAllergies.isEmpty {
            details.append(strings("share.meal.allergens", meal.uniqueAllergies.joined(separator: ", ")))
        }
        if !meal.uniqueAdditives.isEmpty {
            details.append(strings("share.meal.additives", meal.uniqueAdditives.joined(separator: ", ")))
        }
        if let co2 = meal.co2GramPerPortion {
            details.append(strings("share.meal.co2", co2.formatted(.number.precision(.fractionLength(0)).locale(locale))))
        }
        return ShareText.compose([head, details], locale: locale)
    }
}
