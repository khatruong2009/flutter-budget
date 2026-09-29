import SwiftUI

/// Clamps a fraction to 0...1; NaN is 0 (Flutter's progress widgets).
private func unit(_ value: Double) -> Double {
    value.isNaN ? 0 : min(max(value, 0), 1)
}

/// Capsule progress bar with a glowing fill (`GlowProgressBar`) that grows
/// from 0 on first appearance over 800ms (instant under Reduce Motion).
/// Heights: 8 budgets, 6 categories, 12-16 comparisons, 14 the Home gauge.
struct GlowProgressBar: View {
    let value: Double
    var height: CGFloat = 8
    var color: Color = BudgieColor.accent
    var track: Color? = nil
    /// Fill gradient (the Home gauge); the glow keeps `color`.
    var gradient: LinearGradient? = nil
    /// End-of-fill thumb dot (the Home gauge).
    var showThumb = false
    /// 1pt border colour around the track.
    var trackBorder: Color? = nil
    /// Gap between track edge and fill (the Home gauge uses 2).
    var fillInset: CGFloat = 0
    var animate = true

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        let target = unit(value)
        let shown = appeared || !animate ? target : 0
        GeometryReader { geometry in
            let border: CGFloat = trackBorder == nil ? 0 : 1
            let innerWidth = geometry.size.width - fillInset * 2 - border * 2
            let innerHeight = height - fillInset * 2 - border * 2
            let fillWidth = max(0, innerWidth * shown)
            ZStack(alignment: .leading) {
                Capsule().fill(track ?? BudgieColor.track)
                    .overlay { if let trackBorder { Capsule().strokeBorder(trackBorder, lineWidth: 1) } }
                if shown > 0 {
                    Capsule()
                        .fill(gradient.map(AnyShapeStyle.init) ?? AnyShapeStyle(color))
                        .frame(width: fillWidth, height: innerHeight)
                        .glow(color, blur: 12, alpha: 0.6)
                        .offset(x: fillInset + border)
                    if showThumb {
                        let minX = fillInset
                        let maxX = innerWidth + fillInset - height
                        if maxX > minX {
                            Circle()
                                .fill(scheme == .dark ? Color(hex: 0xF2F2FA) : .white)
                                .overlay { if scheme != .dark { Circle().strokeBorder(color.opacity(0.6), lineWidth: 2) } }
                                .frame(width: height, height: height)
                                .glow(color, blur: 12, alpha: 0.8)
                                .offset(x: min(max(fillInset + fillWidth - height / 2, minX), maxX))
                        }
                    }
                }
            }
        }
        .frame(height: height)
        .motion(Motion.progress, value: shown)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion { appeared = true } else { withAnimation(Motion.progress) { appeared = true } }
        }
        .accessibilityElement()
        .accessibilityValue(Text("\(Int((target * 100).rounded())) percent"))
    }
}

/// Assets/liabilities split (`SplitGlowBar`): green gradient left, rose
/// right, 3pt gap, both glowing; a single bar at 0 or 1.
struct SplitGlowBar: View {
    /// assets / (assets + liabilities).
    let assetsFraction: Double
    var height: CGFloat = 16

    var body: some View {
        let fraction = unit(assetsFraction)
        let green = Color(hex: 0x34D399)
        GeometryReader { geometry in
            if fraction >= 1 || fraction <= 0 {
                segment(fraction >= 1 ? green : BudgieColor.danger, gradient: fraction >= 1)
            } else {
                // Flex weights rounded to thousandths, as Flutter's `flex`.
                let greenFlex = (fraction * 1000).rounded(), roseFlex = ((1 - fraction) * 1000).rounded()
                let available = geometry.size.width - 3
                HStack(spacing: 3) {
                    segment(green, gradient: true).frame(width: available * greenFlex / (greenFlex + roseFlex))
                    segment(BudgieColor.danger, gradient: false)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func segment(_ color: Color, gradient: Bool) -> some View {
        Capsule()
            .fill(gradient ? AnyShapeStyle(BudgieColor.splitBarGradient) : AnyShapeStyle(color))
            .glow(color, blur: 14, alpha: 0.5)
    }
}

/// Conic progress ring (`ProgressRing`): track ring, fill arc from 12
/// o'clock with butt caps, inner disc, glow scaled by progress; grows from
/// 0 over 900ms (instant under Reduce Motion). 72/8 summary, 84/9 goals.
struct ProgressRing<Center: View>: View {
    let value: Double
    var size: CGFloat = 84
    var thickness: CGFloat = 9
    var color: Color = BudgieColor.accent
    var inner: Color? = nil
    var glowAlpha: Double = 0.4
    @ViewBuilder var center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        let target = unit(value)
        let t = appeared ? target : 0
        ZStack {
            if t > 0 { GlowHalo(shape: Circle(), color: color, blur: 28, alpha: glowAlpha * t) }
            Circle()
                .inset(by: thickness / 2)
                .stroke(BudgieColor.track, lineWidth: thickness)
            Circle()
                .inset(by: thickness / 2)
                .trim(from: 0, to: t)
                .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(inner ?? BudgieColor.card)
                .padding(thickness)
            center()
        }
        .frame(width: size, height: size)
        .motion(Motion.ring, value: t)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion { appeared = true } else { withAnimation(Motion.ring) { appeared = true } }
        }
    }
}
