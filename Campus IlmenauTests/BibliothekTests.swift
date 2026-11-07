import Foundation
import Testing
@testable import Campus_Ilmenau

struct BibliothekTests {
    // MARK: - Beispiele

    private let calendar = Calendar(identifier: .gregorian)
    /// Feste Uhrzeit mittags, damit „Tage bis zur Fälligkeit“ nicht von der Tageszeit abhängt.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 12))! }

    private func date(plusDays days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: now)!
    }

    private func item(
        _ title: String,
        status: PAIAItemStatus = .held,
        days: Int? = nil,
        renewals: Int? = 0,
        canRenew: Bool? = true,
        storage: String? = nil,
        queue: Int? = nil,
        comment: String? = nil
    ) -> PAIALoanItem {
        PAIALoanItem(
            item: title,
            edition: nil,
            about: title,
            label: "SIG 1",
            queue: queue,
            renewals: renewals,
            reminder: nil,
            starttime: nil,
            endtime: days.map(date(plusDays:)),
            cancancel: nil,
            canrenew: canRenew,
            storage: storage,
            storageid: nil,
            comment: comment,
            status: status
        )
    }

    private func info(days: Int?, renewals: Int? = 0, canRenew: Bool? = true) -> BibliothekLoanInfo {
        BibliothekLoanInfo(item: item("x", days: days, renewals: renewals, canRenew: canRenew), now: now, calendar: calendar)
    }

    // MARK: - Dringlichkeit und Chip

    @Test func urgencyThresholds() {
        #expect(info(days: -2).urgency == .urgent)
        #expect(info(days: 0).urgency == .urgent)
        #expect(info(days: 3).urgency == .urgent)
        #expect(info(days: 4).urgency == .soon)
        #expect(info(days: 5).urgency == .soon)
        #expect(info(days: 6).urgency == .normal)
        #expect(info(days: nil).urgency == .normal)
    }

    @Test func dueTextMatchesMockup() {
        #expect(info(days: -2).dueText == "Überfällig seit 2 Tagen")
        #expect(info(days: -1).dueText == "Überfällig seit 1 Tag")
        #expect(info(days: 0).dueText == "Heute fällig")
        #expect(info(days: 1).dueText == "Fällig in 1 Tag")
        #expect(info(days: 5).dueText == "Fällig in 5 Tagen")
        #expect(info(days: 12).dueText == "Fällig 10. Nov.")
        #expect(info(days: nil).dueText == nil)
    }

    @Test func daysIgnoreTimeOfDay() {
        let evening = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: now)!
        let loan = item("x", days: 1)
        #expect(BibliothekLoanInfo(item: loan, now: evening, calendar: calendar).days == 1)
        #expect(BibliothekLoanInfo(item: loan, now: now, calendar: calendar).days == 1)
    }

    // MARK: - Zeitleiste und Fußzeile

    @Test func progressIsClampedAndFullWhenOverdue() {
        #expect(info(days: -3).progress == 1)
        #expect(info(days: 21).progress == 0.04)
        #expect(info(days: 40).progress == 0.04)
        #expect(abs(info(days: 7).progress - (14.0 / 21.0)) < 0.0001)
        #expect(info(days: 0).progress == 1)
    }

    @Test func metaTextShowsRenewalsAndLock() {
        #expect(info(days: 5, renewals: 0).metaText == "Noch nicht verlängert")
        #expect(info(days: 5, renewals: nil).metaText == "Noch nicht verlängert")
        #expect(info(days: 5, renewals: 2).metaText == "2× verlängert")
        #expect(info(days: 5, renewals: 2, canRenew: false).metaText == "2× verlängert · nicht verlängerbar")
    }

    @Test func timelineLabelForVoiceOver() {
        #expect(info(days: 14, renewals: 1).timelineLabel == "Leihfrist: fällig am 12. Nov., 1-mal verlängert")
        #expect(info(days: -1, renewals: 0).timelineLabel == "Leihfrist: überfällig, noch nicht verlängert")
    }

    @Test func onlyAnExplicitFalseBlocksRenewal() {
        #expect(item("a", canRenew: nil).canBeRenewed)
        #expect(item("a", canRenew: true).canBeRenewed)
        #expect(!item("a", canRenew: false).canBeRenewed)
    }

    // MARK: - Listen

    @Test func loansAreSortedByDueDateWithOverdueFirst() {
        let lists = BibliothekLists(items: [
            item("normal", days: 12),
            item("ohne Datum"),
            item("überfällig", days: -2),
            item("bald", days: 2)
        ])
        #expect(lists.loans.map(\.displayTitle) == ["überfällig", "bald", "normal", "ohne Datum"])
    }

    @Test func holdsContainEveryStatusExceptHeld() {
        let lists = BibliothekLists(items: [
            item("a", status: .reserved),
            item("b", status: .ordered),
            item("c", status: .provided),
            item("d", status: .rejected),
            item("e", status: .none),
            item("f", status: .held, days: 3)
        ])
        #expect(lists.holds.map(\.displayTitle) == ["a", "b", "c", "d", "e"])
        #expect(lists.loans.map(\.displayTitle) == ["f"])
    }

    @Test func summaryCountsOverdueAndSoon() {
        let lists = BibliothekLists(items: [
            item("a", days: -2), item("b", days: 2), item("c", days: 5), item("d", days: 12)
        ])
        #expect(lists.summary(now: now, calendar: calendar) == "4 ausgeliehen · 1 überfällig · 2 bald fällig")
        #expect(BibliothekLists(items: [item("a", days: 12)]).summary(now: now, calendar: calendar) == "1 ausgeliehen")
        #expect(BibliothekLists(items: []).summary(now: now, calendar: calendar) == "Nichts ausgeliehen")
    }

    // MARK: - Vormerkungen

    @Test func holdChipsPerStatus() {
        #expect(BibliothekHoldInfo(item: item("a", status: .provided)).statusText == "Abholbereit")
        #expect(BibliothekHoldInfo(item: item("a", status: .provided)).variant == .green)
        #expect(BibliothekHoldInfo(item: item("a", status: .ordered)).variant == .blue)
        #expect(BibliothekHoldInfo(item: item("a", status: .reserved)).statusText == "Vorgemerkt")
        #expect(BibliothekHoldInfo(item: item("a", status: .rejected)).variant == .dangerSoft)
        #expect(BibliothekHoldInfo(item: item("a", status: .none)).statusText == "Kein Status")
    }

    @Test func holdDetailOnlyWhenDataExists() {
        #expect(BibliothekHoldInfo(item: item("a", status: .reserved)).detail == nil)
        let provided = item("a", status: .provided, days: 6, storage: "Ausleihtheke")
        #expect(BibliothekHoldInfo(item: provided).detail == "Abholort: Ausleihtheke · Abholbar bis 4. Nov.")
        let reserved = item("a", status: .reserved, queue: 2)
        #expect(BibliothekHoldInfo(item: reserved).detail == "Warteschlange: 2")
        let rejected = item("a", status: .rejected, comment: "Nicht bestellbar.")
        #expect(BibliothekHoldInfo(item: rejected).detail == "Nicht bestellbar.")
    }

    // MARK: - Mitteilungen

    @Test func notificationKindIsDerivedFromText() {
        #expect(PAIANotificationKind(about: "„Regelungstechnik 1“ liegt zur Abholung bereit.") == .provided)
        #expect(PAIANotificationKind(about: "„Einführung“ ist überfällig. Bitte gib das Medium zurück.") == .reminder)
        #expect(PAIANotificationKind(about: "„Statistik kompakt“ wurde nicht abgeholt.") == .holdExpired)
        #expect(PAIANotificationKind(about: "Ihre Vormerkung ist abgelaufen.") == .holdExpired)
        #expect(PAIANotificationKind(about: "Die Bibliothek hat am Freitag geschlossen.") == .other)
        #expect(PAIANotificationKind.other.title == "Mitteilung")
    }

    @Test func notificationDateIsGermanFormat() {
        let notification = PAIANotification(
            id: "1",
            about: "x",
            date: calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12))!,
            item: nil,
            url: nil
        )
        #expect(notification.dateText == "28.10.2026")
    }

    // MARK: - Details aus der Ausleihliste

    private func paiaItem(edition: String?, item: String? = "http://uri.gbv.de/document/de-ilm1:epn:1", about: String? = "Titel") -> PAIALoanItem {
        PAIALoanItem(
            item: item, edition: edition, about: about, label: "SIG 1", queue: nil, renewals: 0, reminder: nil,
            starttime: nil, endtime: nil, cancancel: nil, canrenew: true, storage: nil, storageid: nil,
            comment: nil, status: .held
        )
    }

    @Test func ppnIsReadFromTheEditionURI() {
        #expect(paiaItem(edition: "http://uri.gbv.de/document/gvk:ppn:1009895648").catalogPPN == "1009895648")
        #expect(paiaItem(edition: "http://uri.gbv.de/document/opac-de-ilm1:ppn:12345678X").catalogPPN == "12345678X")
        #expect(paiaItem(edition: "https://opac.example/DB=1/PPNSET?PPN=1009895648").catalogPPN == "1009895648")
        #expect(paiaItem(edition: "http://example.org/ppn/1009895648").catalogPPN == "1009895648")
    }

    @Test func ppnFallsBackToTheItemURIAndOtherwiseIsMissing() {
        #expect(paiaItem(edition: nil, item: "http://uri.gbv.de/document/gvk:ppn:1009895648").catalogPPN == "1009895648")
        #expect(paiaItem(edition: nil).catalogPPN == nil)
        #expect(paiaItem(edition: "").catalogPPN == nil)
        #expect(paiaItem(edition: "http://example.org/ohne-nummer").catalogPPN == nil)
    }

    @Test func routeOpensTheCatalogTitleWithTheLoanTitle() throws {
        let item = paiaItem(edition: "http://uri.gbv.de/document/gvk:ppn:1009895648", about: "Programmieren trainieren")
        let route = try #require(item.catalogRoute)
        #expect(route.media.id == "med_1009895648")
        #expect(route.media.ppn == "1009895648")
        #expect(route.media.title == "Programmieren trainieren")
        #expect(paiaItem(edition: nil).catalogRoute == nil)   // ohne PPN keine Details
    }
}
