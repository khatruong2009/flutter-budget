import SwiftUI

extension View {
    /// Hosts `model.toast` along the bottom edge (floating, radius 12,
    /// success or danger fill), dismissing it after its duration. VoiceOver
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
/// keeps it legible on the bright dark-mode green and rose.
private struct ToastView: View {
    @Environment(AppModel.self) private var model
    let toast: Toast

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.message)
                .textStyle(.bodySmall)
                .foregroundStyle(BudgieColor.onAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
            if toast.action == .retrySaves {
                Button("Retry") {
                    model.dismissToast(toast.id)
                    Task { await model.retrySaves() }
                }
                .textStyle(.labelSmall)
                .foregroundStyle(BudgieColor.onAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(toast.style == .danger ? BudgieColor.danger : BudgieColor.income,
                    in: RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }
}
