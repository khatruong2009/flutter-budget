import SwiftUI

extension View {
    /// Hosts `model.toast` along the bottom edge (floating, radius 12,
    /// success, danger or neutral fill), dismissing it after its duration. VoiceOver
    /// announces it.
    func toastHost(bottomInset: CGFloat = 0) -> some View {
        modifier(ToastHost(bottomInset: bottomInset))
    }
}

private struct ToastHost: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let bottomInset: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = model.toast {
                    ToastView(toast: toast)
                        .padding(.horizontal, Metrics.spacingM)
                        .padding(.bottom, bottomInset + Metrics.spacingS)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .id(toast.id)
                        .task(id: toast.id) {
                            AccessibilityNotification.Announcement(toast.message).post()
                            // A cancelled wait (the view went away) must not
                            // cut the toast short.
                            guard (try? await Task.sleep(for: .seconds(toast.duration))) != nil else { return }
                            model.dismissToast(toast.id)
                        }
                }
            }
            .motion(Motion.easeOut(0.25), value: model.toast?.id)
    }
}

/// Flutter's SnackBar text is M3 `onInverseSurface` (a dark neutral in dark
/// mode, near-white in light), not white: `onAccent` (#0A0A12 / #FFFFFF)
/// keeps it legible on the bright dark-mode green and rose. The neutral
/// style stands in for M3 `inverseSurface` / `onInverseSurface` with the
/// primary text colour as the fill and the page background as the text
/// (text on fill: #F9FAFB on #111827 light, #0A0A12 on #F2F2FA dark).
private struct ToastView: View {
    @Environment(AppModel.self) private var model
    let toast: Toast

    var body: some View {
        let foreground = toast.style == .neutral ? BudgieColor.background : BudgieColor.onAccent
        HStack(spacing: 12) {
            Text(toast.message)
                .textStyle(.bodySmall)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
            if toast.action == .retrySaves {
                Button("Retry") {
                    model.dismissToast(toast.id)
                    Task { await model.retrySaves() }
                }
                .textStyle(.labelSmall)
                .foregroundStyle(foreground)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(fill, in: RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var fill: Color {
        switch toast.style {
        case .success: BudgieColor.income
        case .danger: BudgieColor.danger
        case .neutral: BudgieColor.textPrimary
        }
    }
}
