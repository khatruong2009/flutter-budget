import UIKit
import Flutter

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  private var deepLinkChannel: FlutterMethodChannel?
  private var initialLink: String?
  private var flutterViewController: FlutterViewController?
  private var pendingShortcutType: String?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    
    // Create the Flutter view controller
    let flutterViewController = FlutterViewController(
      engine: (UIApplication.shared.delegate as! AppDelegate).flutterEngine,
      nibName: nil,
      bundle: nil
    )
    self.flutterViewController = flutterViewController
    
    // Create and configure the window
    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = flutterViewController
    window?.makeKeyAndVisible()
    
    // Setup deep link channel
    setupDeepLinkChannel(with: flutterViewController)
    
    // Handle initial URL if present
    if let urlContext = connectionOptions.urlContexts.first {
      handleDeepLink(urlContext.url)
    }

    if let shortcutItem = connectionOptions.shortcutItem {
      pendingShortcutType = shortcutItem.type
    }
  }
  
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    handleDeepLink(url)
  }
  
  private func setupDeepLinkChannel(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "budget_app/deeplink",
      binaryMessenger: controller.binaryMessenger
    )
    deepLinkChannel = channel
    
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: FlutterResult) in
      guard call.method == "getInitialLink" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.initialLink)
      self?.initialLink = nil
    }
  }
  
  private func handleDeepLink(_ url: URL) {
    initialLink = url.absoluteString
    deepLinkChannel?.invokeMethod("deep_link", arguments: url.absoluteString)
  }

  private func sendQuickAction(_ shortcutType: String) {
    guard let controller = flutterViewController else {
      pendingShortcutType = shortcutType
      return
    }

    let channel = FlutterBasicMessageChannel(
      name: "dev.flutter.pigeon.quick_actions_ios.IOSQuickActionsFlutterApi.launchAction",
      binaryMessenger: controller.binaryMessenger,
      codec: FlutterStandardMessageCodec.sharedInstance()
    )
    channel.sendMessage([shortcutType])
  }

  func sceneDidDisconnect(_ scene: UIScene) {}
  func sceneDidBecomeActive(_ scene: UIScene) {
    if let shortcutType = pendingShortcutType {
      pendingShortcutType = nil
      sendQuickAction(shortcutType)
    }
  }
  func sceneWillResignActive(_ scene: UIScene) {}
  func sceneWillEnterForeground(_ scene: UIScene) {}
  func sceneDidEnterBackground(_ scene: UIScene) {}

  func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    sendQuickAction(shortcutItem.type)
    completionHandler(true)
  }
}
