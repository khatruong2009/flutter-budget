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
    // WCAG AA (4.5:1) on every surface the text sits on (owner-approved
    // 2026-09-30, PARITY_GAPS "Colour tokens"): Flutter's light #6B7280 /
    // #9CA3AF and dark #5C5C78 fell short, so these are the nearest values
    // with the same hue that pass.
    static let textSecondary = dynamic(light: 0x626977, dark: 0x9A9AB5)
    static let textTertiary = dynamic(light: 0x686F7A, dark: 0x81829F)
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x0A0A12)

    // Semantic
    // Light values are darkened to pass WCAG AA both as text on the light
    // surfaces and tints, and behind a white label (Flutter: #6366F1,
    // #10B981, #EF4444, #F59E0B). Dark values are unchanged.
    static let accent = dynamic(light: 0x5453DD, dark: 0x818CF8)
    static let income = dynamic(light: 0x07744F, dark: 0x34D399)
    /// Expense, over-limit and errors (`getDanger`).
    static let danger = dynamic(light: 0xC60D21, dark: 0xFB7185)
    static let warning = dynamic(light: 0x8F5B05, dark: 0xFBBF24)
    static let info = dynamic(light: 0x3B82F6, dark: 0x60A5FA)
    static let pink = Color(hex: 0xF0ABFC)
    static let cyan = Color(hex: 0x22D3EE)
    /// `AppColors.primary`: the same indigo in both modes (unlike `accent`);
    /// darkened from #6366F1 so the white month chip label passes AA.
    static let primary = Color(hex: 0x5453DD)
    static let primaryDark = Color(hex: 0x4F46E5)
    static let primaryLight = Color(hex: 0x818CF8)
    /// `AppColors.expense` / `AppColors.income`: the same red and green in
    /// both modes (unlike `danger` / `income`), as the forms' category
    /// wheel tiles use them.
    static let expenseFixed = Color(hex: 0xEF4444)
    static let incomeFixed = Color(hex: 0x10B981)
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

    // Worth editor dialog (net_worth_page.dart)
    /// The 32pt close circle: white 8% dark, black 6% light.
    static let dialogCloseFill = overlay(dark: 0.08, light: 0.06)
    /// The outlined Cancel button: white 6% dark, black 5% light.
    static let dialogOutlinedFill = overlay(dark: 0.06, light: 0.05)

    // Settings (settings_page.dart)
    /// The brand card's wash (`_BrandCard`): `accent @ 22%` alpha-blended
    /// over `card`, unrounded, fading to `card` at the bottom right.
    static let brandCardWash = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 43.2 / 255, green: 45.62 / 255, blue: 78.74 / 255, alpha: 1)
            : UIColor(red: 220.68 / 255, green: 221.34 / 255, blue: 251.92 / 255, alpha: 1)
    })
    /// The Version row's icon: `AppColors.dockInactiveIcon`, #8A8AA8 in both
    /// modes (unlike the dynamic `dockInactiveIcon` below).
    static let versionIcon = Color(hex: 0x8A8AA8)
    /// The Version row's tile: white 6% dark, black 6% light.
    static let versionTile = overlay(dark: 0.06, light: 0.06)

    // Dock (unused by the native tab bar; kept for custom chrome)
    /// The segmented pills' unselected label too (on the 0xE9E9F1 track); light
    /// darkened from #6B7280 to pass AA there.
    static let dockInactiveIcon = dynamic(light: 0x636A78, dark: 0x8A8AA8)

    /// The split bar's assets segment (`glow_progress_bar.dart`).
    static let splitBarGradient = LinearGradient(
        colors: [Color(hex: 0x2AB98A), Color(hex: 0x34D399)], startPoint: .leading, endPoint: .trailing)

    /// Opening screen, dark only (`main.dart`).
    static let openingGradient = LinearGradient(
        colors: [Color(hex: 0x0A0A12), Color(hex: 0x0F0F18)], startPoint: .top, endPoint: .bottom)

    // 135-degree gradients (topLeading to bottomTrailing)
    // The gradients sit behind white labels (the form and sheet buttons), so
    // both stops of each pass AA against white; the stops keep their lightness
    // gap. Flutter: primary (#6366F1, #8B5CF6), income (#10B981, #34D399) /
    // (#059669, #10B981), expense (#EF4444, #F87171) / (#DC2626, #EF4444).
    static let primaryStops = stops(light: (0x5F61EC, 0x8757F1), dark: (0x4F46E5, 0x7C3AED))
    static let incomeStops = stops(light: (0x006E4B, 0x05875E), dark: (0x056647, 0x04875D))
    static let expenseStops = stops(light: (0xC2021D, 0xCC4A4D), dark: (0xCC0716, 0xDF3337))
    static let primaryGradient = gradient(primaryStops)
    static let incomeGradient = gradient(incomeStops)
    static let expenseGradient = gradient(expenseStops)
    static let amberGradient = gradient(light: (0xF59E0B, 0xF97316), dark: (0xFBBF24, 0xFB923C))
    static let blueGradient = gradient(light: (0x3B82F6, 0x60A5FA), dark: (0x2563EB, 0x3B82F6))

    /// The 14-colour chart and category palette (`getChartColors`).
    static let chartPalette: [Color] = zip(
        [0x6366F1, 0x8B5CF6, 0x10B981, 0x34D399, 0xEF4444, 0xF87171, 0xF59E0B, 0xFBBF24, 0x3B82F6, 0x60A5FA, 0xEC4899,
         0xF472B6, 0x14B8A6, 0x2DD4BF],
        [0x818CF8, 0xA78BFA, 0x34D399, 0x6EE7B7, 0xF87171, 0xFCA5A5, 0xFBBF24, 0xFCD34D, 0x60A5FA, 0x93C5FD, 0xF472B6,
         0xF9A8D4, 0x2DD4BF, 0x5EEAD4]
    ).map { dynamic(light: $0, dark: $1) }

    // The Spend donut's rank palette keeps Flutter's values (the chart
    // palette is unchanged): the slices are graphics, not text.
    static let chartAccent = dynamic(light: 0x6366F1, dark: 0x818CF8)
    static let chartIncome = dynamic(light: 0x10B981, dark: 0x34D399)
    static let chartDanger = dynamic(light: 0xEF4444, dark: 0xFB7185)
    static let chartWarning = dynamic(light: 0xF59E0B, dark: 0xFBBF24)

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

    /// `textSecondary` for text on a strongly tinted card (a category colour
    /// at 22%, or the Worth hero's wash and glow), where the page-level value
    /// reaches only 3.3-4.4:1.
    static let textSecondaryOnTint = dynamic(light: 0x4B5563, dark: 0xBEBED2)

    /// A category or chart colour as text on its own tint (the colour at up
    /// to 18% over the card): the colour itself when that reaches 4.5:1, else
    /// the colour mixed towards the primary text colour until it does. The
    /// palette includes teals, pinks and light blues that cannot be read as
    /// text on a pale tint.
    /// `tint` is the strongest share of the colour behind the text: 0.18 for
    /// a chip on a card, 0.35 for a chip on a tinted card.
    static func legible(_ color: Color, tint: Double = 0.18) -> Color {
        Color(UIColor { traits in
            let base = UIColor(color).resolvedColor(with: traits)
            let card = UIColor(BudgieColor.card).resolvedColor(with: traits)
            let ink = UIColor(textPrimary).resolvedColor(with: traits)
            return LegibleColor.mix(base, towards: ink, on: card, tint: tint)
        })
    }

    static func dynamic(light: UInt32, dark: UInt32, alpha: Bool = false) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: alpha) : UIColor(hex: light, alpha: alpha) })
    }

    /// Flutter's `Colors.white` (dark) / `Colors.black` (light) at an alpha.
    private static func overlay(dark: CGFloat, light: CGFloat) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: dark) : UIColor(white: 0, alpha: light) })
    }

    private static func stops(light: (UInt32, UInt32), dark: (UInt32, UInt32)) -> [Color] {
        [dynamic(light: light.0, dark: dark.0), dynamic(light: light.1, dark: dark.1)]
    }

    private static func gradient(_ stops: [Color]) -> LinearGradient {
        LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private static func gradient(light: (UInt32, UInt32), dark: (UInt32, UInt32)) -> LinearGradient {
        gradient(stops(light: light, dark: dark))
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

/// The arithmetic behind `BudgieColor.legible`.
private enum LegibleColor {
    static func mix(_ base: UIColor, towards ink: UIColor, on card: UIColor, tint: Double) -> UIColor {
        for step in 0...20 {
            let candidate = blend(base, ink, Double(step) / 20)
            if contrast(candidate, tinted(candidate, over: card, alpha: tint)) >= 4.5 { return candidate }
        }
        return ink
    }

    private static func components(_ color: UIColor) -> (Double, Double, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private static func blend(_ a: UIColor, _ b: UIColor, _ t: Double) -> UIColor {
        let (ar, ag, ab) = components(a), (br, bg, bb) = components(b)
        return UIColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t, blue: ab + (bb - ab) * t, alpha: 1)
    }

    private static func tinted(_ color: UIColor, over card: UIColor, alpha: Double) -> UIColor { blend(card, color, alpha) }

    private static func luminance(_ color: UIColor) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        let (r, g, b) = components(color)
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    static func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
