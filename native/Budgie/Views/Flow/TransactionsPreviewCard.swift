import BudgieCore
import SwiftUI

/// The Flow preview (`_buildTransactionsPreview`, hp:398-427): the three
/// newest transactions of any month, each opening SEE ALL; with none, a
/// tappable card 'No transactions recorded yet.' that opens it too.
struct TransactionsPreviewCard: View {
    let rows: ArraySlice<LedgerRow>
    let formatter: MoneyFormatter
    let onOpen: () -> Void

    var body: some View {
        if rows.isEmpty {
            GlowCard(onTap: onOpen) {
                FlowEmptyMessage(text: "No transactions recorded yet.")
            }
            .accessibilityHint("Opens all transactions")
            .accessibilityIdentifier("flow.preview.empty")
        } else {
            GlowListCard(rows: rows.map { FlowTransactionRow(record: $0.record, formatter: formatter, action: onOpen) })
        }
    }
}

/// `_TransactionRow` (hp:1057-1135): padding 12; the category's icon on an
/// income (or, for expenses, accent) tile; description over "category ·
/// MMM d"; the signed amount, green for income and primary text for
/// expenses. No press scale; a light haptic on tap.
private struct FlowTransactionRow: View {
    let record: TransactionRecord
    let formatter: MoneyFormatter
    let action: () -> Void

    @Environment(AppModel.self) private var model
    @State private var taps = 0

    var body: some View {
        let isIncome = record.type == .income
        let day = DartDateFormat.MMMd(record.date)
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: symbol, color: isIncome ? BudgieColor.income : BudgieColor.accent)
                VStack(alignment: .leading, spacing: 3) {
                    // Flutter shows a blank line for an empty description.
                    Text(record.description.isEmpty ? " " : record.description)
                        .textStyle(.rowTitle)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .lineLimit(1)
                    Text("\(record.category) \u{00B7} \(day)")
                        .textStyle(.rowSubtitle)
                        .foregroundStyle(BudgieColor.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(formatter.formatSigned(isIncome ? record.amount : -record.amount, plusForPositive: true))
                    .textStyle(.amountSmall)
                    .foregroundStyle(isIncome ? BudgieColor.income : BudgieColor.textPrimary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        // Read like Home's recent-activity rows: the description, then the rest.
        .accessibilityLabel(record.description.isEmpty ? "Transaction" : record.description)
        .accessibilityValue("\(record.category), \(day), \(isIncome ? "income" : "expense") \(formatter.format(record.amount))")
        .accessibilityHint("Opens all transactions")
        .accessibilityIdentifier("flow.preview.row")
    }

    /// The category's icon, else Flutter's fallback (`money_dollar` for
    /// income, `square_grid_2x2` for expenses, hp:1131-1135).
    private var symbol: String {
        if let info = model.categoryInfo(named: record.category, type: record.type) {
            return CategoryCatalog.symbol(for: info.iconIdentifier)
        }
        return record.type == .income ? "dollarsign" : "square.grid.2x2"
    }
}
