import BudgieCore
import SwiftUI

/// The "SEE ALL" page pushed from Home (`transaction_page.dart`): a strip of
/// month chips, that month's summary card, and its transactions grouped by
/// day under pinned date headers. Rows open the edit form and swipe to
/// delete behind a confirmation.
///
/// The selected month is local to the page (it does not follow
/// `model.selectedMonth`). Everything is read from `model.ledger`, which is
/// rebuilt off the main thread after each change, so nothing here re-scans
/// the transactions.
struct TransactionsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The month the user tapped. `nil` (or a month that no longer has
    /// transactions) means the newest available month.
    @State private var chosenMonth: DartDateTime?
    @State private var editing: TransactionRecord?
    @State private var showingAdd = false
    @State private var pendingDelete: TransactionRecord?
    @State private var monthTaps = 0
    @State private var rowTaps = 0
    @State private var deleteConfirms = 0

    var body: some View {
        let ledger = model.ledger
        let months = ledger.availableMonths
        let month = effectiveMonth(in: months)
        let formatter = model.moneyFormatter

        Group {
            if let month {
                VStack(spacing: 0) {
                    MonthStrip(months: months, selected: month, reduceMotion: reduceMotion) { picked in
                        monthTaps += 1
                        chosenMonth = picked
                    }
                    SummaryCard(summary: ledger.summary(forMonth: month), formatter: formatter)
                        .padding(.horizontal, Metrics.spacingM)
                    monthContent(rows: ledger.newestFirst(inMonth: month), formatter: formatter)
                        .padding(.top, Metrics.spacingM)
                }
            } else {
                EmptyStateView(
                    kind: .noData, symbol: "dollarsign.circle", title: "No Transactions Yet",
                    message: "Start tracking your finances by adding your first transaction",
                    actionTitle: "Add Transaction"
                ) { showingAdd = true }
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BudgieColor.background)
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(BudgieColor.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Transactions")
                    .textStyle(.sectionHeader)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .onChange(of: model.ledgerRevision) { _, _ in
            // The chosen month lost its last row: leave it for good rather
            // than snapping back to it if a row is added there later.
            if let chosenMonth, !model.ledger.availableMonths.contains(chosenMonth) { self.chosenMonth = nil }
        }
        .sheet(item: $editing) { record in
            TransactionFormView(mode: .edit(record))
        }
        .sheet(isPresented: $showingAdd) {
            TransactionFormView(mode: .add(.expense))
        }
        .alert(
            "Delete Transaction", isPresented: deleteAlertBinding, presenting: pendingDelete
        ) { record in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteConfirms += 1
                Task {
                    // Already gone (deleted elsewhere): nothing failed.
                    guard model.hasTransaction(id: record.id) else { return }
                    let saved = await model.deleteTransaction(id: record.id)
                    model.showToast(saved ? .transactionDeleted : .saveFailed)
                }
            }
        } message: { _ in
            Text("Are you sure you want to delete this transaction?")
        }
        .sensoryFeedback(.selection, trigger: monthTaps)
        .sensoryFeedback(.impact(weight: .light), trigger: rowTaps)
        .sensoryFeedback(.impact(weight: .heavy), trigger: deleteConfirms)
    }

    // MARK: - State

    /// The chosen month if it still has transactions, else the newest.
    private func effectiveMonth(in months: [DartDateTime]) -> DartDateTime? {
        if let chosenMonth, months.contains(chosenMonth) { return chosenMonth }
        return months.first
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    // MARK: - List

    @ViewBuilder
    private func monthContent(rows: ArraySlice<LedgerRow>, formatter: MoneyFormatter) -> some View {
        if rows.isEmpty {
            EmptyStateView(kind: .noData, symbol: "tray", title: "No Transactions", message: "No transactions for this month")
                .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(DayGroup.build(from: rows)) { group in
                        Section {
                            ForEach(group.rows) { row in
                                SwipeToDeleteRow {
                                    pendingDelete = row.record
                                } content: {
                                    TransactionRow(record: row.record, formatter: formatter) {
                                        rowTaps += 1
                                        editing = row.record
                                    }
                                }
                                .padding(.horizontal, Metrics.spacingM)
                                .padding(.bottom, Metrics.spacingS)
                            }
                        } header: {
                            DateHeader(title: group.title)
                        }
                    }
                }
                // The scroll view already insets its content for the tab bar
                // and home indicator; this is only breathing room.
                .padding(.bottom, Metrics.spacingS)
            }
        }
    }
}

// MARK: - Grouping

/// One calendar day of a month's rows (`DateFormat.yMMMd` group key).
private struct DayGroup: Identifiable {
    let id: Int
    let title: String
    var rows: [LedgerRow]

