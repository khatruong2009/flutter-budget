import SwiftUI
import UIKit

/// The first-launch tour (`onboarding_tutorial.dart`): three swipeable pages,
/// Skip at the top right, page dots and a full-width Continue / Start
/// budgeting button. Shown once, as `MainView`'s content inside the lock gate
/// (Flutter's `AppPrivacyGate(OnboardingTutorialGate(...))`); Skip and the
/// last page's button call `model.completeOnboarding()`, which writes the
/// flag, swaps in the tabs and lets a queued quick action or link open.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    struct Page: Equatable {
        let symbol: String
        let eyebrow: String
        let title: String
        let body: String
    }

    /// Flutter's copy (`_pages`), except page 3, which names Settings (D2:
    /// there is no More tab; Settings opens from the gear on Home).
    static let pages: [Page] = [
        Page(
            // Material `account_balance_wallet_rounded`: the bifold wallet
            // where the system has it (iOS 18), else the card.
            symbol: UIImage(systemName: "wallet.bifold.fill") != nil ? "wallet.bifold.fill" : "creditcard.fill",
            eyebrow: "WELCOME TO BUDGIE",
            title: "Your money, made clearer.",
            body: "Budgie keeps your budget simple and private. Financial data and insights stay on this device unless you choose to export or share a backup."),
        Page(
            symbol: "chart.bar.xaxis.ascending",  // `add_chart_rounded`
            eyebrow: "START HERE",
            title: "Track what comes and goes.",
            body: "On Home, use the add button for income or expenses. Your balance and recent activity update as you go."),
        Page(
            symbol: "chart.xyaxis.line",  // `insights_rounded`
            eyebrow: "EXPLORE WHEN READY",
            title: "Plan ahead, then look back.",
            body: "Worth tracks accounts, Goals keeps savings in view, and Spend, Flow, and Settings (behind the gear on Home) help you understand and manage your budget."),
    ]

    /// Material 3 `labelLarge` (14 / w500 / +0.1) in Gabarito: the default
    /// `TextButton` and `FilledButton` label, which Flutter's tour keeps.
    private static let buttonText = TextSpec(face: .gabaritoMedium, size: 14, tracking: 0.1, height: 1.43, relativeTo: .body)

    private var isLast: Bool { page == Self.pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                // Material `TextButton`: 64x40 minimum in a 48pt tap target.
                Button { model.completeOnboarding() } label: {
                    Text("Skip")
                        .textStyle(Self.buttonText)
                        .padding(.horizontal, 12)
                        .frame(minWidth: 64, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .tint(BudgieColor.accent)
                .accessibilityIdentifier("onboarding.skip")
            }
            TabView(selection: $page) {
                ForEach(Self.pages.indices, id: \.self) { index in
                    OnboardingPageView(page: Self.pages[index])
                        .accessibilityIdentifier("onboarding.page.\(index + 1)")
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            dots
            Spacer().frame(height: Metrics.spacingL)
            Button(action: next) {
                Text(isLast ? "Start budgeting" : "Continue")
                    .textStyle(Self.buttonText)
                    .foregroundStyle(BudgieColor.onAccent)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, Metrics.spacingS)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(BudgieColor.accent, in: RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous))
            }
            .accessibilityIdentifier("onboarding.next")
        }
        .padding(EdgeInsets(top: Metrics.spacingS, leading: Metrics.spacingL, bottom: Metrics.spacingL, trailing: Metrics.spacingL))
        .background(BudgieColor.background.ignoresSafeArea())
    }

    /// Active 22x8 accent, the others 8x8 in the border colour, 4pt margins,
    /// resized over 150ms linear (`AnimatedContainer`'s default curve).
    /// VoiceOver: one adjustable element, "Tutorial page, n of 3".
    private var dots: some View {
        HStack(spacing: 0) {
            ForEach(Self.pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? BudgieColor.accent : BudgieColor.border)
                    .frame(width: index == page ? 22 : 8, height: 8)
                    .padding(.horizontal, 4)
            }
        }
        .motion(.linear(duration: Motion.fast), value: page)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tutorial page")
        .accessibilityValue("\(page + 1) of \(Self.pages.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if page < Self.pages.count - 1 { show(page + 1) }
            case .decrement: if page > 0 { show(page - 1) }
            @unknown default: break
            }
        }
        .accessibilityIdentifier("onboarding.dots")
    }

    private func next() {
        if isLast {
            model.completeOnboarding()
        } else {
            show(page + 1)
        }
    }

    /// Flutter's `nextPage` (300ms easeInOut); a jump under Reduce Motion.
    /// VoiceOver hears the new page, as its focus stays on the control.
    private func show(_ index: Int) {
        if reduceMotion {
            page = index
        } else {
            withAnimation(Motion.easeInOut(Motion.normal)) { page = index }
        }
        let shown = Self.pages[index]
        AccessibilityNotification.Announcement(
            "Tutorial page \(index + 1) of \(Self.pages.count). \(shown.title) \(shown.body)"
        ).post()
    }
}

/// One page (`_TutorialPage`): the glowing 116pt circle with the symbol,
/// then eyebrow, title and body, centred. Scrolls when large text makes it
/// taller than the pager.
private struct OnboardingPageView: View {
    let page: OnboardingView.Page

    /// `bodyLarge` with Flutter's `height: 1.45` override.
    private static let bodyText = TextSpec(face: .gabaritoRegular, size: 17, tracking: -0.4, height: 1.45, relativeTo: .body)

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ZStack {
                        // Flutter's BoxShadow shows through the translucent fill.
                        GlowHalo(shape: Circle(), color: BudgieColor.accent, blur: 32, alpha: 0.25)
                        Circle().fill(BudgieColor.accent.opacity(0.14))
                        Image(systemName: page.symbol)
                            .font(.system(size: 40, weight: .regular))
                            .foregroundStyle(BudgieColor.accent)
                    }
                    .frame(width: 116, height: 116)
                    .accessibilityHidden(true)
                    Text(page.eyebrow)
                        .textStyle(.eyebrow)
                        .foregroundStyle(BudgieColor.accent)
                        .padding(.top, Metrics.spacingXXL)
                    Text(page.title)
                        .textStyle(.displayMedium)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Metrics.spacingM)
                    Text(page.body)
                        .textStyle(Self.bodyText)
                        .foregroundStyle(BudgieColor.textSecondary)
                        .frame(maxWidth: 390)
                        .padding(.top, Metrics.spacingM)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Metrics.spacingS)
                // Room for the halo when the page scrolls; no change while
                // the content fits and is centred.
                .padding(.vertical, Metrics.spacingM)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
    }
}
