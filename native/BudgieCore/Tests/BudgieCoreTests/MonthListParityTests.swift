import Foundation
import Testing

@testable import BudgieCore

/// Zones of Fixtures/monthlist: a DST change at 02:00 (New York) and at
/// midnight (Santiago).
private let monthListZones = ["America/New_York", "America/Santiago"]

private func fixture(_ zone: String, _ file: String) throws -> J {
    J(try JSONParser.parse([UInt8](Fixtures.data("monthlist/tz/\(zone.replacingOccurrences(of: "/", with: "_"))/\(file)"))))
}

private func strings(_ j: J) -> [String] { j.array.map { $0.string! } }

private func same(_ actual: [String], _ expected: [String], _ label: String) {
    #expect(actual.map { Array($0.utf16) } == expected.map { Array($0.utf16) }, "\(label): \(actual) | \(expected)")
}

private func same(_ actual: String, _ expected: String, _ label: String) {
    #expect(Array(actual.utf16) == Array(expected.utf16), "\(label): \(actual) | \(expected)")
}

// MARK: - The views' expressions, verbatim

/// TransactionsView.swift:153-170 (`DayGroup`), as it is today.
private struct ViewDayGroup {
    let id: Int
    let title: String
    var rows: [LedgerRow]

    static func build(from rows: ArraySlice<LedgerRow>) -> [ViewDayGroup] {
        var groups: [ViewDayGroup] = []
        for row in rows {
            if groups.last?.id == row.dayKey {
                groups[groups.count - 1].rows.append(row)
            } else {
                groups.append(ViewDayGroup(id: row.dayKey, title: DartDateFormat.yMMMd(row.record.date), rows: [row]))
            }
        }
        return groups
    }
}

private enum ViewExpr {
    /// MonthStrip.swift:51-54.
    static func chip(_ month: DartDateTime) -> [String] { [DartDateFormat.MMM(month).uppercased(), DartDateFormat.y(month)] }

    /// TransactionsView.swift:186-189 and the labels of 193-194, 199, 203.
    static func summary(_ summary: MonthSummary, _ formatter: MoneyFormatter) -> [String] {
        let net = summary.net
        let income = formatter.format(summary.income)
        let expenses = formatter.format(summary.expenses)
        let netText = formatter.formatSigned(net)
        return ["Income", income, "Expenses", expenses, "Net Cash Flow", netText]
    }

    /// TransactionsView.swift:281, 287, 269.
    static func row(_ record: TransactionRecord, _ formatter: MoneyFormatter) -> [String] {
        [record.description, "\(record.category) \u{2022} \(DartDateFormat.MMMd(record.date))", formatter.format(record.amount)]
    }

    /// CategoryTransactionsView.swift:26-30 (rows and total).
    static func drillIn(_ ledger: LedgerIndex, month: DartDateTime, category: String) -> (rows: [LedgerRow], total: Double) {
        let rows = ledger.newestFirst(inMonth: month).filter {
            $0.record.type == .expense && DartString.equal($0.record.category, category)
        }
        let total = rows.reduce(0.0) { $0 + $1.record.amount }
        return (rows, total)
    }

    /// CategoryTransactionsView.swift:134-135 (SummaryCard), 188-200 (ExpenseRow), 41-42 (empty message).
    static func pills(month: DartDateTime, count: Int) -> [String] {
        ["\(DartDateFormat.MMMMyyyy(month))", "\(count) transaction\(count == 1 ? "" : "s")"]
    }

    static func drillRow(_ record: TransactionRecord, _ formatter: MoneyFormatter) -> [String] {
        [record.description, DartDateFormat.MMMd(record.date), formatter.format(record.amount)]
    }

    static func emptyMessage(_ month: DartDateTime) -> String {
        "No transactions found in this category for \(DartDateFormat.MMMM(month))"
    }
}

