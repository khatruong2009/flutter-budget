import BudgieCore
import SwiftUI

/// Transitional shim over `BudgieColor` for views not yet restyled.
/// Removed once every view uses the design-system tokens.
enum Theme {
    static let accent = BudgieColor.accent
    static let income = BudgieColor.income
    static let expense = BudgieColor.danger
    static let warning = BudgieColor.warning
    static let background = BudgieColor.background
    static let card = BudgieColor.card

    static func color(token: String) -> Color { BudgieColor.category(token) }
}

/// Icon tile for a category name, using its definition when there is one.
struct CategoryIcon: View {
    let info: CategoryInfo?
    var size: CGFloat = 32

    var body: some View {
        let color = Theme.color(token: info?.colorToken ?? "accent")
        Image(systemName: CategoryCatalog.symbol(for: info?.iconIdentifier ?? ""))
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}
