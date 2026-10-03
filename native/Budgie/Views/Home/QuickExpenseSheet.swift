import BudgieCore
import SwiftUI

/// The category list opened by long-pressing Home's add button
/// (`_showQuickCategoryPicker`, spending_page.dart:314-335, 689-803):
/// "Add expense", then one row per expense category. Choosing one hands
/// its name to `onChoose`; the caller opens the expense form with it once
/// this sheet has gone.
struct QuickExpenseSheet: View {
    let onChoose: (String) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var choices = 0

    var body: some View {
        let categories = model.categories(for: .expense)
        VStack(alignment: .leading, spacing: 0) {
            Text("Add expense")
                .textStyle(.sectionHeader)
                .foregroundStyle(BudgieColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(EdgeInsets(top: 16, leading: 24, bottom: 4, trailing: 24))
            Text("Choose a category, then enter the amount and description.")
                .textStyle(.rowSubtitle)
                .foregroundStyle(BudgieColor.textSecondary)
                .padding(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(categories.indices, id: \.self) { index in
                        if index > 0 {
                            BudgieColor.cardBorder.frame(height: 1).accessibilityHidden(true)
                        }
                        row(categories[index])
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .budgieSheetChrome()
        .presentationDetents([.fraction(0.66), .fraction(0.9)])
        .sensoryFeedback(.selection, trigger: choices)
    }

    private func row(_ category: CategoryInfo) -> some View {
        Button {
            choices += 1
            onChoose(category.name)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: CategoryCatalog.symbol(for: category.iconIdentifier), color: BudgieColor.danger)
                Text(category.name)
                    .textStyle(.rowTitle)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .singleLine()
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(BudgieColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Choose \(category.name)")
        .accessibilityAddTraits(.isButton)
    }
}
