import BudgieCore
import SwiftUI

/// Spending tab (UI_SPEC "Spending").
struct SpendingView: View {
    @Environment(AppModel.self) private var model
    /// View state only; nil follows the current month (not persisted, like Flutter).
    @State private var chosenMonth: DartDateTime?
    @State private var sheet: SpendingSheet?
    @State private var pendingDelete: TransactionRecord?

    init() {}

    var body: some View {
        NavigationStack {
            Group {
                if let data = model.data {
                    content(data)
                } else {
                    ProgressView()
                }
            }
            .background(Theme.background)
            .navigationTitle("Spending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add Expense", systemImage: "minus.circle") { sheet = .add(.expense) }
                        Button("Add Income", systemImage: "plus.circle") { sheet = .add(.income) }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add transaction")
                }
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .add(let type): TransactionFormView(mode: .add(type))
                case .edit(let record): TransactionFormView(mode: .edit(record))
                case .breakdown(let breakdown):
                    SpendingSafeToSpendSheet(breakdown: breakdown, formatter: model.moneyFormatter)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .confirmationDialog(
                "Delete this transaction?", isPresented: deleteDialogBinding, titleVisibility: .visible,
                presenting: pendingDelete
            ) { record in
                Button("Delete", role: .destructive) {
                    Task { await model.deleteTransaction(id: record.id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { record in
                Text(record.description)
            }
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ data: FinancialData) -> some View {
        let calendar = model.calendar
        let month = chosenMonth ?? calendar.month(of: model.now)
        let totals = data.totals(forMonth: month)
        let rows = data.transactionsNewestFirst(inMonth: month)
        let formatter = model.moneyFormatter
        let categories = totals.categoryExpenses.sorted { $0.1 > $1.1 }
        let breakdown = SafeToSpend.calculate(
            transactions: data.transactions, templates: data.templates, budgetLimits: data.budgetLimits,
            savingsGoals: data.savingsGoals, month: month, asOf: model.now, wallClock: model.now, calendar: calendar)

        List {
            Section {
                monthSelector(data, current: month)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            Section {
                SpendingTotalsCard(income: totals.income, expenses: totals.expenses, formatter: formatter)
                Button { sheet = .breakdown(breakdown) } label: {
                    SpendingSafeToSpendCard(breakdown: breakdown, formatter: formatter)
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(Theme.card)

            if rows.isEmpty {
                Section {
                    ContentUnavailableView("No transactions this month", systemImage: "tray")
                        .listRowBackground(Color.clear)
                }
            } else {
                if !categories.isEmpty {
                    Section("Expenses by category") {
                        ForEach(categories, id: \.0) { name, amount in
                            HStack(spacing: 12) {
                                CategoryIcon(info: model.categoryInfo(named: name, type: .expense))
                                Text(name).lineLimit(1)
                                Spacer(minLength: 8)
                                Text(formatter.format(amount))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .truncationMode(.head)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(name), \(formatter.format(amount))")
                        }
                    }
                    .listRowBackground(Theme.card)
                }
                Section("Transactions") {
                    ForEach(rows) { record in
                        Button { sheet = .edit(record) } label: {
                            SpendingRow(
                                record: record, info: model.categoryInfo(named: record.category, type: record.type),
                                formatter: formatter)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = record }
                        }
                        .accessibilityHint("Opens the transaction for editing")
                    }
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Month selector

    private func monthSelector(_ data: FinancialData, current: DartDateTime) -> some View {
        let calendar = model.calendar
        let thisMonth = calendar.month(of: model.now)
        var months = data.availableMonths()
        for extra in [thisMonth, current] where !months.contains(extra) { months.append(extra) }
        months.sort { $0 > $1 }
        let f = current.fields
        return HStack {
            Button {
                chosenMonth = calendar.date(f.year, f.month - 1)
            } label: {
                Image(systemName: "chevron.left").padding(8)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Menu {
                Picker("Month", selection: Binding(get: { current }, set: { chosenMonth = $0 })) {
                    ForEach(months, id: \.self) { Text(DartDateFormat.yMMMM($0)).tag($0) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(DartDateFormat.yMMMM(current)).font(.headline)
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                }
            }
            .accessibilityLabel("Month, \(DartDateFormat.yMMMM(current))")
            Spacer()
            Button {
                chosenMonth = calendar.date(f.year, f.month + 1)
            } label: {
                Image(systemName: "chevron.right").padding(8)
            }
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.borderless)
    }
}

enum SpendingSheet: Identifiable {
    case add(TransactionType)
    case edit(TransactionRecord)
    case breakdown(SafeToSpendBreakdown)

    var id: String {
        switch self {
        case .add(let type): "add-\(type.rawValue)"
        case .edit(let record): "edit-\(record.id)"
        case .breakdown: "breakdown"
        }
    }
}

// MARK: - Cards and rows

private struct SpendingTotalsCard: View {
    let income: Double
    let expenses: Double
    let formatter: MoneyFormatter

    var body: some View {
        let net = income - expenses
        let label = net > 0 ? "Saved this month" : (net < 0 ? "Short this month" : "Breaking even")
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                figure("Income", income, Theme.income)
                figure("Expenses", expenses, Theme.expense)
            }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline).foregroundStyle(.secondary)
                Text(formatter.formatSigned(net))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .truncationMode(.head)
                    .foregroundStyle(net >= 0 ? Theme.income : Theme.expense)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Income \(formatter.format(income)). Expenses \(formatter.format(expenses)). \(label) \(formatter.formatSigned(net)).")
    }

    private func figure(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(formatter.format(value))
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .truncationMode(.head)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SpendingSafeToSpendCard: View {
    let breakdown: SafeToSpendBreakdown
    let formatter: MoneyFormatter

    var body: some View {
        let isOver = breakdown.isOverCommitted
        let tint = isOver ? Theme.expense : Theme.accent
        let title = isOver ? "Projected shortfall" : "Safe to spend"
        let amount = formatter.format(isOver ? breakdown.overCommitment : breakdown.safeToSpend, decimalDigits: 0)
        let days = breakdown.daysRemaining
        let subtitle: String = {
            if days <= 0 { return "This month is already closed out" }
            if isOver { return "Add income or reduce planned spending" }
            let daily = formatter.format(breakdown.dailyAllowance, decimalDigits: 0)
            return "\(daily)/day for \(days == 1 ? "1 day left" : "\(days) days left")"
        }()
        HStack(spacing: 12) {
            Image(systemName: isOver ? "exclamationmark.triangle.fill" : "shield.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(subtitle).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount)
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .truncationMode(.head)
                    .foregroundStyle(tint)
                HStack(spacing: 2) {
                    Text("DETAILS").font(.caption2.weight(.bold)).lineLimit(1).fixedSize()
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                }
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 120, alignment: .trailing)
            .layoutPriority(2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(amount). \(subtitle).")
        .accessibilityHint("Shows the breakdown")
        .accessibilityAddTraits(.isButton)
    }
}

private struct SpendingRow: View {
    let record: TransactionRecord
    let info: CategoryInfo?
    let formatter: MoneyFormatter

    var body: some View {
        let isIncome = record.type == .income
        let amount = formatter.formatSigned(isIncome ? record.amount : -record.amount, plusForPositive: true)
        let day = DartDateFormat.MMMd(record.date)
        HStack(spacing: 12) {
            CategoryIcon(info: info)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.description).lineLimit(1)
                Text("\(record.category) \u{00B7} \(day)").font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(amount)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.head)
                .foregroundStyle(isIncome ? Theme.income : Theme.expense)
                .frame(maxWidth: 170, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(record.description), \(record.category), \(day), \(isIncome ? "income" : "expense") \(formatter.format(record.amount))"
        )
    }
}
