import BudgieCore
import SwiftUI

/// A category's expenses in one month (`CategoryTransactionsPage`,
/// category_transactions_page.dart), pushed from a Spend row: the tinted
/// "TOTAL SPENT" card, then the rows newest first. Rows open the edit form
/// and swipe to delete behind the confirmation (a superset of Flutter's
/// read-only, swipe-only rows, like D7).
///
/// Live: the rows come from `model.ledger` on every change, and the colour
/// and icon follow the category's current rank in the month (Flutter keeps
/// the ones it was pushed with); the pushed ones are used only once the
/// category has no expenses left. The month stays the pushed one.
struct CategoryTransactionsView: View {
    let drillIn: SpendDrillIn

    @Environment(AppModel.self) private var model
    @State private var editing: TransactionRecord?
    @State private var pendingDelete: TransactionRecord?
    @State private var deleteConfirms = 0

    var body: some View {
        let category = drillIn.category
        // `where(category == name && type == expense)` on the month's rows,
        // already `compareNewestFirst` in the ledger.
        let rows = model.ledger.newestFirst(inMonth: drillIn.month).filter {
            $0.record.type == .expense && DartString.equal($0.record.category, category)
        }
        // Folded in that order (:46-49).
        let total = rows.reduce(0.0) { $0 + $1.record.amount }
        let (color, symbol) = currentStyle()
        let formatter = model.moneyFormatter

        VStack(alignment: .leading, spacing: 0) {
            SummaryCard(
                total: formatter.format(total), month: drillIn.month, count: rows.count, color: color, symbol: symbol)
                .padding(.horizontal, Metrics.pageHorizontal)
                .padding(.top, 12)
            if rows.isEmpty {
                EmptyStateView(
                    kind: .noData, symbol: "list.bullet.rectangle", title: "No Transactions",
                    message: "No transactions found in this category for \(DartDateFormat.MMMM(drillIn.month))")
                    .frame(maxHeight: .infinity)
            } else {
                Text("TRANSACTIONS")
                    .textStyle(.eyebrow)
                    .foregroundStyle(BudgieColor.textTertiary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(EdgeInsets(top: 28, leading: 24, bottom: 0, trailing: 24))
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(rows) { row in
                            SwipeToDeleteRow {
                                pendingDelete = row.record
                            } content: {
                                ExpenseRow(record: row.record, color: color, symbol: symbol, formatter: formatter) {
                                    editing = row.record
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
                        }
                    }
                    .padding(EdgeInsets(top: 12, leading: Metrics.pageHorizontal, bottom: Metrics.pageHorizontal, trailing: Metrics.pageHorizontal))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BudgieColor.background)
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(BudgieColor.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(category)
                    .textStyle(.cardTitle)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .sheet(item: $editing) { record in
            TransactionFormView(mode: .edit(record))
        }
        .alert("Delete Transaction", isPresented: deleteAlertBinding, presenting: pendingDelete) { record in
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
        .sensoryFeedback(.impact(weight: .heavy), trigger: deleteConfirms)
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    /// The category's colour and icon as its Spend row shows them now, or
    /// the pushed ones when it is no longer in the month's breakdown.
    private func currentStyle() -> (Color, String) {
        guard let data = model.data else { return (drillIn.palette.color, drillIn.symbol) }
        let picker = data.categoryPicker(for: .expense)
        let breakdown = CategoryBreakdown.build(
            month: drillIn.month, ledger: model.ledger, budgetLimits: data.budgetLimits,
            activeExpenseCategories: picker.map(\.name))
        guard let record = breakdown.records.first(where: { DartString.equal($0.name, drillIn.category) }) else {
            return (drillIn.palette.color, drillIn.symbol)
        }
        return (record.palette.color, SpendDrillIn.symbol(for: record, in: SpendDrillIn.activeSymbols(picker)))
    }
}

/// `_buildSummaryCard` (:159-235): a card tinted from the category colour
/// at 22% (top-leading) to the plain card, a 30% border, "TOTAL SPENT", the
/// total with two decimals and the colour's text glow, the month and count
/// pills, and the 56pt tile.
private struct SummaryCard: View {
    let total: String
    let month: DartDateTime
    let count: Int
    let color: Color
    let symbol: String

    var body: some View {
        let countText = "\(count) transaction\(count == 1 ? "" : "s")"
        let monthText = DartDateFormat.MMMMyyyy(month)
        GlowCard(
            fill: AnyShapeStyle(LinearGradient(
                colors: [color.opacity(0.22), color.opacity(0)], startPoint: .topLeading, endPoint: .bottomTrailing)),
            border: color.opacity(0.3)
        ) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("TOTAL SPENT")
                        .textStyle(.eyebrow)
                        .foregroundStyle(BudgieColor.textSecondary)
                    Text(total)
                        .textStyle(.heroSmall)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .textGlow(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .padding(.top, 10)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { pills(monthText, countText) }
                        VStack(alignment: .leading, spacing: 8) { pills(monthText, countText) }
                    }
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                IconTile(symbol: symbol, color: color, size: 56, radius: 18, iconSize: 28)
            }
        }
        // The gradient is drawn over the plain card (Flutter alpha-blends it in).
        .background(BudgieColor.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total spent \(total), \(monthText), \(countText)")
        .accessibilityIdentifier("spend.drillIn.summary")
    }

    @ViewBuilder
    private func pills(_ month: String, _ count: String) -> some View {
        PillChip(label: month, color: color)
        PillChip(label: count, color: color)
    }
}

/// `_TransactionRow` (:236-330): a card (padding 12/14) with the category
/// tile, the description (and the recurrence glyph), the `MMMd` date, and
/// the unsigned two-decimal amount.
private struct ExpenseRow: View {
    let record: TransactionRecord
    let color: Color
    let symbol: String
    let formatter: MoneyFormatter
    let onTap: () -> Void

    var body: some View {
        let amount = formatter.format(record.amount)
        GlowCard(padding: 0, onTap: onTap) {
            HStack(spacing: 12) {
                IconTile(symbol: symbol, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(record.description)
                            .textStyle(.rowTitle)
                            .foregroundStyle(BudgieColor.textPrimary)
                            .lineLimit(1)
                        if record.isRecurring { RecurrenceGlyph(size: 16).fixedSize() }
                    }
                    Text(DartDateFormat.MMMd(record.date))
                        .textStyle(.rowSubtitle)
                        .foregroundStyle(BudgieColor.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(amount)
                    .textStyle(.amountSmall)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(record.description), \(amount), on \(DartDateFormat.yMMMMd(record.date))\(record.isRecurring ? ", recurring" : "")")
        .accessibilityHint("Double tap to edit, swipe left to delete")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .accessibilityIdentifier("spend.drillIn.row")
    }
}
