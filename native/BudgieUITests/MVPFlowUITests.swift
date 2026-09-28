import XCTest

/// End-to-end MVP flow on a fresh install (native/scripts/ui_flow.sh seeds
/// nothing, runs this, then checks the resulting store with the Flutter
/// models).
@MainActor
final class MVPFlowUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.launch()
    }

    private func tab(_ name: String) {
        app.tabBars.buttons[name].tap()
    }

    private func type(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    func testCoreFlow() throws {
        XCTAssertTrue(app.tabBars.buttons["Spending"].waitForExistence(timeout: 20))

        // Add an expense.
        app.buttons["Add transaction"].tap()
        app.buttons["Add Expense"].tap()
        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        type("12.34", into: amount)
        type("UI test coffee", into: app.textFields["Description"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["UI test coffee"].waitForExistence(timeout: 5))

        // Edit it from History.
        tab("History")
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS 'UI test coffee'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let editAmount = app.textFields["Amount"]
        XCTAssertTrue(editAmount.waitForExistence(timeout: 5))
        editAmount.tap()
        editAmount.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        editAmount.typeText("20")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS '20.00'")).firstMatch.waitForExistence(timeout: 5))

        // Add a recurring template and pause it.
        tab("Recurring")
        app.buttons["Add recurring transaction"].tap()
        let description = app.textFields["Description (required)"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        type("UI rent", into: description)
        type("900", into: app.textFields["Amount"])
        app.buttons["Save"].tap()
        let template = app.buttons.containing(NSPredicate(format: "label CONTAINS 'UI rent'")).firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.swipeLeft()
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'paused'")).firstMatch.waitForExistence(timeout: 5))

        // Net worth is read-only and empty on a fresh install.
        tab("Net Worth")
        XCTAssertTrue(app.staticTexts["No accounts yet"].waitForExistence(timeout: 5))

        // Theme.
        tab("Settings")
        app.buttons["Theme, System"].firstMatch.tap()
        app.buttons["Dark"].firstMatch.tap()

        // Delete a second transaction from Spending.
        tab("Spending")
        app.buttons["Add transaction"].tap()
        app.buttons["Add Income"].tap()
        type("5", into: app.textFields["Amount"])
        type("To delete", into: app.textFields["Description"])
        app.buttons["Save"].tap()
        let doomed = app.buttons.containing(NSPredicate(format: "label CONTAINS 'To delete'")).firstMatch
        XCTAssertTrue(doomed.waitForExistence(timeout: 5))
        doomed.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        app.buttons["Delete"].firstMatch.tap()  // confirmation
        XCTAssertTrue(doomed.waitForNonExistence(timeout: 5))
    }
}
