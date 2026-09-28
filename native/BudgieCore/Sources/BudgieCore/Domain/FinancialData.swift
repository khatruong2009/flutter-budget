import Foundation

/// A stored row: readable (typed, patchable) or not (kept verbatim).
public enum StoredRow<Record: Hashable & Sendable>: Hashable, Sendable {
    case record(Record)
    case unreadable(JSONValue)

    public var record: Record? {
        if case .record(let record) = self { return record }
        return nil
    }
}

/// Everything the app shows, loaded from a `FinancialSnapshot` with the same
/// rules as the Flutter models (`TransactionModel.getTransactions`,
/// `RecurringTransactionModel.loadRecurringTransactions`,
/// `AppSettingsProvider.load`). Sections the MVP does not edit are read only
/// or not at all; the store keeps them untouched.
public struct FinancialData: Sendable {
    public let calendar: DartCalendar
    public private(set) var transactionRows: [StoredRow<TransactionRecord>] = []
    public private(set) var templateRows: [StoredRow<RecurringTemplate>] = []
    public private(set) var netWorthRows: [StoredRow<NetWorthEntryRecord>] = []
    public private(set) var savingsGoals: [SavingsGoalRecord] = []
    /// `categoryBudgetLimits` in stored order, values > 0 only.
    public private(set) var budgetLimits: [(String, Double)] = []
    public private(set) var selectedNetWorthMonth: DartDateTime
    /// Parsed once at load; the MVP never edits categories.
    public private(set) var categories: [CategoryInfo] = []
    public var appSettings: AppSettings
    /// Raw sections as loaded, for patch-in-place writes of sections the
    /// typed layer only partly understands.
    public private(set) var sections: JSONObject

    public var transactions: [TransactionRecord] { transactionRows.compactMap(\.record) }
    public var templates: [RecurringTemplate] { templateRows.compactMap(\.record) }
    public var netWorthEntries: [NetWorthEntryRecord] { netWorthRows.compactMap(\.record) }
    public var unreadableTransactionCount: Int { transactionRows.count - transactions.count }

    /// Section writes the load itself requires (Dart saves these during
    /// load): identity backfill and legacy starting balances.
    public struct LoadResult: Sendable {
        public var data: FinancialData
        public var pendingWrites: [(String, JSONValue)]
    }

    public static func load(
        _ snapshot: FinancialSnapshot, preferences: PreferencesStore, calendar: DartCalendar,
        now: () -> DartDateTime, newID: () -> String
    ) -> LoadResult {
        let sections = snapshot.sections
        var pending: [(String, JSONValue)] = []
        let launch = now()
        var data = FinancialData(
            calendar: calendar,
            selectedNetWorthMonth: calendar.month(of: launch),
            appSettings: AppSettings.load(section: sections[Section.appSettings], preferences: preferences),
            sections: sections)

        // Transactions (getTransactions): unreadable rows are skipped by Dart
        // and kept verbatim here; blank or duplicate ids get fresh ones and
        // are persisted only if every row was readable.
        if case .array(let rows)? = sections[Section.transactions], !rows.isEmpty {
            var seen = Set<String>()
            var needsIdentityMigration = false
            var unreadable = 0
            for row in rows {
                guard var record = TransactionRecord.parse(row, calendar: calendar, newID: newID) else {
                    unreadable += 1
                    data.transactionRows.append(.unreadable(row))
                    continue
                }
                let persisted = record.raw["id"]?.stringValue
                let hasIdentity = persisted.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
                var newIdentity: String? = nil
                if !hasIdentity || !seen.insert(record.id).inserted {
                    newIdentity = newID()
                    seen.insert(newIdentity!)
                    needsIdentityMigration = true
                }
                if record.raw["createdAt"]?.stringValue == nil || record.raw["updatedAt"]?.stringValue == nil {
                    needsIdentityMigration = true
                }
                record = record.withBackfilledIdentity(id: newIdentity)
                data.transactionRows.append(.record(record))
            }
            if needsIdentityMigration && unreadable == 0 {
                pending.append((Section.transactions, data.transactionsSection()))
            }
        }

        // Net worth entries, or the legacy starting balances when empty.
        if case .array(let rows)? = sections[Section.netWorthEntries], !rows.isEmpty {
            data.netWorthRows = rows.map { row in
                NetWorthEntryRecord.parse(row, calendar: calendar, now: now).map { .record($0) } ?? .unreadable(row)
            }
        } else {
            let assets = preferences.double(PreferenceKey.startingAssets) ?? 0
            let liabilities = preferences.double(PreferenceKey.startingLiabilities) ?? 0
            var migrated: [NetWorthEntryRecord] = []
            for (name, type, amount) in [("Starting Assets", NetWorthEntryType.asset, assets), ("Starting Liabilities", .liability, liabilities)]
            where amount > 0 {
                let at = now()
                migrated.append(.make(id: newID(), name: name, type: type, createdAt: at,
                                      snapshot: NetWorthSnapshotRecord(recordedAt: at, amount: amount)))
            }
            if !migrated.isEmpty {
                data.netWorthRows = migrated.map { .record($0) }
                pending.append((Section.netWorthEntries, data.netWorthSection()))
            }
        }

        if let text = sections[Section.selectedNetWorthMonth]?.stringValue, !text.isEmpty,
            let parsed = calendar.tryParse(text)
        {
            data.selectedNetWorthMonth = calendar.month(of: parsed)
        }

        data.categories = CategoryCatalog.load(sections[Section.categories])

        if case .object(let limits)? = sections[Section.categoryBudgetLimits] {
            for key in limits.keys {
                guard let value = limits[key]?.numberValue?.doubleValue, value > 0 else { continue }
                data.budgetLimits.append((key, value))
            }
        }

        if case .array(let goals)? = sections[Section.savingsGoals] {
            data.savingsGoals = goals.compactMap { SavingsGoalRecord.parse($0, calendar: calendar, now: launch, newID: newID) }
        }

        if case .array(let rows)? = sections[Section.recurringTransactions], !rows.isEmpty {
            data.templateRows = rows.map { row in
                RecurringTemplate.parse(row, calendar: calendar, newID: newID).map { .record($0) } ?? .unreadable(row)
            }
        }
        return LoadResult(data: data, pendingWrites: pending)
    }