    /// The rows arrive newest first, so a day's rows are contiguous.
    static func build(from rows: ArraySlice<LedgerRow>) -> [DayGroup] {
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
}

// MARK: - Summary card

private struct SummaryCard: View {
    let summary: MonthSummary
    let formatter: MoneyFormatter

    /// Flutter `AppTypography.amount` at 20.
    private static let amountText = TextSpec(face: .gabaritoBold, size: 20, tabular: true, relativeTo: .title3)
    /// `rowSubtitle` at 13, w600 (the Income / Expenses labels).
    private static let labelText = TextSpec(face: .gabaritoSemiBold, size: 13, height: 1.25, relativeTo: .footnote)
    /// `rowTitle` at 16, w700.
    private static let netLabel = TextSpec(face: .gabaritoBold, size: 16, height: 1.25, relativeTo: .body)

    var body: some View {
        let net = summary.net
        let income = formatter.format(summary.income)
        let expenses = formatter.format(summary.expenses)
        let netText = formatter.formatSigned(net)
        GlowCard(padding: Metrics.spacingM) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    figure("Income", income, BudgieColor.income)
                    figure("Expenses", expenses, BudgieColor.danger)
                }
                // Flutter `Divider(height: 24)`: the line centred in 24pt.
                Hairline().padding(.vertical, 11.5)
                HStack(spacing: Metrics.spacingS) {
                    Text("Net Cash Flow")
                        .textStyle(Self.netLabel)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(netText)
                        .textStyle(Self.amountText)
                        .foregroundStyle(net >= 0 ? BudgieColor.income : BudgieColor.danger)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Income \(income). Expenses \(expenses). Net cash flow \(netText).")
    }

    private func figure(_ title: String, _ amount: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            Text(title).textStyle(Self.labelText).foregroundStyle(BudgieColor.textSecondary)
            Text(amount)
                .textStyle(Self.amountText)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Date header

/// A pinned 48pt header in the page background so scrolled rows hide behind
/// it, holding a left-aligned mono pill.
private struct DateHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .textStyle(.monoLabel)
            .foregroundStyle(BudgieColor.textSecondary)
            .padding(.horizontal, Metrics.spacingM)
            .padding(.vertical, Metrics.spacingXS)
            .background(BudgieColor.chipSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(BudgieColor.cardBorder, lineWidth: 1))
            .padding(.horizontal, Metrics.spacingM)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(BudgieColor.background)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Row

/// The older Flutter row (`ModernTransactionListItem`) on the redesign
/// tokens: a solid type-coloured tile with the white category symbol, title
/// with an inline recurrence glyph, "Category • Mon d", and the unsigned
/// amount in the type colour.
private struct TransactionRow: View {
    @Environment(AppModel.self) private var model
    let record: TransactionRecord
    let formatter: MoneyFormatter
    let onTap: () -> Void

    /// Flutter `headingMedium` forced bold.
    private static let amountText = TextSpec(face: .gabaritoBold, size: 22, tracking: -0.2, height: 1.3, relativeTo: .title2)

    var body: some View {
        let isIncome = record.type == .income
        let color = isIncome ? BudgieColor.income : BudgieColor.danger
        let info = model.categoryInfo(named: record.category, type: record.type)
        let amount = formatter.format(record.amount)
        let card = RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)

        Button(action: onTap) {
            HStack(spacing: Metrics.spacingM) {
                Image(systemName: CategoryCatalog.symbol(for: info?.iconIdentifier ?? ""))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(color, in: RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous))
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    HStack(spacing: 6) {
                        Text(record.description)
                            .textStyle(.labelLarge)
                            .foregroundStyle(BudgieColor.textPrimary)
                            .multilineTextAlignment(.leading)
                        if record.isRecurring { RecurrenceGlyph(size: 16).fixedSize() }
                    }
                    Text("\(record.category) \u{2022} \(DartDateFormat.MMMd(record.date))")
                        .textStyle(.caption)
                        .foregroundStyle(BudgieColor.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Its own width first (Flutter's amount is not flexible), so
                // the title and subtitle get the rest of the row.
                Text(amount)
                    .textStyle(Self.amountText)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .layoutPriority(1)
            }
            .padding(Metrics.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BudgieColor.card, in: card)
            .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
            .contentShape(card)
        }
        .buttonStyle(.plain)
        // On the Button itself, so VoiceOver keeps its activation.
        .accessibilityLabel(
            "\(record.description), \(isIncome ? "income" : "expense") \(amount), category \(record.category), on \(DartDateFormat.yMMMMd(record.date))"
                + (record.isRecurring ? ", recurring" : "")
        )
        .accessibilityHint("Double tap to edit, swipe left to delete")
    }
}
