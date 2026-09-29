import BudgieCore
import SwiftUI
import UIKit

/// Home's Budgets section (spending_page.dart:597-627): the section header
/// with its EDIT link, then the budgets card (`_BudgetsCard`). Owns the
/// budget sheets: the EDIT and Add pickers and the limit sheet.
struct BudgetsSection: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: BudgetSheet?
    /// Opens once `sheet` has finished dismissing: Flutter awaits the
    /// picker's pop, then pushes the next sheet (never stacked).
    @State private var nextSheet: BudgetSheet?

    var body: some View {
        let progress = model.budgetProgress(forMonth: model.selectedMonth)
        // Dart `budgets.length < expenseCategories.length`: the rows are the
        // budgeted expense categories, so this holds iff one is unbudgeted.
        let showsAddRow = !model.unbudgetedCategories().isEmpty
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Budgets", link: "EDIT") { sheet = .edit }
            GlowListCard(rows: cardRows(progress, showsAddRow: showsAddRow))
        }
        .padding(.horizontal, Metrics.pageHorizontal)
        .sheet(item: $sheet, onDismiss: presentNextSheet) { item in
            switch item {
            case .edit:
                BudgetPickerSheet(kind: .edit, onPick: openLimit(after:), onAdd: { chain(.add) })
            case .add:
                BudgetPickerSheet(kind: .add, onPick: openLimit(after:), onAdd: {})
            case .limit(let category, let current):
                BudgetLimitSheet(category: category, currentLimit: current, formatter: model.moneyFormatter)
            }
        }
    }

    private func cardRows(_ progress: [BudgetProgress], showsAddRow: Bool) -> [BudgetCardRow] {
        let formatter = model.moneyFormatter
        var rows = progress.map { item in
            BudgetCardRow(
                kind: .budget(item, model.categoryInfo(named: item.category, type: .expense)), formatter: formatter
            ) {
                sheet = .limit(category: item.category, current: model.budgetLimit(for: item.category))
            }
        }
        if showsAddRow {
            let subtitle = progress.isEmpty ? "No monthly limits yet" : "Set a limit for another category"
            rows.append(BudgetCardRow(kind: .add(subtitle: subtitle), formatter: formatter) { sheet = .add })
        }
        return rows
    }

    /// A picker's category pick: close the picker, then the limit sheet.
    private func openLimit(after category: String) {
        chain(.limit(category: category, current: model.budgetLimit(for: category)))
    }

    private func chain(_ next: BudgetSheet) {
        nextSheet = next
        sheet = nil
    }

    private func presentNextSheet() {
        guard let next = nextSheet else { return }
        nextSheet = nil
        sheet = next
    }
}

private enum BudgetSheet: Identifiable {
    case edit, add
    /// The limit is captured when the sheet opens (`currentLimit`).
    case limit(category: String, current: Double?)

    var id: String {
        switch self {
        case .edit: "edit"
        case .add: "add"
        case .limit(let category, _): "limit-\(category)"
        }
    }
}

/// `_BudgetRow._formatCurrency`: whole units from 100 up, else cents.
private func budgetAmount(_ value: Double, _ formatter: MoneyFormatter) -> String {
    formatter.format(value, decimalDigits: abs(value) >= 100 ? 0 : 2)
}

// MARK: - Card rows

/// One child of the budgets card: a budget row or the Add row.
private struct BudgetCardRow: View {
    enum Kind {
        case budget(BudgetProgress, CategoryInfo?)
        case add(subtitle: String)
    }

    let kind: Kind
    let formatter: MoneyFormatter
    let action: () -> Void

    var body: some View {
        switch kind {
        case .budget(let item, let info): BudgetRow(item: item, info: info, formatter: formatter, action: action)
        case .add(let subtitle): AddBudgetRow(subtitle: subtitle, action: action)
        }
    }
}

/// `_BudgetRow` (spending_page.dart:1587-1701): status-tinted icon tile,
/// name over "spent of limit", the left/over chip, then an 8pt bar. Tap
/// opens the limit sheet with a light haptic; no press scale.
private struct BudgetRow: View {
    let item: BudgetProgress
    let info: CategoryInfo?
    let formatter: MoneyFormatter
    let action: () -> Void

    @State private var taps = 0

    var body: some View {
        let color = statusColor
        let subtitle = "\(budgetAmount(item.spent, formatter)) of \(budgetAmount(item.limit, formatter))"
        let chip =
            item.isOver
            ? "\(budgetAmount(abs(item.remaining), formatter)) over" : "\(budgetAmount(item.remaining, formatter)) left"
        Button {
            taps += 1
            action()
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    IconTile(symbol: CategoryCatalog.symbol(for: info?.iconIdentifier ?? ""), color: color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.category)
                            .textStyle(.rowTitle)
                            .foregroundStyle(BudgieColor.textPrimary)
                            .lineLimit(1)
                        Text(subtitle)
                            .textStyle(.rowSubtitle)
                            .foregroundStyle(BudgieColor.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    PillChip(label: chip, color: color).fixedSize()
                }
                GlowProgressBar(value: item.progress, height: 8, color: color)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityLabel("\(item.category), \(subtitle), \(chip)")
        .accessibilityHint("Opens the monthly limit")
    }

    /// `_statusColor`: over is danger, from 85% warning, else income green.
    private var statusColor: Color {
        switch item.status {
        case .over: BudgieColor.danger
        case .warning: BudgieColor.warning
        case .ok: BudgieColor.income
        }
    }
}

/// `_AddBudgetRow` (spending_page.dart:1819-1873): accent plus tile,
/// "Add a budget", an optional subtitle (card only) and a chevron.
private struct AddBudgetRow: View {
    var subtitle: String? = nil
    let action: () -> Void

    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: "plus", color: BudgieColor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a budget").textStyle(.rowTitle).foregroundStyle(BudgieColor.accent)
                    if let subtitle {
                        Text(subtitle).textStyle(.rowSubtitle).foregroundStyle(BudgieColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                BudgetChevron()
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}

/// `Symbols.chevron_right_rounded` 20, weight 500, tertiary.
private struct BudgetChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(BudgieColor.textTertiary)
            .frame(width: 20)
            .accessibilityHidden(true)
    }
}

// MARK: - Picker sheets

/// The EDIT and Add a budget pickers (`_showBudgetCategorySheet`,
/// spending_page.dart:221-312): title, subtitle, then the category tiles
/// with no dividers. Content-sized up to 75% of the screen height, the
/// bottom safe inset added outside the cap as in Flutter.
private struct BudgetPickerSheet: View {
    enum Kind { case edit, add }

