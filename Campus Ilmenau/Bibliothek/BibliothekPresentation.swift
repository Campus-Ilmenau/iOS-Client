import Foundation

/// Dringlichkeit einer Ausleihe. Bestimmt die Farbe von Fälligkeits-Chip und Zeitleiste.
enum LoanUrgency: Equatable {
    /// Mehr als 5 Tage Zeit: neutral.
    case normal
    /// Noch höchstens 5 Tage: `warningFill`.
    case soon
    /// Noch höchstens 3 Tage oder überfällig: `dangerSoft`/`danger`.
    case urgent
}

enum BibliothekFormat {
    /// Kurzes Datum wie „12. Nov.“.
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "de_DE")))
    }

    static func days(_ count: Int) -> String {
        count == 1 ? "1 Tag" : "\(count) Tagen"
    }
}

extension PAIALoanItem {
    /// Laufende Ausleihe (im Gegensatz zu Vormerkung, Bestellung usw.).
    var isLoan: Bool { status == .held }

    /// Wie bisher: Nur ein ausdrückliches `false` des Servers sperrt das Verlängern.
    var canBeRenewed: Bool { canrenew != false }

    var displayTitle: String { about ?? label ?? "Unbekanntes Medium" }

    /// Die Signatur steht unter dem Titel, solange sie nicht selbst der Titel ist.
    var signature: String? { about != nil ? label : nil }
}

/// Alles, was eine Ausleihkarte an Texten und Werten braucht, aus Medium und aktuellem Datum berechnet.
struct BibliothekLoanInfo: Equatable {
    /// Standard-Leihfrist von 3 Wochen.
    static let loanPeriodDays = 21

    /// Tage bis zur Fälligkeit, negativ wenn überfällig. `nil`, wenn der Server keine Fälligkeit liefert.
    let days: Int?
    let dueDate: Date?
    let renewals: Int
    let canRenew: Bool

    init(item: PAIALoanItem, now: Date = .now, calendar: Calendar = .current) {
        dueDate = item.endtime
        renewals = item.renewals ?? 0
        canRenew = item.canBeRenewed
        if let end = item.endtime {
            days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: calendar.startOfDay(for: end)
            ).day
        } else {
            days = nil
        }
    }

    var isOverdue: Bool { (days ?? 0) < 0 }

    var urgency: LoanUrgency {
        guard let days else { return .normal }
        if days <= 3 { return .urgent }
        if days <= 5 { return .soon }
        return .normal
    }

    /// Text im Fälligkeits-Chip: „Fällig 12. Nov.“, „Fällig in 5 Tagen“, „Überfällig seit 2 Tagen“.
    var dueText: String? {
        guard let days, let dueDate else { return nil }
        if days < 0 { return "Überfällig seit \(BibliothekFormat.days(-days))" }
        if days == 0 { return "Heute fällig" }
        if days <= 5 { return "Fällig in \(BibliothekFormat.days(days))" }
        return "Fällig \(BibliothekFormat.shortDate(dueDate))"
    }

    /// Anteil der aktuellen Leihperiode, der vorbei ist. Überfällig: voll. Mindestens 4 %, damit der Strich sichtbar bleibt.
    var progress: Double {
        guard let days else { return 0 }
        if days < 0 { return 1 }
        let elapsed = Double(Self.loanPeriodDays - days) / Double(Self.loanPeriodDays)
        return min(1, max(0.04, elapsed))
    }

    /// Fußzeile: „2× verlängert“ bzw. „Noch nicht verlängert“, bei Sperre „· nicht verlängerbar“.
    var metaText: String {
        let renewed = renewals > 0 ? "\(renewals)× verlängert" : "Noch nicht verlängert"
        return canRenew ? renewed : "\(renewed) · nicht verlängerbar"
    }

    /// VoiceOver-Text der Zeitleiste: „Leihfrist: fällig am 12. Nov., 1-mal verlängert“.
    var timelineLabel: String {
        let due: String
        if isOverdue {
            due = "überfällig"
        } else if let dueDate {
            due = "fällig am \(BibliothekFormat.shortDate(dueDate))"
        } else {
            due = "ohne Fälligkeit"
        }
        let renewed = renewals > 0 ? "\(renewals)-mal verlängert" : "noch nicht verlängert"
        return "Leihfrist: \(due), \(renewed)"
    }
}

/// Status-Chip und Zusatzzeile einer Vormerkung, Bestellung usw.
struct BibliothekHoldInfo: Equatable {
    let statusText: String
    let variant: Chip.Variant
    /// Nur, wenn der Server dazu Daten liefert.
    let detail: String?

