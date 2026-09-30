import BudgieCore
import SwiftUI

/// Tags and merchant rules (`CategorizationSettingsPage`,
/// categorization_settings_page.dart:11-78), pushed from Settings >
/// PERSONALIZATION > Tags & rules: "Tags" with its ADD button over the tags
/// in stored order (or the empty card), then "Merchant rules" over the
/// rules in Flutter's `rules` order (priority descending). Each row has a
/// trailing delete button; rows have no tap (as Flutter).
///
/// Differences from Flutter (PARITY_GAPS): the rows use the redesign's
/// icon tiles and row text; deleting a tag asks first (it also leaves every
/// rule that used it), deleting a rule does not (as Flutter); the dialogs
/// are the redesign's centred card and show refusals inline; a failed
/// write shows the save-failed toast (Flutter is silent).
struct TagsRulesView: View {
    @Environment(AppModel.self) private var model

    @State private var dialog: TagsRulesDialog?

    /// M3 `TextButton` label (`labelLarge`: 14 / w500, tracking 0.1, 1.43).
    static let addText = TextSpec(face: .gabaritoMedium, size: 14, tracking: 0.1, height: 1.43, relativeTo: .subheadline)

    var body: some View {
        let tags = model.tags
        let rules = model.rules
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(title: "Tags", addLabel: "Add tag", identifier: "tags.add") { dialog = .newTag }
                Group {
                    if tags.isEmpty {
                        EmptyCard(message: "Add tags to group transactions across categories.")
                            .accessibilityIdentifier("tags.empty")
                    } else {
                        GlowListCard(rows: Self.keyed(tags, id: \.id).map { item in
                            TagRow(tag: item.value, key: item.key) { dialog = .deleteTag(item.value) }
                        })
                    }
                }
                .padding(.top, Metrics.spacingS)
                SectionTitle(title: "Merchant rules", addLabel: "Add merchant rule", identifier: "rules.add") {
                    dialog = .newRule
                }
                .padding(.top, Metrics.spacingXL)
                Group {
                    if rules.isEmpty {
                        EmptyCard(message: "Rules can automatically choose a category and tags from a merchant name.")
                            .accessibilityIdentifier("rules.empty")
                    } else {
                        GlowListCard(rows: Self.keyed(rules, id: \.id).map { item in
                            RuleRow(rule: item.value, key: item.key) { deleteRule(item.value) }
                        })
                    }
                }
                .padding(.top, Metrics.spacingS)
            }
            // Flutter's ListView padding (`spacingM` all round).
            .padding(Metrics.spacingM)
        }
        .accessibilityIdentifier("tagsRules.list")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BudgieColor.background)
        .navigationTitle("Tags & rules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(BudgieColor.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Tags & rules")
                    .textStyle(.cardTitle)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .budgieDialog(item: $dialog) { presented in
            switch presented {
            case .newTag: NewTagDialog { dialog = nil }
            case .newRule: NewRuleDialog { dialog = nil }
            case .deleteTag(let tag): DeleteTagDialog(tag: tag) { dialog = nil }
            }
        }
    }

    /// Flutter deletes a rule at once (no confirmation). Memory changes
    /// first, so the row goes before the write (Flutter's stays until its
    /// write is done); a second tap finds no rule and writes nothing.
    /// Silent when saved, the save-failed toast (and the unsaved banner)
    /// when only memory changed.
    private func deleteRule(_ rule: CategorizationRuleRecord) {
        Task {
            if await model.deleteRule(id: rule.id) == .failed { model.showToast(.saveFailed) }
        }
    }

    /// The rule row's subtitle, Flutter's exact string: the raw match type
    /// name, the category, and " · n tags" when it has any (never
    /// singular): "contains · Groceries · 1 tags".
    static func ruleSubtitle(_ rule: CategorizationRuleRecord) -> String {
        let tags = rule.tagIds.isEmpty ? "" : " \u{00B7} \(rule.tagIds.count) tags"
        return "\(rule.matchType.rawValue) \u{00B7} \(rule.category)\(tags)"
    }

    /// Row keys: the id, with its occurrence for a repeated id (foreign
    /// data).
    private static func keyed<Value>(_ values: [Value], id: (Value) -> String) -> [(key: String, value: Value)] {
        var seen: [String: Int] = [:]
        return values.map { value in
            let raw = id(value)
            let n = seen[raw, default: 0]
            seen[raw] = n + 1
            return (n == 0 ? raw : "\(raw)#\(n)", value)
        }
    }
}

