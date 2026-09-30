import XCTest

/// Settings > Tags & rules end to end: add a tag (and a refused duplicate),
/// add a merchant rule using it (Done and opening a dropdown dismiss the
/// keyboard), see the rule pick the category and tag in the transaction
/// form, find the saved expense through Flow SEE ALL's tag filter, delete
/// the tag through its confirmation while the rule still uses it (the rule
/// keeps its category and loses the tag; the tag is gone from the form),
/// then delete the rule (instant: no more suggestion). A second test
/// covers the Swift-only rule edit, maximum amount, enable switch and Any
/// type. Names carry a per-run suffix so a rerun without an erase starts
/// clean.
///
/// The test leaves the store as it found it, failed or not: `tearDown`
/// relaunches the app and runs `cleanUp` (delete the added expense, then
/// the rule and the tag if they are still there).
@MainActor
final class TagsRulesUITests: XCTestCase {
    let app = XCUIApplication()
    private var cleanUp: (() -> Void)?

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "1"
        launch()
    }

    override func tearDown() async throws {
        if let cleanUp {
            self.cleanUp = nil
            // From a known state: the failure may have left a dialog, a
            // menu or the form open.
            app.terminate()
            launch()
            cleanUp()
        }
        try await super.tearDown()
    }

    private func launch() {
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

    /// Opens the add-expense form (or Home's Income pill's form) and types
    /// an amount and a description.
    private func openExpenseForm(description: String, amount amountText: String = "12", income: Bool = false) {
        homeRoot()
        tapStable(income ? app.buttons["Income"].firstMatch : app.buttons["Add transaction"])
        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        if income { tapStable(amount) }
        amount.typeText(amountText)
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

    /// Deletes every SEE ALL row whose label contains `text` (swipe, then
    /// the Delete Transaction alert).
    private func deleteTransactions(containing text: String) {
        homeRoot()
        tapStable(app.buttons["See all transactions"].firstMatch)
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        var deleted = 0
        while row.waitForExistence(timeout: 3) && deleted < 5 {
            row.swipeLeft()
            tapStable(app.alerts["Delete Transaction"].buttons["Delete"])
            XCTAssertTrue(app.alerts["Delete Transaction"].waitForNonExistence(timeout: 10))
            deleted += 1
        }
        XCTAssertFalse(row.exists, "transactions with \(text) deleted")
    }

    // MARK: - Test

    func testTagsAndRules() throws {
        let suffix = String(Int.random(in: 1000...9999))
        let tag = "UI Work \(suffix)"
        let merchant = "UIMart \(suffix)"
        let description = "uimart \(suffix) market"
        cleanUp = {
            self.deleteTransactions(containing: description)
            self.openTagsAndRules()
            let deleteRule = self.app.buttons["Delete rule \(merchant)"]
            if deleteRule.exists {
                self.reveal(deleteRule)
                self.tapStable(deleteRule)
                XCTAssertTrue(deleteRule.waitForNonExistence(timeout: 5), "rule deleted")
            }
            let deleteTag = self.app.buttons["Delete \(tag)"]
            if deleteTag.exists {
                self.reveal(deleteTag)
                self.tapStable(deleteTag)
                self.tapStable(self.app.buttons["tags.delete.confirm"])
                XCTAssertTrue(deleteTag.waitForNonExistence(timeout: 10), "tag deleted")
            }
        }

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
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "autofocused")
        pattern.typeText(merchant)
        // Done dismisses the keyboard.
        pattern.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Done dismissed the keyboard")
        XCTAssertEqual(element("rules.editor.type").value as? String, "Expense")
        XCTAssertEqual(element("rules.editor.match").value as? String, "Contains")
        // Opening a dropdown with the keyboard up dismisses it first.
        tapStable(pattern)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        tapStable(element("rules.editor.category"))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "the dropdown dismissed the keyboard")
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

        // Delete the tag while the rule uses it: Cancel keeps it; Delete
        // removes it, and the rule keeps its category without the tag.
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
        reveal(rule)
        XCTAssertEqual(rule.value as? String, "contains \u{00B7} Groceries", "the rule lost the tag")

        // The rule still picks Groceries; the tag chip is gone from the form.
        openExpenseForm(description: description + " again")
        XCTAssertTrue(waitUntil { self.wheelValue.contains("Groceries") }, "rule still sets the category, wheel shows \(wheelValue)")
        XCTAssertFalse(formChip(tag).waitForExistence(timeout: 2), "tag chip gone from the form")
        tapStable(app.buttons["Cancel"])
        XCTAssertTrue(app.textFields["Amount"].waitForNonExistence(timeout: 10))

        // Delete the rule: instant, and the form no longer suggests.
        openTagsAndRules()
        let deleteRule = app.buttons["Delete rule \(merchant)"]
        reveal(deleteRule)
        tapStable(deleteRule)
        XCTAssertTrue(rule.waitForNonExistence(timeout: 5), "rule deleted without a confirmation")
        if startedEmpty {
            XCTAssertTrue(element("tags.empty").waitForExistence(timeout: 5))
            XCTAssertTrue(element("rules.empty").exists)
        }
        openExpenseForm(description: description + " again")
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(wheelValue.contains("Groceries"), "no suggestion, wheel shows \(wheelValue)")
        tapStable(app.buttons["Cancel"])
        XCTAssertTrue(app.textFields["Amount"].waitForNonExistence(timeout: 10))

        // Gone from SEE ALL's filter.
        openSeeAll()
        XCTAssertFalse(app.buttons[tag].waitForExistence(timeout: 2), "tag chip gone from SEE ALL")
        leaveSeeAll()
    }

    // MARK: - Swift-only: edit, bounds, enable switch, any type

    /// The rule row's enable switch.
    private func ruleSwitch(_ pattern: String) -> XCUIElement {
        app.switches.matching(NSPredicate(format: "identifier BEGINSWITH 'rules.row.enabled.' AND label == %@", "Enable rule \(pattern)"))
            .firstMatch
    }

    /// Picks `option` from one of the editor's dropdowns.
    private func pick(_ option: String, in identifier: String) {
        tapStable(element(identifier))
        tapStable(app.buttons[option].firstMatch)
        XCTAssertTrue(waitUntil { self.element(identifier).value as? String == option }, "\(identifier) is \(option)")
    }

    /// Opens a form, checks the wheel, and cancels it.
    private func expectSuggestion(
        _ expected: Bool, category: String, description: String, amount: String, income: Bool = false,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        openExpenseForm(description: description, amount: amount, income: income)
        if expected {
            XCTAssertTrue(
                waitUntil { self.wheelValue.contains(category) }, "suggested \(category), wheel shows \(wheelValue)", file: file,
                line: line)
        } else {
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertFalse(wheelValue.contains(category), "no suggestion, wheel shows \(wheelValue)", file: file, line: line)
        }
        tapStable(app.buttons["Cancel"])
        XCTAssertTrue(app.textFields["Amount"].waitForNonExistence(timeout: 10))
    }

    /// Edit a rule in place (pattern, category, a maximum), see the form
    /// suggest only under the maximum, switch the rule off (no suggestion)
    /// and on again, then make it Any type with a category both types have
    /// and see the income form take it too. Nothing is saved but the rule,
    /// which `tearDown` deletes.
    func testEditBoundsEnableAndAnyType() throws {
        let suffix = String(Int.random(in: 1000...9999))
        let merchant = "UIEdit \(suffix)"
        let edited = "UIEdited \(suffix)"
        let description = "uiedited \(suffix) cafe"
        cleanUp = {
            self.openTagsAndRules()
            for name in [merchant, edited] {
                let delete = self.app.buttons["Delete rule \(name)"]
                if delete.exists {
                    self.reveal(delete)
                    self.tapStable(delete)
                    XCTAssertTrue(delete.waitForNonExistence(timeout: 5), "rule \(name) deleted")
                }
            }
        }

        // A plain rule (Expense, Contains, the first category).
        openTagsAndRules()
        tapStable(app.buttons["rules.add"])
        let pattern = app.textFields["Merchant text"]
        XCTAssertTrue(pattern.waitForExistence(timeout: 5))
        pattern.typeText(merchant)
        tapStable(app.buttons["rules.editor.submit"])
        XCTAssertTrue(pattern.waitForNonExistence(timeout: 10), "rule dialog closed")
        let row = labelled(merchant)
        reveal(row)

        // Edit it: prefilled, Save, in place under the new text.
        tapStable(row)
        XCTAssertTrue(labelled("Edit merchant rule").waitForExistence(timeout: 5))
        XCTAssertEqual(pattern.value as? String, merchant)
        XCTAssertEqual(app.buttons["rules.editor.submit"].label, "Save")
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 1), "an edit does not autofocus")
        tapStable(pattern)
        pattern.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: merchant.count) + edited + "\n")
        pick("Eating Out", in: "rules.editor.category")
        let maximum = app.textFields["Maximum amount"]
        tapStable(maximum)
        maximum.typeText("20")
        tapStable(app.buttons["rules.editor.submit"])
        XCTAssertTrue(pattern.waitForNonExistence(timeout: 10), "editor closed")
        let editedRow = labelled(edited)
        reveal(editedRow)
        let subtitle = editedRow.value as? String ?? ""
        XCTAssertTrue(subtitle.hasPrefix("contains \u{00B7} Eating Out \u{00B7} up to "), subtitle)
        XCTAssertFalse(labelled(merchant).exists, "edited in place, no second row")

        // Only amounts up to the maximum (inclusive) get the suggestion.
        expectSuggestion(false, category: "Eating Out", description: description, amount: "25")
        expectSuggestion(true, category: "Eating Out", description: description, amount: "20")

        // Switched off: dimmed "off", no suggestion.
        openTagsAndRules()
        let toggle = ruleSwitch(edited)
        reveal(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
        tapStable(toggle)
        XCTAssertTrue(waitUntil { toggle.value as? String == "0" }, "switched off")
        XCTAssertTrue(waitUntil { (editedRow.value as? String ?? "").hasSuffix("\u{00B7} off") }, "subtitle says off")
        expectSuggestion(false, category: "Eating Out", description: description, amount: "12")

        // On again, then Any type with Gift (both types have it).
        openTagsAndRules()
        reveal(toggle)
        tapStable(toggle)
        XCTAssertTrue(waitUntil { toggle.value as? String == "1" }, "switched on")
        reveal(editedRow)
        tapStable(editedRow)
        XCTAssertTrue(labelled("Edit merchant rule").waitForExistence(timeout: 5))
        XCTAssertEqual(maximum.value as? String, "20.00", "the maximum prefilled")
        pick("Any type", in: "rules.editor.type")
        XCTAssertEqual(element("rules.editor.category").value as? String, "Eating Out", "kept: the Any list has it")
        XCTAssertTrue(element("rules.editor.anyTypeNote").exists, "Eating Out is expense-only")
        pick("Gift", in: "rules.editor.category")
        XCTAssertFalse(element("rules.editor.anyTypeNote").exists, "Gift is in both lists")
        tapStable(app.buttons["rules.editor.submit"])
        XCTAssertTrue(pattern.waitForNonExistence(timeout: 10), "editor closed")
        reveal(editedRow)
        XCTAssertTrue(
            waitUntil { (editedRow.value as? String ?? "").hasPrefix("contains \u{00B7} Gift \u{00B7} any type \u{00B7} up to ") },
            editedRow.value as? String ?? "")
        expectSuggestion(true, category: "Gift", description: description, amount: "12", income: true)
        expectSuggestion(true, category: "Gift", description: description, amount: "12")
    }
}
