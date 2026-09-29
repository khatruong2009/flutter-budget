import BudgieCore
import SwiftUI

/// The Spend month picker (`_showMonthPicker`, category_page.dart:500-588):
/// card-coloured sheet, 26pt top corners with the card border along the
/// top edge only, a 40x4 grabber, "Select month", then one row per month
/// with transactions (newest first, `yMMMM`), at most 320pt tall before it
/// scrolls. The selected month is accent with a check. Picking a month
/// closes the sheet at once.
struct SpendMonthSheet: View {
    let months: [DartDateTime]
    let selected: DartDateTime?
    let onPick: (DartDateTime) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var listHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var bottomInset: CGFloat = 0

    private static let radius: CGFloat = 26
    /// `rowTitle` at 16 (the ListTile title).
    private static let rowText = TextSpec(face: .gabaritoSemiBold, size: 16, height: 1.25, relativeTo: .body)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(BudgieColor.textTertiary)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .accessibilityHidden(true)
            Text("Select month")
                .textStyle(.sectionHeader)
                .foregroundStyle(BudgieColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(months, id: \.self) { month in row(month) }
                }
                .padding(.horizontal, 12)
                .onGeometryChangeCompat { listHeight = $0.height }
            }
            .frame(height: min(listHeight, 320))
            .scrollBounceBehavior(.basedOnSize)
            .padding(.vertical, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChangeCompat { contentHeight = $0.height }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onBudgetSheetBottomInset { bottomInset = $0 }
        .presentationDetents([contentHeight > 0 ? .height(contentHeight + bottomInset) : .medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(Self.radius)
        .presentationBackground {
            BudgieColor.card
                .overlay(alignment: .top) {
                    // Flutter's `Border(top:)` follows the rounded corners
                    // down to where the sides start.
                    UnevenRoundedRectangle(topLeadingRadius: Self.radius, topTrailingRadius: Self.radius, style: .continuous)
                        .strokeBorder(BudgieColor.cardBorder, lineWidth: 1)
                        .mask(alignment: .top) { Rectangle().frame(height: Self.radius) }
                }
                .ignoresSafeArea()
        }
        .accessibilityIdentifier("spend.monthSheet")
    }

    /// A Material ListTile: 56pt minimum, 16pt insets, 20pt check.
    private func row(_ month: DartDateTime) -> some View {
        let isSelected = selected.map { $0.year == month.year && $0.month == month.month } ?? false
        let color = isSelected ? BudgieColor.accent : BudgieColor.textPrimary
        return Button {
            onPick(month)
            dismiss()
        } label: {
            HStack(spacing: 16) {
                Text(DartDateFormat.yMMMM(month))
                    .textStyle(Self.rowText)
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BudgieColor.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("spend.month.\(DartDateFormat.yyyyMM(month))")
    }
}
