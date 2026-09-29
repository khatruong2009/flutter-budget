import SwiftUI
import UIKit

/// The redesign palette (`theme/app_colors.dart`), resolved per light/dark
/// trait so sheets and overridden interface styles pick the right value.
/// Values are 0xRRGGBB, or 0xAARRGGBB where a token is translucent.
enum BudgieColor {
    // Surfaces
    static let background = dynamic(light: 0xF9FAFB, dark: 0x0A0A12)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x13131F)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x15151F)
    static let chipSurface = dynamic(light: 0xF1F1F7, dark: 0x15151F)
    /// `MonthPill`'s border: white 8% dark, black 8% light (not `cardBorder`).
    static let pillBorder = overlay(dark: 0.08, light: 0.08)
    static let cardBorder = dynamic(light: 0x1410_1020, dark: 0x12FF_FFFF, alpha: true)
    static let hairline = dynamic(light: 0x1010_1020, dark: 0x0FFF_FFFF, alpha: true)
    static let border = dynamic(light: 0xFFE5_E7EB, dark: 0x12FF_FFFF, alpha: true)
    static let track = dynamic(light: 0xE9E9F1, dark: 0x1B1B2C)
    static let trackSecondary = dynamic(light: 0xD9D9E6, dark: 0x2A2A3E)
    static let donutRemainder = dynamic(light: 0xC9C9DA, dark: 0x3A3A52)

    // Text
    static let textPrimary = dynamic(light: 0x111827, dark: 0xF2F2FA)
    static let textSecondary = dynamic(light: 0x6B7280, dark: 0x9A9AB5)
    static let textTertiary = dynamic(light: 0x9CA3AF, dark: 0x5C5C78)
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x0A0A12)

    // Semantic
    static let accent = dynamic(light: 0x6366F1, dark: 0x818CF8)
    static let income = dynamic(light: 0x10B981, dark: 0x34D399)
    /// Expense, over-limit and errors (`getDanger`).
    static let danger = dynamic(light: 0xEF4444, dark: 0xFB7185)
    static let warning = dynamic(light: 0xF59E0B, dark: 0xFBBF24)
    static let info = dynamic(light: 0x3B82F6, dark: 0x60A5FA)
    static let pink = Color(hex: 0xF0ABFC)
    static let cyan = Color(hex: 0x22D3EE)
    /// `AppColors.primary`: the same indigo in both modes (unlike `accent`).
    static let primary = Color(hex: 0x6366F1)
    static let primaryDark = Color(hex: 0x4F46E5)
    static let primaryLight = Color(hex: 0x818CF8)
    /// The Home spend gauge's fill start (spending_page.dart:1388-1461):
    /// `accent @ 55%` alpha-blended over `background`, unrounded.
    static let gaugeFillStart = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 75.45 / 255, green: 81.5 / 255, blue: 144.5 / 255, alpha: 1)
            : UIColor(red: 166.5 / 255, green: 168.6 / 255, blue: 245.5 / 255, alpha: 1)
    })

    // Flow charts (history_page.dart)
    /// The net cash flow bars' zero baseline: white 12% dark, black 12% light.
    static let chartBaseline = overlay(dark: 0.12, light: 0.12)
    /// The trend's dashed zero line: white 8% dark, black 12% light.
    static let chartZeroLine = overlay(dark: 0.08, light: 0.12)
    /// The trend's end dot: #F2F2FA in both modes, no stroke (Flutter's
    /// `FlDotCirclePainter`), so it is faint on the light card.
    static let trendDot = Color(hex: 0xF2F2FA)

    // Dock (unused by the native tab bar; kept for custom chrome)
    static let dockInactiveIcon = dynamic(light: 0x6B7280, dark: 0x8A8AA8)

    /// The split bar's assets segment (`glow_progress_bar.dart`).
    static let splitBarGradient = LinearGradient(
        colors: [Color(hex: 0x2AB98A), Color(hex: 0x34D399)], startPoint: .leading, endPoint: .trailing)

    /// Opening screen, dark only (`main.dart`).
    static let openingGradient = LinearGradient(
        colors: [Color(hex: 0x0A0A12), Color(hex: 0x0F0F18)], startPoint: .top, endPoint: .bottom)

    // 135-degree gradients (topLeading to bottomTrailing)
    static let primaryGradient = gradient(light: (0x6366F1, 0x8B5CF6), dark: (0x4F46E5, 0x7C3AED))
    static let incomeGradient = gradient(light: (0x10B981, 0x34D399), dark: (0x059669, 0x10B981))
    static let expenseGradient = gradient(light: (0xEF4444, 0xF87171), dark: (0xDC2626, 0xEF4444))
    static let amberGradient = gradient(light: (0xF59E0B, 0xF97316), dark: (0xFBBF24, 0xFB923C))
    static let blueGradient = gradient(light: (0x3B82F6, 0x60A5FA), dark: (0x2563EB, 0x3B82F6))

    /// The 14-colour chart and category palette (`getChartColors`).
    static let chartPalette: [Color] = zip(
        [0x6366F1, 0x8B5CF6, 0x10B981, 0x34D399, 0xEF4444, 0xF87171, 0xF59E0B, 0xFBBF24, 0x3B82F6, 0x60A5FA, 0xEC4899,
         0xF472B6, 0x14B8A6, 0x2DD4BF],
        [0x818CF8, 0xA78BFA, 0x34D399, 0x6EE7B7, 0xF87171, 0xFCA5A5, 0xFBBF24, 0xFCD34D, 0x60A5FA, 0x93C5FD, 0xF472B6,
         0xF9A8D4, 0x2DD4BF, 0x5EEAD4]
    ).map { dynamic(light: $0, dark: $1) }

    /// A category `colorToken` (`category_settings_page.dart` `_tokenColor`);
    /// unknown tokens use the accent. Purple is 818CF8 in both modes.
    static func category(_ token: String) -> Color {
        switch token {
        case "green": income
        case "blue": info
        case "orange": warning
        case "red": danger
        case "purple": Color(hex: 0x818CF8)
        case "pink": pink
        case "cyan": cyan
        default: accent
        }
    }

    static func dynamic(light: UInt32, dark: UInt32, alpha: Bool = false) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: alpha) : UIColor(hex: light, alpha: alpha) })
    }

    /// Flutter's `Colors.white` (dark) / `Colors.black` (light) at an alpha.
    private static func overlay(dark: CGFloat, light: CGFloat) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: dark) : UIColor(white: 0, alpha: light) })
    }

    private static func gradient(light: (UInt32, UInt32), dark: (UInt32, UInt32)) -> LinearGradient {
        LinearGradient(
            colors: [dynamic(light: light.0, dark: dark.0), dynamic(light: light.1, dark: dark.1)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

extension UIColor {
    /// `hex` is 0xRRGGBB, or 0xAARRGGBB when `alpha` is true.
    convenience init(hex: UInt32, alpha: Bool = false) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha ? CGFloat((hex >> 24) & 0xFF) / 255 : 1)
    }
}
