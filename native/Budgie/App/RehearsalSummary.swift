#if DEBUG
import BudgieCore
import Foundation

/// Upgrade rehearsal support (UPGRADE_TEST_PLAN.md), debug builds only:
/// when launched with BUDGIE_REHEARSAL_SUMMARY=1, writes what the app shows
/// to Library/Caches/budgie-rehearsal.json so the script can compare it with
/// the numbers the Flutter models compute from the same files.
@MainActor
enum RehearsalSummary {
    static func writeIfRequested(_ model: AppModel) {
        guard ProcessInfo.processInfo.environment["BUDGIE_REHEARSAL_SUMMARY"] == "1", let data = model.data else { return }
        let calendar = data.calendar
        let now = model.now
        var monthly: [String: Any] = [:]
        for month in data.availableMonths() {
            let totals = data.totals(forMonth: month)
            monthly[calendar.netWorthMonthKey(month)] = [
                "totalIncome": totals.income, "totalExpenses": totals.expenses, "count": totals.transactionIDs.count,
            ]
        }
        var netWorth: [String: Any] = [:]
        for month in data.netWorthAvailableMonths(now: now) {
            netWorth[calendar.netWorthMonthKey(month)] = [
                "assets": data.totalAssets(forMonth: month), "liabilities": data.totalLiabilities(forMonth: month),
                "netWorth": data.netWorth(forMonth: month),
            ]
        }
        let widget = data.widgetCashFlow(now: now)
        let summary: [String: Any] = [
            "now": now.toIso8601String(),
            "transactionCount": data.transactions.count,
            "unreadableTransactionRows": data.unreadableTransactionCount,
            "monthly": monthly,
            "netWorth": netWorth,
            "recurring": data.templates.map { ["id": $0.id, "nextOccurrence": $0.nextOccurrence.toIso8601String(), "isActive": $0.isActive] },
            "appSettings": [
                "baseCurrencyCode": data.appSettings.baseCurrencyCode, "localeOverride": data.appSettings.localeOverride as Any,
                "appLockEnabled": data.appSettings.appLockEnabled, "autoLockTimeoutSeconds": data.appSettings.autoLockTimeoutSeconds,
                "hideBalances": data.appSettings.hideBalances,
            ],
            "theme": model.themeMode.rawValue,
            "widget": ["amount": widget.amount, "month": widget.month],
            "hasUnsavedChanges": model.hasUnsavedChanges,
            "loadReport": String(describing: model.loadReport),
            "backup": String(describing: model.backupOutcome),
        ]
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("budgie-rehearsal.json")
        if let json = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) {
            try? json.write(to: url, options: .atomic)
        }
    }
}
#endif
