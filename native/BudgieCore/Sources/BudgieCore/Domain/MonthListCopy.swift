import Foundation

/// The SEE ALL month list (`TransactionPage`, transaction_page.dart) and the
/// Spend category drill-in (`CategoryTransactionsPage`,
/// category_transactions_page.dart) compute their day groups and texts
/// inline; this is one shared definition for the views and the parity
/// tests.
public enum MonthListCopy {
    /// One calendar day of a month's rows (`DateFormat.yMMMd` group key,
    /// transaction_page.dart:141-149).
    public struct DayGroup: Identifiable, Sendable {
        /// The local day as `year * 10000 + month * 100 + day`.
        public let id: Int
        /// "Sep 27, 2026".
        public let title: String
        public var rows: [LedgerRow]
    }

    /// The rows arrive newest first (`Transaction.compareNewestFirst`: calendar
    /// day descending), so a day's rows are contiguous.
    public static func dayGroups(from rows: ArraySlice<LedgerRow>) -> [DayGroup] {
        var groups: [DayGroup] = []
        for row in rows {
            if groups.last?.id == row.dayKey {
                groups[groups.count - 1].rows.append(row)
            } else {
                groups.append(DayGroup(id: row.dayKey, title: DartDateFormat.yMMMd(row.record.date), rows: [row]))
            }
        }
        return groups
    }

    /// A month chip (`_MonthChip`, month_selector.dart:126-127, 196-216).
    public static func chip(_ month: DartDateTime) -> (month: String, year: String) {
        (DartDateFormat.MMM(month).uppercased(), DartDateFormat.y(month))
    }

    /// `_MonthlySummaryCard` (:241-292): income, expenses and the signed net.
    public static func summary(_ summary: MonthSummary, formatter: MoneyFormatter) -> (income: String, expenses: String, net: String) {
        (formatter.format(summary.income), formatter.format(summary.expenses), formatter.formatSigned(summary.net))
    }

    /// `ModernTransactionListItem` (modern_transaction_list_item.dart:114-125):
    /// "Category • Mon d" (U+2022).
    public static func rowSubtitle(_ record: TransactionRecord) -> String {
        "\(record.category) \u{2022} \(DartDateFormat.MMMd(record.date))"
    }

    /// The row's unsigned amount (modern_transaction_list_item.dart:127).
    public static func rowAmount(_ record: TransactionRecord, formatter: MoneyFormatter) -> String {
        formatter.format(record.amount)
    }

    /// The month list's empty copy (transaction_page.dart:55-69, 129-135).
    public static let noTransactionsTitle = "No Transactions Yet"
    public static let noTransactionsMessage = "Start tracking your finances by adding your first transaction"
    public static let emptyMonthTitle = "No Transactions"
    public static let emptyMonthMessage = "No transactions for this month"

    /// The drill-in's rows: this month's expenses in `category` (exact
    /// UTF-16 name), in the ledger's order (:39-44).
    public static func drillInRows(monthRows rows: ArraySlice<LedgerRow>, category: String) -> [LedgerRow] {
        rows.filter { $0.record.type == .expense && DartString.equal($0.record.category, category) }
    }

    /// The drill-in's "TOTAL SPENT" (:46-49, 197): the amounts folded in row
    /// order from 0.0.
    public static func drillInTotal(_ rows: [LedgerRow], formatter: MoneyFormatter) -> String {
        formatter.format(rows.reduce(0.0) { $0 + $1.record.amount })
    }

    /// The drill-in's month and count pills (:210-217).
    public static func drillInPills(month: DartDateTime, count: Int) -> (month: String, count: String) {
        (DartDateFormat.MMMMyyyy(month), "\(count) transaction\(count == 1 ? "" : "s")")
    }

    /// "No transactions found in this category for September" (:83-84).
    public static func drillInEmptyMessage(month: DartDateTime) -> String {
        "No transactions found in this category for \(DartDateFormat.MMMM(month))"
    }
}
