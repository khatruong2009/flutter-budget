import Foundation
import Testing

@testable import BudgieCore

/// Zones of Fixtures/home/tz: a DST change at 02:00 (New York) and at
/// midnight (Santiago).
private let homePageZones = ["America/New_York", "America/Santiago"]

private func fixture(_ zone: String) throws -> J {
    J(try JSONParser.parse([UInt8](Fixtures.data("home/tz/\(zone.replacingOccurrences(of: "/", with: "_"))/page.json"))))
}

private func bits(_ value: J) -> Double? {
    value.string.flatMap { UInt64($0, radix: 16) }.map { Double(bitPattern: $0) }
}

private func hex(_ value: Double) -> String {
    let text = String(value.bitPattern, radix: 16)
    return String(repeating: "0", count: 16 - text.count) + text
}

private func strings(_ j: J) -> [String] { j.array.map { $0.string! } }

// MARK: - The views' expressions, verbatim
//
// Each is a copy of what the view computes today (file:line), so the test
// proves the shared helpers in HomePageCopy.swift are what the views show.

private enum ViewExpr {
    /// HomeHero.swift:19-24 (amount, status), 47 (subline), 58-59 (accessibility label).
    static func hero(income: Double, expenses: Double, formatter: MoneyFormatter)
        -> (amountLabel: String, subline: String, status: String, isNegative: Bool, label: String)
    {
        let cashFlow = income - expenses
        let isNegative = cashFlow < 0
        let amountLabel = formatter.format(abs(cashFlow))
        let statusLabel = cashFlow > 0 ? "SAVED THIS MONTH" : cashFlow < 0 ? "SHORT THIS MONTH" : "BREAKING EVEN"
        return (
            amountLabel,
            "\(formatter.format(income, decimalDigits: 0)) in   \u{00B7}   \(formatter.format(expenses, decimalDigits: 0)) out",
            statusLabel, isNegative,
            isNegative ? "Cash flow, \(amountLabel) short this month." : "Cash flow, \(amountLabel) this month.")
    }

    /// HomeView.swift:193-194, 197 (SpendGauge).
    static func gauge(spent: Double, income: Double, formatter: MoneyFormatter) -> (spent: String, income: String, value: Double) {
        (formatter.format(spent, decimalDigits: 0), formatter.format(income, decimalDigits: 0), income <= 0 ? 0 : spent / income)
    }

    /// HomeView.swift:247 and 253 (FlowChip).
    static func chip(amount: Double, delta: Double?, previousMonthName: String, formatter: MoneyFormatter) -> (amount: String, delta: String) {
        (formatter.format(amount, decimalDigits: 0), HomeSummary.deltaLabel(delta: delta, previousMonthName: previousMonthName))
    }

    /// HomeView.swift:278-282, 320-326, 317 (SafeToSpendCard).
    static func card(_ breakdown: SafeToSpendBreakdown, formatter: MoneyFormatter) -> (title: String, amount: String, subtitle: String, label: String) {
        let isOver = breakdown.isOverCommitted
        let title = isOver ? "Projected shortfall" : "Safe to spend"
        let amount = formatter.format(isOver ? breakdown.overCommitment : breakdown.safeToSpend, decimalDigits: 0)
        func subtitle(isOver: Bool) -> String {
            let days = breakdown.daysRemaining
            if days <= 0 { return "This month is already closed out" }
            if isOver { return "Add income or reduce planned spending" }
            let daily = formatter.format(breakdown.dailyAllowance, decimalDigits: 0)
            return "\(daily)/day for \(days == 1 ? "1 day left" : "\(days) days left")"
        }
        let sub = subtitle(isOver: isOver)
        return (title, amount, sub, "\(title) \(amount). \(sub). Double tap for breakdown.")
    }

