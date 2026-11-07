import Foundation

/// Filter „Medienart“ der Suche (Parameter `type`).
enum LibraryMediaFilter: String, CaseIterable, Equatable {
    case printBook = "print_book"
    case ebook
    case journal
    case all
}

/// Wo gesucht wird (Parameter `in`).
enum LibrarySearchScope: String, Equatable {
    /// Nur der Bestand der UB Ilmenau. Es zählt nur `q`, Feldangaben ignoriert die API ohne Fehler.
    case local
    /// Der Gesamtkatalog. Erzwingt die Suche im Verbund („Im Gesamtkatalog weitersuchen“).
    case catalog
    /// Auch in Inhaltsverzeichnissen und Klappentexten. Es zählt nur `q`; die Treffer haben `match.snippet`.
    case content
}

/// Eingabefelder der Suche, damit Fehler unter dem richtigen Feld stehen können.
enum LibraryQueryField: Equatable {
    case text
    case title
    case author
    case isbn
    case subject
    case yearFrom
    case yearTo
}

/// Ein Fehler in der Eingabe, den die App vor dem Senden abfängt (die API würde mit 400 antworten).
struct LibraryQueryIssue: Equatable {
    let field: LibraryQueryField
    let message: String
}

/// Suchanfrage an `/v1/library/search`: Freitext (`q`) oder Feldsuche. Seiten à 20 Treffer.
struct LibrarySearchQuery: Equatable {
    static let maxTextLength = 200
    static let pageSize = 20
    /// Höchste erlaubte Spanne zwischen „von“ und „bis“.
    static let maxYearSpan = 150

    /// Freitext (`q`).
    var text = ""
    var title = ""
    /// Person (Parameter `author`).
    var author = ""
    var isbn = ""
    var subject = ""
    /// Wo gesucht wird. `nil` (ohne `in`): Freitext zuerst im Bestand und bei Bedarf ergänzt, Feldsuche im Katalog.
    var scope: LibrarySearchScope?
    /// `nil` lässt die Voreinstellung der API gelten, das ist `print_book` („Gedruckt“).
    var mediaType: LibraryMediaFilter?
    /// Jahre so, wie sie getippt wurden. Sie werden vor dem Senden geprüft.
    var yearFrom = ""
    var yearTo = ""
    /// Ab 1.
    var page = 1

    init(
        text: String = "",
        title: String = "",
        author: String = "",
        isbn: String = "",
        subject: String = "",
        scope: LibrarySearchScope? = nil,
        mediaType: LibraryMediaFilter? = nil,
        yearFrom: String = "",
        yearTo: String = "",
        page: Int = 1
    ) {
        self.text = text
        self.title = title
        self.author = author
        self.isbn = isbn
        self.subject = subject
        self.scope = scope
        self.mediaType = mediaType
        self.yearFrom = yearFrom
        self.yearTo = yearTo
        self.page = page
    }

    /// Bei `in=local` und `in=content` zählt nur `q`; die Felder ignoriert die API ohne Fehler.
    private var usesOnlyText: Bool { scope == .local || scope == .content }

    /// Mindestens eines der Felder, nach denen die API sucht, ist gefüllt (bei `local`/`content` nur der Freitext).
    var hasSearchTerm: Bool {
        let terms = usesOnlyText ? [text] : [text, title, author, isbn, subject]
        return terms.contains { !$0.trimmed.isEmpty }
    }

    /// Eine Suche über Felder statt Freitext. Sie läuft im Gesamtkatalog, die Antwort enthält kein `source`.
    var isFieldSearch: Bool {
        guard !usesOnlyText else { return false }
        return [title, author, isbn, subject, yearFrom, yearTo].contains { !$0.trimmed.isEmpty }
    }

    /// Dieselbe Suche im Gesamtkatalog, ab Seite 1. Für „Im Gesamtkatalog weitersuchen“ bei `catalog_suggested`
    /// und für die Fortsetzung einer gemischten Antwort (die endet auf Seite 1).
    func continuedInCatalog() -> LibrarySearchQuery {
        var copy = self
        copy.scope = .catalog
        copy.page = 1
        return copy
    }

