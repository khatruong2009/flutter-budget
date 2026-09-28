import BudgieCore
import SwiftUI

/// STUB: replaced in Phase 4 (UI_SPEC "Transaction form").
struct TransactionFormView: View {
    enum Mode: Hashable {
        case add(TransactionType)
        case edit(TransactionRecord)
    }

    let mode: Mode

    var body: some View { Text("Transaction form") }
}
