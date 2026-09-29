import BudgieCore
import SwiftUI

/// What was loaded, for upgrade rehearsals and support.
struct DiagnosticsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            if let data = model.data {
                let formatter = model.moneyFormatter
                let month = model.calendar.month(of: model.now)
                let totals = model.ledger.summary(forMonth: month)
                Section("Ledger") {
                    LabeledContent("Transactions", value: "\(data.transactions.count)")
                    LabeledContent("Unreadable rows kept", value: "\(data.unreadableTransactionCount)")
                    LabeledContent("This month income", value: formatter.format(totals.income))
                    LabeledContent("This month expenses", value: formatter.format(totals.expenses))
                    LabeledContent("Recurring templates", value: "\(data.templates.count)")
                }
                Section("Net worth") {
                    LabeledContent("Net worth (this month)", value: formatter.format(data.netWorth(forMonth: month)))
                    LabeledContent("Accounts", value: "\(data.netWorthEntries.count)")
                }
                Section("Settings") {
                    LabeledContent("Currency", value: data.appSettings.baseCurrencyCode)
                    LabeledContent("Theme", value: model.themeMode.rawValue)
                    LabeledContent("App Lock", value: data.appSettings.appLockEnabled ? "On" : "Off")
                }
                Section("Migration") {
                    Text(String(describing: model.backupOutcome)).font(.caption2)
                    Text(String(describing: model.loadReport)).font(.caption2)
                    LabeledContent("Unsaved changes", value: model.hasUnsavedChanges ? "Yes" : "No")
                }
            }
        }
        .navigationTitle("Budgie")
    }
}
