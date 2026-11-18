import XCTest

/// Hebrew-interface screenshots for the light/dark bar check and for the App Store sizes.
/// The filename prefix follows the simulator window, so an iPad run does not overwrite the iPhone files.
final class StoreScreenshotUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHebrewLightScreens() throws {
        launch(appearance: "light")
        try shot("light-home")

        tap("home.weekly")
        waitForReader()
        try shot("light-weekly")
        if !isPad { pop() }

        tap("home.book.1")
        let bereshit = app.descendants(matching: .any)["parasha.1"]
        XCTAssertTrue(bereshit.waitForExistence(timeout: 10))
        try shot("light-parasha-list")
        bereshit.tap()
        waitForReader()
        try shot("light-reader")
        if !isPad {
            pop()
            pop()
        }

        tap("home.search")
        let hit = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "search.hit.")).firstMatch
        XCTAssertTrue(hit.waitForExistence(timeout: 10))
        try shot("light-search")
        if !isPad { pop() }

        tap("home.settings")
        XCTAssertTrue(app.descendants(matching: .any)["settings.privacy"].waitForExistence(timeout: 10))
        try shot("light-settings")
    }

    func testHebrewDarkChrome() throws {
        launch(appearance: "dark")
        try shot("dark-home")
        tap("home.book.1")
        XCTAssertTrue(app.descendants(matching: .any)["parasha.1"].waitForExistence(timeout: 10))
        try shot("dark-parasha-list")
    }

    private var isPad: Bool {
        prefix == "ipad"
    }

    /// Point widths: iPhone 17 Pro is 402, iPhone 17 Pro Max is 440, and the 13-inch iPad is much wider.
    /// Separate prefixes keep the 1206×2622 and 1320×2868 captures from overwriting each other.
    private var prefix: String {
        let width = app.windows.firstMatch.frame.width
        if width >= 700 { return "ipad" }
        if width >= 420 { return "iphone69" }
        return "iphone"
    }

    private func launch(appearance: String) {
        app = XCUIApplication()
        app.launchArguments = ["-appearance", appearance, "-search-query", "אורה"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["home.search"].waitForExistence(timeout: 20))
    }

    private func tap(_ identifier: String) {
        let element = app.descendants(matching: .any)[identifier]
        for _ in 0..<6 {
            if element.exists && element.isHittable {
                element.tap()
                return
            }
            app.swipeUp()
        }
        XCTFail("Missing \(identifier)")
    }

    private func pop() {
        let buttons = app.navigationBars.buttons
        XCTAssertTrue(buttons.firstMatch.waitForExistence(timeout: 5))
        for index in 0..<buttons.count {
            let button = buttons.element(boundBy: index)
            let label = button.label
            if label == "שיתוף" || label == "Share" { continue }
            button.tap()
            return
        }
        XCTFail("No back button")
    }

    private func waitForReader() {
        let hit = app.descendants(matching: .any)["home.search"]
        // The reader replaces the home list. Give the commentary a moment to lay out.
        _ = hit.waitForExistence(timeout: 1)
        sleep(1)
    }

    private func shot(_ name: String) throws {
        let directory = URL(fileURLWithPath: "/tmp/shots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(prefix)-\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }
}
