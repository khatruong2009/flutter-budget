import SwiftUI
import UIKit

@main
struct BudgieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(model.colorScheme)
                .onOpenURL { model.open($0) }
                .task {
                    ShortcutInbox.shared.deliver = { [model] type in model.handleShortcut(type) }
                    await model.start()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                AppModel.registerShortcuts()
                // Like the Flutter app: retry unsaved changes on backgrounding.
                if model.hasUnsavedChanges { Task { await model.retrySaves() } }
            }
        }
    }
}

extension AppModel {
    var colorScheme: ColorScheme? {
        switch themeMode {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

/// Quick actions arrive through the scene delegate, sometimes before SwiftUI
/// has built the model; they wait here.
@MainActor
final class ShortcutInbox {
    static let shared = ShortcutInbox()
    private var pending: [String] = []
    var deliver: ((String) -> Void)? {
        didSet {
            guard let deliver else { return }
            pending.forEach(deliver)
            pending = []
        }
    }

    func receive(_ type: String) {
        if let deliver { deliver(type) } else { pending.append(type) }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            MainActor.assumeIsolated { ShortcutInbox.shared.receive(shortcut.type) }
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Replaces the Flutter build's dynamic items (which included voice).
        AppModel.registerShortcuts()
        return true
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        MainActor.assumeIsolated { ShortcutInbox.shared.receive(shortcutItem.type) }
        completionHandler(true)
    }
}
