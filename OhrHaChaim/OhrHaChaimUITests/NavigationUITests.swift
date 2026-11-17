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

/// A guided tour of the app for the Walkthrough workflow. It opens each screen,
/// waits for it, and saves a numbered screenshot. It is skipped unless
/// WALKTHROUGH_DIR is set (pass TEST_RUNNER_WALKTHROUGH_DIR to xcodebuild).
final class WalkthroughUITests: XCTestCase {
    private var app: XCUIApplication!
    private var outputDir: URL!
    private var shotNumber = 0

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["WALKTHROUGH_DIR"], !dir.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_WALKTHROUGH_DIR to run the walkthrough.")
        }
        outputDir = URL(fileURLWithPath: dir, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    func testWalkthrough() throws {
        XCTAssertTrue(element("home.resume").waitForExistence(timeout: 20))
        pause(1)
        shot("home")

        // Genesis, then Bereshit: read a little and save a passage.
        tap("home.book.1")
        wait(for: "parasha.2")
        shot("genesis-parshiyot")
        tap("parasha.1")
        pause(2)
        shot("bereshit-top")
        app.swipeUp()
        pause(1)
        shot("bereshit-scrolled")
        let star = app.buttons["שמירה במועדפים"].firstMatch
        if star.waitForExistence(timeout: 5) {
            star.tap()
            pause(1)
            shot("bereshit-passage-saved")
        }
        pause(4) // Let the reading position settle so Resume has a place.

        goBack()
        tap("parasha.intro")
        pause(2)
        shot("authors-introduction")

        goHome()
        shot("home-after-reading")
        tap("home.weekly")
        pause(2)
        shot("this-week")

        goHome()
        tap("home.resume")
        pause(2)
        shot("resume")
        app.swipeUp()
        pause(3) // Long enough for the reading position to move while on Resume.
        shot("resume-scrolled")

        goHome()
        tap("home.history")
        pause(1)
        shot("history")

        goHome()
        tap("home.favourites")
        pause(1)
        shot("favourites")

        goHome()
        tap("home.help")
        pause(1)
        shot("help")

        goHome()
        tap("home.about")
        pause(1)
        shot("about")

        goHome()
        tap("home.settings")
        pause(1)
        shot("settings")
        tapButton("כהה")
        pause(1)
        shot("settings-dark")
        tapButton("English")
        pause(1)
        shot("after-switching-to-english")
        goHome() // Switching the language rebuilds the screens and returns home.
        tap("home.settings")
        pause(1)
        shot("settings-english-dark")

        goHome()
        shot("home-english-dark")
        tap("home.book.2")
        wait(for: "parasha.13")
        shot("exodus-english-dark")
        tap("parasha.13")
        pause(2)
        shot("shemot-english-dark")

        // Long press on a passage, to see which menu appears.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.55)).press(forDuration: 1.5)
        pause(1)
        shot("long-press-on-passage")
    }

    /// The first element with this identifier. A toolbar button such as the
    /// favourites star is exposed twice (its wrapper and the button itself).
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func wait(for identifier: String) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: 10), "Missing \(identifier)")
    }

    private func tap(_ identifier: String) {
        let target = element(identifier)
        guard target.waitForExistence(timeout: 10) else {
            XCTFail("Missing \(identifier)")
            return
        }
        target.tap()
    }

    private func tapButton(_ label: String) {
        let button = app.buttons[label].firstMatch
        guard button.waitForExistence(timeout: 5) else {
            XCTFail("Missing button \(label)")
            return
        }
        button.tap()
    }

    private func goBack() {
        let bar = app.navigationBars.firstMatch
        let back = bar.buttons["BackButton"]
        if back.exists {
            back.tap()
        } else if bar.buttons.count > 0 {
            bar.buttons.element(boundBy: 0).tap()
        }
        pause(1)
    }

    private func goHome() {
        for _ in 0..<4 {
            let home = element("home.resume")
            if home.exists && home.isHittable {
                return
            }
            goBack()
        }
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func shot(_ name: String) {
        shotNumber += 1
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let file = outputDir.appendingPathComponent(String(format: "%02d-%@.png", shotNumber, name))
        do {
            try screenshot.pngRepresentation.write(to: file)
        } catch {
            XCTFail("Could not save \(file.path): \(error)")
        }
    }
}
