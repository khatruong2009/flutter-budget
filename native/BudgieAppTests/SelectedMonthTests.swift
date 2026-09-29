import BudgieCore
import XCTest

@testable import Runner

@MainActor
final class SelectedMonthTests: XCTestCase {
    func testStartsAtTheCurrentMonthAndNormalisesSelections() {
        let model = AppModel()
        let calendar = model.calendar
        XCTAssertEqual(model.selectedMonth, calendar.month(of: model.now))
        model.selectMonth(calendar.date(2026, 2, 17, 13, 45))
        XCTAssertEqual(model.selectedMonth.toIso8601String(), "2026-02-01T00:00:00.000")
        model.selectMonth(calendar.date(2026, 0, 31))
        XCTAssertEqual(model.selectedMonth.toIso8601String(), "2025-12-01T00:00:00.000")
    }
}
