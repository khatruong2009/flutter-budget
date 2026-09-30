import BudgieCore
import os
import SwiftUI

/// The shell (D2): the native tab bar with Home, Worth, Goals, Spend and
/// Flow, each tab in its own navigation stack (Liquid Glass on iOS 26+).
/// Settings is pushed from Home's gear. Shows the onboarding tour in place
/// of the tabs on first launch. Also hosts the unsaved-changes banner, the
/// toasts and the app lock, and opens the add form for quick actions /
/// widget / deep links (`AddFormPresenter`).
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: Tab = .home
    /// The interval of the tab switch in flight (docs/PERFORMANCE.md).
    @State private var tabSwitch: OSSignpostIntervalState?
    /// One `firstFrame` event per process.
    @MainActor private static var firstFrameEmitted = false

    enum Tab: Hashable { case home, worth, goals, spend, flow }

    var body: some View {
        // The first-launch tour replaces the tabs until it is completed or
        // skipped. It is content, not a cover, so the lock screen and the
        // privacy cover (`AppLockWindow`, a window above this one and every
        // sheet) stay above it (Flutter's gate order).
        Group {
            if model.showsOnboarding {
                OnboardingView()
            } else {
                tabs
            }
        }
        .onAppear {
            guard !Self.firstFrameEmitted else { return }
            Self.firstFrameEmitted = true
            Signpost.launch.emitEvent("firstFrame")
        }
        // Opens over the current tab and anything presented on it
        // (Flutter), once unlocked and past the tour (D14, 1A.8).
        .onChange(of: model.pendingAdd, initial: true) { _, _ in AddFormPresenter.openPendingAdd(model) }
        .onChange(of: model.canOpenRoutes) { _, _ in AddFormPresenter.openPendingAdd(model) }
        // Above the tab bar (49pt).
        .toastHost(bottomInset: model.showsOnboarding ? 0 : 49)
        .appLock()
    }

    /// `$tab`, beginning the `tabSwitch` interval at the tap.
    private var tabSelection: Binding<Tab> {
        Binding(
            get: { tab },
            set: { newValue in
                if newValue != tab {
                    if let state = tabSwitch { Signpost.ui.endInterval("tabSwitch", state, "superseded") }
                    tabSwitch = Signpost.ui.beginInterval("tabSwitch", "to=\(String(describing: newValue), privacy: .public)")
                }
                tab = newValue
            })
    }

    private var tabs: some View {
        TabView(selection: tabSelection) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "dollarsign.circle") }
                .tag(Tab.home)
            NavigationStack { WorthView() }
                .tabItem { Label("Worth", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.worth)
            NavigationStack { GoalsView() }
                .tabItem { Label("Goals", systemImage: "flag") }
                .tag(Tab.goals)
            NavigationStack { SpendView() }
                .tabItem { Label("Spend", systemImage: "chart.pie") }
                .tag(Tab.spend)
            NavigationStack { FlowView() }
                .tabItem { Label("Flow", systemImage: "chart.bar") }
                .tag(Tab.flow)
        }
        .tint(BudgieColor.accent)
        .sensoryFeedback(.selection, trigger: tab)
        .onChange(of: tab) { _, _ in
            // The main thread's work for the switch: the interval ends once
            // the update transaction that changed the tab has finished.
            DispatchQueue.main.async {
                guard let state = tabSwitch else { return }
                Signpost.ui.endInterval("tabSwitch", state)
                tabSwitch = nil
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.hasUnsavedChanges { UnsavedChangesBanner() }
        }
    }
}

extension AddRoute: Identifiable {
    var id: Self { self }
}

/// Shown while a change is only in memory (Flutter `UnsavedChangesBanner`):
/// a danger strip with white content, pushing the pages down.
struct UnsavedChangesBanner: View {
    @Environment(AppModel.self) private var model
    @State private var retrying = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "icloud.slash").font(.system(size: 17, weight: .semibold)).accessibilityHidden(true)
            Text("Some changes are not saved to this device yet.")
                .textStyle(.bodySmall)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(retrying ? "Retrying…" : "Retry") {
                retrying = true
                Task {
                    await model.retrySaves()
                    retrying = false
                }
            }
            .textStyle(.labelSmall)
            .disabled(retrying)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, 10)
        .background(BudgieColor.danger.ignoresSafeArea(edges: .top))
        .accessibilityElement(children: .combine)
    }
}
