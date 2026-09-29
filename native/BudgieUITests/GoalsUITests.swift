import XCTest

/// The Goals tab end to end on a fresh install: the empty state, adding a
/// goal, finishing it with Add money's "Finish goal" (the celebration
/// plays), renaming it from the actions sheet and deleting it again.
@MainActor
final class GoalsUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "1"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Goals"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Goals"].tap()
    }

    /// Any element with the identifier (cards and overlays are custom).
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func type(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    private func replace(_ field: XCUIElement, with text: String) {
        field.tap()
        if let value = field.value as? String, !value.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText(text)
    }

    private func text(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    func testGoalLifecycle() throws {
        XCTAssertTrue(element("goals.empty").waitForExistence(timeout: 10))

        // Add a goal from the add button.
        app.buttons["goals.fab"].tap()
        let name = app.textFields["Goal name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        type("UI Trip", into: name)
        type("100", into: app.textFields["Target amount"])
        app.buttons["goals.form.submit"].tap()
        XCTAssertTrue(text("Savings goal added").waitForExistence(timeout: 5))
        let addMoney = app.buttons["goals.card.addMoney"]
        XCTAssertTrue(addMoney.waitForExistence(timeout: 5))

        // Add money: "Finish goal" fills the remainder; the goal completes.
        addMoney.tap()
        let finish = app.buttons["goals.allocate.chip.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        app.buttons["goals.allocate.submit"].tap()
        XCTAssertTrue(element("goals.celebration").waitForExistence(timeout: 2))
        XCTAssertTrue(addMoney.waitForNonExistence(timeout: 5), "a complete goal has no Add money")

        // Rename it from the actions sheet.
        let more = app.buttons["goals.card.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let edit = app.buttons["goals.actions.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replace(name, with: "UI Trip Renamed")
        let update = app.buttons["goals.form.submit"]
        XCTAssertEqual(update.label, "Update")
        update.tap()
        XCTAssertTrue(text("Savings goal updated").waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "UI Trip Renamed")).firstMatch
                .waitForExistence(timeout: 5))

        // Delete it from the actions sheet.
        more.tap()
        let delete = app.buttons["goals.actions.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let confirm = app.buttons["goals.delete.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(element("goals.empty").waitForExistence(timeout: 5))
    }
}
