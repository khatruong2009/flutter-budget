import BudgieCore
import SwiftUI

/// The "New merchant rule" dialog (`_addRule`,
/// categorization_settings_page.dart:128-260) in the redesign's centred
/// card, fields in Flutter's order: "Merchant text" (hint "Whole Foods",
/// autofocused), "Type" (Income, Expense; default Expense), "Match"
/// (Contains, Starts with, Exact match; default Contains), "Category" (the
/// type's active categories in order; default the first), then the tags as
/// chips when there are any, selected in tap order. Cancel and Add.
///
/// The rule gets only Flutter's fields: no amount bounds, priority 0,
/// enabled. Changing the type keeps the category when the new type has
/// that name (UTF-16), else takes its first; the tag selection stays.
/// Add is disabled while the trimmed merchant text is empty (Flutter's Add
/// does nothing then). The add is awaited with the dialog inert; it closes
/// once written, and also when the write failed (the rule is in memory
/// behind the unsaved banner), with the save-failed toast. A refusal shows
/// its message above the buttons.
struct NewRuleDialog: View {
    let onClose: () -> Void

    @Environment(AppModel.self) private var model
    @State private var pattern = ""
    @State private var type: TransactionType = .expense
    @State private var matchType: MerchantMatchType = .contains
    @State private var category: String?
    @State private var tagIds: [String] = []
    @State private var error: String?
    @State private var busy = false

    /// Flutter's `TransactionTyp.values` order.
    private static let types: [TransactionType] = [.income, .expense]

    var body: some View {
        let categories = model.categories(for: type).map(\.name)
        let selectedCategory = Self.resolvedCategory(category, in: categories)
        let canAdd = !DartString.trim(pattern).isEmpty
        VStack(spacing: 0) {
            TagsRulesDialogTitle(text: "New merchant rule")
            DialogScroll { fields(categories: categories, selectedCategory: selectedCategory) }
                .padding(.top, 20)
            if let error {
                Text(error)
                    .textStyle(.caption)
                    .foregroundStyle(BudgieColor.danger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Metrics.spacingM)
            }
            HStack(spacing: 12) {
                PillButton(title: "Cancel", color: BudgieColor.textSecondary, height: 44, action: onClose)
                    .accessibilityIdentifier("rules.editor.cancel")
                PillButton(title: "Add", filled: true, height: 44) { submit(category: selectedCategory) }
                    .disabled(!canAdd)
                    .opacity(canAdd ? 1 : Metrics.opacityDisabled)
                    .accessibilityIdentifier("rules.editor.submit")
            }
            .padding(.top, 24)
        }
        .disabled(busy)
        .budgieDialogDismissDisabled(busy)
        .onChange(of: pattern) { error = nil }
        .onChange(of: type) {
            category = Self.resolvedCategory(category, in: model.categories(for: type).map(\.name))
        }
    }

    private func fields(categories: [String], selectedCategory: String) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            BudgieField(title: "Merchant text", text: $pattern, prompt: "Whole Foods", autofocus: true)
                .accessibilityIdentifier("rules.editor.pattern")
            MenuField(
                title: "Type", options: Self.types.map(Self.typeLabel),
                selection: Binding(
                    get: { Self.types.firstIndex(of: type) ?? 1 },
                    set: { type = Self.types[$0] }),
                identifier: "rules.editor.type")
            MenuField(
                title: "Match", options: MerchantMatchType.allCases.map(Self.matchLabel),
                selection: Binding(
                    get: { MerchantMatchType.allCases.firstIndex(of: matchType) ?? 0 },
                    set: { matchType = MerchantMatchType.allCases[$0] }),
                identifier: "rules.editor.match")
            MenuField(
                title: "Category", options: categories,
                selection: Binding(
                    get: { categories.firstIndex { DartString.equal($0, selectedCategory) } ?? 0 },
                    set: { if categories.indices.contains($0) { category = categories[$0] } }),
                identifier: "rules.editor.category")
            if !model.tags.isEmpty {
                tagChips
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The tags as the transaction form's pills (accent with a check when
    /// selected), under a "Tags" caption.
    private var tagChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tags")
                .textStyle(.caption)
                .foregroundStyle(BudgieColor.textSecondary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: Metrics.spacingS) {
                ForEach(model.tags) { tag in
                    let selected = tagIds.contains { DartString.equal($0, tag.id) }
                    Button {
                        if selected { tagIds.removeAll { DartString.equal($0, tag.id) } } else { tagIds.append(tag.id) }
                    } label: {
                        PillChip(
                            label: tag.name, color: selected ? BudgieColor.accent : BudgieColor.textSecondary,
                            outlined: !selected, symbol: selected ? "checkmark" : nil, style: .labelSmall,
                            horizontalPadding: 12, verticalPadding: 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tag.name)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("rules.editor.tag.\(tag.id)")
                }
            }
        }
    }

    private func submit(category: String) {
        guard !busy, !DartString.trim(pattern).isEmpty else { return }
        error = nil
        busy = true
        let draft = RuleDraft(
            merchantPattern: pattern, matchType: matchType, transactionType: type, category: category, tagIds: tagIds)
        Task {
            let outcome = await model.addRule(draft)
            busy = false
            switch outcome {
            case .saved, .unchanged: onClose()
            case .failed:
                onClose()
                model.showToast(.saveFailed)
            case .rejected(let rejection):
                error = rejection.message
                AccessibilityNotification.Announcement(rejection.message).post()
            }
        }
    }

    /// The picked category while the type's list has it (UTF-16 equality,
    /// so "Gift" survives a type switch), else the list's first (Flutter's
    /// `if (!categories.containsKey(category)) category = keys.first`).
    static func resolvedCategory(_ picked: String?, in names: [String]) -> String {
        if let picked, names.contains(where: { DartString.equal($0, picked) }) { return picked }
        return names.first ?? ""
    }

    static func typeLabel(_ type: TransactionType) -> String {
        type == .income ? "Income" : "Expense"
    }

    static func matchLabel(_ match: MerchantMatchType) -> String {
        switch match {
        case .contains: "Contains"
        case .startsWith: "Starts with"
        case .exact: "Exact match"
        }
    }
}

/// A dropdown in the redesign's field style (Material
/// `DropdownButtonFormField`): the caption above, the chip-surface box
/// (radius 14, 1pt card border, 52 tall) with the value in rowTitle and an
/// up-down chevron; the system menu lists the options with a check on the
/// current one. Options are picked by index (names are compared as UTF-16
/// elsewhere, and equal-looking names stay separate rows). VoiceOver reads
/// the title with the value.
private struct MenuField: View {
    let title: String
    let options: [String]
    @Binding var selection: Int
    let identifier: String

    var body: some View {
        let value = options.indices.contains(selection) ? options[selection] : ""
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .textStyle(.caption)
                .foregroundStyle(BudgieColor.textSecondary)
                .padding(.leading, 4)
                .accessibilityHidden(true)
            Menu {
                Picker(title, selection: $selection) {
                    ForEach(options.indices, id: \.self) { index in
                        Text(options[index]).tag(index)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(value)
                        .textStyle(.rowTitle)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BudgieColor.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(BudgieColor.chipSurface, in: shape)
                .overlay(shape.strokeBorder(BudgieColor.cardBorder, lineWidth: 1))
                .contentShape(shape)
            }
            .menuOrder(.fixed)
            .accessibilityLabel(title)
            .accessibilityValue(value)
            .accessibilityIdentifier(identifier)
        }
    }
}
