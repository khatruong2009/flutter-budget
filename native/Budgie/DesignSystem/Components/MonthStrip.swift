import BudgieCore
import SwiftUI

/// The horizontal month chip strip (`MonthSelector`, month_selector.dart),
/// shared by the SEE ALL page and the Worth tab (D13): 120pt chips 8 apart,
/// list padding 16 x 8 (84pt tall), newest month first. The selected chip
/// is centred when the strip appears (without animation) and whenever the
/// selection changes (300ms easeOut, none under Reduce Motion). This is the
/// older chip generation: `AppColors.primary` in both themes. The caller
/// owns the tap haptic and the selection.
struct MonthStrip: View {
    let months: [DartDateTime]
    let selected: DartDateTime
    let reduceMotion: Bool
    let onSelect: (DartDateTime) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Metrics.spacingS) {
                    ForEach(months, id: \.self) { month in
                        MonthChip(month: month, isSelected: month == selected) { onSelect(month) }
                            .id(month)
                    }
                }
                .padding(.horizontal, Metrics.spacingM)
                .padding(.vertical, Metrics.spacingS)
            }
            // A horizontal scroll view takes all the height it is offered;
            // Flutter's bar is its chips plus 8 above and below (84).
            .fixedSize(horizontal: false, vertical: true)
            // Flutter centres the selected chip after the first frame too.
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
            .onChange(of: selected) { _, month in
                withAnimation(reduceMotion ? nil : Motion.easeOut(Motion.normal)) {
                    proxy.scrollTo(month, anchor: .center)
                }
            }
        }
    }
}

private struct MonthChip: View {
    let month: DartDateTime
    let isSelected: Bool
    let action: () -> Void

    /// Flutter `bodyLarge` bold with 0.5 tracking, and `bodySmall` w500.
    private static let monthText = TextSpec(face: .gabaritoBold, size: 17, tracking: 0.5, height: 1.5, relativeTo: .body)
    private static let yearText = TextSpec(face: .gabaritoMedium, size: 13, tracking: -0.1, height: 1.4, relativeTo: .footnote)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
        let chip = MonthListCopy.chip(month)
        Button(action: action) {
            VStack(spacing: 2) {
                Text(chip.month)
                    .textStyle(Self.monthText)
                    .foregroundStyle(isSelected ? Color.white : BudgieColor.textPrimary)
                Text(chip.year)
                    .textStyle(Self.yearText)
                    .foregroundStyle(isSelected ? Color.white : BudgieColor.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(Metrics.spacingS)
            .frame(width: 120)
            .frame(minHeight: 68)
            .background {
                if isSelected {
                    shape.fill(LinearGradient(
                        colors: [BudgieColor.primary, BudgieColor.primary.opacity(0.8)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    shape.fill(BudgieColor.surface)
                }
            }
            .overlay(shape.strokeBorder(isSelected ? BudgieColor.primary : BudgieColor.border, lineWidth: isSelected ? 2 : 1))
            .modifier(ChipShadow(isSelected: isSelected))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .motion(Motion.easeOut(Motion.fast), value: isSelected)
        .accessibilityLabel("\(DartDateFormat.MMMM(month)) \(DartDateFormat.y(month))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ChipShadow: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content
        } else {
            content.shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        }
    }
}
