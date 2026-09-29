import BudgieCore
import SwiftUI

/// Sets or removes a category's monthly limit (`_BudgetLimitSheet`,
/// spending_page.dart:811-999): danger-tinted header, the limit field
/// (autofocused, decimal pad), then Remove (only with a limit) and Save.
/// Content-sized; it rides up with the keyboard.
struct BudgetLimitSheet: View {
    let category: String
    let currentLimit: Double?
    let formatter: MoneyFormatter

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    /// What the field opened with; while it still reads this, the stored
    /// limit is used exactly (the prefill is rounded to cents).
    private let prefill: String
    @State private var saving = false
    @State private var contentHeight: CGFloat = 0
    /// The space below the handle with nothing trimmed (the measured height
    /// plus the slack it was measured with).
    @State private var untrimmedHeight: CGFloat = 0
    @State private var keyboardSlack: CGFloat = 0
    @FocusState private var focused: Bool

    private static let helper = "Set a positive amount for this category."

    init(category: String, currentLimit: Double?, formatter: MoneyFormatter) {
        self.category = category
        self.currentLimit = currentLimit
        self.formatter = formatter
        // `formatNumber(limit, 2)`, locale-grouped; not masked by Hide balances.
        let prefill = currentLimit.map { formatter.formatNumber($0, decimalDigits: 2) } ?? ""
        self.prefill = prefill
        _text = State(initialValue: prefill)
    }

    /// The limit Save writes: the stored one while the field is untouched,
    /// else the parsed text.
    private var limit: Double? {
        Self.limit(text: text, prefill: prefill, currentLimit: currentLimit, formatter: formatter)
    }

