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
/// enabled. Changing the type keeps the shown category (the picked one, or
/// the old type's first when none was picked, as Flutter's variable starts
/// at the first expense category) when the new type has that name
/// (UTF-16), else takes its first; the tag selection stays.
/// Add is disabled while the trimmed merchant text is empty (Flutter's Add
/// does nothing then). The add is awaited with the dialog inert; it closes
/// once written, and also when the write failed (the rule is in memory
/// behind the unsaved banner), with the save-failed toast. A refusal shows
/// its message above the buttons.
///
/// The keyboard (Flutter's: no capitalisation, a Done key) goes away on
/// Done and when a dropdown opens, so the menu is not cut by it. With the
/// keyboard up the fields scroll; the scroll indicator flashes once the
/// keyboard is shown and the bottom edge fades while more is below, cues
/// that Category and Tags are there.
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
    /// Flashes the fields' scroll indicator.
    @State private var scrollFlash = 0

    /// Flutter's `TransactionTyp.values` order.
    private static let types: [TransactionType] = [.income, .expense]

    var body: some View {
        let categories = model.categories(for: type).map(\.name)
        let selectedCategory = Self.resolvedCategory(category, in: categories)
        let canAdd = !DartString.trim(pattern).isEmpty
        VStack(spacing: 0) {
            TagsRulesDialogTitle(text: "New merchant rule")
            DialogScroll { fields(categories: categories, selectedCategory: selectedCategory) }
                .scrollIndicatorsFlash(trigger: scrollFlash)
                .modifier(MoreBelowFade())
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
        .onChange(of: type) { old, new in
            category = Self.categoryAfterTypeChange(
                category, from: model.categories(for: old).map(\.name), to: model.categories(for: new).map(\.name))
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            scrollFlash += 1
        }
    }

    private func fields(categories: [String], selectedCategory: String) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            BudgieField(
                title: "Merchant text", text: $pattern, prompt: "Whole Foods", capitalization: .never, autofocus: true)
                .submitLabel(.done)
                .onSubmit(Self.dismissKeyboard)
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
                // By position: foreign data can repeat a tag id.
                ForEach(Array(model.tags.enumerated()), id: \.offset) { _, tag in
                    let selected = tagIds.contains { DartString.equal($0, tag.id) }
                    Button {
                        if selected { tagIds.removeAll { DartString.equal($0, tag.id) } } else { tagIds.append(tag.id) }
                    } label: {
                        PillChip(
                            label: tag.name, color: selected ? BudgieColor.accent : BudgieColor.textSecondary,
                            outlined: !selected, symbol: selected ? "checkmark" : nil, style: .labelSmall,
                            horizontalPadding: 12, verticalPadding: 8)
                        .lineLimit(1)
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

    /// The category after a type change: the one shown under the old type
    /// (the picked one, or its first when none was picked: Flutter's
    /// variable starts at the first expense category), kept when the new
    /// type has it, else the new type's first.
    static func categoryAfterTypeChange(_ picked: String?, from old: [String], to new: [String]) -> String {
        resolvedCategory(resolvedCategory(picked, in: old), in: new)
    }

    /// Ends editing wherever the keyboard is (the field's focus is its own).
    static func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

/// Fades the bottom edge of the dialog's scroll area while more fields are
/// below it (the keyboard is up), so the cut reads as scrollable. iOS 18
/// and later; iOS 17 keeps the indicator flash only.
private struct MoreBelowFade: ViewModifier {
    @State private var moreBelow = false

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height > 1
                } action: { _, more in
                    moreBelow = more
                }
                .mask {
                    VStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(colors: [.black, .black.opacity(moreBelow ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 48)
                    }
                }
        } else {
            content
        }
    }
}

/// A dropdown in the redesign's field style (Material
/// `DropdownButtonFormField`): the caption above, the chip-surface box
/// (radius 14, 1pt card border, 52 tall) with the value in rowTitle and an
/// up-down chevron (footnote-sized, so it scales with Dynamic Type). A tap
/// opens a popover list anchored to the box, a check on the current
/// option. With the keyboard up the tap first dismisses it and opens the
/// list once it is gone and the dialog has settled (Flutter's dropdown
/// closes the keyboard first; a system `Menu` cannot wait, so it opened
/// cut by the keyboard or detached from its moved field). Options are
/// picked by index (names are compared as UTF-16 elsewhere, and
/// equal-looking names stay separate rows). VoiceOver reads the title
/// with the value.
private struct MenuField: View {
    let title: String
    let options: [String]
    @Binding var selection: Int
    let identifier: String

    @State private var open = false
    @State private var keyboardUp = false
    /// Tapped with the keyboard up: opens when it has gone.
    @State private var opening = false
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 48

    var body: some View {
        let value = options.indices.contains(selection) ? options[selection] : ""
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .textStyle(.caption)
                .foregroundStyle(BudgieColor.textSecondary)
                .padding(.leading, 4)
                .accessibilityHidden(true)
            Button(action: tap) {
                HStack(spacing: 10) {
                    Text(value)
                        .textStyle(.rowTitle)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(BudgieColor.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(BudgieColor.chipSurface, in: shape)
                .overlay(shape.strokeBorder(BudgieColor.cardBorder, lineWidth: 1))
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $open, attachmentAnchor: .rect(.bounds)) {
                optionList
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityLabel(title)
            .accessibilityValue(value)
            .accessibilityIdentifier(identifier)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            keyboardUp = false
            if opening {
                opening = false
                open = true
            }
        }
    }

    private func tap() {
        if keyboardUp {
            opening = true
            NewRuleDialog.dismissKeyboard()
        } else {
            open = true
        }
    }

    /// The options, scrolled to the current one, as tall as they need up to
    /// about nine rows.
    private var optionList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(options.indices, id: \.self) { index in
                        let current = index == selection
                        Button {
                            selection = index
                            open = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(BudgieColor.accent)
                                    .opacity(current ? 1 : 0)
                                    .accessibilityHidden(true)
                                Text(options[index])
                                    .textStyle(.rowTitle)
                                    .foregroundStyle(BudgieColor.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: rowHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(current ? .isSelected : [])
                        .id(index)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(idealWidth: 260, idealHeight: min(CGFloat(options.count), 9.5) * rowHeight + 12)
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }
}
