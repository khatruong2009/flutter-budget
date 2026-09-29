import SwiftUI

/// One Flutter `TextStyle` (`theme/app_typography.dart`): face, size,
/// tracking, line height (`height`, a multiple of the size) and tabular
/// figures. Sizes scale with Dynamic Type relative to `relativeTo`.
struct TextSpec: Sendable {
    let face: BudgieFont
    let size: CGFloat
    var tracking: CGFloat = 0
    /// Flutter `height`. Both faces' natural line height is 1.2 x size.
    var height: CGFloat = 1.2
    var tabular = false
    var uppercase = false
    var relativeTo: Font.TextStyle = .body
}

extension TextSpec {
    // MARK: Redesign (lines 14-216)

    static let hero = TextSpec(face: .gabaritoExtraBold, size: 58, tracking: -2, height: 1.0, tabular: true, relativeTo: .largeTitle)
    static let heroDecimals = TextSpec(face: .gabaritoBold, size: 32, height: 1.0, tabular: true, relativeTo: .largeTitle)
    static let heroMedium = TextSpec(face: .gabaritoExtraBold, size: 48, tracking: -1.8, height: 1.0, tabular: true, relativeTo: .largeTitle)
    static let heroSmall = TextSpec(face: .gabaritoExtraBold, size: 34, tracking: -1, height: 1.1, tabular: true, relativeTo: .largeTitle)
    static let pageTitle = TextSpec(face: .gabaritoExtraBold, size: 26, tracking: -0.6, relativeTo: .title)
    static let sectionHeader = TextSpec(face: .gabaritoBold, size: 20, tracking: -0.3, relativeTo: .title3)
    static let cardTitle = TextSpec(face: .gabaritoBold, size: 17, height: 1.25, relativeTo: .headline)
    static let goalTitle = TextSpec(face: .gabaritoBold, size: 18, tracking: -0.3, height: 1.25, relativeTo: .headline)
    static let rowTitle = TextSpec(face: .gabaritoSemiBold, size: 15, height: 1.25, relativeTo: .body)
    static let rowSubtitle = TextSpec(face: .gabaritoRegular, size: 12, height: 1.25, relativeTo: .caption)
    static let amount = TextSpec(face: .gabaritoBold, size: 16, tabular: true, relativeTo: .body)
    static let amountSmall = TextSpec(face: .gabaritoBold, size: 15, tabular: true, relativeTo: .body)
    static let chipAmount = TextSpec(face: .gabaritoBold, size: 24, tracking: -0.5, height: 1.15, tabular: true, relativeTo: .title2)
    static let metricAmount = TextSpec(face: .gabaritoExtraBold, size: 24, tracking: -0.5, height: 1.15, tabular: true, relativeTo: .title2)
    static let badge = TextSpec(face: .gabaritoBold, size: 12, relativeTo: .caption)
    static let badgeSmall = TextSpec(face: .gabaritoBold, size: 11, relativeTo: .caption2)
    static let eyebrow = TextSpec(face: .monoSemiBold, size: 11, tracking: 2.4, uppercase: true, relativeTo: .caption2)
    static let eyebrowTight = TextSpec(face: .monoSemiBold, size: 11, tracking: 2, uppercase: true, relativeTo: .caption2)
    static let monoLabel = TextSpec(face: .monoMedium, size: 11, tracking: 1, relativeTo: .caption2)
    static let monoLink = TextSpec(face: .monoSemiBold, size: 11, tracking: 1.5, relativeTo: .caption2)
    static let monoMetricLabel = TextSpec(face: .monoSemiBold, size: 10, tracking: 1.6, relativeTo: .caption2)
    static let monoAxis = TextSpec(face: .monoMedium, size: 10, relativeTo: .caption2)
    static let monoMonth = TextSpec(face: .monoMedium, size: 11, relativeTo: .caption2)

    // MARK: Legacy (lines 218-366), still used by forms, dialogs and the lock screen

