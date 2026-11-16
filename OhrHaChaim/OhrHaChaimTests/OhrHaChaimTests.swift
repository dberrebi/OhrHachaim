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
}
