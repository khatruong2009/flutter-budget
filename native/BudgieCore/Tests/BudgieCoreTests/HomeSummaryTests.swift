import Foundation
import Testing

@testable import BudgieCore

@Suite("Home summary: month-over-month deltas")
struct HomeSummaryTests {
    @Test("percentDelta table")
    func percentDelta() {
        #expect(HomeSummary.percentDelta(current: 0, previous: 0) == nil)
        #expect(HomeSummary.percentDelta(current: -0.0, previous: 0) == nil)
        #expect(HomeSummary.percentDelta(current: 0, previous: -0.0) == nil)
        #expect(HomeSummary.percentDelta(current: 5, previous: 0) == 100)
        #expect(HomeSummary.percentDelta(current: -5, previous: 0) == 100)
        #expect(HomeSummary.percentDelta(current: 0, previous: 5) == -100)
        #expect(HomeSummary.percentDelta(current: 100, previous: 50) == 100)
        #expect(HomeSummary.percentDelta(current: 50, previous: 100) == -50)
        // No sign correction for a negative previous month.
        #expect(HomeSummary.percentDelta(current: 100, previous: -50) == -300)
        let same = HomeSummary.percentDelta(current: -50, previous: -50)!
        #expect(same == 0 && same.sign == .minus)
    }

    @Test("deltaLabel strings, rounding through toStringAsFixed(1)")
    func labels() {
        func label(_ current: Double, _ previous: Double) -> String {
            HomeSummary.deltaLabel(delta: HomeSummary.percentDelta(current: current, previous: previous), previousMonthName: "August")
        }
        #expect(label(0, 0) == "No August data")
        #expect(label(5, 0) == "+100.0% vs August")
        #expect(label(50, 100) == "-50.0% vs August")
        #expect(label(1, 3) == "-66.7% vs August")
        #expect(label(-50, -50) == "+-0.0% vs August")
        #expect(label(99.96, 100) == "-0.0% vs August")
        // 100.05 / 100 -> 0.04999999999999716: rounds down.
        #expect(label(100.05, 100) == "+0.0% vs August")
        #expect(label(100.15, 100) == "+0.2% vs August")
        #expect(HomeSummary.deltaLabel(delta: 0.25, previousMonthName: "May") == "+0.3% vs May")
        #expect(HomeSummary.deltaLabel(delta: nil, previousMonthName: "December") == "No December data")
    }

    @Test("previous month wraps January to December of the year before")
    func previousMonth() {
        let calendar = DartCalendar(timeZone: Scenario.zone)
        #expect(HomeSummary.previousMonth(of: calendar.date(2026, 1), calendar: calendar) == calendar.date(2025, 12))
        #expect(HomeSummary.previousMonth(of: calendar.date(2026, 3, 31, 23, 30), calendar: calendar) == calendar.date(2026, 2))
        #expect(DartDateFormat.MMMM(HomeSummary.previousMonth(of: calendar.date(2026, 9), calendar: calendar)) == "August")
    }
}
