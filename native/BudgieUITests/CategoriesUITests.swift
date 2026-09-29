import XCTest

/// Settings > Categories end to end: add a category and pick it in the
/// transaction form's wheel, the editor's inline errors, move up / down,
/// archive and restore behind "Show archived", then a rename that reaches
/// an existing transaction's row on Home; and the last active category of
/// a type refusing to be archived. Names carry a per-run suffix so a rerun
/// without an erase starts clean.
@MainActor
final class CategoriesUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "1"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20))
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func labelled(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    /// Taps once the element exists, is hittable and has stopped moving
    /// (the keyboard and the dialog's entrance shift it).
    private func tapStable(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element) exists", file: file, line: line)
        let deadline = Date().addingTimeInterval(10)
        var last = CGRect.null
        while Date() < deadline {
            let frame = element.frame
            if element.isHittable && frame == last { break }
            last = frame
            Thread.sleep(forTimeInterval: 0.3)
        }
        element.tap()
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        tapStable(field)
        if let value = field.value as? String, !value.isEmpty, value != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText(text)
    }

    /// Home's root page (popping anything pushed on the Home tab).
    private func homeRoot() {
        app.tabBars.buttons["Home"].tap()
        var pops = 0
        while !app.buttons["home.settings"].waitForExistence(timeout: 1) && pops < 4 {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            pops += 1
        }
    }

    private func openCategories() {
        homeRoot()
        tapStable(app.buttons["home.settings"])
        tapStable(app.buttons["settings.categories"])
        XCTAssertTrue(element("categories.list").waitForExistence(timeout: 10))
    }

    /// Scrolls the list until the row is on screen.
    private func reveal(_ row: XCUIElement) {
        let list = element("categories.list")
        for _ in 0..<10 {
            if row.exists && row.isHittable { return }
            list.swipeUp()
        }
        XCTAssertTrue(row.isHittable, "\(row) on screen")
    }

    private func value(of element: XCUIElement) -> String { element.value as? String ?? "" }

    /// Polls `condition` until it holds or `timeout` passes.
    private func waitUntil(_ timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }

    private func menu(_ id: String) -> XCUIElement { app.buttons["categories.row.menu.\(id)"] }
    private func row(_ id: String) -> XCUIElement { element("categories.row.\(id)") }

    /// Opens the row's menu and picks `item`.
    private func choose(_ item: String, forRow id: String) {
        reveal(menu(id))
        tapStable(menu(id))
        tapStable(app.buttons[item].firstMatch)
    }

    // MARK: - Tests

    func testAddMoveArchiveRenameAndCascade() throws {
        let suffix = String(Int.random(in: 1000...9999))
        let name = "UI Coffee \(suffix)"
        let renamed = "UI Brew \(suffix)"
        let id = "expense-ui-coffee-\(suffix)"
        let description = "UI latte \(suffix)"

        openCategories()

        // Add: the name, an icon and a colour; it lands last, no subtitle.
        tapStable(app.buttons["categories.add"])
        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        tapStable(app.buttons["categories.editor.icon.cart"])
        XCTAssertTrue(app.buttons["categories.editor.icon.cart"].isSelected)
        tapStable(app.buttons["categories.editor.color.green"])
        XCTAssertTrue(app.buttons["categories.editor.color.green"].isSelected)
        tapStable(app.buttons["categories.editor.submit"])
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "editor closed")
        reveal(row(id))
        XCTAssertEqual(row(id).label, name)
        XCTAssertEqual(value(of: row(id)), "")

        // Inline errors: a duplicate (any case) and an empty name keep the
        // editor open with Flutter's copy.
        tapStable(app.buttons["categories.add"])
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name.lowercased())
        tapStable(app.buttons["categories.editor.submit"])
        XCTAssertTrue(labelled("A category with this name already exists").waitForExistence(timeout: 5))
        XCTAssertTrue(field.exists, "editor still open")
        replaceText(in: field, with: "")
        XCTAssertTrue(labelled("Enter a category name").waitForExistence(timeout: 5), "the error follows the text")
        tapStable(app.buttons["categories.editor.submit"])
        XCTAssertTrue(labelled("Enter a category name").exists)
        tapStable(app.buttons["categories.editor.cancel"])
        XCTAssertTrue(field.waitForNonExistence(timeout: 10))

        // Move up past Loan Payment, then back down.
        let loan = row("expense-loan-payment")
        reveal(row(id))
        XCTAssertGreaterThan(row(id).frame.minY, loan.frame.minY)
        choose("Move up", forRow: id)
        XCTAssertTrue(waitUntil { self.row(id).frame.minY < loan.frame.minY }, "moved up")
        choose("Move down", forRow: id)
        XCTAssertTrue(waitUntil { self.row(id).frame.minY > loan.frame.minY }, "moved down")

        // Archive hides it; Show archived shows it with only Edit / Restore.
        choose("Archive", forRow: id)
        XCTAssertTrue(row(id).waitForNonExistence(timeout: 5), "archived row hidden")
        let showArchived = app.switches["categories.showArchived"]
        tapStable(showArchived)
        reveal(row(id))
        XCTAssertEqual(value(of: row(id)), "Archived")
        tapStable(menu(id))
        XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Edit"].exists)
        XCTAssertFalse(app.buttons["Move up"].exists)
        XCTAssertFalse(app.buttons["Move down"].exists)
        tapStable(app.buttons["Restore"])
        XCTAssertTrue(waitUntil { self.value(of: self.row(id)) == "" }, "restored")
        tapStable(showArchived)

        // The transaction form's wheel offers it; add an expense with it.
        homeRoot()
        tapStable(app.buttons["Add transaction"])
        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.typeText("4.5")
        tapStable(app.textFields["Description"])
        app.textFields["Description"].typeText(description)
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        wheel.adjust(toPickerWheelValue: name)
        tapStable(app.buttons["Add"])
        let transaction = labelled(description)
        XCTAssertTrue(transaction.waitForExistence(timeout: 10))
        XCTAssertTrue(value(of: transaction).contains(name), "row shows \(name)")

        // Rename it: the transaction's row follows (one commit, ledger rebuilt).
        openCategories()
        choose("Edit", forRow: id)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, name)
        replaceText(in: field, with: renamed)
        let save = app.buttons["categories.editor.submit"]
        XCTAssertEqual(save.label, "Save")
        tapStable(save)
        XCTAssertTrue(field.waitForNonExistence(timeout: 10))
        reveal(row(id))
        XCTAssertEqual(row(id).label, renamed)
        homeRoot()
        XCTAssertTrue(transaction.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(10) { self.value(of: transaction).contains(renamed) }, "the transaction shows the new name")
    }

    func testLastActiveCategoryCannotBeArchived() throws {
        openCategories()
        let income = element("categories.type").buttons["Income"]
        tapStable(income)
        XCTAssertTrue(row("income-salary").waitForExistence(timeout: 5))

        let others = ["income-salary", "income-investment", "income-gift"]
        for id in others {
            choose("Archive", forRow: id)
            XCTAssertTrue(row(id).waitForNonExistence(timeout: 5), "\(id) archived")
        }
        choose("Archive", forRow: "income-other")
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "At least one category must remain active")).firstMatch
                .waitForExistence(timeout: 5))
        XCTAssertTrue(row("income-other").exists, "still active")

        // Restore the others (keeps a rerun's starting state).
        tapStable(app.switches["categories.showArchived"])
        for id in others {
            choose("Restore", forRow: id)
            XCTAssertTrue(waitUntil { self.value(of: self.row(id)) == "Built in" }, "\(id) restored")
        }
    }
}