/// What the page presents in its centred dialog.
enum TagsRulesDialog: Identifiable {
    case newTag
    case newRule
    case deleteTag(TransactionTagRecord)

    var id: String {
        switch self {
        case .newTag: "newTag"
        case .newRule: "newRule"
        case .deleteTag(let tag): "deleteTag.\(tag.id)"
        }
    }
}

/// `_SectionTitle`: the title in headingMedium and a Material `TextButton`
/// "ADD" in accent (min 64 wide, 12 side padding, 48 tall with its tap
/// target). No haptic, as Flutter.
private struct SectionTitle: View {
    let title: String
    let addLabel: String
    let identifier: String
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .textStyle(.headingMedium)
                .foregroundStyle(BudgieColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button(action: onAdd) {
                Text("ADD")
                    .textStyle(TagsRulesView.addText)
                    .foregroundStyle(BudgieColor.accent)
                    .padding(.horizontal, 12)
                    .frame(minWidth: 64, minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(addLabel)
            .accessibilityIdentifier(identifier)
        }
    }
}

/// `_EmptyCard`: a GlowCard with the message in bodyMedium, secondary.
private struct EmptyCard: View {
    let message: String

    var body: some View {
        GlowCard {
            Text(message)
                .textStyle(.bodyMedium)
                .foregroundStyle(BudgieColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The 48pt trailing delete button (Material `delete_rounded` in an
/// `IconButton`, 20pt symbol like the other ported 24pt icons).
private struct DeleteButton: View {
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: Metrics.iconS, weight: .medium))
                .foregroundStyle(BudgieColor.textSecondary)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

/// A tag (one-line M3 `ListTile`, 56 tall, padding 16 / 24, 16 gaps): the
/// `tag` tile in accent, the name, the delete button ("Delete {name}",
/// Flutter's tooltip), which asks first. VoiceOver: the name is one
/// element with Delete as an action, then the button.
private struct TagRow: View {
    let tag: TransactionTagRecord
    let key: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            IconTile(symbol: "tag", color: BudgieColor.accent)
            Text(tag.name)
                .textStyle(.rowTitle)
                .foregroundStyle(BudgieColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(tag.name)
                .accessibilityAction(named: "Delete") { onDelete() }
                .accessibilityIdentifier("tags.row.\(key)")
            DeleteButton(label: "Delete \(tag.name)", identifier: "tags.row.delete.\(key)", action: onDelete)
        }
        .padding(.leading, Metrics.spacingM)
        .padding(.trailing, Metrics.spacingL)
        .frame(minHeight: 56)
    }
}

/// A rule (two-line M3 `ListTile`, 72 tall): the `sparkles` tile in info
/// (Settings' Tags & rules tint), the merchant text over Flutter's
/// subtitle, the delete button (instant, as Flutter). VoiceOver: the text
/// is one element (pattern, value = subtitle) with Delete as an action,
/// then "Delete rule {pattern}".
private struct RuleRow: View {
    let rule: CategorizationRuleRecord
    let key: String
    let onDelete: () -> Void

    var body: some View {
        let subtitle = TagsRulesView.ruleSubtitle(rule)
        HStack(spacing: Metrics.spacingM) {
            IconTile(symbol: "sparkles", color: BudgieColor.info)
            VStack(alignment: .leading, spacing: 0) {
                Text(rule.merchantPattern)
                    .textStyle(.rowTitle)
                    .foregroundStyle(BudgieColor.textPrimary)
                Text(subtitle)
                    .textStyle(.rowSubtitle)
                    .foregroundStyle(BudgieColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rule.merchantPattern)
            .accessibilityValue(subtitle)
            .accessibilityAction(named: "Delete") { onDelete() }
            .accessibilityIdentifier("rules.row.\(key)")
            DeleteButton(label: "Delete rule \(rule.merchantPattern)", identifier: "rules.row.delete.\(key)", action: onDelete)
        }
        .padding(.leading, Metrics.spacingM)
        .padding(.trailing, Metrics.spacingL)
        .frame(minHeight: 72)
    }
}
