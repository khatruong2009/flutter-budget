import UIKit
import Flutter

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  private var deepLinkChannel: FlutterMethodChannel?
  private var initialLink: String?

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
  
  func sceneDidDisconnect(_ scene: UIScene) {}
  func sceneDidBecomeActive(_ scene: UIScene) {}
  func sceneWillResignActive(_ scene: UIScene) {}
  func sceneWillEnterForeground(_ scene: UIScene) {}
  func sceneDidEnterBackground(_ scene: UIScene) {}
}
