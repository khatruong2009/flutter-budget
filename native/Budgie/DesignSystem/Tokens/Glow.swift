import SwiftUI

/// Performance A/B switch (docs/PERFORMANCE.md): a Debug build started with
/// `BUDGIE_PERF_NO_GLOW=1` draws no per-row shadow, to measure
/// what it costs. Always false in Release.
enum PerfFlags {
    #if DEBUG
    static let noGlow = ProcessInfo.processInfo.environment["BUDGIE_PERF_NO_GLOW"] == "1"
    #else
    static let noGlow = false
    #endif
}

extension View {
    /// A plain shadow that the `BUDGIE_PERF_NO_GLOW` A/B switch removes: the
    /// per-row shadow.
    @ViewBuilder
    func perfShadow(color: Color, radius: CGFloat, y: CGFloat = 0) -> some View {
        if PerfFlags.noGlow { self } else { shadow(color: color, radius: radius, y: y) }
    }
}
