import XCTest

/// Settings > Tags & rules end to end: add a tag (and a refused duplicate),
/// add a merchant rule using it, see the rule pick the category and tag in
/// the transaction form, find the saved expense through Flow SEE ALL's tag
/// filter, delete the rule (instant: no more suggestion), then delete the
/// tag through its confirmation (gone from the form and the filter). Names
/// carry a per-run suffix so a rerun without an erase starts clean.
@MainActor
final class TagsRulesUITests: XCTestCase {
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

    /// Polls `condition` until it holds or `timeout` passes.
    private func waitUntil(_ timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
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

    private func openTagsAndRules() {
        homeRoot()
        tapStable(app.buttons["home.settings"])
        tapStable(app.buttons["Tags & rules"])
        XCTAssertTrue(element("tagsRules.list").waitForExistence(timeout: 10))
    }

    /// Scrolls the page until the element is on screen.
    private func reveal(_ target: XCUIElement) {
        let list = element("tagsRules.list")
        for _ in 0..<10 {
            if target.exists && target.isHittable { return }
            list.swipeUp()
        }
        XCTAssertTrue(target.isHittable, "\(target) on screen")
    }

    /// Opens the add-expense form and types an amount and a description.
    private func openExpenseForm(description: String) {
        homeRoot()
        tapStable(app.buttons["Add transaction"])
        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.typeText("12")
        guard !description.isEmpty else { return }
        tapStable(app.textFields["Description"])
        app.textFields["Description"].typeText(description)
    }

    private var wheelValue: String { app.pickerWheels.firstMatch.value as? String ?? "" }

    /// The form's tag chip with this name (a button; the page is not
    /// behind the sheet on another tab).
    private func formChip(_ name: String) -> XCUIElement { app.buttons[name] }

    /// Flow > SEE ALL, with its filters.
    private func openSeeAll() {
        app.tabBars.buttons["Flow"].tap()
        let seeAll = app.buttons["See all transactions"].firstMatch
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10))
        if !seeAll.isHittable { app.swipeUp() }
        tapStable(seeAll)
        XCTAssertTrue(app.textFields["flow.all.search"].waitForExistence(timeout: 5))
    }

    private func leaveSeeAll() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    // MARK: - Test

    func testTagsAndRules() throws {
        let suffix = String(Int.random(in: 1000...9999))
        let tag = "UI Work \(suffix)"
        let merchant = "UIMart \(suffix)"
        let description = "uimart \(suffix) market"

        openTagsAndRules()
        let startedEmpty = element("tags.empty").exists && element("rules.empty").exists

        // Add the tag: its row and delete button appear.
        tapStable(app.buttons["tags.add"])
        let name = app.textFields["Tag name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText(tag)
        tapStable(app.buttons["tags.editor.submit"])
        XCTAssertTrue(name.waitForNonExistence(timeout: 10), "tag dialog closed")
        XCTAssertTrue(labelled(tag).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete \(tag)"].exists)
        XCTAssertFalse(element("tags.empty").exists)

        // A duplicate in another case is refused inline; the dialog stays.
        tapStable(app.buttons["tags.add"])
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText(tag.uppercased())
        tapStable(app.buttons["tags.editor.submit"])
        XCTAssertTrue(labelled("A tag with this name already exists").waitForExistence(timeout: 5))
        XCTAssertTrue(name.exists, "dialog still open")
        tapStable(app.buttons["tags.editor.cancel"])
        XCTAssertTrue(name.waitForNonExistence(timeout: 10))

        // Add a rule: Groceries, with the tag; Add is off until there is text.
        tapStable(app.buttons["rules.add"])
        let pattern = app.textFields["Merchant text"]
        XCTAssertTrue(pattern.waitForExistence(timeout: 5))
        let add = app.buttons["rules.editor.submit"]
        XCTAssertFalse(add.isEnabled, "Add is disabled while the text is empty")
        pattern.typeText(merchant)
        XCTAssertEqual(element("rules.editor.type").value as? String, "Expense")
        XCTAssertEqual(element("rules.editor.match").value as? String, "Contains")
        tapStable(element("rules.editor.category"))
        tapStable(app.buttons["Groceries"].firstMatch)
        XCTAssertTrue(waitUntil { self.element("rules.editor.category").value as? String == "Groceries" })
        let chip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'rules.editor.tag.' AND label == %@", tag)).firstMatch
        tapStable(chip)
        XCTAssertTrue(waitUntil { chip.isSelected }, "tag selected")
        tapStable(add)
        XCTAssertTrue(pattern.waitForNonExistence(timeout: 10), "rule dialog closed")
        let rule = labelled(merchant)
        reveal(rule)
        XCTAssertEqual(rule.value as? String, "contains \u{00B7} Groceries \u{00B7} 1 tags")

        // The form: the description picks Groceries and selects the tag.
        openExpenseForm(description: description)
        XCTAssertTrue(waitUntil { self.wheelValue.contains("Groceries") }, "rule set the category, wheel shows \(wheelValue)")
        XCTAssertTrue(formChip(tag).waitForExistence(timeout: 5))
        XCTAssertTrue(formChip(tag).isSelected, "rule selected the tag")
        tapStable(app.buttons["Add"])
        XCTAssertTrue(app.textFields["Amount"].waitForNonExistence(timeout: 10), "form closed")

        // Flow SEE ALL lists the new tag; filtering by it finds the expense.
        openSeeAll()
        let filterChip = app.buttons[tag]
        XCTAssertTrue(filterChip.waitForExistence(timeout: 5), "SEE ALL lists the tag")
        if !filterChip.isHittable { app.swipeUp() }
        tapStable(filterChip)
        let rows = app.buttons.matching(identifier: "flow.all.row")
        XCTAssertTrue(waitUntil { rows.count == 1 }, "one tagged row, got \(rows.count)")
        XCTAssertTrue(rows.firstMatch.label.contains(description))
        leaveSeeAll()

        // Delete the rule: instant, and the form no longer suggests.
        openTagsAndRules()
        let deleteRule = app.buttons["Delete rule \(merchant)"]
        reveal(deleteRule)
        tapStable(deleteRule)
        XCTAssertTrue(rule.waitForNonExistence(timeout: 5), "rule deleted without a confirmation")
        openExpenseForm(description: description + " again")
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(wheelValue.contains("Groceries"), "no suggestion, wheel shows \(wheelValue)")
        XCTAssertTrue(formChip(tag).exists)
        XCTAssertFalse(formChip(tag).isSelected, "no tag applied")
        tapStable(app.buttons["Cancel"])
        XCTAssertTrue(app.textFields["Amount"].waitForNonExistence(timeout: 10))

        // Delete the tag: Cancel keeps it; Delete removes it.
        openTagsAndRules()
        let deleteTag = app.buttons["Delete \(tag)"]
        reveal(deleteTag)
        tapStable(deleteTag)
        XCTAssertTrue(app.buttons["tags.delete.confirm"].waitForExistence(timeout: 5))
        tapStable(app.buttons["tags.delete.cancel"])
        XCTAssertTrue(app.buttons["tags.delete.confirm"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(labelled(tag).exists, "cancel kept the tag")
        tapStable(deleteTag)
        tapStable(app.buttons["tags.delete.confirm"])
        XCTAssertTrue(labelled(tag).waitForNonExistence(timeout: 10), "tag deleted")
        if startedEmpty {
            XCTAssertTrue(element("tags.empty").waitForExistence(timeout: 5))
            XCTAssertTrue(element("rules.empty").exists)
        }

        // Gone from the form's chips and from SEE ALL's filter.
        openExpenseForm(description: "")
        XCTAssertFalse(formChip(tag).waitForExistence(timeout: 2), "tag chip gone from the form")
        tapStable(app.buttons["Cancel"])
        XCTAssertTrue(app.textFields["Amount"].waitForNonExistence(timeout: 10))
        openSeeAll()
        XCTAssertFalse(app.buttons[tag].waitForExistence(timeout: 2), "tag chip gone from SEE ALL")
        leaveSeeAll()
    }
}
