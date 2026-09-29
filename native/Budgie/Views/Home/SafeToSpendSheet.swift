import BudgieCore
import SwiftUI

/// The breakdown behind Home's safe-to-spend card (`_showSafeToSpendBreakdown`,
/// spending_page.dart:362-446, 1330-1385): title, blurb, the six signed
/// rows, a divider, the total and the footer. On the card colour with the
/// grab handle, sized to its content; the system adds the bottom safe area
/// (Flutter's `SafeArea`).
struct SafeToSpendSheet: View {
    let breakdown: SafeToSpendBreakdown
    let formatter: MoneyFormatter

    @State private var contentHeight: CGFloat = 0

    /// `bodyMedium` w500 / w600 and `bodyLarge` w700 / w800.
    private static let label = TextSpec(face: .gabaritoMedium, size: 15, tracking: -0.2, height: 1.5, relativeTo: .subheadline)
    private static let value = TextSpec(face: .gabaritoSemiBold, size: 15, tracking: -0.2, height: 1.5, relativeTo: .subheadline)
    private static let totalLabel = TextSpec(face: .gabaritoBold, size: 17, tracking: -0.4, height: 1.5, relativeTo: .body)
    private static let totalValue = TextSpec(face: .gabaritoExtraBold, size: 17, tracking: -0.4, height: 1.5, relativeTo: .body)

    var body: some View {
        let isOver = breakdown.isOverCommitted
        let title = isOver ? "Projected shortfall" : "Safe to spend"
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .textStyle(.headingLarge)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(
                    isOver
                        ? "What you have spent and reserved for the rest of this month is more than the income you expect."
                        : "A forward-looking estimate for the rest of this month."
                )
                .textStyle(.bodyMedium)
                .foregroundStyle(BudgieColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                VStack(spacing: 0) {
                    row("Income recorded", breakdown.actualIncome, positive: true)
                    row("Income still expected", breakdown.expectedIncome, positive: true)
                    row("Expenses recorded", breakdown.actualExpenses)
                    row("Upcoming recurring bills", breakdown.upcomingRecurringExpenses)
                    row("Flexible budget reserve", breakdown.flexibleBudgetReserve)
                    row("Suggested goal contributions", breakdown.plannedGoalContributions)
                    BudgieColor.border
                        .frame(height: 1)
                        .padding(.vertical, 13.5)
                        .accessibilityHidden(true)
                    row(
                        title, isOver ? breakdown.overCommitment : breakdown.safeToSpend, positive: true, emphasized: true,
                        color: isOver ? BudgieColor.danger : BudgieColor.accent)
                }
                .padding(.top, 20)
                Text(footer)
                    .textStyle(.caption)
                    .foregroundStyle(BudgieColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(EdgeInsets(top: 8, leading: 24, bottom: 24, trailing: 24))
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChangeCompat { contentHeight = $0.height }
        }
        .scrollBounceBehavior(.basedOnSize)
        .budgieSheetChrome()
        .presentationDetents([
            .height(BudgetSheetLayout.handleHeight + (contentHeight > 0 ? contentHeight : estimatedHeight))
        ])
    }

    /// The content's height at the default text size, so the sheet opens at
    /// its final height instead of resizing once measured: 8, the title, 6,
    /// the blurb (two lines when over), 20, six rows, the divider, the total,
    /// 8, the footer (two lines when over with days left), 24. Every line
    /// is `round(size * height)` (`textStyle`): title 34, body 23, total 26,
    /// footer 18.
    private var estimatedHeight: CGFloat {
        let blurbLines: CGFloat = breakdown.isOverCommitted ? 2 : 1
        let footerLines: CGFloat = breakdown.isOverCommitted && breakdown.daysRemaining > 0 ? 2 : 1
        return 8 + 34 + 6 + blurbLines * 23 + 20 + 6 * (12 + 23) + 28 + (12 + 26) + 8 + footerLines * 18 + 24
    }

    /// `_breakdownFooter` (spending_page.dart:350-360).
    private var footer: String {
        let days = breakdown.daysRemaining
        if days <= 0 { return "This month is already closed out." }
        let daysLabel = days == 1 ? "1 day remaining" : "\(days) days remaining"
        if breakdown.isOverCommitted {
            return "Add income or reduce planned spending to close the shortfall \u{00B7} \(daysLabel)"
        }
        return "\(formatter.format(breakdown.dailyAllowance)) per day \u{00B7} \(daysLabel)"
    }

    /// `_BreakdownRow`: the value is shown negated unless `positive`, with a
    /// "+" only on positive non-total rows.
    private func row(
        _ label: String, _ value: Double, positive: Bool = false, emphasized: Bool = false, color: Color? = nil
    ) -> some View {
        let text = formatter.formatSigned(positive ? value : -value, plusForPositive: positive && !emphasized)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .textStyle(emphasized ? Self.totalLabel : Self.label)
                .foregroundStyle(BudgieColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(text)
                .textStyle(emphasized ? Self.totalValue : Self.value)
                .foregroundStyle(color ?? BudgieColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(text)")
    }
}
