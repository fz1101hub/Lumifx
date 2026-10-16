import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LumiFXWidgetData") {
      WidgetData.register(with: registrar)
    }
  }
}

/// The home-screen widget's content, sent by the app over
/// `com.lumifx/widgets`: written to the app group the widget extension
/// reads (ios/LumiFXWidget), then the widget is reloaded. Without the app
/// group (the extension is not set up yet, see docs/IOS_WIDGET.md) this
/// does nothing.
class WidgetData: NSObject, FlutterPlugin {
  static let appGroup = "group.com.lumifx.lumifx"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.lumifx/widgets", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(WidgetData(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "update" else {
      result(FlutterMethodNotImplemented)
      return
    }
    if let arguments = call.arguments,
      let defaults = UserDefaults(suiteName: WidgetData.appGroup),
      let data = try? JSONSerialization.data(withJSONObject: arguments),
      let json = String(data: data, encoding: .utf8)
    {
      defaults.set(json, forKey: "content")
      WidgetCenter.shared.reloadAllTimelines()
    }
    result(nil)
  }
}