private func load(_ c: J, _ calendar: DartCalendar) throws -> (FinancialData, MoneyFormatter, LedgerIndex) {
    let sections = try JSONParser.parse(c["sections"].string!).objectValue!
    let now = calendar.date(2026, 9, 28, 9, 15)
    let data = FinancialData.load(
        FinancialSnapshot(revision: 1, sections: sections), preferences: InMemoryPreferences([:]), calendar: calendar,
        now: { now }, newID: { UUID().uuidString.lowercased() }
    ).data
    let formatter = MoneyFormatter(currencyCode: c["currency"].string!, locale: c["locale"].string, hideBalances: c["hide"].bool!)
    return (data, formatter, LedgerIndex.build(data.transactions, calendar: calendar))
}

@Suite("Month lists: SEE ALL and the category drill-in match the Flutter pages (Fixtures/monthlist)")
struct MonthListParityTests {
    /// The real `TransactionPage` for each dataset: the month chips, and for
    /// every month the summary card and the list (pinned date headers with
    /// their rows, in order), against `LedgerIndex`, the shared helpers
    /// (`MonthListCopy`) and a verbatim copy of what the views compute.
    @Test("SEE ALL page", arguments: monthListZones)
    func page(zone: String) throws {
        let f = try fixture(zone, "page.json")
        #expect(f["tz"].string == zone)
        let tz = TimeZone(identifier: zone)!
        let calendar = DartCalendar(timeZone: tz)
        let cases = f["cases"].array
        #expect(cases.count == 8)
        var months = 0, groupsSeen = 0, rowsSeen = 0, multiRowDays = 0, emptyStates = 0, hidden = 0
        for c in cases {
            let label = "\(zone) \(c["name"].string!)"
            let (data, formatter, ledger) = try load(c, calendar)
            #expect(ledger.availableMonths.map { $0.toIso8601String() } == strings(c["availableMonths"]), "\(label) available months")
            if ledger.availableMonths.isEmpty {
                emptyStates += 1
                let texts = strings(c["empty"])
                #expect(texts.contains(MonthListCopy.noTransactionsTitle), "\(label) empty title \(texts)")
                #expect(texts.contains(MonthListCopy.noTransactionsMessage), "\(label) empty message \(texts)")
                #expect(data.transactions.isEmpty)
                continue
            }
            if c["hide"].bool! { hidden += 1 }
            // Chips, in the order of the months.
            let chips = c["chips"].array
            #expect(chips.count == ledger.availableMonths.count, "\(label) chips")
            for (month, chip) in zip(ledger.availableMonths, chips) {
                let copy = MonthListCopy.chip(month)
                same(strings(chip), [copy.month, copy.year], "\(label) chip")
                same(strings(chip), ViewExpr.chip(month), "\(label) view chip")
            }

            for m in c["months"].array {
                let month = try calendar.parse(m["month"].string!)
                let at = "\(label) \(m["month"].string!)"
                months += 1
                // Summary card.
                let summary = ledger.summary(forMonth: month)
                let copy = MonthListCopy.summary(summary, formatter: formatter)
                same(strings(m["summary"]), ["Income", copy.income, "Expenses", copy.expenses, "Net Cash Flow", copy.net], "\(at) summary")
                same(strings(m["summary"]), ViewExpr.summary(summary, formatter), "\(at) view summary")

                // The list: headers and rows.
                let rows = ledger.newestFirst(inMonth: month)
                let groups = MonthListCopy.dayGroups(from: rows)
                let viewGroups = ViewDayGroup.build(from: rows)
                #expect(groups.map(\.id) == viewGroups.map(\.id) && groups.map(\.title) == viewGroups.map(\.title), "\(at) view groups")
                #expect(groups.map { $0.rows.map(\.id) } == viewGroups.map { $0.rows.map(\.id) }, "\(at) view group rows")
                var expected: [(header: String?, row: String?, texts: [String])] = []
                for g in groups {
                    expected.append((g.title, nil, []))
                    for row in g.rows {
                        expected.append((nil, row.record.id, [
                            row.record.description, MonthListCopy.rowSubtitle(row.record),
                            MonthListCopy.rowAmount(row.record, formatter: formatter),
                        ]))
                        same(expected.last!.texts, ViewExpr.row(row.record, formatter), "\(at) view row \(row.record.id)")
                    }
                    groupsSeen += 1
                    if g.rows.count > 1 { multiRowDays += 1 }
                }
                let dart = m["list"].array
                #expect(dart.count == expected.count, "\(at) list length \(dart.count) vs \(expected.count)")
                for (d, e) in zip(dart, expected) {
                    if let header = e.header {
                        same(strings(d["header"]), [header], "\(at) header")
                    } else {
                        #expect(d["row"].string == e.row, "\(at) row order \(d["row"].string ?? "?") vs \(e.row ?? "?")")
                        same(strings(d["texts"]), e.texts, "\(at) row \(e.row ?? "")")
                        rowsSeen += 1
                    }
                }
                // Every row of the month is in the list once.
                #expect(rowsSeen > 0)
            }
        }
        #expect(months >= 20 && groupsSeen >= 40 && rowsSeen >= 80 && multiRowDays >= 10 && emptyStates == 1 && hidden == 1, "coverage \(months) \(groupsSeen) \(rowsSeen) \(multiRowDays)")
    }

