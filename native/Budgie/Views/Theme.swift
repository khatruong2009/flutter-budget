import BudgieCore
import SwiftUI

/// The Flutter app's palette (research G section 2.1), light and dark.
enum Theme {
    static let accent = dynamic(light: 0x6366F1, dark: 0x818CF8)
    static let income = dynamic(light: 0x10B981, dark: 0x34D399)
    static let expense = dynamic(light: 0xEF4444, dark: 0xFB7185)
    static let warning = dynamic(light: 0xF59E0B, dark: 0xFBBF24)
    static let background = dynamic(light: 0xF9FAFB, dark: 0x0A0A12)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x13131F)

    /// Colour for a category `colorToken`.
    static func color(token: String) -> Color {
        switch token {
        case "orange": warning
        case "green": income
        case "blue": dynamic(light: 0x3B82F6, dark: 0x60A5FA)
        case "purple": dynamic(light: 0x8B5CF6, dark: 0xA78BFA)
        case "cyan": Color(hex: 0x22D3EE)
        case "pink": Color(hex: 0xF0ABFC)
        case "red": expense
        default: accent
        }
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
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
