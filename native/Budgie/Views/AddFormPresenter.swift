import SwiftUI
import UIKit

/// Opens the add form for quick actions, widget taps and deep links
/// (`model.pendingAdd`) on top of whatever is showing: a Home sheet, an
/// edit form, its date picker, a Goals or Worth dialog. Flutter pushes
/// `showTransactionForm` on the root navigator over any sheet or dialog
/// (D14); the user's own presentation stays underneath, untouched.
///
/// A `.voice` route is the exception to stacking: while a voice host is up
/// (the recording sheet and the prefilled form after it) another `.voice`
/// route is dropped, as Flutter's `_voiceFlowActive` does. Add and income
/// routes still open over it.
///
/// The one presenter for every route. From the topmost presented controller
/// of the key window it presents, without animation, a transparent
/// full-screen `AddFormHost` whose SwiftUI root shows the form as an
/// ordinary `.sheet` (so its sheet chrome, dismiss lock and nested date
/// picker behave as anywhere else) and which removes itself once that sheet
/// is gone. A `.sheet` on the tab view could not: UIKit refuses a second
/// presentation from a controller that is already presenting, and the
/// refused route then blocked every later one.
///
/// A route is taken from the model only when there is a controller to
/// present from. While one is being presented or dismissed the route stays
/// queued and is retried shortly; a presentation UIKit still refuses puts
/// the route back.
@MainActor
enum AddFormPresenter {
    private static var retry: Task<Void, Never>?

    /// The host presented for the latest `.voice` route. Weak, so a refused
    /// presentation (whose host is never kept) or a host that has gone
    /// leaves nothing behind.
    private static weak var voiceHost: UIViewController?

    private static var voiceFlowIsUp: Bool { voiceHost?.presentingViewController != nil }

    static func openPendingAdd(_ model: AppModel) {
        guard retry == nil, model.canOpenRoutes, model.pendingAdd != nil else { return }
        let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
        if let refused = open(above: scene?.keyWindow?.rootViewController, take: model.takePendingAdd, host: {
            AddFormHost(route: $0, model: model)
        }) {
            model.pendingAdd = model.pendingAdd ?? refused
        }
        guard model.pendingAdd != nil else { return }
        retry = Task {
            try? await Task.sleep(for: .milliseconds(150))
            retry = nil
            openPendingAdd(model)
        }
    }

    /// Takes a route (`take`) once `root`'s window has a controller to
    /// present from, and presents `host(route)` over it. Returns a route
    /// that was taken but refused by UIKit, for the caller to queue again;
    /// nil when it presented, took nothing, or dropped a `.voice` route
    /// because a voice host is already up.
    static func open(
        above root: UIViewController?, take: () -> AddRoute?, host: (AddRoute) -> UIViewController
    ) -> AddRoute? {
        guard let presenter = presenter(above: root), let route = take() else { return nil }
        if route == .voice && voiceFlowIsUp { return nil }
        let controller = host(route)
        presenter.present(controller, animated: false)
        if route == .voice { voiceHost = controller }
        return controller.presentingViewController == nil ? route : nil
    }

    /// The topmost presented controller above `root`, or nil while there is
    /// none to present from yet (the caller waits and retries): the chain is
    /// not in a window, or a controller in it is being presented or
    /// dismissed, or the top is an `AddFormHost` whose form is not up yet or
    /// has just closed (the host is about to dismiss itself, and would take
    /// anything presented from it along).
    ///
    /// An alert is a valid presenter: the form opens over it, as Flutter's
    /// does over a dialog, and the alert is still there once it closes.
    static func presenter(above root: UIViewController?) -> UIViewController? {
        guard var top = root, top.viewIfLoaded?.window != nil else { return nil }
        while true {
            if top.isBeingPresented || top.isBeingDismissed { return nil }
            guard let next = top.presentedViewController else { break }
            top = next
        }
        return top.transitionCoordinator == nil && !(top is AddFormHost) ? top : nil
    }
}

/// The transparent full-screen host of one route's add form (see
/// `AddFormPresenter`). It dismisses itself, without animation, once the
/// form's sheet has been dismissed.
final class AddFormHost: UIHostingController<AddFormHostRoot> {
    init(route: AddRoute, model: AppModel) {
        super.init(rootView: AddFormHostRoot(route: route, model: model, close: {}))
        modalPresentationStyle = .overFullScreen
        view.backgroundColor = .clear
        rootView = AddFormHostRoot(route: route, model: model) { [weak self] in
            self?.presentingViewController?.dismiss(animated: false)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The screens beneath, hidden from VoiceOver while the host is up.
    private var hiddenBeneath: [UIView] = []

    /// An over-full-screen presentation leaves the screens beneath it in
    /// the accessibility tree, so VoiceOver could leave the form for the
    /// sheet or tab under it. They are hidden until the host goes (views
    /// something else already hid are left alone).
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        var beneath = presentingViewController
        while let controller = beneath {
            if let view = controller.viewIfLoaded, !view.accessibilityElementsHidden {
                view.accessibilityElementsHidden = true
                hiddenBeneath.append(view)
            }
            beneath = controller.presentingViewController
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for view in hiddenBeneath { view.accessibilityElementsHidden = false }
        hiddenBeneath = []
    }
}

/// Shows the route's sheet as soon as the host is on screen. The
/// host sits in the app's window, so the theme override, Dynamic Type and
/// Reduce Motion reach it from there; the environment that `AppRoot` and
/// `MainView` give the rest of the app is set on the form here.
struct AddFormHostRoot: View {
    let route: AddRoute
    let model: AppModel
    let close: () -> Void
    @State private var shown: AddRoute?

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .sheet(item: $shown, onDismiss: close) { route in
                content(for: route)
                    .font(TextSpec.bodyLarge.font())
                    .environment(model)
                    .tint(BudgieColor.accent)
            }
            .onAppear { shown = route }
    }

    @ViewBuilder
    private func content(for route: AddRoute) -> some View {
        switch route {
        case .expense: TransactionFormView(mode: .add(.expense))
        case .income: TransactionFormView(mode: .add(.income))
        case .voice: VoiceEntryFlow()
        }
    }
}