    /// SafeToSpendSheet.swift:22-23, 30-33, 40-52, 85-93, 100.
    static func sheet(_ breakdown: SafeToSpendBreakdown, formatter: MoneyFormatter) -> [String] {
        let isOver = breakdown.isOverCommitted
        let title = isOver ? "Projected shortfall" : "Safe to spend"
        func text(_ value: Double, positive: Bool = false, emphasized: Bool = false) -> String {
            formatter.formatSigned(positive ? value : -value, plusForPositive: positive && !emphasized)
        }
        var footer: String {
            let days = breakdown.daysRemaining
            if days <= 0 { return "This month is already closed out." }
            let daysLabel = days == 1 ? "1 day remaining" : "\(days) days remaining"
            if breakdown.isOverCommitted {
                return "Add income or reduce planned spending to close the shortfall \u{00B7} \(daysLabel)"
            }
            return "\(formatter.format(breakdown.dailyAllowance)) per day \u{00B7} \(daysLabel)"
        }
        return [
            title,
            isOver
                ? "What you have spent and reserved for the rest of this month is more than the income you expect."
                : "A forward-looking estimate for the rest of this month.",
            "Income recorded", text(breakdown.actualIncome, positive: true),
            "Income still expected", text(breakdown.expectedIncome, positive: true),
            "Expenses recorded", text(breakdown.actualExpenses),
            "Upcoming recurring bills", text(breakdown.upcomingRecurringExpenses),
            "Flexible budget reserve", text(breakdown.flexibleBudgetReserve),
            "Suggested goal contributions", text(breakdown.plannedGoalContributions),
            title, text(isOver ? breakdown.overCommitment : breakdown.safeToSpend, positive: true, emphasized: true),
            footer,
        ]
    }

    /// BudgetsSection.swift:73-75 (`BudgetsSection.amount`).
    static func budgetAmount(_ value: Double, _ formatter: MoneyFormatter) -> String {
        formatter.format(value, decimalDigits: abs(value) >= 100 ? 0 : 2)
    }

    /// BudgetsSection.swift:127-130 (BudgetRow) and 49 (the add row).
    static func budgetRow(_ item: BudgetProgress, _ formatter: MoneyFormatter) -> (subtitle: String, chip: String) {
        let subtitle = "\(budgetAmount(item.spent, formatter)) of \(budgetAmount(item.limit, formatter))"
        let chip =
            item.isOver
            ? "\(budgetAmount(abs(item.remaining), formatter)) over" : "\(budgetAmount(item.remaining, formatter)) left"
        return (subtitle, chip)
    }

    static func addSubtitle(_ overview: FinancialData.BudgetOverview) -> String {
        overview.progress.isEmpty ? "No monthly limits yet" : "Set a limit for another category"
    }

    /// HomeView.swift:362-363, 375, 381, 387 (RecentRow).
    static func recent(_ record: TransactionRecord, _ formatter: MoneyFormatter) -> (title: String, subtitle: String, amount: String) {
        let isIncome = record.type == .income
        let day = DartDateFormat.MMMd(record.date)
        return (
            record.description.isEmpty ? "Transaction" : record.description,
            "\(record.category) \u{00B7} \(day)",
            formatter.formatSigned(isIncome ? record.amount : -record.amount, plusForPositive: true))
    }
}

private func same(_ actual: String, _ expected: String, _ label: String) {
    #expect(Array(actual.utf16) == Array(expected.utf16), "\(label): \(actual) | \(expected)")
}

private func same(_ actual: [String], _ expected: [String], _ label: String) {
    #expect(actual.map { Array($0.utf16) } == expected.map { Array($0.utf16) }, "\(label): \(actual) | \(expected)")
}

