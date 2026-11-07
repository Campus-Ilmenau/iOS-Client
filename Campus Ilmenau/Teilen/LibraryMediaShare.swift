import Foundation

/// Ein Medium aus dem Katalog als Text. Ohne Verfügbarkeit (die ändert sich), ohne Token und ohne Benutzerdaten;
/// der Link zum UB-Katalog zeigt den aktuellen Stand.
struct LibraryMediaShare: ShareContent {
    let media: LibraryMedia
    /// Exemplare aus dem Detail; solange es nicht geladen ist, leer.
    let items: [LibraryItem]
    let isOnline: Bool
    let locale: Locale

    init(media: LibraryMedia, items: [LibraryItem] = [], isOnline: Bool = false, locale: Locale = ShareStrings.appLocale) {
        self.media = media
        self.items = items
        self.isOnline = isOnline
        self.locale = locale
    }

    init(detail: LibraryMediaDetail, locale: Locale = ShareStrings.appLocale) {
        self.init(media: detail.media, items: detail.items, isOnline: detail.availabilityStatus == .online, locale: locale)
    }

    /// Der Titel, wie die Ansicht ihn gerade kennt: nach dem Laden mit Exemplaren, davor nur mit den Daten der Trefferliste.
    init(media: LibraryMedia, detail: LibraryMediaDetail?, locale: Locale = ShareStrings.appLocale) {
        if let detail {
            self.init(detail: detail, locale: locale)
        } else {
            self.init(media: media, locale: locale)
        }
    }

    var title: String { media.title }

    var text: String {
        let strings = ShareStrings(locale: locale)

        let edition = [media.edition, media.year].compactMap(ShareText.clean).joined(separator: ", ")
        let byline = [media.personsLine, edition].filter { !$0.isEmpty }.joined(separator: " · ")
        let head = [strings("share.medium.intro"), media.title, media.trimmedSubtitle ?? "", byline, placeLine(strings)]

        return ShareText.compose([head, [media.catalogUrl?.absoluteString ?? ""]], locale: locale)
    }

    /// „Lehrbuchsammlung, 2. OG · ZQ 5000 R444(16)“ vom ersten Exemplar, bei Online-Titeln „Online im Campusnetz“.
    private func placeLine(_ strings: ShareStrings) -> String {
        if isOnline { return strings("share.medium.online") }
        guard let item = items.first else { return "" }
        return [ShareText.clean(item.location?.name), Self.signature(item.label)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// Signatur ohne Exemplar-Endung: „ZQ 5000 R444(16)-1“ → „ZQ 5000 R444(16)“.
    static func signature(_ label: String) -> String? {
        let stripped = label.replacingOccurrences(of: "-\\d{1,2}$", with: "", options: .regularExpression)
        return ShareText.clean(stripped)
    }
}
