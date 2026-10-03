import LinkPresentation
import UIKit

/// A file to share, and what to do once the share sheet is done with it.
struct ShareFile {
    let url: URL
    /// share_plus's `subject`: the Mail subject and the sheet's title.
    let subject: String
    /// Shown when an activity completed (Flutter shows its SnackBar after
    /// any dismissal, a cancel included).
    let completedToast: Toast
}

/// `Share.shareXFiles([file], subject:)` (share_plus): the system share
/// sheet for one file, presented by UIKit from the topmost presented
/// controller as share_plus does, so it is the system's compact sheet
/// (about half height, pulled up for more), not a SwiftUI sheet around an
/// embedded one. The subject is the Mail subject and the header's title;
/// the header's subtitle is the system's own for the file ("JSON · 5 KB").
@MainActor
enum SharePresenter {
    /// Presents the sheet; `onComplete` gets whether an activity completed,
    /// once it is gone. False when there is no controller to present from
    /// (the window is not up, or a presentation is coming or going);
    /// `onComplete` is then never called. The activity controller shows
    /// asynchronously, so the check is made before presenting, not after.
    static func present(_ file: ShareFile, onComplete: @escaping (Bool) -> Void) -> Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard var top = scene?.keyWindow?.rootViewController, top.viewIfLoaded?.window != nil else { return false }
        while let next = top.presentedViewController { top = next }
        guard !top.isBeingPresented, !top.isBeingDismissed, top.transitionCoordinator == nil else { return false }

        let controller = UIActivityViewController(
            activityItems: [ShareItemSource(url: file.url, subject: file.subject)], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onComplete(completed) }
        // iPad (the iPhone app in compatibility mode): centred, no arrow.
        if let popover = controller.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(controller, animated: true)
        return true
    }
}

/// The file, with the subject for activities that take one (Mail) and as
/// the title of the sheet's header. The header's subtitle is the last path
/// component of the metadata's `originalURL`, so, as share_plus does
/// (FPPSharePlusPlugin.m `activityViewControllerLinkMetadata`), that is a
/// file URL whose path is "JSON • 5 KB" (the extension uppercased and the
/// file size), not the file's own URL (which showed its name).
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
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        let type = url.pathExtension.uppercased()
        metadata.originalURL = URL(fileURLWithPath: type.isEmpty ? size : "\(type) • \(size)")
        return metadata
    }
}
