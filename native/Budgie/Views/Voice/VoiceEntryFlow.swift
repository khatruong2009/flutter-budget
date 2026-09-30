import BudgieCore
import SwiftUI

/// The `.voice` route's one sheet (`startVoiceExpenseFlow`): the recording
/// sheet, then, in place, the add form prefilled with the draft. Swapping
/// the content rather than the host's sheet item keeps a single
/// presentation, so the host's `onDismiss` fires once, when the flow ends
/// (Cancel, Add, or a swipe while recording).
struct VoiceEntryFlow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: VoiceDraft?

    var body: some View {
        Group {
            if let draft {
                TransactionFormView(mode: .prefill(draft))
                    .presentationDetents([.large])
                    .transition(.opacity)
            } else {
                VoiceRecordingSheet(onDraft: { draft = $0 }, onCancel: { dismiss() })
                    .transition(.opacity)
            }
        }
        .motion(Motion.easeOut(Motion.fast), value: draft)
    }
}
