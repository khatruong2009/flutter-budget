import BudgieCore
import SwiftUI

/// Flutter `_InsightCard` (local_insights_section.dart:135-233): a plain
/// GlowCard (no tap) with the severity-coloured 40pt tile, 12, the headline
/// (rowTitle), 4, the explanation (rowSubtitle, secondary), 8, the suggested
/// action (caption, severity colour), and the "Insight options" menu. Text
/// wraps without limits. The menu acts at once: no confirmation, no undo,
/// no haptic and no animation (Flutter has none, so Reduce Motion has
/// nothing to change).
///
/// At accessibility text sizes the tile sits above the text, which takes
/// the card's full width (as RecurringCard stacks): beside the fixed 40pt
/// tile and 48pt menu the column is too narrow and words break. The menu
/// stays in the top trailing corner, level with the tile.
struct InsightCard: View {
    let insight: LocalInsight
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Flutter's 48pt IconButton.
    private static let menuSize: CGFloat = 48

    var body: some View {
        let color = Self.color(insight.severity)
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout =
            stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        GlowCard {
            layout {
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
            // Beside the text, or above it level with the tile when stacked.
            .padding(.trailing, stacked ? 0 : Self.menuSize)
            .overlay(alignment: .topTrailing) { menu }
        }
    }

    private var menu: some View {
        Menu {
            Button("Snooze for 30 days", action: onSnooze)
                .accessibilityIdentifier("flow.insight.snooze")
            Button("Dismiss", action: onDismiss)
                .accessibilityIdentifier("flow.insight.dismiss")
        } label: {
            // Material `more_horiz` (24) in the 48pt IconButton: SF Symbols
            // draw larger at one size, so 17pt bold matches its dots (as
            // the Categories rows).
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(BudgieColor.textSecondary)
                .frame(width: Self.menuSize, height: Self.menuSize)
                .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
        .accessibilityLabel("Insight options")
        .accessibilityValue(insight.headline)
        .accessibilityIdentifier("flow.insight.menu")
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
