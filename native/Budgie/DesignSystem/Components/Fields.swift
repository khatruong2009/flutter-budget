import SwiftUI

/// Text field in the redesign's field style (Goals' form fields, which the
/// legacy `ModernTextField` screens are ported to, D1): caption label above,
/// chip-surface fill, radius 14, 1pt card-border stroke that turns 1.5pt
/// accent while focused (danger with an error), optional 20pt leading
/// symbol, input in rowTitle, error text in danger below.
struct BudgieField: View {
    let title: String
    @Binding var text: String
    var prompt: String = ""
    var symbol: String? = nil
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var error: String? = nil
    /// Focuses the field when it appears (the transaction form's amount).
    var autofocus = false

    @FocusState private var focused: Bool

    var body: some View {
        let hasError = error != nil
        let stroke: Color = hasError ? BudgieColor.danger : focused ? BudgieColor.accent : BudgieColor.cardBorder
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .textStyle(.caption)
                .foregroundStyle(hasError ? BudgieColor.danger : focused ? BudgieColor.accent : BudgieColor.textSecondary)
                .padding(.leading, 4)
                .accessibilityHidden(true)
            HStack(spacing: 10) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(BudgieColor.textSecondary)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                }
                TextField(title, text: $text, prompt: Text(prompt).foregroundStyle(BudgieColor.textTertiary))
                    .textStyle(.rowTitle)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled(keyboard == .decimalPad || keyboard == .numberPad)
                    .focused($focused)
                    // A prompt replaces the title as the field's label.
                    .accessibilityLabel(title)
                    .onAppear { if autofocus { focused = true } }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(BudgieColor.chipSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(stroke, lineWidth: focused || hasError ? 1.5 : 1))
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            if let error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle").font(.system(size: 13)).accessibilityHidden(true)
                    Text(error).textStyle(.caption)
                }
                .foregroundStyle(BudgieColor.danger)
                .padding(.leading, 4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(error.map { Text("Error: \($0)") } ?? Text(""))
    }
}

/// Date row (`_DatePickerTile`): chip surface, radius 14, 1pt card border,
/// padding 16; calendar symbol, label over value, chevron (right, or down
/// for the Worth editor's `expand_more`). Light haptic.
struct DateTile: View {
    let label: String
    let value: String
    var symbol = "calendar"
    var trailingSymbol = "chevron.right"
    let action: () -> Void

    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(BudgieColor.textSecondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).textStyle(.rowSubtitle).foregroundStyle(BudgieColor.textSecondary)
                    Text(value).textStyle(.rowTitle).foregroundStyle(BudgieColor.textPrimary)
                }
                Spacer(minLength: 8)
                Image(systemName: trailingSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BudgieColor.textSecondary)
            }
            .padding(16)
            .background(BudgieColor.chipSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BudgieColor.cardBorder, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAddTraits(.isButton)
    }
}

/// Empty state (`EmptyState`), ported to the redesign tokens: 64pt symbol,
/// headingMedium title, bodyMedium message, optional filled pill action.
struct EmptyStateView: View {
    enum Kind { case noData, noResults, error }

    var kind: Kind = .noData
    var symbol: String? = nil
    var title: String? = nil
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: symbol ?? defaultSymbol)
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(kind == .error ? BudgieColor.danger : BudgieColor.textSecondary)
                .frame(height: 64)
                .accessibilityHidden(true)
                .padding(.bottom, Metrics.spacingL)
            Text(title ?? defaultTitle)
                .textStyle(.headingMedium)
                .foregroundStyle(BudgieColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Metrics.spacingS)
            Text(message ?? defaultMessage)
                .textStyle(.bodyMedium)
                .foregroundStyle(BudgieColor.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PillButton(title: actionTitle, filled: true, action: action)
                    .frame(maxWidth: 260)
                    .padding(.top, Metrics.spacingXL)
            }
        }
        .padding(Metrics.spacingL)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var defaultSymbol: String {
        switch kind {
        case .noData: "tray"
        case .noResults: "magnifyingglass"
        case .error: "exclamationmark.triangle"
        }
    }

    private var defaultTitle: String {
        switch kind {
        case .noData: "No Data Yet"
        case .noResults: "No Results Found"
        case .error: "Something Went Wrong"
        }
    }

    private var defaultMessage: String {
        switch kind {
        case .noData: "Get started by adding your first item"
        case .noResults: "Try adjusting your search or filters"
        case .error: "We encountered an error. Please try again"
        }
    }
}
