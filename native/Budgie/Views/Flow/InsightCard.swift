import BudgieCore
import SwiftUI

/// Flutter `_InsightCard` (local_insights_section.dart:135-233): a plain
/// GlowCard (no tap) with the severity-coloured 40pt tile, 12, the headline
/// (rowTitle), 4, the explanation (rowSubtitle, secondary), 8, the suggested
/// action (caption, severity colour), and the "Insight options" menu. Text
/// wraps without limits. The menu acts at once: no confirmation, no undo,
/// no haptic and no animation (Flutter has none, so Reduce Motion has
/// nothing to change).
struct InsightCard: View {
    let insight: LocalInsight
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        let color = Self.color(insight.severity)
        GlowCard {
            HStack(alignment: .top, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    IconTile(symbol: Self.symbol(insight.type), color: color)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(insight.headline)
                            .textStyle(.rowTitle)
                            .foregroundStyle(BudgieColor.textPrimary)
                        Text(insight.explanation)
                            .textStyle(.rowSubtitle)
                            .foregroundStyle(BudgieColor.textSecondary)
                            .padding(.top, Metrics.spacingXS)
                        Text(insight.suggestedAction)
                            .textStyle(.caption)
                            .foregroundStyle(color)
                            .padding(.top, Metrics.spacingS)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // VoiceOver: the card is one element (headline, explanation,
                // action) carrying the menu's two actions.
                .accessibilityElement(children: .combine)
                .accessibilityActions {
                    Button("Snooze for 30 days", action: onSnooze)
                    Button("Dismiss", action: onDismiss)
                }
                .accessibilityIdentifier("flow.insight.card")

                Menu {
                    Button("Snooze for 30 days", action: onSnooze)
                        .accessibilityIdentifier("flow.insight.snooze")
                    Button("Dismiss", action: onDismiss)
                        .accessibilityIdentifier("flow.insight.dismiss")
                } label: {
                    // Material `more_horiz` (24) in the 48pt IconButton;
                    // bold gives its larger dots (as the Categories rows).
                    Image(systemName: "ellipsis")
                        .font(.system(size: Metrics.iconM, weight: .bold))
                        .foregroundStyle(BudgieColor.textSecondary)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .menuOrder(.fixed)
                .accessibilityLabel("Insight options")
                .accessibilityValue(insight.headline)
                .accessibilityIdentifier("flow.insight.menu")
            }
        }
    }

    /// `AppColors.getDanger/getWarning/getIncome/getAccent`.
    static func color(_ severity: InsightSeverity) -> Color {
        switch severity {
        case .urgent: BudgieColor.danger
        case .warning: BudgieColor.warning
        case .positive: BudgieColor.income
        case .info: BudgieColor.accent
        }
    }

    /// `_iconFor`: the Material Symbols as SF Symbols (D3).
    static func symbol(_ type: InsightType) -> String {
        switch type {
        case .budgetPace: "speedometer"
        case .monthlySpendingChange: "chart.line.uptrend.xyaxis"
        case .unusualTransaction: "bell.badge.fill"
        case .savingsRateTrend: "banknote"
        case .recurringAmountChange: "repeat"
        case .consistentlyUnderBudget: "hand.thumbsup.fill"
        case .goalBehindSchedule: "flag.fill"
        case .negativeCashFlow: "chart.line.downtrend.xyaxis"
        case .possibleDuplicate: "doc.on.doc"
        }
    }
}