    var body: some View {
        let canSave = !saving && limit != nil
        VStack(alignment: .leading, spacing: 0) {
            header
            field.padding(.top, 24)
            HStack(spacing: 16) {
                if currentLimit != nil {
                    LimitSheetButton(title: "Remove", symbol: "trash", primary: false, enabled: !saving, action: remove)
                }
                LimitSheetButton(
                    title: "Save", symbol: "checkmark.circle.fill", primary: true, loading: saving, enabled: canSave,
                    action: save)
            }
            .padding(.top, 24)
        }
        // 16 + the chrome's 20pt handle inset = Flutter's 16 + 4 + 16.
        .padding(16)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChangeCompat {
            contentHeight = $0.height
            updateKeyboardSlack()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onGeometryChangeCompat {
            untrimmedHeight = $0.height + keyboardSlack
            updateKeyboardSlack()
        }
        .budgieSheetChrome()
        .presentationDetents([
            .height(
                BudgetSheetLayout.handleHeight + (contentHeight > 0 ? contentHeight : Self.estimatedHeight) - keyboardSlack)
        ])
        .interactiveDismissDisabled(saving)
        .onAppear { focused = true }
    }

    /// The content's height at the default text size, so the sheet opens at
    /// its final height instead of resizing once measured: 16, the 40pt
    /// header tile, 24, the 56pt field, 6, the helper, 24, the 48pt buttons,
    /// 16.
    private static let estimatedHeight: CGFloat = 16 + 40 + 24 + 56 + 6 + 15 + 24 + 48 + 16

    /// The room left below the content, trimmed off the detent. With the
    /// keyboard up the system keeps the sheet's home-indicator allowance
    /// above the keyboard as empty space; trimming it leaves the content's
    /// own 16pt bottom padding as the gap, as in Flutter. Without the
    /// keyboard the content already reaches into that allowance, so nothing
    /// is trimmed.
    private func updateKeyboardSlack() {
        guard contentHeight > 0, untrimmedHeight > 0 else { return }
        let slack = max(0, untrimmedHeight - contentHeight)
        if abs(slack - keyboardSlack) >= 0.5 { keyboardSlack = slack }
    }

    private var header: some View {
        HStack(spacing: 16) {
            IconTile(
                symbol: CategoryCatalog.symbol(for: model.categoryInfo(named: category, type: .expense)?.iconIdentifier ?? ""),
                color: BudgieColor.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .textStyle(.cardTitle)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .lineLimit(1)
                Text("Monthly spending limit")
                    .textStyle(.rowSubtitle)
                    .foregroundStyle(BudgieColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// The outlined Material field: floating "Limit" label notched into the
    /// border (accent and 2pt while focused), currency prefix, "0.00" hint,
    /// helper text below. The fill behind the text field focuses it when the
    /// padding, prefix or label is tapped; the text field keeps its own
    /// touches (caret, selection menu).
    private var field: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(AmountInput.currencySymbol(formatter))
                    .textStyle(.numericMedium)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .accessibilityHidden(true)
                TextField("Limit", text: $text, prompt: Text("0.00").foregroundStyle(BudgieColor.textTertiary))
                    .textStyle(.numericMedium)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focused)
                    // Only a hardware keyboard can submit; the decimal pad has no return key.
                    .onSubmit(save)
                    // The prompt replaces the title as the field's label.
                    .accessibilityLabel("Limit")
                    .accessibilityHint(Self.helper)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 56)
            .background(
                shape.fill(BudgieColor.chipSurface)
                    .contentShape(shape)
                    .onTapGesture { focused = true }
                    .accessibilityHidden(true)
            )
            .overlay(
                shape.strokeBorder(
                    focused ? BudgieColor.accent : BudgieColor.textTertiary, lineWidth: focused ? 2 : 1)
                    .allowsHitTesting(false))
            .overlay(alignment: .topLeading) {
                Text("Limit")
                    .textStyle(.rowSubtitle)
                    .foregroundStyle(focused ? BudgieColor.accent : BudgieColor.textSecondary)
                    .padding(.horizontal, 4)
                    .background(
                        LinearGradient(
                            stops: [
                                .init(color: BudgieColor.card, location: 0.5),
                                .init(color: BudgieColor.chipSurface, location: 0.5),
                            ], startPoint: .top, endPoint: .bottom)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { focused = true }
                    .padding(.leading, 12)
                    .alignmentGuide(.top) { $0.height / 2 }
                    .accessibilityHidden(true)
            }
            Text(Self.helper)
                .textStyle(.rowSubtitle)
                .foregroundStyle(BudgieColor.textSecondary)
                .padding(.horizontal, 16)
                .accessibilityHidden(true)
        }
    }

    /// `_saveLimit`: re-checks the guard (the submit path), spins, awaits the
    /// verified write, then closes.
    private func save() {
        guard !saving, let limit else { return }
        saving = true
        Task {
            // A failed write still closes the sheet, as in Flutter: the change
            // stays in memory and the unsaved-changes banner offers the retry.
            _ = await model.setBudgetLimit(category: category, limit: limit)
            dismiss()
        }
    }

    /// `_removeLimit`: also sets `saving`, so Save spins and Remove disables.
    private func remove() {
        guard !saving else { return }
        saving = true
        Task {
            _ = await model.removeBudgetLimit(category: category)
            dismiss()
        }
    }

    // MARK: - Parsing (D6)

    /// An unchanged prefill keeps `currentLimit` exactly (99.999 stays
    /// 99.999, not the 100.0 its "100.00" parses to; 0.001 stays saveable);
    /// any edit parses (`AmountInput`, D6) and must be above 0. Flutter
    /// always parses the text.
    nonisolated static func limit(text: String, prefill: String, currentLimit: Double?, formatter: MoneyFormatter) -> Double? {
        if let currentLimit, text == prefill { return currentLimit }
        return AmountInput.parse(text, formatter: formatter).flatMap { $0 > 0 ? $0 : nil }
    }
}

/// `AppButton` medium (design_system.dart:386-760): 48pt, radius 12,
/// primary gradient with a white label and a soft shadow, or a 1.5pt
/// outline in the text colour at 30%. 0.38 opacity when disabled; a 24pt
/// spinner replaces the icon while loading.
private struct LimitSheetButton: View {
    let title: String
    let symbol: String
    let primary: Bool
    var loading = false
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
        let foreground: Color = primary ? .white : BudgieColor.textPrimary
        Button(action: action) {
            HStack(spacing: 8) {
                if loading {
                    ProgressView().tint(foreground).frame(width: 24, height: 24)
                } else {
                    Image(systemName: symbol).font(.system(size: 20)).frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }
                Text(title).textStyle(.buttonMedium).lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                if primary {
                    shape.fill(BudgieColor.primaryGradient)
                        .shadow(color: .black.opacity(enabled ? 0.1 : 0), radius: 4, y: 4)
                } else {
                    shape.strokeBorder(BudgieColor.textPrimary.opacity(0.3), lineWidth: Metrics.borderMedium)
                }
            }
            .opacity(enabled ? 1 : Metrics.opacityDisabled)
            .contentShape(shape)
        }
        .buttonStyle(LimitSheetButtonStyle())
        .disabled(!enabled)
    }
}

/// Scales to 0.95 over 100ms and fires the light haptic on touch-down, as
/// `AppButton` does.
private struct LimitSheetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .motion(Motion.easeOut(0.1), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}