    /// Dieselbe Suche für die nächste Seite.
    func nextPage() -> LibrarySearchQuery {
        var copy = self
        copy.page += 1
        return copy
    }

    // MARK: Prüfung

    /// Prüft die Eingabe. Leere Liste heißt: darf gesendet werden.
    func validate() -> [LibraryQueryIssue] {
        var issues: [LibraryQueryIssue] = []

        if !hasSearchTerm {
            issues.append(LibraryQueryIssue(field: .text, message: "Bitte gib einen Suchbegriff ein."))
        } else if usesOnlyText, text.trimmed.isEmpty {
            issues.append(LibraryQueryIssue(field: .text, message: "Bitte gib einen Suchbegriff ein."))
        }
        if text.trimmed.count > Self.maxTextLength {
            issues.append(LibraryQueryIssue(
                field: .text,
                message: "Der Suchbegriff darf höchstens \(Self.maxTextLength) Zeichen lang sein."
            ))
        }
        issues.append(contentsOf: Self.validateYears(from: yearFrom, to: yearTo))
        if page < 1 {
            issues.append(LibraryQueryIssue(field: .text, message: "Die Seitenzahl muss mindestens 1 sein."))
        }
        return issues
    }

    /// Jahre: vierstellig (1000–9999), „von“ nicht nach „bis“, höchstens 150 Jahre Spanne.
    /// Leere Felder sind erlaubt; ein einzelnes Jahr ist eine offene Grenze.
    static func validateYears(from: String, to: String) -> [LibraryQueryIssue] {
        var issues: [LibraryQueryIssue] = []
        let fromText = from.trimmed
        let toText = to.trimmed

        let fromYear = parseYear(fromText)
        let toYear = parseYear(toText)

        if !fromText.isEmpty, fromYear == nil {
            issues.append(LibraryQueryIssue(field: .yearFrom, message: "Bitte das Jahr vierstellig eingeben."))
        }
        if !toText.isEmpty, toYear == nil {
            issues.append(LibraryQueryIssue(field: .yearTo, message: "Bitte das Jahr vierstellig eingeben."))
        }
        if let fromYear, let toYear {
            if fromYear > toYear {
                issues.append(LibraryQueryIssue(field: .yearFrom, message: "„von“ darf nicht nach „bis“ liegen."))
            } else if toYear - fromYear > maxYearSpan {
                issues.append(LibraryQueryIssue(
                    field: .yearTo,
                    message: "Höchstens \(maxYearSpan) Jahre auf einmal."
                ))
            }
        }
        return issues
    }

    /// Vierstellig, ohne führende Null (die API verlangt mindestens 1000).
    private static func parseYear(_ text: String) -> Int? {
        guard text.count == 4, text.allSatisfy(\.isASCII), text.allSatisfy(\.isNumber), text.first != "0" else {
            return nil
        }
        return Int(text)
    }

    // MARK: Anfrage

    /// Query-Parameter für die API. Leere Felder entfallen.
    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String) {
            let trimmed = value.trimmed
            if !trimmed.isEmpty { items.append(URLQueryItem(name: name, value: trimmed)) }
        }
        add("q", text)
        // Bei `local` und `content` würde die API die Felder stillschweigend ignorieren; sie gar nicht zu senden ist ehrlicher.
        if !usesOnlyText {
            add("title", title)
            add("author", author)
            add("isbn", isbn)
            add("subject", subject)
        }
        if let scope { items.append(URLQueryItem(name: "in", value: scope.rawValue)) }
        if let mediaType { items.append(URLQueryItem(name: "type", value: mediaType.rawValue)) }
        add("year_from", yearFrom)
        add("year_to", yearTo)
        items.append(URLQueryItem(name: "page", value: String(page)))
        items.append(URLQueryItem(name: "per_page", value: String(Self.pageSize)))
        return items
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
