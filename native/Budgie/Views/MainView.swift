import BudgieCore
import SwiftUI

/// The shell (D2): the native tab bar with Home, Worth, Goals, Spend and
/// Flow, each tab in its own navigation stack (Liquid Glass on iOS 26+).
/// Settings is pushed from Home's gear. Also hosts the unsaved-changes
/// banner, the toasts, the add sheet opened by quick actions / widget /
/// deep links, and the app lock.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: Tab = .home
    @State private var addRoute: AddRoute?

    enum Tab: Hashable { case home, worth, goals, spend, flow }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "dollarsign.circle") }
                .tag(Tab.home)
            NavigationStack { WorthView() }
                .tabItem { Label("Worth", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.worth)
            NavigationStack { UpcomingTabView(title: "Goals", symbol: "flag") }
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.hasUnsavedChanges { UnsavedChangesBanner() }
        }
        .sheet(item: $addRoute) { route in
            TransactionFormView(mode: .add(route == .income ? .income : .expense))
        }
        // Opens over the current tab (Flutter), once unlocked (D14, 1A.8).
        .onChange(of: model.pendingAdd, initial: true) { _, _ in openPendingAdd() }
        .onChange(of: model.canOpenRoutes) { _, _ in openPendingAdd() }
        // Above the tab bar (49pt).
        .toastHost(bottomInset: 49)
        .appLock()
    }

    private func openPendingAdd() {
        guard addRoute == nil, let route = model.takePendingAdd() else { return }
        addRoute = route
    }
}

extension AddRoute: Identifiable {
    var id: Self { self }
}

/// A tab whose redesign lands in a later phase: its header and a notice.
struct UpcomingTabView: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: 0) {
            BudgieHeader(title: title)
            EmptyStateView(symbol: symbol, title: title, message: "This tab is being rebuilt and arrives in an upcoming update.")
                .frame(maxHeight: .infinity)
        }
        .background(BudgieColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }
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
