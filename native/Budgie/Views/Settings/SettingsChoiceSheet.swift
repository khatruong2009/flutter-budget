import BudgieCore
import SwiftUI

/// Material 3 `ListTile` title (`bodyLarge`: 16 / w400, height 1.5,
/// tracking 0.5) in Gabarito.
private let choiceRowText = TextSpec(face: .gabaritoRegular, size: 16, tracking: 0.5, height: 1.5, relativeTo: .body)

/// A Settings choice sheet (`_showChoiceSheet`, settings_page.dart:985-1035)
/// in the redesign chrome: the title in `headingMedium`, then one row per
/// choice with an accent check on the current value (none when the stored
/// value is not listed), and 8pt below. Content-sized up to 75% of the
/// screen, where the list scrolls. No search and no haptics, as in Flutter.
/// Picking a row (the current one included, as Flutter re-fires the setter)
/// awaits the setter, then closes the sheet.
struct SettingsChoiceSheet<Value: Hashable & Sendable>: View {
    let title: String
    let choices: [SettingsChoice<Value>]
    let current: Value
    let onPick: (Value) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var headerHeight: CGFloat = 0
    @State private var listHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .textStyle(.headingMedium)
                .foregroundStyle(BudgieColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(Metrics.spacingM)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChangeCompat { headerHeight = $0.height }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(choices, id: \.value) { choice in row(choice) }
                }
                .padding(.bottom, Metrics.spacingS)
                .onGeometryChangeCompat { listHeight = $0.height }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .budgieSheetChrome()
        .presentationDetents([detent])
    }

    /// Handle, title and list, at most 75% of the screen; the system adds
    /// the bottom safe area (Flutter's `SafeArea`). Until measured, the
    /// default-size title (16 + 29 + 16) and 56pt rows stand in, so the
    /// sheet opens at its final height.
    private var detent: PresentationDetent {
        let header = headerHeight > 0 ? headerHeight : 16 + 29 + 16
        let list = listHeight > 0 ? listHeight : CGFloat(choices.count) * 56 + Metrics.spacingS
        return .height(min(BudgetSheetLayout.handleHeight + header + list, BudgetSheetLayout.screenHeight * 0.75))
    }

    /// A Material `ListTile`: 56pt minimum, insets 16 / 24, 24pt check box.
    private func row(_ choice: SettingsChoice<Value>) -> some View {
        let isCurrent = choice.value == current
        return Button {
            guard !picking else { return }
            picking = true
            Task {
                await onPick(choice.value)
                dismiss()
            }
        } label: {
            HStack(spacing: 16) {
                Text(choice.label)
                    .textStyle(choiceRowText)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(BudgieColor.accent)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 24)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