    // MARK: - Section serialization (lossless)

    public func transactionsSection() -> JSONValue {
        .array(transactionRows.map { row in
            switch row {
            case .record(let record): return .object(record.raw)
            case .unreadable(let raw): return raw
            }
        })
    }

    public func templatesSection() -> JSONValue {
        .array(templateRows.map { row in
            switch row {
            case .record(let record): return .object(record.raw)
            case .unreadable(let raw): return raw
            }
        })
    }

    public func netWorthSection() -> JSONValue {
        .array(netWorthRows.map { row in
            switch row {
            case .record(let record): return .object(record.raw)
            case .unreadable(let raw): return raw
            }
        })
    }

    public func appSettingsSection() -> JSONValue {
        appSettings.section(over: sections[Section.appSettings])
    }

    mutating func noteWritten(_ section: String, _ value: JSONValue) {
        sections[section] = value
    }

    // MARK: - Transactions (TransactionModel mutations)

    public mutating func addTransaction(
        type: TransactionType, description: String, amount: Double, category: String, date: DartDateTime,
        recurringTemplateId: String? = nil, tagIds: [String] = [], id: String, now: DartDateTime
    ) -> TransactionRecord {
        let record = TransactionRecord.make(
            id: id, type: type, description: description, amount: amount, category: category, date: date,
            recurringTemplateId: recurringTemplateId, tagIds: tagIds, now: now)
        transactionRows.append(.record(record))
        return record
    }

    @discardableResult
    public mutating func updateTransaction(id: String, _ edit: TransactionRecord.Edit, now: DartDateTime) -> Bool {
        guard let index = transactionRows.firstIndex(where: { $0.record?.id == id }), let record = transactionRows[index].record else {
            return false
        }
        transactionRows[index] = .record(record.applying(edit, now: now))
        return true
    }

    @discardableResult
    public mutating func deleteTransaction(id: String) -> Bool {
        let before = transactionRows.count
        transactionRows.removeAll { $0.record?.id == id }
        return transactionRows.count != before
    }

    // MARK: - Ledger queries

    public struct MonthTotals: Sendable {
        public var income = 0.0
        public var expenses = 0.0
        public var net: Double { income - expenses }
        /// Insertion order of first appearance (Dart map order).
        public var categoryExpenses: [(String, Double)] = []
        public var transactionIDs: [String] = []
    }

    /// Dart `_monthLedger`: per `year*12+month`, sums in list order.
    public func monthLedger() -> [Int: MonthTotals] {
        var months: [Int: MonthTotals] = [:]
        for transaction in transactions {
            let key = calendar.ledgerMonthKey(transaction.date)
            var totals = months[key] ?? MonthTotals()
            totals.transactionIDs.append(transaction.id)
            if transaction.type == .income {
                totals.income += transaction.amount
            } else {
                totals.expenses += transaction.amount
                if let index = totals.categoryExpenses.firstIndex(where: { $0.0 == transaction.category }) {
                    totals.categoryExpenses[index].1 += transaction.amount
                } else {
                    totals.categoryExpenses.append((transaction.category, transaction.amount))
                }
            }
            months[key] = totals
        }
        return months
    }

