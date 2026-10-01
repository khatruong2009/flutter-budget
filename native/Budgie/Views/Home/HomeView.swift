import BudgieCore
import SwiftUI

/// The Home tab (`SpendingPage`, spending_page.dart:448-686): header with
/// the month pill and its wheel panel, the cash-flow hero, the spend gauge,
/// the income/expense chips, safe to spend, budgets, recent activity and
/// the Expense/Income pills, with the add button floating bottom-trailing
/// under the smaller voice button.
/// Everything is read from `model.ledger` except safe to spend, whose Core
/// calculation takes the transactions.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sheet: HomeSheet?
    @State private var monthPanelOpen = false
    @State private var page: HomePage?
    /// A category picked in the quick-expense sheet; its form opens once
    /// that sheet has been dismissed.
    @State private var pendingQuickCategory: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                HomeMonthPanel(expanded: monthPanelOpen)
                if let data = model.data {
                    content(data)
                } else {
                    ProgressView().padding(.top, 48)
                }
            }
            // Clears the buttons (20 + 54 + 12 + 44 above the tab bar).
            .padding(.bottom, 130)
        }
        .background(BudgieColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $page) { _ in TransactionsView() }
        .overlay(alignment: .bottomTrailing) {
            // The mic over the add button, centred on it (Flutter's Column).
            VStack(spacing: 12) {
                GlowFab(symbol: "mic.fill", size: Metrics.micFabSize, label: "Add by voice") {
                    model.pendingAdd = .voice
                }
                .accessibilityIdentifier("home.voice")
                GlowFab(label: "Add transaction") {
                    sheet = .add(.expense)
                } longPress: {
                    sheet = .quickExpense
                }
            }
            .padding(.trailing, Metrics.fabInset)
            .padding(.bottom, Metrics.fabInset)
        }
        .sheet(item: $sheet, onDismiss: openPendingQuickCategory) { item in
            switch item {
            case .add(let type):
                TransactionFormView(mode: .add(type))
            case .addExpense(let category):
                TransactionFormView(mode: .add(.expense), initialCategory: category)
            case .breakdown(let breakdown):
                SafeToSpendSheet(breakdown: breakdown, formatter: model.moneyFormatter)
            case .quickExpense:
                QuickExpenseSheet { pendingQuickCategory = $0 }
            }
        }
    }

    private func openPendingQuickCategory() {
        guard let category = pendingQuickCategory else { return }
        pendingQuickCategory = nil
        sheet = .addExpense(category: category)
    }

    // MARK: - Header

    private var header: some View {
        BudgieHeader(showLogo: true, centerTrailing: true) {
            MonthPill(label: DartDateFormat.yMMMM(model.selectedMonth)) {
                // Explicit, so the sections below move with the panel.
                withAnimation(reduceMotion ? nil : Motion.easeInOut(0.25)) { monthPanelOpen.toggle() }
            }
            .accessibilityIdentifier("home.monthPill")
        } accessory: {
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(BudgieColor.textSecondary)
                    // The glyph's 36pt slot is unchanged; the tap area is
                    // the 44pt minimum, centred on it.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("home.settings")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func content(_ data: FinancialData) -> some View {
        let calendar = model.calendar
        let month = model.selectedMonth
        let formatter = model.moneyFormatter
        let totals = model.ledger.summary(forMonth: month)
        let previous = HomeSummary.previousMonth(of: month, calendar: calendar)
        let previousTotals = model.ledger.summary(forMonth: previous)
        let previousName = DartDateFormat.MMMM(previous)
        let breakdown = Signpost.ui.withIntervalSignpost("home.safeToSpend") {
            SafeToSpend.calculate(
                transactions: data.transactions, templates: data.templates, budgetLimits: data.budgetLimits,
                savingsGoals: data.savingsGoals, month: month, asOf: model.now, wallClock: model.now, calendar: calendar)
        }

        HomeHero(income: totals.income, expenses: totals.expenses, formatter: formatter)

        SpendGauge(spent: totals.expenses, income: totals.income, formatter: formatter)
            .padding(.horizontal, 24)
            .padding(.top, 20)

        HStack(spacing: 12) {
            FlowChip(
                label: "Income", amount: totals.income, dot: BudgieColor.income,
                delta: HomeSummary.percentDelta(current: totals.income, previous: previousTotals.income),
                deltaColor: BudgieColor.income, previousMonthName: previousName, formatter: formatter)
            FlowChip(
                label: "Expenses", amount: totals.expenses, dot: BudgieColor.danger,
                delta: HomeSummary.percentDelta(current: totals.expenses, previous: previousTotals.expenses),
                deltaColor: BudgieColor.danger, previousMonthName: previousName, formatter: formatter)
        }
        .padding(.horizontal, Metrics.pageHorizontal)
        .padding(.top, 20)

        SafeToSpendCard(breakdown: breakdown, formatter: formatter) { sheet = .breakdown(breakdown) }
            .padding(.horizontal, Metrics.pageHorizontal)
            .padding(.top, 12)

        // Applies its own page padding.
        BudgetsSection()
            .padding(.top, Metrics.sectionGap)

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent activity", link: "SEE ALL", linkAccessibilityLabel: "See all transactions") {
                page = .transactions
            }
            RecentActivityCard(rows: model.ledger.recent(3), formatter: formatter)
        }
        .padding(.horizontal, Metrics.pageHorizontal)
        .padding(.top, Metrics.sectionGap)

        HStack(spacing: 12) {
            PillButton(title: "Expense", symbol: "minus", color: BudgieColor.danger) { sheet = .add(.expense) }
            PillButton(title: "Income", symbol: "plus", color: BudgieColor.income) { sheet = .add(.income) }
        }
        .padding(.horizontal, Metrics.pageHorizontal)
        .padding(.top, 24)
    }
}

