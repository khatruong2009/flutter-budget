import Foundation
import Testing

@testable import BudgieCore

/// The SEE ALL month pill limiting From/To to a month (D6) and telling
/// whether the list is still limited to it.
@Suite("TransactionFilter: limit to a month")
struct TransactionFilterMonthTests {
    private static func day(_ d: DartDateTime?) -> [Int]? {
        d.map { [$0.year, $0.month, $0.day] }
    }

    @Test("From is the first day and To the last, for any instant in the month", arguments: [
        ("UTC", 2026, 9, 17, 30),
        ("America/New_York", 2026, 12, 31, 31),
        ("Europe/Berlin", 2028, 2, 29, 29),
        ("Europe/Berlin", 2026, 2, 1, 28),
        ("Asia/Tokyo", 2026, 4, 30, 30),
    ])
    func bounds(zone: String, year: Int, month: Int, dayInMonth: Int, lastDay: Int) {
        let calendar = DartCalendar(timeZone: TimeZone(identifier: zone)!)
        var filter = TransactionFilter()
        filter.limit(toMonth: calendar.date(year, month, dayInMonth, 18, 30), calendar: calendar)
        #expect(Self.day(filter.from) == [year, month, 1])
        #expect(Self.day(filter.to) == [year, month, lastDay])
        #expect(filter.from?.hour == 0 && filter.to?.hour == 0)
        #expect(filter.isActive)
        #expect(filter.isLimited(toMonth: calendar.date(year, month), calendar: calendar))
    }

    /// Paraguay moved its clocks from 00:00 to 01:00 on 1 October 2017, so
    /// that month's first midnight does not exist; the days still match.
    @Test("a month starting in a DST gap")
    func dstGapOnTheFirst() {
        let calendar = DartCalendar(timeZone: TimeZone(identifier: "America/Asuncion")!)
        let october = calendar.date(2017, 10)
        var filter = TransactionFilter()
        filter.limit(toMonth: october, calendar: calendar)
        #expect(Self.day(filter.from) == [2017, 10, 1])
        #expect(Self.day(filter.to) == [2017, 10, 31])
        #expect(filter.isLimited(toMonth: october, calendar: calendar))
        #expect(filter.isLimited(toMonth: calendar.date(2017, 10, 15), calendar: calendar))
        #expect(!filter.isLimited(toMonth: calendar.date(2017, 9), calendar: calendar))
    }

    /// Brazil's 2018 change was at midnight on 4 November, mid-month.
    @Test("a month with a DST gap inside it")
    func dstGapMidMonth() {
        let calendar = DartCalendar(timeZone: TimeZone(identifier: "America/Sao_Paulo")!)
        var filter = TransactionFilter()
        filter.limit(toMonth: calendar.date(2018, 11, 4, 12), calendar: calendar)
        #expect(Self.day(filter.from) == [2018, 11, 1])
        #expect(Self.day(filter.to) == [2018, 11, 30])
        #expect(filter.isLimited(toMonth: calendar.date(2018, 11), calendar: calendar))
    }

    @Test("editing From or To, RESET or another month is no longer limited to it")
    func notLimitedAfterChanges() {
        let calendar = DartCalendar(timeZone: TimeZone(identifier: "UTC")!)
        let september = calendar.date(2026, 9)

        #expect(!TransactionFilter().isLimited(toMonth: september, calendar: calendar))

        var filter = TransactionFilter()
        filter.limit(toMonth: september, calendar: calendar)
        #expect(!filter.isLimited(toMonth: calendar.date(2026, 8), calendar: calendar))
        #expect(!filter.isLimited(toMonth: calendar.date(2025, 9), calendar: calendar))

        var from = filter
        from.setFrom(calendar.date(2026, 9, 2))
        #expect(!from.isLimited(toMonth: september, calendar: calendar))

        var to = filter
        to.setTo(calendar.date(2026, 10, 1))
        #expect(!to.isLimited(toMonth: september, calendar: calendar))

        // Picking the same days again restores it; other filters do not matter.
        var same = filter
        same.setFrom(calendar.date(2026, 9, 1, 9))
        same.setTo(calendar.date(2026, 9, 30, 23, 59))
        same.kind = .expense
        same.searchText = "gym"
        #expect(same.isLimited(toMonth: september, calendar: calendar))

        var reset = filter
        reset.reset()
        #expect(!reset.isLimited(toMonth: september, calendar: calendar))
        #expect(reset.from == nil && reset.to == nil)
    }

    @Test("limiting keeps the other filters and replaces earlier dates")
    func keepsOtherFilters() {
        let calendar = DartCalendar(timeZone: TimeZone(identifier: "UTC")!)
        var filter = TransactionFilter()
        filter.kind = .income
        filter.minAmount = 10
        filter.setFrom(calendar.date(2020, 1, 5))
        filter.setTo(calendar.date(2030, 1, 5))
        filter.limit(toMonth: calendar.date(2026, 8), calendar: calendar)
        #expect(filter.kind == .income && filter.minAmount == 10)
        #expect(Self.day(filter.from) == [2026, 8, 1])
        #expect(Self.day(filter.to) == [2026, 8, 31])
    }
}