@Suite("Home page: hero, gauge, chips, safe to spend, budgets and recent activity copy match the Flutter page (Fixtures/home/tz)")
struct HomePageParityTests {
    /// Every text the real `SpendingPage` showed for each dataset, against
    /// the shared helpers (`HomeSummary`) and against a verbatim copy of what
    /// the Swift views compute today.
    @Test("page copy", arguments: homePageZones)
    func page(zone: String) throws {
        let f = try fixture(zone)
        #expect(f["tz"].string == zone)
        let tz = TimeZone(identifier: zone)!
        let calendar = DartCalendar(timeZone: tz)
        let cases = f["cases"].array
        #expect(cases.count >= 22)
        var statuses = Set<String>(), subtitles = Set<String>(), chips = 0, over = 0, closed = 0, noData = 0, addRows = 0, noAddRows = 0, emptyRecent = 0
        var dots = 0, fallbackTitle = 0, daysLeftOne = 0, shortfalls = 0, pill = Set<String>()

        for c in cases {
            let name = c["name"].string!
            let label = "\(zone) \(name)"
            let now = DartDateTime(microsecondsSinceEpoch: Int64(c["clockUs"].int!), timeZone: tz)
            #expect(now.toIso8601String() == c["clock"].string, "\(label) clock")
            let sections = try JSONParser.parse(c["sections"].string!).objectValue!
            let data = FinancialData.load(
                FinancialSnapshot(revision: 1, sections: sections), preferences: InMemoryPreferences([:]), calendar: calendar,
                now: { now }, newID: { UUID().uuidString.lowercased() }
            ).data
            let formatter = MoneyFormatter(
                currencyCode: c["currency"].string!, locale: c["locale"].string, hideBalances: c["hide"].bool!)
            let month = try calendar.parse(c["month"].string!)
            let ledger = LedgerIndex.build(data.transactions, calendar: calendar)
            let totals = ledger.summary(forMonth: month)
            let previous = HomeSummary.previousMonth(of: month, calendar: calendar)
            let previousTotals = ledger.summary(forMonth: previous)
            let previousName = DartDateFormat.MMMM(previous)
            // HomeView.swift:108-110.
            let breakdown = SafeToSpend.calculate(
                transactions: data.transactions, templates: data.templates, budgetLimits: data.budgetLimits,
                savingsGoals: data.savingsGoals, month: month, asOf: now, wallClock: now, calendar: calendar)
            let page = c["page"]
            if c["hide"].bool! { dots += 1 }

            // Month pill (HomeView.swift:78).
            same(DartDateFormat.yMMMM(month), page["pill"].string!, "\(label) pill")
            pill.insert(page["pill"].string!)

            // Hero.
            let heroTexts = strings(page["hero"]["texts"])
            #expect(heroTexts.count == 4 && heroTexts[0] == "CASH FLOW", "\(label) hero texts")
            let hero = HomeSummary.hero(income: totals.income, expenses: totals.expenses, formatter: formatter)
            let viewHero = ViewExpr.hero(income: totals.income, expenses: totals.expenses, formatter: formatter)
            same(hero.amount, heroTexts[1], "\(label) hero amount")
            same(hero.subline, heroTexts[2], "\(label) hero subline")
            same(hero.status, heroTexts[3], "\(label) hero status")
            same(hero.accessibilityLabel, page["hero"]["semantics"].string!, "\(label) hero semantics")
            same(viewHero.amountLabel, heroTexts[1], "\(label) view hero amount")
            same(viewHero.subline, heroTexts[2], "\(label) view hero subline")
            same(viewHero.status, heroTexts[3], "\(label) view hero status")
            same(viewHero.label, page["hero"]["semantics"].string!, "\(label) view hero semantics")
            #expect(hero.isNegative == viewHero.isNegative)
            statuses.insert(heroTexts[3])

            // Gauge.
            let gaugeTexts = strings(page["gauge"]["texts"])
            let labels = HomeSummary.gaugeLabels(spent: totals.expenses, income: totals.income, formatter: formatter)
            let viewGauge = ViewExpr.gauge(spent: totals.expenses, income: totals.income, formatter: formatter)
            same(gaugeTexts, ["SPENT  \(labels.spent)", "INCOME  \(labels.income)"], "\(label) gauge labels")
            same(gaugeTexts, ["SPENT  \(viewGauge.spent)", "INCOME  \(viewGauge.income)"], "\(label) view gauge labels")
            let gaugeValue = HomeSummary.gaugeFraction(spent: totals.expenses, income: totals.income)
            #expect(hex(gaugeValue) == page["gauge"]["value"].string, "\(label) gauge fraction")
            #expect(hex(viewGauge.value) == page["gauge"]["value"].string, "\(label) view gauge fraction")

            // Flow chips: label, amount, delta line.
            let chipRows = page["chips"].array
            #expect(chipRows.count == 2, "\(label) chips")
            for (index, (title, amount, previousAmount)) in [
                ("Income", totals.income, previousTotals.income), ("Expenses", totals.expenses, previousTotals.expenses),
            ].enumerated() {
                let delta = HomeSummary.percentDelta(current: amount, previous: previousAmount)
                let expected = strings(chipRows[index])
                let view = ViewExpr.chip(amount: amount, delta: delta, previousMonthName: previousName, formatter: formatter)
                same(expected, [title, HomeSummary.chipAmount(amount, formatter: formatter), HomeSummary.deltaLabel(delta: delta, previousMonthName: previousName)], "\(label) \(title) chip")
                same(expected, [title, view.amount, view.delta], "\(label) view \(title) chip")
                chips += 1
            }

            // Safe-to-spend card and sheet.
            let cardTexts = strings(page["card"]["texts"])
            let card = HomeSummary.safeToSpendCard(breakdown, formatter: formatter)
            let viewCard = ViewExpr.card(breakdown, formatter: formatter)
            same(cardTexts, [card.title, card.subtitle, card.amount, "DETAILS"], "\(label) card")
            same(cardTexts, [viewCard.title, viewCard.subtitle, viewCard.amount, "DETAILS"], "\(label) view card")
            same(card.accessibilityLabel, page["card"]["semantics"].string!, "\(label) card semantics")
            same(viewCard.label, page["card"]["semantics"].string!, "\(label) view card semantics")
            let sheetTexts = strings(c["sheet"])
            same(HomeSummary.breakdownSheet(breakdown, formatter: formatter).texts, sheetTexts, "\(label) sheet")
            same(ViewExpr.sheet(breakdown, formatter: formatter), sheetTexts, "\(label) view sheet")
            same(HomeSummary.breakdownFooter(breakdown, formatter: formatter), sheetTexts.last!, "\(label) footer")
            subtitles.insert(card.subtitle.contains("/day for") ? "daily" : card.subtitle)
            if card.isOver { shortfalls += 1 }
            if breakdown.daysRemaining <= 0 { closed += 1 }
            if breakdown.daysRemaining == 1 { daysLeftOne += 1 }

            // Budget rows, the add row, the expense category order.
            let overview = data.budgetOverview(totals)
            same(data.categoryPicker(for: .expense).map(\.name), strings(c["expenseCategories"]), "\(label) expense categories")
            let rows = page["budgets"]["rows"].array
            #expect(overview.progress.count == rows.count, "\(label) budget rows \(overview.progress.map(\.category)) vs \(rows.map { strings($0["texts"]) })")
            for (item, row) in zip(overview.progress, rows) {
                let copy = HomeSummary.budgetRow(item, formatter: formatter)
                let view = ViewExpr.budgetRow(item, formatter)
                same(strings(row["texts"]), [item.category, copy.subtitle, copy.chip], "\(label) \(item.category) row")
                same(strings(row["texts"]), [item.category, view.subtitle, view.chip], "\(label) view \(item.category) row")
                #expect(hex(item.progress) == row["bar"].string, "\(label) \(item.category) bar")
                if item.isOver { over += 1 }
            }
            if overview.progress.isEmpty { noData += 1 }
            if page["budgets"]["add"].isNull {
                #expect(overview.unbudgeted.isEmpty, "\(label) no add row only when every category has a limit")
                noAddRows += 1
            } else {
                #expect(!overview.unbudgeted.isEmpty, "\(label) add row")
                let add = strings(page["budgets"]["add"])
                same(add, ["Add a budget", HomeSummary.addBudgetSubtitle(hasBudgets: !overview.progress.isEmpty)], "\(label) add row")
                same(add, ["Add a budget", ViewExpr.addSubtitle(overview)], "\(label) view add row")
                addRows += 1
            }

            // Recent activity: the newest three of any month.
            let recent = page["recent"]
            let recentRows = recent["rows"].array
            let swiftRecent = ledger.recent(3)
            #expect(recent["empty"].bool == swiftRecent.isEmpty, "\(label) empty")
            if swiftRecent.isEmpty { emptyRecent += 1 }
            #expect(swiftRecent.count == recentRows.count, "\(label) recent count")
            for (row, expected) in zip(swiftRecent, recentRows) {
                let copy = HomeSummary.recentRow(row.record, formatter: formatter)
                let view = ViewExpr.recent(row.record, formatter)
                same(strings(expected), [copy.title, copy.subtitle, copy.amount], "\(label) recent \(row.record.id)")
                same(strings(expected), [view.title, view.subtitle, view.amount], "\(label) view recent \(row.record.id)")
                if row.record.description.isEmpty { fallbackTitle += 1 }
            }
        }
        #expect(statuses == ["SAVED THIS MONTH", "SHORT THIS MONTH", "BREAKING EVEN"], "all three statuses \(statuses)")
        #expect(chips == 2 * cases.count && over >= 2 && closed >= 1 && noData >= 3 && addRows >= 10 && noAddRows >= 1 && emptyRecent >= 1, "coverage")
        #expect(dots >= 1 && fallbackTitle >= 1 && daysLeftOne >= 1 && shortfalls >= 1 && pill.count >= 4, "coverage 2")
        #expect(subtitles.count >= 3, "card subtitles \(subtitles)")
    }
}
