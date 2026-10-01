import BudgieCore
import SwiftUI

/// One goal (`_SavingsGoalCard`, savings_goals_page.dart:691-892): the 84pt
/// ring in the status colour (percent, or a check when complete), the name
/// and status pill, "{saved} of {target}" (or "{saved} saved"), the pace or
/// "Fully funded" line, then Add money and the ellipsis (only the ellipsis,
/// right-aligned, once complete). A completed card is tinted green and
/// long-presses to its actions, as in Flutter; a tap does nothing.
///
/// VoiceOver reads the ring and texts as one element with Add money, Edit
/// goal and Delete goal actions; the two buttons stay separate elements.
struct GoalCard: View {
    let goal: SavingsGoalRecord
    let now: DartDateTime
    let calendar: DartCalendar
    let formatter: MoneyFormatter
    let onAddMoney: () -> Void
    let onMore: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var longPresses = 0

    /// `badgeSmall` at 16 / w800.
    private static let ringText = TextSpec(face: .gabaritoExtraBold, size: 16, relativeTo: .caption)
    /// `rowTitle` with tabular figures (the saved amount).
    private static let amountText = TextSpec(face: .gabaritoSemiBold, size: 15, height: 1.25, tabular: true, relativeTo: .body)
    /// The same at w500 (" of {target}", " saved").
    private static let amountTail = TextSpec(face: .gabaritoMedium, size: 15, height: 1.25, tabular: true, relativeTo: .body)

    var body: some View {
        let status = goal.status(now: now, calendar: calendar)
        let complete = status == .complete
        let color = Self.color(status)
        GlowCard(
            fill: complete
                ? AnyShapeStyle(
                    LinearGradient(
                        colors: [BudgieColor.income.opacity(0.10), BudgieColor.income.opacity(0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                : nil,
            border: complete ? BudgieColor.income.opacity(0.30) : nil
        ) {
            VStack(spacing: 16) {
                summary(status: status, color: color)
                HStack(spacing: 8) {
                    if complete {
                        Spacer(minLength: 0)
                    } else {
                        PillButton(title: "Add money", symbol: "plus", filled: true, height: 44, action: onAddMoney)
                            .accessibilityIdentifier("goals.card.addMoney")
                    }
                    GoalMoreButton(action: onMore)
                }
            }
        }
        // GlowCard's own long press would merge the buttons into the card's
        // accessibility element; this keeps them reachable.
        .gesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                longPresses += 1
                onMore()
            },
            including: complete ? .all : .subviews)
        .sensoryFeedback(.impact(weight: .medium), trigger: longPresses)
        .accessibilityElement(children: .contain)
    }

    private func summary(status: SavingsGoalStatus, color: Color) -> some View {
        let complete = status == .complete
        let saved = formatter.format(goal.currentAmount, decimalDigits: 0)
        let tail = complete ? " saved" : " of \(formatter.format(goal.targetAmount, decimalDigits: 0))"
        let note = complete ? SavingsGoalText.fullyFunded(goal) : SavingsGoalText.pace(goal, now: now, calendar: calendar, formatter: formatter)
        return HStack(spacing: 18) {
            ProgressRing(value: complete ? 1 : goal.progress, size: 84, thickness: 9, color: color, glowAlpha: complete ? 0.45 : 0.4) {
                if complete {
                    // Material `check_rounded` 28 / w500 draws an 18.5pt
                    // wide tick; SF `checkmark` medium at 20 is 18.75.
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(BudgieColor.income)
                } else {
                    Text(SavingsGoalText.percent(goal))
                        .textStyle(Self.ringText)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 12)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(goal.name)
                        .textStyle(.goalTitle)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .singleLine()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PillChip(label: status.label, color: color, style: .badgeSmall)
                        .fixedSize()
                }
                (Text(saved).font(Self.amountText.font()).foregroundStyle(BudgieColor.textPrimary)
                    + Text(tail).font(Self.amountTail.font()).foregroundStyle(BudgieColor.textSecondary))
                    .padding(.top, 6)
                Text(note)
                    .textStyle(.rowSubtitle)
                    .foregroundStyle(complete ? BudgieColor.income : BudgieColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(goal.name), \(status.label)")
        .accessibilityValue(
            "\(goal.progressPercent) percent, \(saved)\(tail), "
                + note.replacingOccurrences(of: " \u{00B7} ", with: ", "))
        .accessibilityIdentifier("goals.card")
        .modifier(OptionalAccessibilityAction(name: "Add money", action: complete ? nil : onAddMoney))
        .accessibilityAction(named: "Edit goal", onEdit)
        .accessibilityAction(named: "Delete goal", onDelete)
    }

    /// The status colour: success, warning or accent.
    static func color(_ status: SavingsGoalStatus) -> Color {
        switch status {
        case .complete: BudgieColor.income
        case .behind: BudgieColor.warning
        case .onTrack: BudgieColor.accent
        }
    }
}

/// `_MoreButton` (savings_goals_page.dart:919-959): a 44pt outlined circle
/// with an ellipsis, light haptic, "More goal actions".
struct GoalMoreButton: View {
    let action: () -> Void

    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            // Material `more_horiz_rounded` 18 / w500: 11.5pt wide, 3pt
            // dots; SF `ellipsis` medium at 12 is 12 x 3.
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 18, height: 18)
                .foregroundStyle(BudgieColor.textSecondary)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(BudgieColor.pillBorder, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityLabel("More goal actions")
        .accessibilityIdentifier("goals.card.more")
    }
}