    let kind: Kind
    let onPick: (String) -> Void
    let onAdd: () -> Void

    @Environment(AppModel.self) private var model
    @State private var headerHeight: CGFloat = 0
    @State private var listHeight: CGFloat = 0
    @State private var bottomInset: CGFloat = 0

    var body: some View {
        let categories = kind == .edit ? model.budgetedCategories() : model.unbudgetedCategories()
        // `showAddRow: budgeted.length < expenseCategories.length` (EDIT only).
        let showsAddRow = kind == .edit && !model.unbudgetedCategories().isEmpty
        let formatter = model.moneyFormatter
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .textStyle(.sectionHeader)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    // 12 + the chrome's 20pt handle inset = Flutter's 12 + 4 + 16.
                    .padding(EdgeInsets(top: 12, leading: 24, bottom: 8, trailing: 24))
                Text(subtitle(hasBudgets: !categories.isEmpty))
                    .textStyle(.rowSubtitle)
                    .foregroundStyle(BudgieColor.textSecondary)
                    .padding(EdgeInsets(top: 0, leading: 24, bottom: 8, trailing: 24))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChangeCompat { headerHeight = $0.height }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(categories) { info in
                        BudgetCategoryTile(
                            info: info, limit: kind == .edit ? model.budgetLimit(for: info.name) : nil,
                            formatter: formatter
                        ) { onPick(info.name) }
                    }
                    if showsAddRow { AddBudgetRow(action: onAdd) }
                }
                .padding(EdgeInsets(top: 4, leading: 12, bottom: 12, trailing: 12))
                .onGeometryChangeCompat { listHeight = $0.height }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onBudgetSheetBottomInset { bottomInset = $0 }
        .budgieSheetChrome()
        .presentationDetents([detent])
    }

    private var detent: PresentationDetent {
        guard headerHeight > 0 else { return .medium }
        let natural = BudgetSheetLayout.handleHeight + headerHeight + listHeight
        return .height(min(natural, BudgetSheetLayout.screenHeight * 0.75) + bottomInset)
    }

    private var title: String { kind == .edit ? "Edit budgets" : "Add a budget" }

    private func subtitle(hasBudgets: Bool) -> String {
        switch kind {
        case .edit:
            hasBudgets
                ? "Tap a budget to change or remove its monthly limit."
                : "No monthly limits yet. Add one to start tracking a category."
        case .add: "Choose a category to set a monthly limit."
        }
    }
}

/// `_EditBudgetCategoryTile` (spending_page.dart:1876-1946): accent tile
/// and "$X limit" for a budgeted category, a grey tile and no subtitle in
/// the Add sheet; chevron; light haptic.
private struct BudgetCategoryTile: View {
    let info: CategoryInfo
    let limit: Double?
    let formatter: MoneyFormatter
    let action: () -> Void

    @State private var taps = 0

    var body: some View {
        let budgeted = (limit ?? 0) > 0
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: 12) {
                IconTile(
                    symbol: CategoryCatalog.symbol(for: info.iconIdentifier),
                    color: budgeted ? BudgieColor.accent : BudgieColor.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name).textStyle(.rowTitle).foregroundStyle(BudgieColor.textPrimary).lineLimit(1)
                    if budgeted, let limit {
                        Text("\(formatter.format(limit, decimalDigits: 0)) limit")
                            .textStyle(.rowSubtitle)
                            .foregroundStyle(BudgieColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                BudgetChevron()
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 1))
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}

// MARK: - Sheet sizing

/// Sizes the budget sheets to their content the way Flutter's
/// `MediaQuery` does: against the full window height.
@MainActor
enum BudgetSheetLayout {
    /// `budgieSheetChrome`'s grab-handle inset: 10 + 4 + 6.
    static let handleHeight: CGFloat = 20

    /// Flutter `MediaQuery.sizeOf(context).height`.
    static var screenHeight: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.keyWindow?.bounds.height ?? scene?.screen.bounds.height ?? 844
    }
}

extension View {
    /// Reports the bottom safe-area inset under a sheet's content: the home
    /// indicator, or 0 while the sheet sits on the keyboard.
    func onBudgetSheetBottomInset(_ action: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { action(proxy.safeAreaInsets.bottom) }
                    .onChange(of: proxy.safeAreaInsets.bottom) { _, inset in action(inset) }
            }
            .ignoresSafeArea(.container, edges: .bottom))
    }
}
