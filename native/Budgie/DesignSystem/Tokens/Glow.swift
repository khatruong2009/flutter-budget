import SwiftUI

/// Performance A/B switch (docs/PERFORMANCE.md): a Debug build started with
/// `BUDGIE_PERF_NO_GLOW=1` draws no glows, no hero blur and no per-row
/// shadow, to measure what they cost. Always false in Release.
enum PerfFlags {
    #if DEBUG
    static let noGlow = ProcessInfo.processInfo.environment["BUDGIE_PERF_NO_GLOW"] == "1"
    #else
    static let noGlow = false
    #endif
}

/// The signature glow (`AppColors.glow`): a pure halo in dark mode; in light
/// mode a softer ambient shadow (25% of the colour, 0.6 of the blur, 4pt
/// down) so accent elements keep their lift without smudging.
struct GlowModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let color: Color
    let blur: CGFloat
    let alpha: Double

    func body(content: Content) -> some View {
        if PerfFlags.noGlow {
            content
        } else if scheme == .dark {
            content.shadow(color: color.opacity(alpha), radius: blur / 2)
        } else {
            content.shadow(color: color.opacity(0.25), radius: blur * 0.6 / 2, y: 4)
        }
    }
}

/// Text glow for hero numbers (`AppColors.textGlow`): alpha x0.4 in light mode.
struct TextGlowModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let color: Color
    let blur: CGFloat
    let alpha: Double

    func body(content: Content) -> some View {
        if PerfFlags.noGlow {
            content
        } else {
            content.shadow(color: color.opacity(scheme == .dark ? alpha : alpha * 0.4), radius: blur / 2)
        }
    }
}

extension View {
    /// `blur` is Flutter's `BoxShadow.blurRadius`, which (like CSS) is about
    /// twice the Gaussian sigma; a SwiftUI shadow radius is about the sigma,
    /// so it gets `blur / 2`.
    func glow(_ color: Color, blur: CGFloat = 24, alpha: Double = 0.55) -> some View {
        modifier(GlowModifier(color: color, blur: blur, alpha: alpha))
    }

    func textGlow(_ color: Color, blur: CGFloat = 48, alpha: Double = 0.45) -> some View {
        modifier(TextGlowModifier(color: color, blur: blur, alpha: alpha))
    }

    /// A plain shadow (not a glow) that the `BUDGIE_PERF_NO_GLOW` A/B switch
    /// also removes: the per-row shadow and the hero number's blur.
    @ViewBuilder
    func perfShadow(color: Color, radius: CGFloat, y: CGFloat = 0) -> some View {
        if PerfFlags.noGlow { self } else { shadow(color: color, radius: radius, y: y) }
    }

    @ViewBuilder
    func perfBlur(radius: CGFloat) -> some View {
        if PerfFlags.noGlow { self } else { blur(radius: radius) }
    }
}

/// The glow of a shape that has no fill of its own (Flutter draws a
/// `BoxShadow` for an unfilled decoration; a SwiftUI shadow needs opaque
/// pixels): the shape filled with the glow colour and blurred, placed behind.
struct GlowHalo<S: Shape>: View {
    @Environment(\.colorScheme) private var scheme
    let shape: S
    let color: Color
    var blur: CGFloat = 24
    var alpha: Double = 0.55

    var body: some View {
        if PerfFlags.noGlow {
            EmptyView()
        } else if scheme == .dark {
            shape.fill(color.opacity(alpha)).blur(radius: blur / 2).accessibilityHidden(true)
        } else {
            shape.fill(color.opacity(0.25)).blur(radius: blur * 0.6 / 2).offset(y: 4).accessibilityHidden(true)
        }
    }
}
