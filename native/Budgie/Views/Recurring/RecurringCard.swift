import BudgieCore
import SwiftUI

/// A template card (`_RecurringTransactionListItem`,
/// recurring_transactions_page.dart:227-366) in the redesign's card language
/// (D15): a GlowCard with the category tile, the description with the
/// recurrence glyph over the category, the amount; a hairline; the
/// "Pattern" and "Next Occurrence" columns; then Edit, Pause / Resume
/// (approved MVP extra, Flutter has none) and Delete. A paused card is
/// dimmed and badged "Paused", its buttons stay at full strength.
struct RecurringCard: View {
    let template: RecurringTemplate
    let onEdit: () -> Void
    let onToggleActive: () -> Void
    let onDelete: () -> Void

    @Environment(AppModel.self) private var model

    /// Flutter's detail label: `caption` at w600.
    private static let detailLabel = TextSpec(face: .gabaritoSemiBold, size: 13, tracking: -0.1, height: 1.4, relativeTo: .footnote)

    var body: some View {
        let amount = model.moneyFormatter.format(template.amount)
        let next = DartDateFormat.MMMddyyyy(template.nextOccurrence)
        let pattern = template.pattern.displayName
        GlowCard(padding: Metrics.spacingM) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    header(amount: amount)
                    Hairline().padding(.vertical, Metrics.spacingM)
                    HStack(alignment: .top, spacing: Metrics.spacingM) {
                        detail(symbol: "repeat", label: "Pattern", value: pattern)
                        detail(symbol: "calendar", label: "Next Occurrence", value: next)
                    }
                }
                .opacity(template.isActive ? 1 : 0.65)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(template.description), \(template.type == .income ? "income" : "expense"), \(amount), "
                        + "\(template.category), \(pattern), next occurrence \(next)" + (template.isActive ? "" : ", paused"))
                .accessibilityIdentifier("recurring.summary")
                actions
                    .padding(.top, Metrics.spacingM)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recurring.card")
    }

    // MARK: - Pieces

    private func header(amount: String) -> some View {
        let isIncome = template.type == .income
        return HStack(spacing: 12) {
            IconTile(symbol: symbol, color: isIncome ? BudgieColor.income : BudgieColor.accent, size: 44)
            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                HStack(spacing: 6) {
                    Text(template.description)
                        .textStyle(.cardTitle)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .lineLimit(2)
                    RecurrenceGlyph(size: 16).fixedSize()
                    if !template.isActive {
                        PillChip(label: "Paused", color: BudgieColor.warning, style: .badgeSmall, horizontalPadding: 8, verticalPadding: 3)
                            .fixedSize()
                    }
                }
                Text(template.category)
                    .textStyle(.rowSubtitle)
                    .foregroundStyle(BudgieColor.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(amount)
                .textStyle(.amount)
                .foregroundStyle(isIncome ? BudgieColor.income : BudgieColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
        }
    }

    private func detail(symbol: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXXS) {
            HStack(spacing: Metrics.spacingXS) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                Text(label).textStyle(Self.detailLabel)
            }
            .foregroundStyle(BudgieColor.textSecondary)
            Text(value)
                .textStyle(.bodySmall)
                .foregroundStyle(BudgieColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One row of three pills, stacked when they do not fit (large text).
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Metrics.spacingS) { buttons }
            VStack(spacing: Metrics.spacingS) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        PillButton(title: "Edit", symbol: "pencil", height: Metrics.pillButtonCompactHeight, action: onEdit)
            .accessibilityIdentifier("recurring.edit")
        PillButton(
            title: template.isActive ? "Pause" : "Resume", symbol: template.isActive ? "pause.fill" : "play.fill",
            color: template.isActive ? BudgieColor.warning : BudgieColor.income, height: Metrics.pillButtonCompactHeight,
            action: onToggleActive
        )
        .accessibilityIdentifier("recurring.pause")
        PillButton(title: "Delete", symbol: "trash", color: BudgieColor.danger, height: Metrics.pillButtonCompactHeight, action: onDelete)
            .accessibilityIdentifier("recurring.delete")
    }

    /// The category's icon (found case-insensitively, archived included);
    /// Flutter's fallbacks otherwise (`shopping_bag`, `attach_money`).
    private var symbol: String {
        if let info = model.categoryInfo(named: template.category, type: template.type) {
            return CategoryCatalog.symbol(for: info.iconIdentifier)
        }
        return template.type == .income ? "dollarsign" : "bag.fill"
    }
}
