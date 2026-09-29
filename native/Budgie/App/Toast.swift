import BudgieCore
import Foundation

/// A floating message at the bottom of the app (Flutter's floating
/// SnackBars). One at a time; a new one replaces the current one. Every
/// value is a new toast with its own id (the presets are computed), so
/// showing the same message twice restarts its timer: a shared id kept the
/// first one's timer, and the second toast vanished early.
struct Toast: Identifiable, Equatable {
    enum Style: Equatable { case success, danger }
    enum Action: Equatable { case retrySaves }

    let id = UUID()
    var message: String
    var style: Style = .success
    var action: Action? = nil
    /// Seconds on screen (Flutter's SnackBar default is 4).
    var duration: Double = 4

    /// After a failed write (transaction form).
    static var saveFailed: Toast {
        Toast(
            message: "Couldn't save to this device. The entry is kept in memory until Retry succeeds.", style: .danger,
            action: .retrySaves, duration: 8)
    }

    /// After a transaction delete.
    static var transactionDeleted: Toast { Toast(message: "Transaction deleted", style: .danger) }

    /// Goals tab (savings_goals_page.dart `_runMutation`), all success
    /// green in Flutter, the delete included.
    static var goalAdded: Toast { Toast(message: "Savings goal added") }
    static var goalUpdated: Toast { Toast(message: "Savings goal updated") }
    static var allocationAdded: Toast { Toast(message: "Allocation added") }
    static var goalDeleted: Toast { Toast(message: "Savings goal deleted") }

    /// After adding a transaction dated outside the month on screen:
    /// "Added to September", or "Added to September 2025" in another year.
    static func addedTo(month: DartDateTime, now: DartDateTime) -> Toast {
        let label = month.year == now.year ? DartDateFormat.MMMM(month) : DartDateFormat.MMMMyyyy(month)
        return Toast(message: "Added to \(label)")
    }
}
