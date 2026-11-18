import XCTest
@testable import OhrHaChaim

final class OhrHaChaimTests: XCTestCase {
    func testHebrewNumerals() {
        XCTAssertEqual(HebrewNumerals.string(1), "א׳")
        XCTAssertEqual(HebrewNumerals.string(10), "י׳")
        XCTAssertEqual(HebrewNumerals.string(15), "ט״ו")
        XCTAssertEqual(HebrewNumerals.string(16), "ט״ז")
        XCTAssertEqual(HebrewNumerals.string(21), "כ״א")
    }

    func testSearchQueryDropsNikud() {
        XCTAssertEqual(HebrewText.ftsQuery("אוֹרָה"), "\"אורה\"*")
        XCTAssertEqual(HebrewText.ftsQuery("בראשית ברא"), "\"בראשית\"* \"ברא\"*")
        XCTAssertEqual(HebrewText.ftsQuery("light"), "")
    }

    @MainActor
    func testSearchFindsPointedTextFromPlainLetters() {
        let store = CommentaryStore()
        XCTAssertNil(store.loadError)
        let plain = store.search("אורה")
        XCTAssertFalse(plain.isEmpty)
        XCTAssertTrue(plain.contains { $0.comment.body.contains("אוֹרָה") })
        XCTAssertFalse(plain[0].snippet.isEmpty)
        let pointed = store.search("אוֹרָה")
        XCTAssertEqual(pointed.map(\.comment.id), plain.map(\.comment.id))
        XCTAssertTrue(store.search("   ").isEmpty)
        XCTAssertTrue(store.search("xyzzy").isEmpty)
        let hit = plain[0]
        XCTAssertNotNil(hit.comment.parashaID)
    }

    func testNikudStrippingAndMarkup() {
        XCTAssertEqual(HebrewText.stripNikud("בְּרֵאשִׁית"), "בראשית")
        let marked = "<b>בְּרֵאשִׁית</b> בָּרָא"
        XCTAssertEqual(HebrewText.plain(marked, stripNikud: true), "בראשית ברא")
        let pointed = HebrewText.plain(marked, stripNikud: false)
        XCTAssertTrue(pointed.contains("בְּרֵאשִׁית"))
        XCTAssertFalse(pointed.contains("<"))
    }

    @MainActor
    func testBundledCommentary() {
        let store = CommentaryStore()
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.books.map(\.heName), ["בראשית", "שמות", "ויקרא", "במדבר", "דברים"])
        XCTAssertEqual(store.parashot.count, 54)
        XCTAssertEqual(store.gapChapters(parashaID: 2), [10])
        XCTAssertEqual(store.gapChapters(parashaID: 33), [27])

        let openingID = 1_001_001_001
        let opening = store.comment(id: openingID)
        XCTAssertEqual(opening?.chapter, 1)
        XCTAssertEqual(opening?.verse, 1)
        XCTAssertTrue(opening?.body.contains("אוֹרָה") == true)
        XCTAssertEqual(store.introduction().count, 14)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12))
        let reading = date.flatMap { store.currentReading(israel: true, now: $0) }
        XCTAssertEqual(reading?.parashaIDs, [7])
        XCTAssertEqual(store.parasha(id: 7)?.heName, "ויצא")
    }

    func testIsraelCalendarFollowsRegion() {
        XCTAssertTrue(AppSettings.usesIsraelCalendar(regionCode: "IL"))
        XCTAssertFalse(AppSettings.usesIsraelCalendar(regionCode: "US"))
        XCTAssertFalse(AppSettings.usesIsraelCalendar(regionCode: nil))
    }

    @MainActor
    func testHistoryKeepsOneRowPerParasha() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("library.json")
        let store = CommentaryStore()
        let library = UserLibrary(storageURL: url)
        let first = try XCTUnwrap(store.comments(parashaID: 1).first)
        let later = try XCTUnwrap(store.comments(parashaID: 1).dropFirst(8).first)
        let other = try XCTUnwrap(store.comments(parashaID: 2).first)
        library.note(first)
        library.note(later)
        XCTAssertEqual(library.history.count, 1)
        XCTAssertEqual(library.history[0].commentID, later.id)
        library.note(other)
        XCTAssertEqual(library.history.count, 2)
        XCTAssertEqual(library.history[0].parashaID, 2)
    }

    @MainActor
    func testReadingAParashaAgainMovesItToTheTop() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = CommentaryStore()
        let library = UserLibrary(storageURL: directory.appendingPathComponent("library.json"))
        let first = try XCTUnwrap(store.comments(parashaID: 1).first)
        let other = try XCTUnwrap(store.comments(parashaID: 2).first)
        library.note(first)
        library.note(other)
        XCTAssertEqual(library.history.map(\.parashaID), [2, 1])
        // Back to Bereshit at the same passage as before.
        library.note(first)
        XCTAssertEqual(library.history.map(\.parashaID), [1, 2])
        XCTAssertEqual(library.lastCommentID, first.id)
    }

    @MainActor
    func testFlushHasWrittenTheFileWhenItReturns() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("library.json")
        let store = CommentaryStore()
        let comment = try XCTUnwrap(store.comments(parashaID: 1).first)
        let library = UserLibrary(storageURL: url)
        library.toggleFavourite(comment.id)
        library.note(comment)
        library.flush()
        let reopened = UserLibrary(storageURL: url)
        XCTAssertEqual(reopened.favouriteIDs, [comment.id])
        XCTAssertEqual(reopened.history.first?.commentID, comment.id)
    }

    @MainActor
    func testUnreadableLibraryIsBackedUp() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("library.json")
        try Data("not json".utf8).write(to: url)
        let library = UserLibrary(storageURL: url)
        XCTAssertTrue(library.history.isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(names.contains { $0.contains("corrupt-") })
    }
}
