import XCTest

/// Flow's Insights section end to end on a store with no transactions:
/// three expenses each added twice today give three "Possible duplicate
/// transaction" cards (ids sorted: A, B, C). The first is snoozed and the
/// next dismissed from the "Insight options" menu; both stay hidden after a
/// relaunch while the third still shows. The rows are deleted at the end.
///
/// The snooze and the dismissal stay in the app's preferences (there is no
/// way to undo either in the app). The descriptions carry a per-run suffix,
/// so each run's card ids are new and a second run on the same simulator,
/// even the same day, is not hidden by the first one's.
@MainActor
final class InsightsUITests: XCTestCase {
    let app = XCUIApplication()

    /// Digits: the keyboard never autocorrects them.
    private let run = String(Int.random(in: 100_000...999_999))
    private var descriptions: [String] { ["A", "B", "C"].map { "Insight UI \($0) \(run)" } }

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "1"
        app.launch()
    }

    private func tab(_ name: String) {
        app.tabBars.buttons[name].tap()
    }

    private func type(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    /// The duplicate card whose explanation names `description`.
    private func card(_ description: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == 'flow.insight.card' AND label CONTAINS %@", "\(description) appears more than once")).firstMatch
    }

    private var cards: XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "flow.insight.card")
    }

    private func addExpense(_ description: String) {
        app.buttons["Add transaction"].tap()
        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        type("7", into: amount)
        type(description, into: app.textFields["Description"])
        // Return first: with the keyboard up, the tap on Add was sometimes
        // lost on a busy machine (the form stayed open, nothing saved).
        app.textFields["Description"].typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "keyboard dismissed")
        app.buttons["Add"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 10), "form closed")
    }

    /// Opens the menu of the card at `index` and picks `item`.
    private func pick(_ item: String, onCardAt index: Int) {
        let menu = app.buttons.matching(identifier: "flow.insight.menu").element(boundBy: index)
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let button = app.buttons[item]
        XCTAssertTrue(button.waitForExistence(timeout: 5), item)
        button.tap()
    }

    func testSnoozeAndDismissPersist() throws {
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20))
        tab("Flow")
        XCTAssertFalse(app.descendants(matching: .any)["flow.insights"].waitForExistence(timeout: 2), "no cards on an empty store")

        tab("Home")
        for description in descriptions {
            addExpense(description)
            addExpense(description)
        }

        tab("Flow")
        XCTAssertTrue(app.descendants(matching: .any)["flow.insights"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Insights"].exists)
        XCTAssertTrue(app.staticTexts["Calculated privately on this device \u{B7} Not financial advice"].exists)
        for description in descriptions {
            XCTAssertTrue(card(description).waitForExistence(timeout: 5), description)
        }
        XCTAssertEqual(cards.count, 3)

        // Snooze A (the first card), then dismiss B (first after A went).
        pick("Snooze for 30 days", onCardAt: 0)
        XCTAssertTrue(card(descriptions[0]).waitForNonExistence(timeout: 5), "snoozed card gone")
        pick("Dismiss", onCardAt: 0)
        XCTAssertTrue(card(descriptions[1]).waitForNonExistence(timeout: 5), "dismissed card gone")
        XCTAssertTrue(card(descriptions[2]).exists)
        XCTAssertEqual(cards.count, 1)

        // Both stay hidden after a relaunch.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Flow"].waitForExistence(timeout: 20))
        tab("Flow")
        XCTAssertTrue(card(descriptions[2]).waitForExistence(timeout: 10))
        XCTAssertFalse(card(descriptions[0]).exists)
        XCTAssertFalse(card(descriptions[1]).exists)
        XCTAssertEqual(cards.count, 1)

        // Clean up: delete the six rows from Home's SEE ALL list.
        let thisRun = NSPredicate(format: "label CONTAINS 'Insight UI' AND label CONTAINS %@", run)
        tab("Home")
        app.buttons["See all transactions"].firstMatch.tap()
        for _ in 0..<6 {
            let row = app.buttons.containing(thisRun).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.swipeLeft()
            let confirm = app.alerts["Delete Transaction"].buttons["Delete"]
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            confirm.tap()
            XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        }
        XCTAssertFalse(app.buttons.containing(thisRun).firstMatch.waitForExistence(timeout: 2))
        tab("Flow")
        XCTAssertFalse(app.descendants(matching: .any)["flow.insights"].waitForExistence(timeout: 2), "no cards once the rows are gone")
    }
}
