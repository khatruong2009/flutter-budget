import Foundation

// `dart:math` and `num` helpers on doubles, shared by the Worth and Flow
// math (NetWorthPresentation, CashFlowMath) so both fold values as Dart.

/// Dart `dart:math` `max`/`min` on doubles (NaN wins; `max(-0.0, 0.0)` is 0.0).
func dartMax(_ a: Double, _ b: Double) -> Double {
    if a > b { return a }
    if a < b { return b }
    if a == 0 && b == 0 { return a.sign == .minus ? b : a }
    return b.isNaN ? b : a
}

func dartMin(_ a: Double, _ b: Double) -> Double {
    if a > b { return b }
    if a < b { return a }
    if a == 0 && b == 0 { return a.sign == .minus ? a : b }
    return b.isNaN ? b : a
}

/// Dart `num.clamp` for doubles in range order.
func dartClamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
    if value < lower { return lower }
    if value > upper { return upper }
    return value
}
