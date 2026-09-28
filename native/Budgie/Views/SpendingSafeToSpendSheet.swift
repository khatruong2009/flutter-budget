import BudgieCore
import SwiftUI

/// Breakdown sheet behind the safe-to-spend card (the Flutter bottom sheet).
struct SpendingSafeToSpendSheet: View {
    let breakdown: SafeToSpendBreakdown
    let formatter: MoneyFormatter

    var body: some View {
        let isOver = breakdown.isOverCommitted
        let title = isOver ? "Projected shortfall" : "Safe to spend"
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title2.weight(.bold))
                Text(
                    isOver
                        ? "What you have spent and reserved for the rest of this month is more than the income you expect."
                        : "A forward-looking estimate for the rest of this month."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    row("Income recorded", breakdown.actualIncome, positive: true)
                    row("Income still expected", breakdown.expectedIncome, positive: true)
                    row("Expenses recorded", breakdown.actualExpenses)
                    row("Upcoming recurring bills", breakdown.upcomingRecurringExpenses)
                    row("Flexible budget reserve", breakdown.flexibleBudgetReserve)
                    row("Suggested goal contributions", breakdown.plannedGoalContributions)
                    Divider().padding(.vertical, 8)
                    row(
                        title, isOver ? breakdown.overCommitment : breakdown.safeToSpend, positive: true,
                        emphasized: true, color: isOver ? Theme.expense : Theme.accent)
                }
                .padding(.top, 14)

                Text(footer).font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
    }

    private var footer: String {
        let days = breakdown.daysRemaining
        if days <= 0 { return "This month is already closed out." }
        let daysLabel = days == 1 ? "1 day remaining" : "\(days) days remaining"
        if breakdown.isOverCommitted {
            return "Add income or reduce planned spending to close the shortfall \u{00B7} \(daysLabel)"
        }
        return "\(formatter.format(breakdown.dailyAllowance)) per day \u{00B7} \(daysLabel)"
    }

    private func row(
        _ label: String, _ value: Double, positive: Bool = false, emphasized: Bool = false, color: Color? = nil
    ) -> some View {
        let text = formatter.formatSigned(positive ? value : -value, plusForPositive: positive && !emphasized)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(emphasized ? .body.weight(.bold) : .subheadline.weight(.medium))
                .layoutPriority(1)
            Spacer(minLength: 8)
            Text(text)
                .font(emphasized ? .body.weight(.heavy) : .subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .truncationMode(.head)
                .foregroundStyle(color ?? (emphasized ? Theme.accent : Color.secondary))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(text)")
    }
}
