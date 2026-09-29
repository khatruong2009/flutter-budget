import BudgieCore
import XCTest

@testable import Runner

/// The form's day picker: a stored day goes in as 12:00 local and comes
/// back as the same year / month / day, stored as `DateTime(y, m, d)`,
/// including across DST changes (Santiago's happen at midnight).
final class DayPickerDateTests: XCTestCase {
    private func roundTrip(zone: String, from start: (Int, Int, Int), days: Int, file: StaticString = #filePath, line: UInt = #line) {
        let calendar = DartCalendar(timeZone: TimeZone(identifier: zone)!)
        let gregorian = DayPickerSheet.gregorian(calendar, firstWeekday: 2)
        for offset in 0..<days {
            let input = calendar.date(start.0, start.1, start.2 + offset)
            let label = "\(zone) \(input.toIso8601String())"
            let picked = DayPickerSheet.pickerDate(for: input, in: gregorian)
            let parts = gregorian.dateComponents([.year, .month, .day, .hour], from: picked)
            XCTAssertEqual(parts.year, input.year, label, file: file, line: line)
            XCTAssertEqual(parts.month, input.month, label, file: file, line: line)
            XCTAssertEqual(parts.day, input.day, label, file: file, line: line)
            XCTAssertEqual(parts.hour, 12, label, file: file, line: line)
            let stored = DayPickerSheet.storedDay(from: picked, in: gregorian, calendar: calendar)
            XCTAssertEqual(stored, calendar.date(input.year, input.month, input.day), label, file: file, line: line)
            XCTAssertEqual(stored?.year, input.year, label, file: file, line: line)
            XCTAssertEqual(stored?.month, input.month, label, file: file, line: line)
            XCTAssertEqual(stored?.day, input.day, label, file: file, line: line)
        }
    }

    /// Chile moves its clocks at midnight: 2026-04-05 (back) and
    /// 2026-09-06 (forward; that day has no 00:00).
    func testSantiagoAcrossMidnightDSTChanges() {
        roundTrip(zone: "America/Santiago", from: (2026, 4, 1), days: 10)
        roundTrip(zone: "America/Santiago", from: (2026, 9, 1), days: 10)
        roundTrip(zone: "America/Santiago", from: (2025, 1, 1), days: 3 * 365)
    }

    /// 2026-03-08 and 2026-11-01 change at 02:00.
    func testNewYorkAcrossDSTChanges() {
        roundTrip(zone: "America/New_York", from: (2026, 3, 5), days: 7)
        roundTrip(zone: "America/New_York", from: (2026, 10, 29), days: 7)
    }

    /// UTC-10 all year: noon local is 22:00 UTC, still the same day.
    func testHonolulu() {
        roundTrip(zone: "Pacific/Honolulu", from: (2025, 12, 25), days: 400)
    }

    func testCalendarUsesTheGivenFirstWeekdayAndZone() {
        let calendar = DartCalendar(timeZone: TimeZone(identifier: "America/Santiago")!)
        let monday = DayPickerSheet.gregorian(calendar, firstWeekday: 2)
        XCTAssertEqual(monday.firstWeekday, 2)
        XCTAssertEqual(monday.timeZone, calendar.timeZone)
        XCTAssertEqual(monday.identifier, .gregorian)
        XCTAssertEqual(DayPickerSheet.gregorian(calendar).firstWeekday, Calendar.autoupdatingCurrent.firstWeekday)
    }
}
