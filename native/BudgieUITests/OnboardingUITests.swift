import XCTest

/// The first-launch tour. Each test forces a first launch with
/// `BUDGIE_SKIP_ONBOARDING=0` (removes the flag an earlier test may have
/// set), whatever ran before on the simulator.
@MainActor
final class OnboardingUITests: XCTestCase {
    let app = XCUIApplication()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "0"
        app.launch()
        XCTAssertTrue(title("Your money, made clearer.").waitForExistence(timeout: 20), "tour not shown on a first launch")
    }

    private func title(_ text: String) -> XCUIElement { app.staticTexts[text] }
    private var next: XCUIElement { app.buttons["onboarding.next"] }
    private var skip: XCUIElement { app.buttons["onboarding.skip"] }
    private var dots: XCUIElement { app.descendants(matching: .any)["onboarding.dots"] }
    private var home: XCUIElement { app.tabBars.buttons["Home"] }

    private func expectPage(_ number: Int, _ pageTitle: String, button: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(title(pageTitle).waitForExistence(timeout: 5), "page \(number) not shown", file: file, line: line)
        XCTAssertEqual(next.label, button, file: file, line: line)
        XCTAssertEqual(dots.value as? String, "\(number) of 3", file: file, line: line)
    }

    func testContinueThroughTheTourThenNeverAgain() throws {
        XCTAssertFalse(home.exists, "the tabs show under the tour")
        XCTAssertTrue(app.staticTexts["WELCOME TO BUDGIE"].exists)
        XCTAssertTrue(skip.isHittable)
        XCTAssertGreaterThanOrEqual(next.frame.height, 48)
        expectPage(1, "Your money, made clearer.", button: "Continue")

        next.tap()
        expectPage(2, "Track what comes and goes.", button: "Continue")
        XCTAssertTrue(app.staticTexts["START HERE"].exists)

        next.tap()
        expectPage(3, "Plan ahead, then look back.", button: "Start budgeting")
        XCTAssertTrue(app.staticTexts["EXPLORE WHEN READY"].exists)
        // Longer than a subscript query allows (128 characters).
        let pageThreeBody = "Worth tracks accounts, Goals keeps savings in view, and Spend, Flow, and Settings (behind the gear on Home) help you understand and manage your budget."
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", pageThreeBody)).firstMatch.exists)

        next.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 10), "Start budgeting did not open the tabs")
        XCTAssertFalse(title("Plan ahead, then look back.").exists)

        // The flag persisted: a normal launch goes straight to the tabs.
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "BUDGIE_SKIP_ONBOARDING")
        app.launch()
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        XCTAssertFalse(title("Your money, made clearer.").exists, "tour shown again after completing it")
    }

    func testSkipOpensTheTabs() {
        skip.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 10), "Skip did not open the tabs")
        XCTAssertFalse(title("Your money, made clearer.").exists)
    }

    func testSwipeBetweenPages() {
        let pager = title("Your money, made clearer.")
        pager.swipeLeft()
        expectPage(2, "Track what comes and goes.", button: "Continue")
        title("Track what comes and goes.").swipeLeft()
        expectPage(3, "Plan ahead, then look back.", button: "Start budgeting")
        title("Plan ahead, then look back.").swipeRight()
        expectPage(2, "Track what comes and goes.", button: "Continue")
    }

    /// A link arriving during the tour waits behind it, then opens the form
    /// over Home once the tour is done.
    func testDeepLinkWaitsForTheTour() {
        XCUIDevice.shared.system.open(URL(string: "budgetapp://add-expense")!)
        let open = springboard.buttons["Open"]
        if open.waitForExistence(timeout: 3) { open.tap() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(title("Your money, made clearer.").waitForExistence(timeout: 5), "tour gone after the link")
        XCTAssertFalse(title("Add Expense").waitForExistence(timeout: 3), "form opened over the tour")

        next.tap()
        next.tap()
        next.tap()
        XCTAssertTrue(title("Add Expense").waitForExistence(timeout: 10), "queued link did not open after the tour")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 5))
    }
}
