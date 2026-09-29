import Foundation
import Testing

@testable import BudgieCore

@Suite("LedgerIndex: one pass per revision, same answers as the Dart ledger")
struct LedgerIndexTests {
    @Test("matches the Dart model and the Swift oracle for every fixture", arguments: DomainParityTests.cases)
    func parity(_ path: String) async throws {
        let url = Fixtures.url(path)
        let scenario = try Scenario(url)
        let dart = try loadExpected(url)["appAfterGenerate"]
        guard dart.value != nil else { return }
        let known = inputIDs(scenario)  // before launch writes generated rows
        guard let data = try await launch(scenario) else { return }
        let calendar = data.calendar
        let index = LedgerIndex.build(data.transactions, calendar: calendar)

        #expect(index.availableMonths.map { $0.toIso8601String() } == dart["availableMonths"].array.compactMap(\.string), "\(path) months")
        #expect(index.newestFirst.map(\.id) == data.transactionsNewestFirst().map(\.id), "\(path) order vs oracle")
        #expect(index.newestFirst.map(\.id).filter(known.contains) == dart["sortedIds"].array.compactMap(\.string).filter(known.contains))
        let oracle = data.monthLedger()
        for month in index.availableMonths {
            let key = calendar.netWorthMonthKey(month)
            let want = dart["monthly"][key]
            let summary = index.summary(forMonth: month)
            let totals = oracle[calendar.ledgerMonthKey(month)]!
            #expect(summary.income == want["totalIncome"].double && summary.expenses == want["totalExpenses"].double, "\(path) \(key)")
            #expect(summary.net == want["summary"]["net"].double, "\(path) \(key) net")
            // Same names, same (Dart map) order, same sums.
            #expect(summary.categoryExpenses.map(\.name) == want["categoryExpenses"].keys, "\(path) \(key) category order")
            for (name, amount) in summary.categoryExpenses {
                #expect(amount == want["categoryExpenses"][name].double, "\(path) \(key) \(name)")
            }
            #expect(summary.transactionCount == totals.transactionIDs.count)
            let expenseRows = data.transactions.filter { $0.type == .expense && calendar.ledgerMonthKey($0.date) == calendar.ledgerMonthKey(month) }
            for (name, count) in summary.expenseCounts {
                #expect(expenseRows.filter { $0.category == name }.count == count)
            }
            #expect(index.newestFirst(inMonth: month).map(\.id) == data.transactionsNewestFirst(inMonth: month).map(\.id), "\(path) \(key) month rows")
        }
        #expect(index.recent(3).map(\.id) == Array(data.transactionsNewestFirst().prefix(3).map(\.id)))
        #expect(index.recent(0).isEmpty)
    }

    @Test("history is ascending; the rolling window is contiguous and zero-filled across years")
    func windows() {
        let calendar = DartCalendar(timeZone: Scenario.zone)
        let now = calendar.date(2026, 9, 28)
        let rows = [
            TransactionRecord.make(id: "a", type: .income, description: "Pay", amount: 100, category: "Salary",
                                   date: calendar.date(2025, 11, 30, 23, 59), now: now),
            TransactionRecord.make(id: "b", type: .expense, description: "Food", amount: 40, category: "Groceries",
                                   date: calendar.date(2026, 2, 1), now: now),
            TransactionRecord.make(id: "c", type: .expense, description: "More", amount: 2.5, category: "Groceries",
                                   date: calendar.date(2026, 2, 14), now: now),
        ]
        let index = LedgerIndex.build(rows, calendar: calendar)
        #expect(index.netCashFlowHistory.map { $0.month.toIso8601String() } == ["2025-11-01T00:00:00.000", "2026-02-01T00:00:00.000"])
        #expect(index.netCashFlowHistory.map(\.net) == [100, -42.5])
        let window = index.rollingNet(endingAt: calendar.date(2026, 2), months: 5)
        #expect(window.map { $0.month.toIso8601String().prefix(7) } == ["2025-10", "2025-11", "2025-12", "2026-01", "2026-02"])
        #expect(window.map(\.net) == [0, 100, 0, 0, -42.5])
        #expect(index.rollingNet(endingAt: now, months: 0).isEmpty)
        #expect(index.summary(forMonth: calendar.date(2026, 2)).expenseCounts == ["Groceries": 2])
        #expect(index.summary(forMonth: calendar.date(2026, 3)).transactionCount == 0)
        #expect(index.newestFirst(inMonth: calendar.date(2026, 3)).isEmpty)
        let row = index.newestFirst[0]
        #expect(row.dayKey == 20260214 && row.monthKey == 2026 * 12 + 2 && row.descriptionLower == "more")
    }

    @Test("builds the 10k-row store in well under a second")
    func timing() async throws {
        let scenario = try Scenario(Fixtures.url("store/large_10k"))
        let data = try #require(try await launch(scenario))
        #expect(data.transactions.count >= 10_000)
        let clock = ContinuousClock()
        var index = LedgerIndex.empty(calendar: data.calendar)
        let elapsed = clock.measure { index = LedgerIndex.build(data.transactions, calendar: data.calendar) }
        print("LedgerIndex.build(\(data.transactions.count) rows): \(elapsed)")
        #expect(index.newestFirst.count == data.transactions.count)
        #expect(elapsed < .seconds(1))
    }
}
