import BudgieCore
import SwiftUI

/// The confirmation before an import writes anything, in the redesign's
/// centred card: "Import 3 transactions?" with the skipped counts
/// (`_confirmImport`, settings_page.dart:217-286) or "Replace all data?"
/// with the counts the backup brings (`_confirmRestore`, :525-577), then
/// Cancel and the action. The action is awaited with the dialog inert
/// (no Cancel, no scrim dismiss); `onConfirm` closes it.
struct DataImportDialog: View {
    let title: String
    /// The body; nil shows none (Flutter's `content: null`).
    let message: String?
    let confirmTitle: String
    /// "Replace" is drawn in the danger colour (Flutter `AppColors.expense`).
    let destructive: Bool
    /// Prefix of the accessibility identifiers (`<prefix>.title`, `.message`,
    /// `.cancel`, `.confirm`).
    let identifier: String
    let onCancel: () -> Void
    let onConfirm: @MainActor () async -> Void

    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            TagsRulesDialogTitle(text: title)
                .accessibilityIdentifier("\(identifier).title")
            if let message {
                DialogScroll {
                    Text(message)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(BudgieColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("\(identifier).message")
                }
                .padding(.top, 12)
            }
            HStack(spacing: 12) {
                PillButton(title: CSVImport.cancelButtonTitle, color: BudgieColor.textSecondary, height: 44, action: onCancel)
                    .accessibilityIdentifier("\(identifier).cancel")
                PillButton(
                    title: confirmTitle, color: destructive ? BudgieColor.danger : BudgieColor.accent, filled: true, height: 44,
                    action: confirm
                )
                .accessibilityIdentifier("\(identifier).confirm")
            }
            .padding(.top, 24)
        }
        .disabled(busy)
        .budgieDialogDismissDisabled(busy)
    }

    private func confirm() {
        guard !busy else { return }
        busy = true
        Task { await onConfirm() }
    }
}
