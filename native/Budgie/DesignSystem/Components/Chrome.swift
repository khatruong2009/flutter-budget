import SwiftUI

// MARK: - Sheet chrome

extension View {
    /// The redesign's bottom-sheet chrome (Home sheets): card fill, 1pt card
    /// border along the rounded top, 28pt top radius, a 44x4 grab handle.
    /// Apply to the root view inside `.sheet`.
    func budgieSheetChrome(radius: CGFloat = Metrics.sheetRadius) -> some View {
        modifier(SheetChrome(radius: radius))
    }
}

private struct SheetChrome: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                Capsule()
                    .fill(BudgieColor.textTertiary.opacity(0.6))
                    .frame(width: 44, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(radius)
            .presentationBackground {
                let shape = UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius, style: .continuous)
                BudgieColor.card
                    .overlay(shape.strokeBorder(BudgieColor.cardBorder, lineWidth: 1).padding(.bottom, -2))
                    .ignoresSafeArea()
            }
    }
}

// MARK: - Centred dialog

extension View {
    /// A centred card dialog over a dimmed scrim (Flutter `showDialog` with
    /// the Goals `_DarkDialog` shell: GlowCard padding 20, max width 500,
    /// inset 24/32). Presented above everything, including the tab bar;
    /// the keyboard pushes it up. Tapping the scrim dismisses it.
    func budgieDialog<Dialog: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Dialog) -> some View {
        modifier(DialogPresenter(isPresented: isPresented, dialog: content))
    }
}

private struct DialogPresenter<Dialog: View>: ViewModifier {
    @Binding var isPresented: Bool
    let dialog: () -> Dialog
    @State private var coverShown = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $coverShown) {
                DialogHost(dismiss: { isPresented = false }, dialog: dialog)
                    .presentationBackground(.clear)
            }
            .onChange(of: isPresented, initial: true) { _, shown in
                // The cover appears without its slide; DialogHost animates.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { coverShown = shown }
            }
    }
}

private struct DialogHost<Dialog: View>: View {
    let dismiss: () -> Void
    let dialog: () -> Dialog
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        ZStack {
            Color.black.opacity(visible ? 0.54 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Dismiss")
            GlowCard(padding: Metrics.cardPadding) { dialog() }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .scaleEffect(visible || reduceMotion ? 1 : 0.92)
                .opacity(visible ? 1 : 0)
                .accessibilityAddTraits(.isModal)
        }
        .onAppear {
            if reduceMotion { visible = true } else { withAnimation(Motion.easeOut(0.15)) { visible = true } }
        }
    }
}

// MARK: - Recurrence glyph

/// The recurring-transaction mark (`RecurrenceIndicator`): two arcs with
/// arrowheads forming an elongated oval, 1.5pt round strokes, 16 x 9.6.
struct RecurrenceGlyph: View {
    var size: CGFloat = 16
    var color: Color = BudgieColor.textSecondary

    var body: some View {
        RecurrenceShape()
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size * 0.6)
            .accessibilityLabel("Recurring")
    }
}

struct RecurrenceShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width, height = rect.height
        let centerY = rect.minY + height / 2
        let leftX = rect.minX + width * 0.1, rightX = rect.minX + width * 0.9
        let arrow = width * 0.18
        var path = Path()
        path.move(to: CGPoint(x: leftX + arrow * 0.5, y: centerY))
        path.addCurve(
            to: CGPoint(x: rightX - arrow * 0.5, y: centerY),
            control1: CGPoint(x: leftX + arrow * 0.5, y: rect.minY + height * 0.05),
            control2: CGPoint(x: rightX - arrow * 0.5, y: rect.minY + height * 0.05))
        path.move(to: CGPoint(x: rightX - arrow, y: centerY - arrow * 0.5))
        path.addLine(to: CGPoint(x: rightX, y: centerY))
        path.addLine(to: CGPoint(x: rightX - arrow, y: centerY + arrow * 0.5))
        path.move(to: CGPoint(x: rightX - arrow * 0.5, y: centerY))
        path.addCurve(
            to: CGPoint(x: leftX + arrow * 0.5, y: centerY),
            control1: CGPoint(x: rightX - arrow * 0.5, y: rect.minY + height * 0.95),
            control2: CGPoint(x: leftX + arrow * 0.5, y: rect.minY + height * 0.95))
        path.move(to: CGPoint(x: leftX + arrow, y: centerY - arrow * 0.5))
        path.addLine(to: CGPoint(x: leftX, y: centerY))
        path.addLine(to: CGPoint(x: leftX + arrow, y: centerY + arrow * 0.5))
        return path
    }
}

// MARK: - Swipe to delete

/// A card row that reveals a delete action when swiped left (Flutter
/// `Dismissible` on the transaction list): past 40% of the width a medium
/// haptic marks the threshold, and releasing there calls `onDelete` (which
/// confirms) while the row springs back. Also offered as an accessibility
/// action, since the gesture is not discoverable with VoiceOver.
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 1
    @State private var armed = false

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                    .fill(BudgieColor.danger)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "trash")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.trailing, 24)
                    }
                    .accessibilityHidden(true)
            }
            content()
                .offset(x: offset)
        }
        .onGeometryChangeCompat { width = max($0.width, 1) }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    offset = min(0, value.translation.width)
                    let past = -offset > width * 0.4
                    if past != armed { armed = past }
                }
                .onEnded { _ in
                    let delete = armed
                    armed = false
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { offset = 0 }
                    if delete { onDelete() }
                }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: armed) { _, new in new }
        .accessibilityAction(named: "Delete", onDelete)
    }
}

extension View {
    /// Reports this view's size (a PreferenceKey reader; `onGeometryChange`
    /// needs iOS 18).
    func onGeometryChangeCompat(_ action: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { action(proxy.size) }
                    .onChange(of: proxy.size) { _, size in action(size) }
            })
    }
}
