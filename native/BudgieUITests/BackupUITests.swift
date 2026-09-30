import XCTest

/// Settings > DATA backup rows end to end through the system share sheet
/// and document picker: Export backup opens the share sheet (cancelled: no
/// message), a corrupt file gives Flutter's error, and a backup is
/// restored after its confirmation (Cancel first changes nothing).
///
/// Needs the picker files: after an erase and boot, run
/// `native/scripts/stage_import_fixtures.sh <UDID>` (they show under
/// Browse > On My iPhone). Restoring replaces the simulator's data with the
/// fixture's three transactions (dated last month, so a later suite's
/// current month starts empty).
@MainActor
final class BackupUITests: XCTestCase {
    let app = XCUIApplication()
    private var screen: SettingsDataScreen!

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchEnvironment["BUDGIE_SKIP_ONBOARDING"] = "1"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20))
        screen = SettingsDataScreen(app: app)
    }

    /// The share sheet opens with the file (titled with the subject);
    /// cancelling it shows no "Backup exported" and frees the rows.
    func testExportOpensShareSheetAndCancelShowsNothing() {
        screen.openSettings()
        screen.tapRow("settings.exportBackup")
        // The sheet's header shows the subject (share_plus's `subject`).
        let title = app.descendants(matching: .any)["LP.CaptionBar.TopCaption"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "share sheet\n\(app.debugDescription)")
        XCTAssertEqual(title.label, "Budgie Backup")
        screen.closeShareSheet()
        XCTAssertTrue(screen.waitUntil(10) { !title.exists }, "share sheet closed")
        XCTAssertFalse(screen.labelled("Backup exported").waitForExistence(timeout: 3), "no message after a cancel")
        XCTAssertTrue(screen.waitUntil(5) { app.buttons["settings.exportBackup"].exists }, "the row is enabled again")
    }

    /// A file Flutter refuses: its message, nothing restored.
    func testCorruptFileShowsTheError() {
        screen.openSettings()
        let before = screen.transactionCount()
        screen.tapRow("settings.importBackup")
        screen.pick("Budgie UITest Corrupt")
        XCTAssertTrue(
            screen.labelled("Could not import backup: This is not a valid Budgie backup file").waitForExistence(timeout: 15))
        XCTAssertFalse(screen.element("backup.confirm.title").exists)
        XCTAssertEqual(screen.transactionCount(), before)
    }

    /// "Replace all data?" with Flutter's counts; Cancel keeps the data;
    /// Replace restores it ("Backup restored") and Home shows its rows.
    func testRestoreAfterConfirmation() {
        screen.openSettings()
        let before = screen.transactionCount()
        screen.tapRow("settings.importBackup")
        screen.pick("Budgie UITest Backup")
        let title = screen.element("backup.confirm.title")
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertEqual(title.label, "Replace all data?")
        XCTAssertEqual(
            screen.element("backup.confirm.message").label,
            "This will import 3 transactions, 0 net worth entries, 1 budgets, 0 goals and 0 recurring templates, "
                + "replacing everything currently in Budgie. This cannot be undone.")
        screen.tapStable(screen.element("backup.confirm.cancel"))
        XCTAssertTrue(screen.waitUntil(5) { !title.exists })
        XCTAssertFalse(screen.labelled("Backup restored").waitForExistence(timeout: 2))
        XCTAssertEqual(screen.transactionCount(), before, "Cancel changes nothing")

        screen.restoreFixtureBackup()
        XCTAssertEqual(screen.transactionCount(), 3)
        screen.homeRoot()
        for name in ["UITest Groceries", "UITest Rent", "UITest Paycheck"] {
            XCTAssertTrue(screen.containing(name).waitForExistence(timeout: 10), name)
        }
    }
}

/// Driving Settings > DATA, the document picker and the share sheet (shared
/// with CSVImportUITests).
@MainActor
struct SettingsDataScreen {
    let app: XCUIApplication

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func labelled(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    func containing(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Polls `condition` until it holds or `timeout` passes.
    func waitUntil(_ timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }

    /// Taps once the element exists, is hittable and has stopped moving
    /// (dialog entrances and scrolling shift it).
    func tapStable(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
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

    /// Home's root page (popping anything pushed on the Home tab).
    func homeRoot() {
        app.tabBars.buttons["Home"].tap()
        var pops = 0
        while !app.buttons["home.settings"].waitForExistence(timeout: 1) && pops < 4 {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            pops += 1
        }
    }

    func openSettings() {
        homeRoot()
        app.buttons["home.settings"].tap()
        XCTAssertTrue(element("settings.recurring").waitForExistence(timeout: 10))
    }

    /// Scrolls the DATA row into view and taps it.
    func tapRow(_ identifier: String) {
        let row = element(identifier)
        XCTAssertTrue(row.waitForExistence(timeout: 10), identifier)
        for _ in 0..<6 where !row.isHittable || row.frame.maxY > app.frame.maxY - 140 {
            app.swipeUp(velocity: .slow)
        }
        tapStable(row)
    }

    /// The N in the Export as CSV row's "All N transactions".
    func transactionCount() -> Int? {
        let row = element("settings.exportCSV")
        guard row.waitForExistence(timeout: 10), let value = row.value as? String else { return nil }
        return Int(value.replacingOccurrences(of: "All ", with: "").replacingOccurrences(of: " transactions", with: ""))
    }

    /// Picks a staged file in the document picker: Browse (on a fresh
    /// simulator it opens on Recents), On My iPhone, then the file.
    func pick(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let item = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        if !item.waitForExistence(timeout: 8) {
            let browse = app.buttons["Browse"]
            if browse.waitForExistence(timeout: 5) { browse.tap() }
            if !item.waitForExistence(timeout: 6) {
                let location = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "On My iPhone")).firstMatch
                if location.waitForExistence(timeout: 5) { location.tap() }
            }
        }
        XCTAssertTrue(item.waitForExistence(timeout: 15), "\(name) in the picker\n\(app.debugDescription)", file: file, line: line)
        tapStable(item, file: file, line: line)
    }

    /// Closes the share sheet without sharing (its header's close button,
    /// once the sheet has settled).
    func closeShareSheet() {
        tapStable(app.buttons["header.closeButton"])
    }

    /// Settings > Import backup > "Budgie UITest Backup" > Replace, then
    /// "Backup restored": the known three-transaction ledger.
    func restoreFixtureBackup() {
        tapRow("settings.importBackup")
        pick("Budgie UITest Backup")
        tapStable(element("backup.confirm.confirm"))
        XCTAssertTrue(labelled("Backup restored").waitForExistence(timeout: 15))
        XCTAssertTrue(waitUntil(10) { !element("backup.confirm.title").exists })
    }
}
