import BudgieCore
import SwiftUI

/// Category management (`CategorySettingsPage`,
/// category_settings_page.dart:26-181), pushed from Settings >
/// PERSONALIZATION > Categories: the Expenses | Income pills, "Show
/// archived", then one card per definition of the selected type in sort
/// order (archived ones interleaved, only while the switch is on). The bar's
/// "+" opens the editor for the selected type; each row's menu offers Edit,
/// Move up, Move down and Archive / Restore.
///
/// Differences from Flutter (PARITY_GAPS): no duplicate FAB; Move up / Move
/// down step over hidden archived rows (`categoryMoveOffset`); the editor is
/// the redesign's centred card with inline errors; the row menu is the
/// system menu. Refused row actions (archiving the last active category)
/// show Flutter's copy in the neutral toast (its default SnackBar), a
/// failed write the save-failed toast. Neither the type nor the switch is
/// persisted (as Flutter).
struct CategoriesView: View {
    @Environment(AppModel.self) private var model

    /// 0 Expenses, 1 Income (`_selectedType`, default expense).
    @State private var typeIndex = 0
    @State private var showArchived = false
    @State private var editor: CategoryEditorRequest?

    /// `SwitchListTile`'s title: M3 `bodyLarge` (16 / 1.5, tracking 0.5).
    private static let switchTitle = TextSpec(face: .gabaritoRegular, size: 16, tracking: 0.5, height: 1.5, relativeTo: .body)

    private var type: TransactionType { typeIndex == 0 ? .expense : .income }

    var body: some View {
        let categories = model.categoryDefinitions(type: type, includeArchived: showArchived)
        VStack(spacing: 0) {
            SegmentedPills(items: ["Expenses", "Income"], selection: $typeIndex)
                .fixedSize()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Category type")
                .accessibilityIdentifier("categories.type")
                .padding(EdgeInsets(top: Metrics.spacingS, leading: Metrics.spacingM, bottom: 0, trailing: Metrics.spacingM))
            archivedSwitch
            ScrollView {
                LazyVStack(spacing: Metrics.spacingS) {
                    ForEach(Self.keyed(categories), id: \.key) { item in
                        CategoryRow(
                            category: item.category,
                            actions: CategoryRowAction.menu(
                                index: item.index, count: categories.count, isArchived: item.category.isArchived)
                        ) { perform($0, on: item.category) }
                    }
                }
                .padding(EdgeInsets(top: 0, leading: Metrics.spacingM, bottom: Metrics.spacingXL, trailing: Metrics.spacingM))
            }
            // A new list per type, starting at the top: the kept offset of a
            // scrolled Expenses list left the shorter Income list above the
            // viewport (Flutter's list shows the other type from the top).
            .id(typeIndex)
            .accessibilityIdentifier("categories.list")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BudgieColor.background)
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(BudgieColor.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Categories")
                    .textStyle(.cardTitle)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .singleLine()
                    .accessibilityAddTraits(.isHeader)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = CategoryEditorRequest(type: type, category: nil)
                } label: {
                    Image(systemName: "plus").foregroundStyle(BudgieColor.textPrimary)
                }
                .accessibilityLabel("Add category")
                .accessibilityIdentifier("categories.add")
            }
        }
        .budgieDialog(item: $editor) { request in
            CategoryEditorDialog(request: request) { editor = nil }
        }
    }

    /// `SwitchListTile.adaptive` (padding 24 horizontal, 56 tall): the
    /// systemGreen switch, and the title also toggles it (the whole tile
    /// is Flutter's tap target). VoiceOver reads the switch by the title.
    /// The title's tap and the switch do not overlap: a zero-length
    /// synthetic tap (Simulator tooling) misses every system switch in the
    /// app, Settings' included, while a real touch toggles it once.
    private var archivedSwitch: some View {
        HStack(spacing: Metrics.spacingM) {
            Text("Show archived")
                .textStyle(Self.switchTitle)
                .foregroundStyle(BudgieColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { showArchived.toggle() }
                .accessibilityHidden(true)
            Toggle("Show archived", isOn: $showArchived)
                .labelsHidden()
                .tint(.green)
                .accessibilityIdentifier("categories.showArchived")
        }
        .padding(.leading, Metrics.spacingL)
        // CupertinoSwitch keeps its own margin inside the tile: its track
        // ends about 30pt from the edge.
        .padding(.trailing, Metrics.spacingL + Metrics.spacingS)
        .frame(minHeight: 56)
    }

    // MARK: - Row actions

    private func perform(_ action: CategoryRowAction, on category: CategoryInfo) {
        switch action {
        case .edit:
            editor = CategoryEditorRequest(type: category.type, category: category)
        case .moveUp, .moveDown:
            // Relative to the rows shown (hops over hidden archived rows).
            guard let offset = model.categoryMoveOffset(
                id: category.id, direction: action == .moveUp ? -1 : 1, includeArchived: showArchived)
            else { return }
            run { await model.moveCategory(id: category.id, offset: offset) }
        case .archive:
            run { await model.setCategoryArchived(id: category.id, true) }
        case .restore:
            run { await model.setCategoryArchived(id: category.id, false) }
        }
    }

    /// Awaits the edit; silent when saved or a no-op (as Flutter), the
    /// save-failed toast when only memory changed, Flutter's message in the
    /// neutral toast when refused.
    private func run(_ edit: @escaping () async -> AppModel.CategoryOutcome) {
        Task {
            switch await edit() {
            case .saved, .unchanged: break
            case .failed: model.showToast(.saveFailed)
            case .rejected(let error): model.showToast(CategoryRowAction.refusedToast(error))
            }
        }
    }

    /// Row keys: the id, with its occurrence for a repeated id (foreign
    /// data), and the row's index in the list shown.
    private static func keyed(_ categories: [CategoryInfo]) -> [(key: String, index: Int, category: CategoryInfo)] {
        var seen: [String: Int] = [:]
        return categories.enumerated().map { index, category in
            let n = seen[category.id, default: 0]
            seen[category.id] = n + 1
            return (n == 0 ? category.id : "\(category.id)#\(n)", index, category)
        }
    }
}

