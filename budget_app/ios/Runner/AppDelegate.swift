import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var deepLinkChannel: FlutterMethodChannel?
  private var initialLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let url = launchOptions?[.url] as? URL {
      initialLink = url.absoluteString
    }

    if let controller = window?.rootViewController as? FlutterViewController {
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

    return result
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    handleDeepLink(url)
    return super.application(app, open: url, options: options)
  }

  private func handleDeepLink(_ url: URL) {
    initialLink = url.absoluteString
    deepLinkChannel?.invokeMethod("deep_link", arguments: url.absoluteString)
  }
}
