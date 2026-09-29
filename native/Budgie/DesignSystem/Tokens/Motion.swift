import SwiftUI

/// Durations and curves (`theme/app_animations.dart`, spec 01 section 1.5).
/// Every animated component takes its animation through `motion(_:)`, which
/// is nil under Reduce Motion.
enum Motion {
    static let fast = 0.15
    static let normal = 0.30
    static let slow = 0.50
    static let verySlow = 0.80

    static func easeOut(_ duration: Double) -> Animation { .timingCurve(0, 0, 0.58, 1, duration: duration) }
    static func easeInOut(_ duration: Double) -> Animation { .timingCurve(0.42, 0, 0.58, 1, duration: duration) }
    static func easeInOutCubic(_ duration: Double) -> Animation { .timingCurve(0.645, 0.045, 0.355, 1, duration: duration) }
    static func fastOutSlowIn(_ duration: Double) -> Animation { .timingCurve(0.4, 0, 0.2, 1, duration: duration) }
    static func easeOutBack(_ duration: Double) -> Animation { .timingCurve(0.175, 0.885, 0.32, 1.275, duration: duration) }

    /// Press feedback on cards (0.98) and pills (0.96).
    static let press = easeOut(0.12)
    /// Progress bars fill from zero on first appearance.
    static let progress = easeInOutCubic(0.8)
    static let ring = easeInOutCubic(0.9)
    static let segment = easeOut(0.2)
}

extension View {
    /// `animation(_:value:)` that turns into no animation under Reduce Motion.
    func motion<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(ReducibleAnimation(animation: animation, value: value))
    }
}

private struct ReducibleAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
