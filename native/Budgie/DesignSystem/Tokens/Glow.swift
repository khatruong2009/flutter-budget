import SwiftUI

/// The signature glow (`AppColors.glow`): a pure halo in dark mode; in light
/// mode a softer ambient shadow (25% of the colour, 0.6 of the blur, 4pt
/// down) so accent elements keep their lift without smudging.
struct GlowModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let color: Color
    let blur: CGFloat
    let alpha: Double

    func body(content: Content) -> some View {
        if scheme == .dark {
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
        content.shadow(color: color.opacity(scheme == .dark ? alpha : alpha * 0.4), radius: blur / 2)
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
}
