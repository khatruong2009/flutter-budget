import LinkPresentation
import SwiftUI
import UIKit

/// A file to share, and what to do once the share sheet is done with it.
struct ShareFile: Identifiable {
    let url: URL
    /// share_plus's `subject`: the Mail subject line and the sheet's title.
    let subject: String
    /// Shown when an activity completed (Flutter shows its SnackBar after
    /// any dismissal, a cancel included).
    let completedToast: Toast
    var id: URL { url }
}

/// `Share.shareXFiles([file], subject:)` (share_plus): the system share
/// sheet for one file, with the subject for Mail and as the sheet's title.
/// Present it in a `.sheet` with `.ignoresSafeArea()`. `onComplete` gets
/// whether an activity completed; the sheet dismisses itself either way.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    let subject: String
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [ShareItemSource(url: url, subject: subject)], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onComplete(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// The file, with the subject for activities that take one (Mail) and as
/// the title of the sheet's header.
private final class ShareItemSource: NSObject, UIActivityItemSource {
    let url: URL
    let subject: String

    init(url: URL, subject: String) {
        self.url = url
        self.subject = subject
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { url }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType type: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewController(_ controller: UIActivityViewController, subjectForActivityType type: UIActivity.ActivityType?) -> String {
        subject
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = subject
        metadata.originalURL = url
        return metadata
    }
}
