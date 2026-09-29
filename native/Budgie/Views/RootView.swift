import BudgieCore
import SwiftUI

/// Chooses what to show for the bootstrap phase. Financial screens appear
/// only once the store has been read safely.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BUDGIE_DESIGN_GALLERY"] == "1" {
            DesignGalleryView()
        } else {
            phaseView
        }
        #else
        phaseView
        #endif
    }

    @ViewBuilder private var phaseView: some View {
        switch model.phase {
        case .waitingForUnlock:
            StatusScreen(
                symbol: "lock.fill", title: "Unlock your iPhone",
                message: "Budgie opens your data once your iPhone is unlocked.")
        case .starting:
            ProgressView()
        case .blocked(let blocker):
            BlockedView(blocker: blocker)
        case .ready:
            MainView()
        }
    }
}

struct StatusScreen: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
    }
}

struct BlockedView: View {
    @Environment(AppModel.self) private var model
    let blocker: AppModel.Blocker

    var body: some View {
        switch blocker {
        case .backupFailed(let reason):
            VStack(spacing: 16) {
                StatusScreen(
                    symbol: "externaldrive.badge.exclamationmark", title: "Couldn't prepare your data",
                    message: "Budgie makes a safety copy of your data before opening it and couldn't this time. Nothing was changed. Free up some storage and try again.")
                Text(reason).font(.caption2).foregroundStyle(.secondary).padding(.horizontal)
                Button("Try Again") { Task { await model.retryStart() } }.buttonStyle(.borderedProminent)
            }
        case .readFailed(let reason):
            VStack(spacing: 16) {
                StatusScreen(
                    symbol: "exclamationmark.triangle", title: "Couldn't read your data",
                    message: "Your data is still on this iPhone. Nothing was changed.")
                Text(reason).font(.caption2).foregroundStyle(.secondary).padding(.horizontal)
                Button("Try Again") { Task { await model.retryStart() } }.buttonStyle(.borderedProminent)
            }
        case .dataUnreadable(let files):
            VStack(spacing: 16) {
                StatusScreen(
                    symbol: "exclamationmark.octagon", title: "Your data couldn't be read",
                    message: "Both copies of your budget data are damaged. They have been kept on this iPhone, along with a safety copy made before this version first opened.")
                Button("Start with an Empty Budget", role: .destructive) {
                    Task { await model.startFresh(acknowledging: files) }
                }
            }
        }
    }
}
