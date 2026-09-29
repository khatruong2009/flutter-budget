import XCTest

/// The Spend and Flow tabs end to end on a fresh install: one expense added
/// from Home shows up in the Spend donut and drill-in and in Flow's bars,
/// then is found and deleted from Flow's filterable list.
@MainActor
final class TabsUITests: XCTestCase {
    let app = XCUIApplication()

    private static let description = "UI tabs coffee"

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "1"
        app.launch()
    }

    private func tab(_ name: String) {
        app.tabBars.buttons[name].tap()
    }

    /// Any element with the identifier (bars and rows are custom elements).
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func type(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    /// The current month as the app keys its bars ("2026-09").
    private var currentMonthKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    func testSpendAndFlow() throws {
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20))

        // Add an expense from the Home FAB.
        app.buttons["Add transaction"].tap()
        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        type("12.34", into: amount)
        type(Self.description, into: app.textFields["Description"])
        app.buttons["Add"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", Self.description)).firstMatch
                .waitForExistence(timeout: 5))

        // Spend: the donut and the one category row, its drill-in and back.
        tab("Spend")
        XCTAssertTrue(element("spend.donut").waitForExistence(timeout: 5))
        let row = app.buttons["spend.row.0"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(element("spend.drillIn.summary").waitForExistence(timeout: 5))
        XCTAssertTrue(element("spend.drillIn.row").exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("spend.donut").waitForExistence(timeout: 5))

        // Flow: the net cash flow card with this month's bar.
        tab("Flow")
        XCTAssertTrue(element("flow.netCashFlow").waitForExistence(timeout: 5))
        XCTAssertTrue(element("flow.bar.\(currentMonthKey)").exists, "bar for \(currentMonthKey)")

        // The range sheet: pick 12 months.
        let rangePill = app.buttons["flow.rangePill"]
        rangePill.tap()
        let twelve = app.buttons["flow.range.12"]
        XCTAssertTrue(twelve.waitForExistence(timeout: 5))
        twelve.tap()
        XCTAssertTrue(twelve.waitForNonExistence(timeout: 5))
        XCTAssertEqual(rangePill.value as? String, "12 months")

        // SEE ALL: search filters the rows.
        let seeAll = app.buttons["See all transactions"].firstMatch
        if !seeAll.isHittable { app.swipeUp() }
        seeAll.tap()
        let search = app.textFields["flow.all.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        let rows = app.buttons.matching(identifier: "flow.all.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        type("zzz", into: search)
        XCTAssertTrue(element("flow.all.empty").waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 0)
        app.buttons["Clear search"].tap()
        search.tap()
        search.typeText("tabs coffee")
        let match = rows.firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(match.label.contains(Self.description))

        // Swipe to delete, confirmed in the alert.
        match.swipeLeft()
        let alert = app.alerts["Delete Transaction"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Delete"].tap()
        XCTAssertTrue(element("flow.all.empty").waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 0)
    }
}