    static let displayLarge = TextSpec(face: .gabaritoBold, size: 34, tracking: -0.5, relativeTo: .largeTitle)
    static let displayMedium = TextSpec(face: .gabaritoBold, size: 28, tracking: -0.3, relativeTo: .title)
    static let displaySmall = TextSpec(face: .gabaritoBold, size: 24, tracking: -0.2, height: 1.3, relativeTo: .title2)
    static let headingLarge = TextSpec(face: .gabaritoBold, size: 28, tracking: -0.3, relativeTo: .title)
    static let headingMedium = TextSpec(face: .gabaritoSemiBold, size: 22, tracking: -0.2, height: 1.3, relativeTo: .title2)
    static let headingSmall = TextSpec(face: .gabaritoSemiBold, size: 20, tracking: -0.1, height: 1.3, relativeTo: .title3)
    static let bodyLarge = TextSpec(face: .gabaritoRegular, size: 17, tracking: -0.4, height: 1.5, relativeTo: .body)
    static let bodyMedium = TextSpec(face: .gabaritoRegular, size: 15, tracking: -0.2, height: 1.5, relativeTo: .subheadline)
    static let bodySmall = TextSpec(face: .gabaritoRegular, size: 13, tracking: -0.1, height: 1.4, relativeTo: .footnote)
    static let labelLarge = TextSpec(face: .gabaritoSemiBold, size: 17, tracking: -0.4, height: 1.3, relativeTo: .body)
    static let labelMedium = TextSpec(face: .gabaritoSemiBold, size: 15, tracking: -0.2, height: 1.3, relativeTo: .subheadline)
    static let labelSmall = TextSpec(face: .gabaritoSemiBold, size: 13, tracking: -0.1, height: 1.3, relativeTo: .footnote)
    static let buttonLarge = TextSpec(face: .gabaritoSemiBold, size: 17, tracking: -0.4, relativeTo: .body)
    static let buttonMedium = TextSpec(face: .gabaritoSemiBold, size: 15, tracking: -0.2, relativeTo: .subheadline)
    static let buttonSmall = TextSpec(face: .gabaritoSemiBold, size: 13, tracking: -0.1, relativeTo: .footnote)
    static let caption = TextSpec(face: .gabaritoRegular, size: 13, tracking: -0.1, height: 1.4, relativeTo: .footnote)
    static let captionSmall = TextSpec(face: .gabaritoRegular, size: 11, height: 1.3, relativeTo: .caption2)
    static let numericLarge = TextSpec(face: .gabaritoBold, size: 34, tracking: -0.5, tabular: true, relativeTo: .largeTitle)
    static let numericMedium = TextSpec(face: .gabaritoSemiBold, size: 22, tracking: -0.2, height: 1.3, tabular: true, relativeTo: .title2)
    static let numericSmall = TextSpec(face: .gabaritoSemiBold, size: 17, tracking: -0.4, height: 1.3, tabular: true, relativeTo: .body)

    /// The font alone (for places that take a `Font`, e.g. `Text` concatenation).
    func font(scaledSize: CGFloat? = nil) -> Font {
        let font = Font.custom(face.postScriptName, size: scaledSize ?? size, relativeTo: relativeTo)
        return tabular ? font.monospacedDigit() : font
    }
}

extension View {
    /// Applies a Flutter text style: face, Dynamic Type size, tracking,
    /// tabular figures, and Flutter's line height. Heights above the faces'
    /// natural 1.2 add line spacing; the hero styles (1.0-1.1, single line)
    /// trim the frame to `size * height` as Flutter lays them out.
    func textStyle(_ spec: TextSpec) -> some View {
        modifier(TextStyleModifier(spec: spec))
    }
}

private struct TextStyleModifier: ViewModifier {
    let spec: TextSpec
    @ScaledMetric private var scaledSize: CGFloat

    init(spec: TextSpec) {
        self.spec = spec
        _scaledSize = ScaledMetric(wrappedValue: spec.size, relativeTo: spec.relativeTo)
    }

    func body(content: Content) -> some View {
        let natural: CGFloat = 1.2
        let font = Font.custom(spec.face.postScriptName, fixedSize: scaledSize)
        content
            .font(spec.tabular ? font.monospacedDigit() : font)
            .tracking(spec.tracking)
            .textCase(spec.uppercase ? .uppercase : nil)
            .lineSpacing(max(0, scaledSize * (spec.height - natural)))
            .padding(.vertical, min(0, scaledSize * (spec.height - natural) / 2))
    }
}