/// The page Home pushes from SEE ALL. Pushed by item, never with
/// `navigationDestination(isPresented:)`: that form rebuilt the pushed page
/// each time an accessibility client read the screen, which kept the main
/// thread busy under XCUITest (see UI_SPEC "Shell").
private enum HomePage {
    case transactions
}

/// Home's sheets, one at a time.
enum HomeSheet: Identifiable {
    case add(TransactionType)
    /// The expense form with a category from the quick-expense sheet.
    case addExpense(category: String)
    case breakdown(SafeToSpendBreakdown)
    case quickExpense

    var id: String {
        switch self {
        case .add(let type): "add-\(type.rawValue)"
        case .addExpense(let category): "add-expense-\(category)"
        case .breakdown: "breakdown"
        case .quickExpense: "quick-expense"
        }
    }
}

// MARK: - Spend gauge

/// Spent against income (spending_page.dart:1388-1461): the 14pt gauge,
/// then "SPENT  $43" and "INCOME  $3,200" (whole units).
private struct SpendGauge: View {
    let spent: Double
    let income: Double
    let formatter: MoneyFormatter

    var body: some View {
        let labels = HomeSummary.gaugeLabels(spent: spent, income: income, formatter: formatter)
        VStack(spacing: 10) {
            GlowProgressBar(
                value: HomeSummary.gaugeFraction(spent: spent, income: income), height: 14, color: BudgieColor.accent,
                track: BudgieColor.chipSurface,
                gradient: LinearGradient(colors: [BudgieColor.gaugeFillStart, BudgieColor.accent], startPoint: .leading, endPoint: .trailing),
                showThumb: true, trackBorder: BudgieColor.hairline, fillInset: 2)
            HStack {
                label("SPENT  ", labels.spent)
                Spacer(minLength: 8)
                label("INCOME  ", labels.income)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spent \(labels.spent) of \(labels.income) income")
    }

    private func label(_ prefix: String, _ value: String) -> some View {
        (Text(prefix).foregroundStyle(BudgieColor.textTertiary) + Text(value).foregroundStyle(BudgieColor.textPrimary))
            .textStyle(.monoLabel)
            .singleLine()
    }
}

// MARK: - Flow chips

/// One of the two month-over-month chips (`_FlowChip`,
/// spending_page.dart:1465-1550). Not tappable.
private struct FlowChip: View {
    let label: String
    let amount: Double
    let dot: Color
    let delta: Double?
    let deltaColor: Color
    let previousMonthName: String
    let formatter: MoneyFormatter

    /// `rowSubtitle` at 13, w600.
    private static let labelStyle = TextSpec(face: .gabaritoSemiBold, size: 13, height: 1.25, relativeTo: .footnote)

    var body: some View {
        GlowCard(padding: 16, radius: Metrics.statCardRadius) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(dot)
                        .frame(width: 8, height: 8)
                        .glow(dot, blur: 10, alpha: 0.8)
                    Text(label)
                        .textStyle(Self.labelStyle)
                        .foregroundStyle(BudgieColor.textSecondary)
                        .singleLine()
                }
                Text(HomeSummary.chipAmount(amount, formatter: formatter))
                    .textStyle(.chipAmount)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .padding(.top, 10)
                Text(HomeSummary.deltaLabel(delta: delta, previousMonthName: previousMonthName))
                    .textStyle(.rowSubtitle)
                    .foregroundStyle(delta == nil ? BudgieColor.textTertiary : deltaColor)
                    .singleLine()
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Safe to spend

/// The safe-to-spend row (`_SafeToSpendCard`, spending_page.dart:1222-1328):
/// tap opens the breakdown. An over-committed month reads "Projected
/// shortfall" with the positive shortfall.
private struct SafeToSpendCard: View {
    let breakdown: SafeToSpendBreakdown
    let formatter: MoneyFormatter
    let onTap: () -> Void

    /// `captionSmall` with w700.
    private static let details = TextSpec(face: .gabaritoBold, size: 11, height: 1.3, relativeTo: .caption2)

    var body: some View {
        let card = HomeSummary.safeToSpendCard(breakdown, formatter: formatter)
        let isOver = card.isOver
        let tint = isOver ? BudgieColor.danger : BudgieColor.accent

        GlowCard(padding: 16, radius: Metrics.statCardRadius, onTap: onTap) {
            HStack(spacing: 0) {
                IconTile(symbol: isOver ? "exclamationmark.triangle" : "shield", color: tint)
                    .padding(.trailing, 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title)
                        .textStyle(.rowTitle)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .singleLine()
                    Text(card.subtitle)
                        .textStyle(.rowSubtitle)
                        .foregroundStyle(BudgieColor.textSecondary)
                        .singleLine()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(card.amount)
                        .textStyle(.chipAmount)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    HStack(spacing: 2) {
                        Text("DETAILS").textStyle(Self.details)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(BudgieColor.textTertiary)
                    .fixedSize()
                }
                .padding(.leading, 8)
                .layoutPriority(1)
            }
            .accessibilityElement(children: .ignore)
        }
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityIdentifier("home.safeToSpend")
    }
}

// MARK: - Recent activity

/// The newest three transactions of any month (`_RecentActivityCard`,
/// spending_page.dart:1706-1816). Rows are not tappable.
private struct RecentActivityCard: View {
    let rows: ArraySlice<LedgerRow>
    let formatter: MoneyFormatter

    /// `rowSubtitle` at 14.
    private static let empty = TextSpec(face: .gabaritoRegular, size: 14, height: 1.25, relativeTo: .subheadline)

    var body: some View {
        if rows.isEmpty {
            GlowCard {
                Text("No transactions yet.")
                    .textStyle(Self.empty)
                    .foregroundStyle(BudgieColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        } else {
            GlowListCard(rows: rows.map { RecentRow(record: $0.record, formatter: formatter) })
        }
    }
}

private struct RecentRow: View {
    let record: TransactionRecord
    let formatter: MoneyFormatter

    @Environment(AppModel.self) private var model

    var body: some View {
        let isIncome = record.type == .income
        let day = DartDateFormat.MMMd(record.date)
        let copy = HomeSummary.recentRow(record, formatter: formatter)
        HStack(spacing: 12) {
            if isIncome {
                IconTile(symbol: "arrow.down.left", color: BudgieColor.income)
            } else {
                IconTile(
                    symbol: CategoryCatalog.symbol(
                        for: model.categoryInfo(named: record.category, type: .expense)?.iconIdentifier ?? ""),
                    color: BudgieColor.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(copy.title)
                        .textStyle(.rowTitle)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .lineLimit(1)
                    if record.isRecurring { RecurrenceGlyph(size: 16).fixedSize() }
                }
                Text(copy.subtitle)
                    .textStyle(.rowSubtitle)
                    .foregroundStyle(BudgieColor.textSecondary)
                    .singleLine()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(copy.amount)
                .textStyle(.amountSmall)
                .foregroundStyle(isIncome ? BudgieColor.income : BudgieColor.textPrimary)
                .singleLine()
                .layoutPriority(1)
        }
        .padding(12)
        // Flutter's label is "description, category, day, type amount";
        // VoiceOver reads the label then the value, so this sounds the
        // same while the description stays findable on its own.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.title)
        .accessibilityValue(
            "\(record.category), \(day), \(isIncome ? "income" : "expense") \(formatter.format(record.amount))"
                + (record.isRecurring ? ", recurring" : ""))
        .accessibilityAddTraits(.isStaticText)
    }
}
