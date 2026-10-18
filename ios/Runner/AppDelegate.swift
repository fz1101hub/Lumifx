import Flutter
import UIKit
import WidgetKit

#if canImport(ActivityKit)
  import ActivityKit
#endif

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LumiFXLiveActivity") {
      LiveActivityBridge.register(with: registrar)
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

#if canImport(ActivityKit)
  /// The effect playing, for the lock screen and the Dynamic Island. The
  /// widget extension declares the same type (ios/LumiFXWidget/
  /// PlayingLiveActivity.swift) to draw it: keep the two alike.
  @available(iOS 16.1, *)
  struct PlayingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
      var effect: String
      var room: String
      var playing: Bool
      var colors: [Int]
    }

    var stopLabel: String
  }
#endif

/// `com.lumifx/live_activity`: `update` shows (or updates) the effect
/// playing as a Live Activity, `end` takes it away. Without iOS 16.1, or
/// with Live Activities switched off, it answers false and does nothing.
class LiveActivityBridge: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.lumifx/live_activity", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LiveActivityBridge(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
      guard #available(iOS 16.1, *) else {
        result(false)
        return
      }
      switch call.method {
      case "update":
        result(update(call.arguments as? [String: Any] ?? [:]))
      case "end":
        end()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    #else
      result(false)
    #endif
  }

  #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private func update(_ arguments: [String: Any]) -> Bool {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
      let state = PlayingAttributes.ContentState(
        effect: arguments["effect"] as? String ?? "LumiFX",
        room: arguments["room"] as? String ?? "",
        playing: arguments["playing"] as? Bool ?? true,
        colors: (arguments["colors"] as? [NSNumber])?.map { $0.intValue } ?? []
      )
      if let activity = Activity<PlayingAttributes>.activities.first {
        Task {
          if #available(iOS 16.2, *) {
            await activity.update(ActivityContent(state: state, staleDate: nil))
          } else {
            await activity.update(using: state)
          }
        }
        return true
      }
      let attributes = PlayingAttributes(stopLabel: arguments["stopLabel"] as? String ?? "Stop")
      do {
        if #available(iOS 16.2, *) {
          _ = try Activity.request(
            attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
        } else {
          _ = try Activity.request(attributes: attributes, contentState: state)
        }
        return true
      } catch {
        return false
      }
    }

    @available(iOS 16.1, *)
    private func end() {
      for activity in Activity<PlayingAttributes>.activities {
        Task {
          if #available(iOS 16.2, *) {
            await activity.end(nil, dismissalPolicy: .immediate)
          } else {
            await activity.end(dismissalPolicy: .immediate)
          }
        }
      }
    }
  #endif
}
