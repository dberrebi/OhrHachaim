import Foundation
import SQLite3

@MainActor
@Observable
final class CommentaryStore {
    private var database: OpaquePointer?
    private(set) var books: [Book] = []
    private(set) var parashot: [Parasha] = []
    private(set) var weekly: [WeeklyReading] = []
    private(set) var meta: [String: String] = []
    private(set) var loadError: String?

    private var commentsByParasha: [Int: [Comment]] = [:]
    private var introductionCache: [Comment]?
    private var gapsByParasha: [Int: [Int]] = [:]

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init() {
        open()
    }

    var yearStart: String { meta["year_start"] ?? "2024" }
    var yearEnd: String { meta["year_end"] ?? "2038" }

    func book(id: Int) -> Book? {
        books.first { $0.id == id }
    }

    func parasha(id: Int) -> Parasha? {
        parashot.first { $0.id == id }
    }

    func parashot(in bookID: Int) -> [Parasha] {
        parashot.filter { $0.bookID == bookID }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func hasIntroduction(bookID: Int) -> Bool {
        bookID == 1 && !introduction().isEmpty
    }

    func introduction() -> [Comment] {
        if let introductionCache { return introductionCache }
        let rows = comments(sql: """
            SELECT id, book_id, parasha_id, chapter, verse, comment_index, dibbur, body, source
            FROM comments
            WHERE source = 'on-your-way-introduction'
            ORDER BY verse, comment_index
            """)
        introductionCache = rows
        return rows
    }

    func comments(parashaID: Int) -> [Comment] {
        if let cached = commentsByParasha[parashaID] { return cached }
        let rows = comments(sql: """
            SELECT id, book_id, parasha_id, chapter, verse, comment_index, dibbur, body, source
            FROM comments
            WHERE parasha_id = \(parashaID)
            ORDER BY chapter, verse, comment_index
            """)
        commentsByParasha[parashaID] = rows
        return rows
    }

    func comment(id: Int) -> Comment? {
        if let cached = commentsByParasha.values.joined().first(where: { $0.id == id }) {
            return cached
        }
        if let cached = introductionCache?.first(where: { $0.id == id }) {
            return cached
        }
        return comments(sql: """
            SELECT id, book_id, parasha_id, chapter, verse, comment_index, dibbur, body, source
            FROM comments
            WHERE id = \(id)
            LIMIT 1
            """).first
    }

    func gapChapters(parashaID: Int) -> [Int] {
        if let cached = gapsByParasha[parashaID] { return cached }
        guard let database else { return [] }
        var statement: OpaquePointer?
        let sql = "SELECT chapter FROM gaps WHERE parasha_id = ? ORDER BY chapter"
        let status = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard status == SQLITE_OK, let prepared = statement else {
            sqlite3_finalize(statement)
            return []
        }
        defer { sqlite3_finalize(prepared) }
        sqlite3_bind_int(prepared, 1, Int32(parashaID))
        var chapters: [Int] = []
        while sqlite3_step(prepared) == SQLITE_ROW {
            chapters.append(Int(sqlite3_column_int(prepared, 0)))
        }
        gapsByParasha[parashaID] = chapters
        return chapters
    }

    func title(for parashaIDs: [Int], language: AppLanguage) -> String {
        let names = parashaIDs.compactMap { parasha(id: $0)?.name(for: language) }
        let separator = language == .he ? "־" : "–"
        return names.joined(separator: separator)
    }

    func locationTitle(for comment: Comment, language: AppLanguage) -> String {
        if comment.isIntroduction {
            return L10n.text("book.introduction", language)
        }
        let parashaName = comment.parashaID.flatMap { parasha(id: $0)?.name(for: language) } ?? ""
        let chapter = language == .he ? HebrewNumerals.string(comment.chapter) : String(comment.chapter)
        let verse = language == .he ? HebrewNumerals.string(comment.verse) : String(comment.verse)
        let place = String(
            format: L10n.text("reading.place", language),
            chapter,
            verse
        )
        if parashaName.isEmpty { return place }
        return "\(parashaName) · \(place)"
    }

    func formattedDate(_ iso: String, language: AppLanguage) -> String {
        guard let date = Self.isoFormatter.date(from: iso) else { return iso }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// The reading for "this week": today's reading, otherwise the one coming
    /// within six days, otherwise the most recent reading in the last ten days.
    func currentReading(israel: Bool, now: Date = Date()) -> WeeklyReading? {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        let todayISO = Self.isoFormatter.string(from: today)
        let rows = weekly
            .filter { $0.israel == israel }
            .sorted { $0.date < $1.date }
        if let exact = rows.first(where: { $0.date == todayISO }) {
            return exact
        }
        if let upcoming = rows.first(where: { row in
            guard let date = Self.isoFormatter.date(from: row.date) else { return false }
            let days = calendar.dateComponents([.day], from: today, to: date).day ?? 99
            return days > 0 && days <= 6
        }) {
            return upcoming
        }
        if let recent = rows.reversed().first(where: { row in
            guard let date = Self.isoFormatter.date(from: row.date) else { return false }
            let days = calendar.dateComponents([.day], from: date, to: today).day ?? 99
            return days > 0 && days <= 10
        }) {
            return recent
        }
        return nil
    }

    func readingCoversToday(_ now: Date = Date()) -> Bool {
        guard
            let start = Int(yearStart),
            let end = Int(yearEnd)
        else { return true }
        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        return year >= start && year <= end
    }

    private func open() {
        guard let url = Bundle.main.url(forResource: "ohr_hachaim", withExtension: "sqlite") else {
            loadError = "missing"
            return
        }
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
            if let handle { sqlite3_close(handle) }
            loadError = "open"
            return
        }
        database = handle
        loadBooks()
        loadParashot()
        loadWeekly()
        loadMeta()
        if books.isEmpty || parashot.count != 54 {
            loadError = "incomplete"
        }
    }

    private func loadBooks() {
        books = query("SELECT id, he_name, en_name FROM books ORDER BY sort_order") { statement in
            Book(
                id: Int(sqlite3_column_int(statement, 0)),
                heName: columnText(statement, 1),
                enName: columnText(statement, 2)
            )
        }
    }

    private func loadParashot() {
        parashot = query("""
            SELECT id, book_id, he_name, en_name, sort_order
            FROM parashot
            ORDER BY sort_order
            """) { statement in
            Parasha(
                id: Int(sqlite3_column_int(statement, 0)),
                bookID: Int(sqlite3_column_int(statement, 1)),
                heName: columnText(statement, 2),
                enName: columnText(statement, 3),
                sortOrder: Int(sqlite3_column_int(statement, 4))
            )
        }
    }

    private func loadWeekly() {
        weekly = query("""
            SELECT gregorian_date, israel, hebcal_title, hdate, parasha_ids, kind
            FROM weekly
            ORDER BY gregorian_date
            """) { statement in
            let ids = columnText(statement, 4)
                .split(separator: ",")
                .compactMap { Int($0) }
            return WeeklyReading(
                date: columnText(statement, 0),
                israel: sqlite3_column_int(statement, 1) == 1,
                hebcalTitle: columnText(statement, 2),
                hdate: columnText(statement, 3),
                parashaIDs: ids,
                kind: columnText(statement, 5)
            )
        }
    }

    private func loadMeta() {
        let rows: [(String, String)] = query("SELECT key, value FROM meta") { statement in
            (columnText(statement, 0), columnText(statement, 1))
        }
        meta = Dictionary(uniqueKeysWithValues: rows)
    }

    private func comments(sql: String) -> [Comment] {
        query(sql) { statement in
            let parasha: Int? = sqlite3_column_type(statement, 2) == SQLITE_NULL
                ? nil
                : Int(sqlite3_column_int(statement, 2))
            return Comment(
                id: Int(sqlite3_column_int64(statement, 0)),
                bookID: Int(sqlite3_column_int(statement, 1)),
                parashaID: parasha,
                chapter: Int(sqlite3_column_int(statement, 3)),
                verse: Int(sqlite3_column_int(statement, 4)),
                index: Int(sqlite3_column_int(statement, 5)),
                dibbur: columnText(statement, 6),
                body: columnText(statement, 7),
                source: columnText(statement, 8)
            )
        }
    }

    private func query<T>(_ sql: String, map: (OpaquePointer) -> T) -> [T] {
        guard let database else { return [] }
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard status == SQLITE_OK, let prepared = statement else {
            sqlite3_finalize(statement)
            return []
        }
        defer { sqlite3_finalize(prepared) }
        var rows: [T] = []
        while sqlite3_step(prepared) == SQLITE_ROW {
            rows.append(map(prepared))
        }
        return rows
    }

    private func columnText(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self))
    }
}
