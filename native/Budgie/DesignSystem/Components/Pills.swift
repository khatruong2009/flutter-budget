import SwiftUI

/// Small badge (`PillChip`): tinted (colour at 14%) or outlined (colour at
/// 40%), optional 15pt symbol, badge text in the colour.
struct PillChip: View {
    let label: String
    let color: Color
    var outlined = false
    var symbol: String? = nil
    var style: TextSpec = .badge
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 5
    var action: (() -> Void)? = nil

    @State private var taps = 0

    var body: some View {
        let chip = HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 13, weight: .medium)).accessibilityHidden(true)
            }
            Text(label).textStyle(style)
        }
        .foregroundStyle(color)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(outlined ? Color.clear : color.opacity(0.14), in: Capsule())
        .overlay { if outlined { Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1) } }

        if let action {
            Button {
                taps += 1
                action()
            } label: {
                chip
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: taps)
        } else {
            chip
        }
    }
}

/// Capsule button (`PillButton`): 52pt tinted outline (colour at 10% with a
/// 35% border), or 44pt accent-filled with a glow and on-accent label.
/// Presses to 0.96 with a light haptic.
struct PillButton: View {
    let title: String
    var symbol: String? = nil
    var color: Color = BudgieColor.accent
    var filled = false
    var height: CGFloat? = nil
    let action: () -> Void

    @State private var taps = 0

    var body: some View {
        let foreground = filled ? BudgieColor.onAccent : color
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: filled ? 6 : 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: filled ? 16 : 18, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.custom(BudgieFont.gabaritoBold.postScriptName, size: filled ? 14 : 15, relativeTo: .body))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height ?? (filled ? Metrics.pillButtonCompactHeight : Metrics.pillButtonHeight))
            .background(filled ? color : color.opacity(0.1), in: Capsule())
            .overlay { if !filled { Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1) } }
            .modifier(OptionalGlow(color: color, enabled: filled))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle(scale: 0.96))
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}

private struct OptionalGlow: ViewModifier {
    let color: Color
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled { content.glow(color, blur: 20, alpha: 0.45) } else { content }
    }
}

/// Segmented capsule control (`SegmentedPillControl`): a track with an
/// accent-filled active segment (Settings theme), or the mono variant with
/// no track and an accent-tint active segment (chart range pills).
struct SegmentedPills: View {
    let items: [String]
    @Binding var selection: Int
    var mono = false

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: mono ? 4 : 0) {
            ForEach(items.indices, id: \.self) { index in
                let selected = index == selection
                Button {
                    selection = index
                } label: {
                    Text(items[index])
                        .font(labelFont(selected: selected))
                        .tracking(0)
                        .foregroundStyle(
                            selected ? (mono ? BudgieColor.accent : BudgieColor.onAccent) : BudgieColor.dockInactiveIcon)
                        .padding(.horizontal, mono ? 11 : 12)
                        .padding(.vertical, mono ? 5 : 6)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(mono ? BudgieColor.accent.opacity(0.18) : BudgieColor.accent)
                                    .matchedGeometryEffect(id: "active", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(mono ? 0 : 3)
        .background { if !mono { Capsule().fill(BudgieColor.track) } }
        .motion(Motion.segment, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func labelFont(selected: Bool) -> Font {
        if mono { return .custom(BudgieFont.monoSemiBold.postScriptName, size: 11, relativeTo: .caption2) }
        return .custom((selected ? BudgieFont.gabaritoBold : .gabaritoSemiBold).postScriptName, size: 12, relativeTo: .caption)
    }
}

/// Month/range selector pill (`MonthPill`, budgie_header.dart:80-132):
/// chip surface and a 1pt 8% border around padding 16 x 9 (Flutter's
/// Container adds the border's width to the padding), the label in
/// `rowTitle` at 14 (w600, height 1.25) and a 16pt `expand_more` chevron,
/// 6 apart. `dimmed` greys the label for a pill whose choice is no longer
/// applied (the SEE ALL month after the dates changed).
struct MonthPill: View {
    let label: String
    var dimmed = false
    var action: (() -> Void)? = nil

    @State private var taps = 0

    /// `rowTitle` with fontSize 14.
    private static let labelText = TextSpec(face: .gabaritoSemiBold, size: 14, height: 1.25, relativeTo: .subheadline)
    /// Flutter's 1.25 line box is 0.7pt taller than the face's natural 1.2
    /// one, which a single line does not get from `textStyle`.
    @ScaledMetric(relativeTo: .subheadline) private var halfLeading: CGFloat = 14 * 0.05 / 2

    var body: some View {
        let pill = HStack(spacing: 6) {
            Text(label)
                .textStyle(Self.labelText)
                .foregroundStyle(dimmed ? BudgieColor.textSecondary : BudgieColor.textPrimary)
                .padding(.vertical, halfLeading)
            // Material `expand_more_rounded` 16 / w500: a small chevron in a 16pt box.
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(BudgieColor.textSecondary)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16 + Metrics.borderThin)
        .padding(.vertical, 9 + Metrics.borderThin)
        .background(BudgieColor.chipSurface, in: Capsule())
        .overlay(Capsule().strokeBorder(BudgieColor.pillBorder, lineWidth: Metrics.borderThin))

        if let action {
            Button {
                taps += 1
                action()
            } label: {
                pill
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: taps)
            .accessibilityHint("Choose a month")
        } else {
            pill
        }
    }
}
