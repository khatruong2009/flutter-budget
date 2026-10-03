import BudgieCore
import SwiftUI

// MARK: - Range sheet

/// 'CHART RANGE' (`_showRangePicker`, hp:439-496, tiles hp:1188-1220): the
/// eyebrow and one row per option (3, 6, 12 months); the selected row is
/// accent, bold, with a check. Picking reports the choice; the caller gives
/// the selection haptic and closes the sheet.
struct RangeSheet: View {
    let selected: Int
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CHART RANGE")
                .textStyle(.eyebrow)
                .foregroundStyle(BudgieColor.textTertiary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)
                // 12 + the chrome's 20pt handle inset = Flutter's 12 + 4 + 16.
                .padding(.top, 12)
                .padding(.bottom, 8)
            ForEach(CashFlowMath.rangeOptions, id: \.self) { months in
                RangeOptionRow(months: months, selected: months == selected) { onPick(months) }
            }
        }
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 12 + the eyebrow line + 8, the tiles, 12.
        .modifier(FlowSheetFit(estimate: 12 + 13 + 8 + CGFloat(CashFlowMath.rangeOptions.count) * 56 + 12))
    }
}

/// A Material `ListTile` row: min height 56, content inset 16 / 24, title
/// in rowTitle (w700 accent when selected, w600 text otherwise), check.
private struct RangeOptionRow: View {
    let months: Int
    let selected: Bool
    let action: () -> Void

    /// `rowTitle` with w700.
    private static let selectedStyle = TextSpec(face: .gabaritoBold, size: 15, height: 1.25, relativeTo: .body)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(CashFlowMath.rangeLabel(months))
                    .textStyle(selected ? Self.selectedStyle : .rowTitle)
                    .foregroundStyle(selected ? BudgieColor.accent : BudgieColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(BudgieColor.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 24)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("flow.range.\(months)")
    }
}

// MARK: - Month detail sheet

/// A tapped bar's month (`_showMonthDetailsBottomSheet`, hp:498-620): the
/// bar-chart tile in the net colour and the `yMMMM` title, the Income and
/// Expenses tiles, and the net row. A snapshot of the tapped entry; no
/// actions.
struct MonthDetailSheet: View {
    let detail: CashFlowMath.MonthDetail
    let formatter: MoneyFormatter

    var body: some View {
        let netColor = detail.netIsPositive ? BudgieColor.income : BudgieColor.danger
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: "chart.bar.fill", color: netColor, size: 44)
                Text(detail.title)
                    .textStyle(.sectionHeader)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                MonthDetailTile(
                    label: "Income", amount: detail.incomeText(formatter), color: BudgieColor.income, symbol: "arrow.down.left")
                MonthDetailTile(
                    label: "Expenses", amount: detail.expensesText(formatter), color: BudgieColor.danger, symbol: "arrow.up.right")
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 20)
            netRow(color: netColor)
                .padding(.top, 12)
        }
        // Top: 16 + the chrome's 20pt handle inset = Flutter's 12 + 4 + 20.
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 24, trailing: 20))
        // A container: the identifier must not replace the tiles' elements.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("flow.monthDetail")
        // 16, the 44pt tile, 20, the tiles (14 + 16 + 6 + amount + 14), 12,
        // the net row (14 + chipAmount + 14), 24.
        .modifier(FlowSheetFit(estimate: 16 + 44 + 20 + (14 + 16 + 6 + 19 + 14) + 12 + (14 + 28 + 14) + 24))
    }

    /// Net row: padding 16 x 14, radius 16, net colour at 10% with a 30%
    /// border; check, or a down trend when negative (Flutter shows `trending_up`, D6), and
    /// 'Net cash flow'; `formatSigned(net)` in chipAmount.
    private func netRow(color: Color) -> some View {
        let net = detail.netText(formatter)
        return HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: detail.netIsPositive ? "checkmark" : "chart.line.downtrend.xyaxis")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 20, height: 20)
                Text("Net cash flow")
                    .textStyle(.rowTitle)
                    .foregroundStyle(BudgieColor.textPrimary)
            }
            Spacer(minLength: 0)
            Text(net)
                .textStyle(.chipAmount)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .circular))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .circular).strokeBorder(color.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Net cash flow")
        .accessibilityValue(net)
    }
}

/// `_MonthDetailTile` (hp:1137-1186): padding 14, radius 16, colour at 10%
/// with a 30% border; 16pt arrow and the label, 6, the amount.
private struct MonthDetailTile: View {
    let label: String
    let amount: String
    let color: Color
    let symbol: String

    /// `rowSubtitle` w600.
    private static let labelStyle = TextSpec(face: .gabaritoSemiBold, size: 12, height: 1.25, relativeTo: .caption)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
                Text(label)
                    .textStyle(Self.labelStyle)
                    .foregroundStyle(BudgieColor.textSecondary)
            }
            Text(amount)
                .textStyle(.amount)
                .foregroundStyle(color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .circular))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .circular).strokeBorder(color.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(amount)
    }
}

// MARK: - Sheet sizing

/// Sizes a Flow sheet to its content (Flutter's modal sheet wraps a
/// `mainAxisSize.min` column) and applies the redesign chrome with the Flow
/// sheets' 24pt top radius. The detent is the grab handle's inset plus the
/// content: the system adds the bottom safe area (Flutter's `SafeArea`)
/// itself. Until the content is measured it uses `estimate`, the content's
/// height at the default text size, so the sheet opens at its final height
/// instead of resizing from `.medium`.
private struct FlowSheetFit: ViewModifier {
    let estimate: CGFloat
    @State private var contentHeight: CGFloat = 0

    func body(content: Content) -> some View {
        ScrollView {
            content.onGeometryChangeCompat { contentHeight = $0.height }
        }
        .scrollBounceBehavior(.basedOnSize)
        .budgieSheetChrome(radius: Metrics.flowSheetRadius)
        .presentationDetents([.height(BudgetSheetLayout.handleHeight + (contentHeight > 0 ? contentHeight : estimate))])
    }
}
