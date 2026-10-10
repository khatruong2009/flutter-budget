import XCTest

@MainActor
final class CustomPageCaptureUITests: XCTestCase {
    func testCaptureCustomPage() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let audio = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("marketing-voice.m4a")
        try Data([0, 1, 2, 3]).write(to: audio)
        defer { try? FileManager.default.removeItem(at: audio) }
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["BUDGIE_VOICE_AUDIO_FILE"] = audio.path
        app.launchEnvironment["BUDGIE_VOICE_STUB"] = "{}"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 30))
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        func theme(_ name: String) {
            app.tabBars.buttons["Home"].tap()
            app.buttons["home.settings"].tap()
            app.buttons[name].firstMatch.tap()
            XCTAssertTrue(app.buttons[name].firstMatch.isSelected)
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
        }
        theme("Light")
        capture("01-home")
        app.buttons["home.safeToSpend"].tap()
        XCTAssertTrue(app.staticTexts["Income recorded"].waitForExistence(timeout: 5))
        capture("03-safe-to-spend")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Spend"].tap()
        capture("05-spending")
        app.tabBars.buttons["Flow"].tap()
        app.swipeUp()
        capture("07-insights")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 10))
        theme("Dark")
        capture("08-private")
        app.buttons["home.voice"].tap()
        XCTAssertTrue(app.staticTexts["LISTENING"].waitForExistence(timeout: 10))
        capture("02-voice")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Worth"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Worth"].tap()
        capture("04-net-worth")
        app.tabBars.buttons["Goals"].tap()
        capture("06-goals")
    }
}