    /// The real `CategoryTransactionsPage` for (dataset, category, month)
    /// pairs: header, TOTAL SPENT card, month and count pills, the rows
    /// newest first, or the empty message.
    @Test("category drill-in", arguments: monthListZones)
    func drillIn(zone: String) throws {
        let f = try fixture(zone, "drillin.json")
        #expect(f["tz"].string == zone)
        let calendar = DartCalendar(timeZone: TimeZone(identifier: zone)!)
        let cases = f["cases"].array
        #expect(cases.count >= 40)
        var withRows = 0, empty = 0, singular = 0, multiRow = 0
        for c in cases {
            let category = c["category"].string!
            let label = "\(zone) \(c["dataset"].string!) \(category) \(c["month"].string!)"
            let (_, formatter, ledger) = try load(c, calendar)
            let month = try calendar.parse(c["month"].string!)
            let rows = MonthListCopy.drillInRows(monthRows: ledger.newestFirst(inMonth: month), category: category)
            let view = ViewExpr.drillIn(ledger, month: month, category: category)
            #expect(rows.map(\.id) == view.rows.map(\.id), "\(label) view rows")
            #expect(rows.map(\.id) == c["rows"].array.map { $0["id"].string! }, "\(label) rows")

            let pills = MonthListCopy.drillInPills(month: month, count: rows.count)
            same([pills.month, pills.count], ViewExpr.pills(month: month, count: view.rows.count), "\(label) view pills")
            var expected = [category, "TOTAL SPENT", MonthListCopy.drillInTotal(rows, formatter: formatter), pills.month, pills.count]
            same(MonthListCopy.drillInTotal(rows, formatter: formatter), formatter.format(view.total), "\(label) view total")
            if rows.isEmpty {
                empty += 1
                let texts = strings(c["texts"])
                same(Array(texts.prefix(5)), expected, "\(label) card")
                #expect(c["hasEyebrow"].bool == false, "\(label) no eyebrow")
                let rest = Array(texts.dropFirst(5))
                #expect(rest.contains(MonthListCopy.emptyMonthTitle), "\(label) empty title \(rest)")
                #expect(rest.contains(MonthListCopy.drillInEmptyMessage(month: month)), "\(label) empty message \(rest)")
                same(MonthListCopy.drillInEmptyMessage(month: month), ViewExpr.emptyMessage(month), "\(label) view empty message")
            } else {
                withRows += 1
                if rows.count == 1 { singular += 1 } else { multiRow += 1 }
                expected.append("TRANSACTIONS")
                for (row, dart) in zip(rows, c["rows"].array) {
                    let texts = [row.record.description, DartDateFormat.MMMd(row.record.date), formatter.format(row.record.amount)]
                    same(strings(dart["texts"]), texts, "\(label) row \(row.id)")
                    same(texts, ViewExpr.drillRow(row.record, formatter), "\(label) view row \(row.id)")
                    expected += texts
                }
                same(strings(c["texts"]), expected, "\(label) texts")
                #expect(c["hasEyebrow"].bool == true, "\(label) eyebrow")
            }
        }
        #expect(withRows >= 25 && empty >= 5 && singular >= 5 && multiRow >= 5, "coverage \(withRows) \(empty) \(singular) \(multiRow)")
    }
}