    public func totals(forMonth month: DartDateTime) -> MonthTotals {
        monthLedger()[calendar.ledgerMonthKey(month)] ?? MonthTotals()
    }

    /// `getAvailableMonths`: months with transactions, newest first.
    public func availableMonths() -> [DartDateTime] {
        monthLedger().keys.map { calendar.month(fromLedgerKey: $0) }.sorted { $0 > $1 }
    }

    /// `getAllTransactionsSorted` (compareNewestFirst).
    public func transactionsNewestFirst() -> [TransactionRecord] {
        FinancialData.sortNewestFirst(transactions, calendar: calendar)
    }

    /// One month's transactions, newest first.
    public func transactionsNewestFirst(inMonth month: DartDateTime) -> [TransactionRecord] {
        let key = calendar.ledgerMonthKey(month)
        return FinancialData.sortNewestFirst(transactions.filter { calendar.ledgerMonthKey($0.date) == key }, calendar: calendar)
    }

    /// `Transaction.compareNewestFirst` with its keys computed once per row
    /// (calendar day, createdAt, id as UTF-16), so 10k rows sort quickly.
    static func sortNewestFirst(_ rows: [TransactionRecord], calendar: DartCalendar) -> [TransactionRecord] {
        let keyed = rows.map { record -> (day: Int64, created: Int64, id: [UInt16], record: TransactionRecord) in
            let f = record.date.fields
            return (calendar.date(f.year, f.month, f.day).microsecondsSinceEpoch, record.createdAt.microsecondsSinceEpoch,
                    Array(record.id.utf16), record)
        }
        return keyed.sorted { a, b in
            if a.day != b.day { return a.day > b.day }
            if a.created != b.created { return a.created > b.created }
            return b.id.lexicographicallyPrecedes(a.id)
        }.map(\.record)
    }

    /// Widget value (`_syncWidgetCashFlow`): current calendar month's income
    /// minus expenses, summed in list order.
    public func widgetCashFlow(now: DartDateTime) -> (amount: Double, month: String) {
        let n = now.fields
        var cashFlow = 0.0
        for transaction in transactions {
            let f = transaction.date.fields
            guard f.year == n.year && f.month == n.month else { continue }
            cashFlow += transaction.type == .income ? transaction.amount : -transaction.amount
        }
        return (cashFlow, "\(n.year)-\(DartCalendar.pad(n.month, 2))")
    }

    // MARK: - Recurring templates

    public mutating func addTemplate(_ template: RecurringTemplate) {
        templateRows.append(.record(template))
    }

    /// Edit (approved divergence Q2): Dart resets `nextOccurrence` and
    /// `isActive`, which duplicates already generated transactions. Here the
    /// cursor and pause state are kept; if the schedule changed, the cursor
    /// restarts from the new start date but never lands on or before the
    /// last occurrence already generated for this template.
    @discardableResult
    public mutating func updateTemplate(id: String, _ edit: RecurringTemplate.Edit) -> Bool {
        guard let index = templateRows.firstIndex(where: { $0.record?.id == id }), let template = templateRows[index].record else {
            return false
        }
        var next = template.applying(edit)
        if next.scheduleKey != template.scheduleKey {
            var cursor = next.startDate
            if let last = transactions.filter({ $0.recurringTemplateId == id }).map(\.date).max() {
                var guardCount = 0
                while (cursor < last || calendar.isSameDay(cursor, last)) && guardCount < 5000 {
                    cursor = RecurringGenerator.nextOccurrence(of: next, after: cursor, calendar: calendar)
                    guardCount += 1
                }
            }
            next = next.with(nextOccurrence: cursor)
        }
        templateRows[index] = .record(next)
        return true
    }

    @discardableResult
    public mutating func setTemplateActive(id: String, _ active: Bool) -> Bool {
        guard let index = templateRows.firstIndex(where: { $0.record?.id == id }), let template = templateRows[index].record else {
            return false
        }
        templateRows[index] = .record(template.with(isActive: active))
        return true
    }

    @discardableResult
    public mutating func deleteTemplate(id: String) -> Bool {
        let before = templateRows.count
        templateRows.removeAll { $0.record?.id == id }
        return templateRows.count != before
    }

    mutating func replaceTemplate(_ template: RecurringTemplate) {
        if let index = templateRows.firstIndex(where: { $0.record?.id == template.id }) {
            templateRows[index] = .record(template)
        }
    }
}
