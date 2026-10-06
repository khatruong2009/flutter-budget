import XCTest
@MainActor
final class AppStoreCaptureUITests: XCTestCase {
    func testCaptureMarketingScreens() throws {
        let app = XCUIApplication()
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "1"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 30))
        func capture(_ name: String) {
            let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            image.name = name
            image.lifetime = .keepAlways
            add(image)
        }
        capture("01-home-dark")
        for (name, file) in [("Spend", "02-spending-dark"), ("Goals", "03-goals-dark"), ("Worth", "04-worth-dark"), ("Flow", "05-flow-dark")] {
            app.tabBars.buttons[name].tap()
            XCTAssertTrue(app.tabBars.buttons[name].isSelected)
            if name == "Flow" { app.swipeUp() }
            capture(file)
        }
        app.tabBars.buttons["Home"].tap()
        app.buttons["home.settings"].tap()
        app.buttons["Light"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Light"].firstMatch.isSelected)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
        capture("06-home-light")
        app.buttons["home.settings"].tap()
        app.buttons["Dark"].firstMatch.tap()
        app.buttons["Recurring transactions"].firstMatch.tap()
        capture("07-recurring-dark")
    }
}