    init(item: PAIALoanItem) {
        switch item.status {
        case .provided: (statusText, variant) = ("Abholbereit", .green)
        case .ordered: (statusText, variant) = ("Bestellt", .blue)
        case .reserved: (statusText, variant) = ("Vorgemerkt", .neutral)
        case .rejected: (statusText, variant) = ("Abgelehnt", .dangerSoft)
        case .none, .held: (statusText, variant) = ("Kein Status", .neutral)
        }

        // Aus den PAIA-Feldern comment, storage, queue und (bei Bereitstellung) endtime zusammengesetzt.
        var parts: [String] = []
        if let comment = item.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
            parts.append(comment)
        }
        if let storage = item.storage?.trimmingCharacters(in: .whitespacesAndNewlines), !storage.isEmpty {
            parts.append(item.status == .provided ? "Abholort: \(storage)" : "Standort: \(storage)")
        }
        if let queue = item.queue, queue > 0 {
            parts.append("Warteschlange: \(queue)")
        }
        if item.status == .provided, let end = item.endtime {
            parts.append("Abholbar bis \(BibliothekFormat.shortDate(end))")
        }
        detail = parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Teilt die eine PAIA-Liste in die beiden Segmente.
struct BibliothekLists: Equatable {
    /// Status „ausgeliehen“, nach Fälligkeit sortiert. Überfälliges steht zuerst, Medien ohne Fälligkeit zuletzt.
    let loans: [PAIALoanItem]
    /// Vorgemerkt, bestellt, bereitgestellt, abgelehnt und ohne Status.
    let holds: [PAIALoanItem]

    init(items: [PAIALoanItem]) {
        loans = items.filter(\.isLoan).sorted { lhs, rhs in
            switch (lhs.endtime, rhs.endtime) {
            case let (l?, r?): l != r ? l < r : lhs.displayTitle < rhs.displayTitle
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): lhs.displayTitle < rhs.displayTitle
            }
        }
        holds = items.filter { !$0.isLoan }
    }

    /// Zeile unter dem Titel: „4 ausgeliehen · 1 überfällig · 2 bald fällig“.
    func summary(now: Date = .now, calendar: Calendar = .current) -> String {
        guard !loans.isEmpty else { return "Nichts ausgeliehen" }
        let infos = loans.map { BibliothekLoanInfo(item: $0, now: now, calendar: calendar) }
        let overdue = infos.filter(\.isOverdue).count
        let soon = infos.filter { ($0.days ?? Int.max) >= 0 && ($0.days ?? Int.max) <= 5 }.count
        var parts = ["\(loans.count) ausgeliehen"]
        if overdue > 0 { parts.append("\(overdue) überfällig") }
        if soon > 0 { parts.append("\(soon) bald fällig") }
        return parts.joined(separator: " · ")
    }
}

extension PAIALoanItem: Equatable {
    static func == (lhs: PAIALoanItem, rhs: PAIALoanItem) -> Bool {
        lhs.item == rhs.item && lhs.about == rhs.about && lhs.label == rhs.label
            && lhs.status == rhs.status && lhs.endtime == rhs.endtime
            && lhs.renewals == rhs.renewals && lhs.canrenew == rhs.canrenew
            && lhs.queue == rhs.queue && lhs.storage == rhs.storage && lhs.comment == rhs.comment
    }
}

// MARK: - Details eines Mediums aus der Ausleihliste

/// Ziel beim Antippen eines Eintrags der Ausleihliste: der Titel im Katalog.
struct LibraryTitleRoute: Hashable {
    let media: LibraryMedia

    static func == (lhs: LibraryTitleRoute, rhs: LibraryTitleRoute) -> Bool { lhs.media.id == rhs.media.id }
    func hash(into hasher: inout Hasher) { hasher.combine(media.id) }
}

extension PAIALoanItem {
    /// PPN des Titels. PAIA nennt sie in der Adresse der Ausgabe (`edition`, z. B. `…:ppn:1009895648`);
    /// ersatzweise steht sie manchmal in der Adresse des Exemplars (`item`).
    var catalogPPN: String? {
        for uri in [edition, item] {
            if let ppn = Self.ppn(in: uri) { return ppn }
        }
        return nil
    }

    /// Der Katalog-Titel zu diesem Eintrag oder `nil`, wenn sich keine PPN finden lässt.
    var catalogRoute: LibraryTitleRoute? {
        guard let ppn = catalogPPN else { return nil }
        let media = LibraryMedia(id: "med_\(ppn)", ppn: ppn, title: displayTitle)
        return LibraryTitleRoute(media: media)
    }

    private static func ppn(in uri: String?) -> String? {
        guard let uri, !uri.isEmpty else { return nil }
        // „…:ppn:123456789“, „…/ppn/123456789“ oder „…?PPN=123456789“
        if let match = uri.firstMatch(of: /(?i)ppn[:\/=]([0-9]{6,12}[0-9Xx]?)/) {
            return String(match.1).uppercased()
        }
        return nil
    }
}
