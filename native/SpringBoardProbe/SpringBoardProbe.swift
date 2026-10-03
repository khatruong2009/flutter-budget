import XCTest

/// Drives SpringBoard only (no app under test, so nothing is installed):
/// used to look at the home screen while the Flutter build is installed.
@MainActor
final class SpringBoardProbe: XCTestCase {
    func testWidgetPage() throws {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        XCUIDevice.shared.press(.home)
        sleep(2)
        // SystemIntegrationUITests placed the widget on the second page (the
        // first free slot on a fresh simulator); after reinstalls the icon's
        // hittability is unreliable, so go to that page directly.
        springboard.swipeLeft()
        sleep(3)
        let page = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        page.name = "widget page"
        page.lifetime = .keepAlways
        add(page)
        // The small widget sits in the page's top-left slot; tap its
        // Expense link and show what opened.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.26, dy: 0.24)).tap()
        sleep(8)
        let opened = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        opened.name = "after tapping Expense"
        opened.lifetime = .keepAlways
        add(opened)
    }
}
