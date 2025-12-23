import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var deepLinkChannel: FlutterMethodChannel?
  private var initialLink: String?
  
  // Lazy initialization of Flutter engine for scene-based lifecycle
  lazy var flutterEngine = FlutterEngine(name: "budget_app_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Start the Flutter engine
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)

    // For iOS 12 and below (non-scene based)
    if #unavailable(iOS 13.0) {
      let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

      if let url = launchOptions?[.url] as? URL {
        initialLink = url.absoluteString
      }

      if let controller = window?.rootViewController as? FlutterViewController {
        setupDeepLinkChannel(with: controller)
      }

      return result
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - UISceneSession Lifecycle (iOS 13+)
  
  @available(iOS 13.0, *)
  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let sceneConfig = UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
    sceneConfig.delegateClass = SceneDelegate.self
    return sceneConfig
  }
  
  @available(iOS 13.0, *)
  override func application(
    _ application: UIApplication,
    didDiscardSceneSessions sceneSessions: Set<UISceneSession>
  ) {}

  // MARK: - Deep Linking (iOS 12 and below)
  
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if #unavailable(iOS 13.0) {
      handleDeepLink(url)
    }
    return super.application(app, open: url, options: options)
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
}
