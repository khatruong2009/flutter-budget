import BudgieCore
import XCTest

@testable import Runner

@MainActor
final class ToastTests: XCTestCase {
    func testShowReplaceAndDismissOnlyTheCurrentToast() {
        let model = AppModel()
        let first = Toast.transactionDeleted
        model.showToast(first)
        let second = Toast.saveFailed
        model.showToast(second)
        model.dismissToast(first.id)
        XCTAssertEqual(model.toast, second, "a stale timer must not dismiss a newer toast")
        model.dismissToast(second.id)
        XCTAssertNil(model.toast)
    }

    func testAddedToCopyNamesTheYearOnlyWhenItDiffers() {
        let calendar = DartCalendar(timeZone: .current)
        let now = calendar.date(2026, 9, 28)
        XCTAssertEqual(Toast.addedTo(month: calendar.date(2026, 3), now: now).message, "Added to March")
        XCTAssertEqual(Toast.addedTo(month: calendar.date(2025, 12), now: now).message, "Added to December 2025")
        XCTAssertEqual(Toast.saveFailed.duration, 8)
    }
}
