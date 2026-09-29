import XCTest

/// End-to-end MVP flow on a fresh install (native/scripts/ui_flow.sh seeds
/// nothing, runs this, then checks the resulting store with the Flutter
/// models).
@MainActor
final class MVPFlowUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "1"
        app.launch()
    }

    private func tab(_ name: String) {
        app.tabBars.buttons[name].tap()
    }

    /// Home's root page (popping anything pushed on the Home tab).
    private func homeRoot() {
        tab("Home")
        var pops = 0
        while !app.buttons["home.settings"].waitForExistence(timeout: 1) && pops < 4 {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            pops += 1
        }
    }

    /// Settings is pushed from the gear in the Home header.
    private func openSettings() {
        homeRoot()
        app.buttons["home.settings"].tap()
    }

    /// Any element whose label contains `text` (Home rows are combined
    /// accessibility elements, not buttons).
    private func labelled(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func type(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    func testCoreFlow() throws {
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20))
        for name in ["Worth", "Goals", "Spend", "Flow"] {
            XCTAssertTrue(app.tabBars.buttons[name].exists, "\(name) tab")
        }

        // Add an expense (the FAB opens the expense form).
        app.buttons["Add transaction"].tap()
        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        type("12.34", into: amount)
        type("UI test coffee", into: app.textFields["Description"])
        app.buttons["Add"].tap()
        // Home's Recent activity shows it.
        XCTAssertTrue(labelled("UI test coffee").waitForExistence(timeout: 5))

        // Edit it from the full list (SEE ALL).
        app.buttons["See all transactions"].firstMatch.tap()
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS 'UI test coffee'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let editAmount = app.textFields["Amount"]
        XCTAssertTrue(editAmount.waitForExistence(timeout: 5))
        editAmount.tap()
        editAmount.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        editAmount.typeText("20")
        app.buttons["Update"].tap()
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS '20.00'")).firstMatch.waitForExistence(timeout: 5))

        // Add a recurring template and pause it (Settings > Recurring).
        openSettings()
        app.buttons["Recurring transactions"].firstMatch.tap()
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

        // Net worth is empty on a fresh install.
        tab("Worth")
        XCTAssertTrue(app.staticTexts["No net worth accounts yet"].waitForExistence(timeout: 5))

        // Theme.
        openSettings()
        app.buttons["Theme, System"].firstMatch.tap()
        app.buttons["Dark"].firstMatch.tap()

        // Add an income from the Home pill, then delete it from SEE ALL.
        homeRoot()
        app.buttons["Income"].firstMatch.tap()
        type("5", into: app.textFields["Amount"])
        type("To delete", into: app.textFields["Description"])
        app.buttons["Add"].tap()
        app.buttons["See all transactions"].firstMatch.tap()
        let doomed = app.buttons.containing(NSPredicate(format: "label CONTAINS 'To delete'")).firstMatch
        XCTAssertTrue(doomed.waitForExistence(timeout: 5))
        doomed.swipeLeft()
        let confirm = app.alerts["Delete Transaction"].buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(doomed.waitForNonExistence(timeout: 5))
    }
}
