import XCTest

/// The Worth tab end to end on a fresh install: the empty state, adding an
/// account, editing its balance from the row, the history page and its
/// editor, and deleting it again from the row's context menu. Also the port
/// of net_worth_page_widget_test.dart "can open and cancel the add account
/// dialog".
@MainActor
final class WorthUITests: XCTestCase {
    let app = XCUIApplication()

    private static let account = "UI Brokerage"

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "1"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Worth"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Worth"].tap()
    }

    /// Any element with the identifier (cards and rows are custom elements).
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func type(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    /// Replaces a field's text (the editor prefills the balance).
    private func replace(_ field: XCUIElement, with text: String) {
        field.tap()
        if let value = field.value as? String, !value.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText(text)
    }

    /// net_worth_page_widget_test.dart:18: the add button opens "Add
    /// account" with "Balance month", and Cancel closes it.
    func testAddAccountDialogOpensAndCancels() throws {
        let add = app.buttons["worth.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(element("worth.editor").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Add account"].exists)
        XCTAssertTrue(app.buttons["worth.editor.month"].exists)
        XCTAssertEqual(app.buttons["worth.editor.month"].label, "Balance month")
        let cancel = app.buttons["worth.editor.cancel"]
        XCTAssertTrue(cancel.exists)
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertFalse(element("worth.editor").exists)
    }

    func testAccountLifecycle() throws {
        // Empty state.
        XCTAssertTrue(app.staticTexts["No net worth accounts yet"].waitForExistence(timeout: 10))

        // Add an account from the empty state.
        app.buttons["worth.empty.add"].tap()
        XCTAssertTrue(element("worth.editor").waitForExistence(timeout: 5))
        type(Self.account, into: app.textFields["Account name"])
        type("1000", into: app.textFields["Asset balance"])
        app.buttons["worth.editor.save"].tap()
        let row = element("worth.account.\(Self.account)")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(element("worth.editor").exists)

        // Tap the row: the editor, prefilled; change the balance and save.
        row.tap()
        XCTAssertTrue(element("worth.editor").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Edit account"].exists)
        let balance = app.textFields["Asset balance"]
        XCTAssertEqual(balance.value as? String, "1,000")
        replace(balance, with: "1250")
        app.buttons["worth.editor.save"].tap()
        XCTAssertTrue(element("worth.editor").waitForNonExistence(timeout: 5))
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("1,250"), row.label)

        // Long-press: View History.
        row.press(forDuration: 1.0)
        let viewHistory = app.buttons["View History"]
        XCTAssertTrue(viewHistory.waitForExistence(timeout: 5))
        viewHistory.tap()
        XCTAssertTrue(element("worth.history.hero").waitForExistence(timeout: 5))

        // The history page's Edit opens the editor; Cancel closes it.
        app.buttons["worth.history.edit"].tap()
        XCTAssertTrue(element("worth.editor").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Edit account"].exists)
        app.buttons["worth.editor.cancel"].tap()
        XCTAssertTrue(element("worth.editor").waitForNonExistence(timeout: 5))

        // Back to Worth.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // Long-press: Delete Account, confirmed.
        row.press(forDuration: 1.0)
        let deleteAction = app.buttons["Delete Account"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 5))
        deleteAction.tap()
        let alert = app.alerts["Delete account?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Delete"].tap()

        // Empty state again.
        XCTAssertTrue(app.staticTexts["No net worth accounts yet"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
    }
}
