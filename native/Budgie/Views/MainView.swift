import BudgieCore
import SwiftUI

/// Tab shell (UI_SPEC "Shell"). Owns the unsaved-changes banner, the add
/// sheet opened by quick actions / widget / deep links, and the app lock.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: Tab = .spending
    @State private var addRoute: AddRoute?

    enum Tab: Hashable { case spending, history, netWorth, recurring, settings }

    var body: some View {
        TabView(selection: $tab) {
            SpendingView()
                .tabItem { Label("Spending", systemImage: "dollarsign.circle") }
                .tag(Tab.spending)
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet.rectangle") }
                .tag(Tab.history)
            NetWorthView()
                .tabItem { Label("Net Worth", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.netWorth)
            RecurringView()
                .tabItem { Label("Recurring", systemImage: "arrow.triangle.2.circlepath") }
                .tag(Tab.recurring)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(Theme.accent)
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.hasUnsavedChanges { UnsavedChangesBanner() }
        }
        .sheet(item: $addRoute) { route in
            TransactionFormView(mode: .add(route == .income ? .income : .expense))
        }
        .onChange(of: model.pendingAdd, initial: true) { _, route in
            guard let route else { return }
            tab = .spending
            addRoute = route
            model.pendingAdd = nil
        }
        .appLock()
    }
}

extension AddRoute: Identifiable {
    var id: Self { self }
}

/// Shown while a change is only in memory (UI_SPEC "Shell").
struct UnsavedChangesBanner: View {
    @Environment(AppModel.self) private var model
    @State private var retrying = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.icloud").foregroundStyle(Theme.warning)
            Text("Some changes aren't saved yet.").font(.subheadline)
            Spacer()
            Button(retrying ? "Retrying…" : "Retry") {
                retrying = true
                Task {
                    await model.retrySaves()
                    retrying = false
                }
            }
            .disabled(retrying)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .accessibilityElement(children: .combine)
    }
}
