import Foundation

/// Eine Veranstaltung als Text. Tage und Uhrzeiten laufen in Berlin wie überall bei den Events.
struct EventShare: ShareContent {
    /// Längste Beschreibung im Text.
    static let descriptionLimit = 280

    let event: CampusEvent
    let locale: Locale

    init(event: CampusEvent, locale: Locale = ShareStrings.appLocale) {
        self.event = event
        self.locale = locale
    }

    var title: String {
        "\(event.titel) · \(ShareDate.short(event.beginn, locale: locale, timeZone: EventKalender.zeitzone))"
    }

    var text: String {
        let strings = ShareStrings(locale: locale)

        let name = event.status == .abgesagt ? strings("share.event.cancelled", event.titel) : event.titel
        var timeLine = "\(dateText) · \(timeText(strings))"
        if event.status == .unbestaetigt { timeLine += " " + strings("share.event.tentative") }
        let place = [ShareText.clean(event.ort), ShareText.clean(event.adresse)].compactMap { $0 }.joined(separator: ", ")
        let organizer = ShareText.clean(event.veranstalter).map { strings("share.event.organizer", $0) } ?? ""
        let head = [name, timeLine, place, organizer]

        // Abgesagt: keine Beschreibung, wie auf dem Bild.
        let description = event.status == .abgesagt
            ? ""
            : ShareText.clean(event.beschreibung).map { ShareText.shortened($0, limit: Self.descriptionLimit) } ?? ""

        let link: String
        if let tickets = event.ticketURL {
            link = strings("share.event.tickets", tickets.absoluteString)
        } else if let info = event.infoURL {
            link = strings("share.event.info", info.absoluteString)
        } else {
            link = ""
        }
        return ShareText.compose([head, [description], [link]], locale: locale)
    }

    /// „Freitag, 30. Oktober“, mehrtägig „Mittwoch, 28. Oktober – Sonntag, 1. November“.
    var dateText: String {
        let first = ShareDate.full(event.ersterTag, locale: locale, timeZone: EventKalender.zeitzone)
        guard event.istMehrtaegig else { return first }
        return "\(first) – \(ShareDate.full(event.letzterTag, locale: locale, timeZone: EventKalender.zeitzone))"
    }

    /// „21:00–03:00 Uhr“, ohne Ende „ab 21:00 Uhr“, ganztägig „ganztägig“.
    private func timeText(_ strings: ShareStrings) -> String {
        if event.ganztaegig { return strings("share.event.allDay") }
        let start = EventZeitFormatter.uhrzeit(event.beginn)
        if let end = event.ende, end > event.beginn, !event.istMehrtaegig {
            return strings("share.event.range", start, EventZeitFormatter.uhrzeit(end))
        }
        return strings("share.event.from", start)
    }
}
