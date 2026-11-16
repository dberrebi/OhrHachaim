import XCTest

final class NavigationUITests: XCTestCase {
    func testTappingGenesisOpensItsParashaList() throws {
        let app = XCUIApplication()
        app.launch()

        let genesis = app.descendants(matching: .any)["home.book.1"]
        XCTAssertTrue(genesis.waitForExistence(timeout: 15))
        genesis.tap()

        let noach = app.descendants(matching: .any)["parasha.2"]
        XCTAssertTrue(noach.waitForExistence(timeout: 10))

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "parasha-list"
        attachment.lifetime = .keepAlways
        add(attachment)

        try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/parasha-list.png"))
    }
}
