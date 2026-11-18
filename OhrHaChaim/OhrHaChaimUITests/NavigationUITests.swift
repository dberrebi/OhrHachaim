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

    /// Close the app before the next UI test launches it (see StoreScreenshotUITests).
    override func tearDownWithError() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 30)
        }
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
        app.launchArguments = [
            // Pre-fills the search screen; the simulator keyboard cannot type Hebrew.
            "-search-query", "אורה",
            // Lengthens the app's 20-second rule for an unscrolled screen, so the
            // brief looks in the Resume check stay brief on a slow simulator.
            "-reading-opening-delay", String(Int(Self.openingDelay)),
        ]
    }

    /// Close the app before the next test launches it (see StoreScreenshotUITests).
    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 30)
        }
    }

    /// How long the app waits before an unscrolled screen counts as read, in this test.
    private static let openingDelay: TimeInterval = 120

    /// The main screens at the largest accessibility text size, for checking that
    /// nothing is cut off or overlaps. It saves screenshots ("xl-…") and checks only
    /// that each screen opens. Runs after testWalkthrough (alphabetical order).
    func testWalkthroughLargestText() throws {
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        XCTAssertTrue(element("home.resume").waitForExistence(timeout: 90))
        pause(5)
        shot("xl-home")
        app.swipeUp()
        pause(1)
        shot("xl-home-scrolled")

        goHome()
        tap("home.book.1")
        wait(for: "parasha.2")
        shot("xl-genesis-parshiyot")
        tap("parasha.1")
        let star = app.buttons["שמירה במועדפים"].firstMatch
        XCTAssertTrue(star.waitForExistence(timeout: Self.patience * 2), "Bereshit did not open")
        pause(2)
        shot("xl-bereshit")

        goHome()
        tap("home.search")
        pause(2)
        shot("xl-search")

        goHome()
        tap("home.settings")
        pause(1)
        shot("xl-settings")
        app.swipeUp()
        pause(1)
        shot("xl-settings-scrolled")
    }

    func testWalkthrough() throws {
        app.launch()
        // Hosted CI Macs can be slow: launching has taken over 40 seconds.
        XCTAssertTrue(element("home.resume").waitForExistence(timeout: 90))
        // A freshly booted simulator can still be too busy to accept a tap: the first
        // tap once failed with "Timed out while synthesizing event".
        pause(5)
        shot("home")

        // Genesis, then Bereshit: read a little and save a passage.
        tap("home.book.1")
        wait(for: "parasha.2")
        shot("genesis-parshiyot")
        tap("parasha.1")
        let star = app.buttons["שמירה במועדפים"].firstMatch
        // Laying out a whole parasha can keep a slow simulator busy for a while.
        XCTAssertTrue(star.waitForExistence(timeout: Self.patience * 2), "Bereshit did not open")
        pause(2)
        shot("bereshit-top")
        app.swipeUp()
        pause(1)
        shot("bereshit-scrolled")
        if star.waitForExistence(timeout: Self.patience) {
            star.tap()
            pause(1)
            shot("bereshit-passage-saved")
        }
        pause(6) // A passage counts as read after it stays at the top for 4 seconds.

        // Each look is timed from the tap that opens the screen to the tap on Back,
        // which is how long the app sees it on screen. Returning home is not counted.
        goBack()
        let glanceStart = Date()
        tap("parasha.intro")
        pause(2)
        shot("authors-introduction")
        goBack()
        let introGlance = Date().timeIntervalSince(glanceStart)
        goHome()

        shot("home-after-reading")
        let weeklyStart = Date()
        tap("home.weekly")
        pause(2)
        shot("this-week")
        goBack()
        let weeklyGlance = Date().timeIntervalSince(weeklyStart)
        goHome()

        // A short look at the introduction and at This week is not a read:
        // Resume must still point to Bereshit. Its subtitle reads
        // "בראשית · פרק … · פסוק …"; the book row is plain "בראשית".
        // The test launches the app with a 120-second rule for an unscrolled screen
        // (20 seconds in normal use), so the check applies even on a slow simulator.
        // Each measured look includes the tap and the second after Back, so it is
        // longer than the time on screen. Only a look that comes near the rule
        // skips the check, and then it is reported, not failed.
        let limit = Self.openingDelay - 10
        if introGlance < limit && weeklyGlance < limit {
            let savedPlace = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "בראשית ·"))
                .firstMatch
            XCTAssertTrue(savedPlace.waitForExistence(timeout: Self.patience), "Resume moved without a real read")
        } else {
            XCTContext.runActivity(named: String(
                format: "Resume check not applied: the looks took %.0f s and %.0f s",
                introGlance, weeklyGlance
            )) { _ in }
        }
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
        tap("home.search")
        let hits = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "search.hit."))
        if hits.firstMatch.waitForExistence(timeout: Self.patience) {
            shot("search")
            openDeepSearchResult(in: hits)
            shot("search-result-opened")
        } else {
            XCTFail("No search results for the pre-filled query")
            shot("search")
        }

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

    /// How long to wait for a screen or a row. Hosted CI Macs are sometimes slow
    /// enough that a single accessibility query takes many seconds.
    private static let patience: TimeInterval = 30

    /// Opens the search result for Emor 22:12, deep inside a long parasha, and
    /// checks that its passage is on screen near the top. The reader builds rows
    /// lazily and estimates the heights of rows it has not built, so a jump this
    /// far is where it could land short.
    private func openDeepSearchResult(in hits: XCUIElementQuery) {
        let phrase = "יפחת אורה" // From the Emor 22:12 passage that the query "אורה" finds.
        let deepHit = hits.matching(NSPredicate(format: "label CONTAINS %@", phrase)).firstMatch
        for _ in 0..<3 where !(deepHit.exists && deepHit.isHittable) {
            app.swipeUp()
            pause(0.5)
        }
        guard deepHit.exists && deepHit.isHittable else {
            XCTFail("No search result for Emor 22:12 (\(phrase))")
            hits.firstMatch.tap()
            pause(2)
            return
        }
        deepHit.tap()
        _ = deepHit.waitForNonExistence(timeout: Self.patience)
        let passage = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", phrase))
            .firstMatch
        guard passage.waitForExistence(timeout: Self.patience * 2) else {
            XCTFail("Opening the Emor 22:12 result did not show its passage")
            return
        }
        pause(2) // Let the reader's second scroll settle.
        let screenHeight = app.windows.firstMatch.frame.height
        let top = passage.frame.minY
        XCTAssertTrue(passage.isHittable, "The Emor 22:12 passage is not on screen")
        XCTAssertTrue(
            top >= 0 && top < screenHeight * 0.5,
            String(format: "The Emor 22:12 passage starts at %.0f of %.0f points, not near the top", top, screenHeight)
        )
    }

    private func wait(for identifier: String) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: Self.patience), "Missing \(identifier)")
    }

    /// Taps a row that opens another screen, scrolling down and then up to reach
    /// it (lists only build the rows that are on screen). The tap counts once the
    /// row has left the screen; a tap that a busy simulator dropped is retried once.
    private func tap(_ identifier: String) {
        let target = element(identifier)
        _ = target.waitForExistence(timeout: Self.patience)
        for attempt in 0..<10 {
            if target.exists && target.isHittable {
                target.tap()
                if target.waitForNonExistence(timeout: Self.patience) { return }
                if target.exists && target.isHittable {
                    target.tap()
                    if target.waitForNonExistence(timeout: Self.patience) { return }
                }
                XCTFail("Tapping \(identifier) did not open its screen")
                return
            }
            if attempt < 4 {
                app.swipeUp()
            } else {
                app.swipeDown()
            }
            pause(0.5)
        }
        XCTFail("Missing \(identifier)")
    }

    private func tapButton(_ label: String) {
        let button = app.buttons[label].firstMatch
        guard button.waitForExistence(timeout: Self.patience) else {
            XCTFail("Missing button \(label)")
            return
        }
        button.tap()
    }

    /// Home is the root of the stack: it has no back button, and its rows exist.
    private var isHome: Bool {
        guard !app.navigationBars.buttons["BackButton"].exists else { return false }
        return ["home.resume", "home.search", "home.settings", "home.about"]
            .contains { element($0).exists }
    }

    private func goBack() {
        let buttons = app.navigationBars.buttons
        let back = buttons["BackButton"]
        if back.exists {
            back.tap()
        } else {
            // Fallback: the first bar button that is not Share.
            for index in 0..<buttons.count {
                let button = buttons.element(boundBy: index)
                if ["שיתוף", "Share"].contains(button.label) { continue }
                button.tap()
                break
            }
        }
        pause(1)
    }

    /// Polls a condition, so a slow simulator gets time to finish a transition.
    private func eventually(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            pause(0.5)
        } while Date() < end
        return false
    }

    private func goHome() {
        for _ in 0..<4 {
            if eventually(3, { isHome }) { break }
            goBack()
        }
        XCTAssertTrue(eventually(Self.patience, { isHome }), "Could not return to the home screen")
        // Back to the top of the list, so home screenshots start at Resume.
        for _ in 0..<3 where !(element("home.resume").exists && element("home.resume").isHittable) {
            app.swipeDown()
            pause(0.5)
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