/// A row menu item (`PopupMenuItem`s, category_settings_page.dart:113-139).
enum CategoryRowAction: Hashable {
    case edit, moveUp, moveDown, archive, restore

    var title: String {
        switch self {
        case .edit: "Edit"
        case .moveUp: "Move up"
        case .moveDown: "Move down"
        case .archive: "Archive"
        case .restore: "Restore"
        }
    }

    /// Flutter's items for the row at `index` of the `count` rows shown:
    /// Edit; Move up unless archived or first; Move down unless archived or
    /// last; Restore for an archived row, else Archive.
    static func menu(index: Int, count: Int, isArchived: Bool) -> [CategoryRowAction] {
        var items: [CategoryRowAction] = [.edit]
        if !isArchived && index > 0 { items.append(.moveUp) }
        if !isArchived && index < count - 1 { items.append(.moveDown) }
        items.append(isArchived ? .restore : .archive)
        return items
    }

    /// The row's subtitle: "Built in" and "Archived" joined with " · ",
    /// empty for an active custom category.
    static func subtitle(for category: CategoryInfo) -> String {
        [category.isBuiltIn ? "Built in" : nil, category.isArchived ? "Archived" : nil]
            .compactMap { $0 }
            .joined(separator: " \u{00B7} ")
    }

    /// A refused row action: Flutter's message in its default SnackBar
    /// (`_handleAction`'s plain `SnackBar`), the neutral toast.
    static func refusedToast(_ error: CategoryEditError) -> Toast {
        Toast(message: error.message, style: .neutral)
    }
}

extension Metrics {
    /// Categories' glyphs (row tiles, the editor's icon grid, the row
    /// menu): SF Symbols draw about 18% larger than Flutter's Cupertino and
    /// Material glyphs at the same size, so 17 renders like Flutter's 20
    /// (tile and grid, measured) and its 24pt `more_horiz`.
    static let categoryGlyph: CGFloat = 17
}

/// One definition (`GlowCard(padding: 8)` around a two-line M3 `ListTile`,
/// :90-141): content padding 16 / 24, the 40pt tile in the category colour,
/// 16 apart, the name over the subtitle 4 apart as the M3 two-line layout
/// places them (an empty subtitle still takes its line, as Flutter's empty
/// `Text`), the 48pt "Category actions" menu; 72 tall. No row tap (as
/// Flutter).
///
/// VoiceOver: the text is one element ("Groceries", "Built in") offering
/// the menu's items as actions; the menu button follows it, valued with the
/// category's name.
private struct CategoryRow: View {
    let category: CategoryInfo
    let actions: [CategoryRowAction]
    let onAction: (CategoryRowAction) -> Void

    /// `rowTitle` / `rowSubtitle` as `ListTile` renders them: they set no
    /// letter spacing, so M3's `bodyLarge` (0.5) and `bodyMedium` (0.25)
    /// tracking carries over.
    private static let title = TextSpec(face: .gabaritoSemiBold, size: 15, tracking: 0.5, height: 1.25, relativeTo: .body)
    private static let subtitle = TextSpec(
        face: .gabaritoRegular, size: 12, tracking: 0.25, height: 1.25, relativeTo: .caption)

    var body: some View {
        let subtitle = CategoryRowAction.subtitle(for: category)
        GlowCard(padding: Metrics.spacingS) {
            HStack(spacing: Metrics.spacingM) {
                IconTile(
                    symbol: CategoryCatalog.symbol(for: category.iconIdentifier),
                    color: BudgieColor.category(category.colorToken), iconSize: Metrics.categoryGlyph)
                VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                    Text(category.name)
                        .textStyle(Self.title)
                        .foregroundStyle(BudgieColor.textPrimary)
                    Text(subtitle.isEmpty ? " " : subtitle)
                        .textStyle(Self.subtitle)
                        .foregroundStyle(BudgieColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(category.name)
                .accessibilityValue(subtitle)
                .accessibilityActions {
                    ForEach(actions, id: \.self) { action in
                        Button(action.title) { onAction(action) }
                    }
                }
                .accessibilityIdentifier("categories.row.\(category.id)")
                Menu {
                    ForEach(actions, id: \.self) { action in
                        Button(action.title) { onAction(action) }
                    }
                } label: {
                    // Material `more_horiz` (24) in a 48pt IconButton; bold
                    // gives its larger dots.
                    Image(systemName: "ellipsis")
                        .font(.system(size: Metrics.categoryGlyph, weight: .bold))
                        .foregroundStyle(BudgieColor.textSecondary)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .menuOrder(.fixed)
                .accessibilityLabel("Category actions")
                .accessibilityValue(category.name)
                .accessibilityIdentifier("categories.row.menu.\(category.id)")
            }
            .padding(.leading, Metrics.spacingM)
            .padding(.trailing, Metrics.spacingL)
            .frame(minHeight: 72)
        }
    }
}
