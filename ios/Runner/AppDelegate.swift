import CoreLocation
import CryptoKit
import EventKit
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
    // Woken in the background by crossing the circle around home: the
    // location manager's delegate must exist before the event arrives.
    HomeAwayBridge.shared.start()
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LumiFXCalendar") {
      CalendarBridge.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LumiFXHomeAway") {
      HomeAwayBridge.register(with: registrar)
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

/// `com.lumifx/calendar`: the phone's appointments, read only, for the
/// lights before an appointment. `events` lists those starting between
/// `from` and `to` (milliseconds) with their title, start and whether they
/// last all day. Only the times reach the bridge.
class CalendarBridge: NSObject, FlutterPlugin {
  private let store = EKEventStore()

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.lumifx/calendar", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(CalendarBridge(), channel: channel)
  }

  private var granted: Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      return status == .fullAccess
    }
    return status == .authorized
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasAccess":
      result(granted)
    case "requestAccess":
      if granted {
        result(true)
        return
      }
      let done: (Bool, Error?) -> Void = { allowed, _ in
        DispatchQueue.main.async { result(allowed) }
      }
      if #available(iOS 17.0, *) {
        store.requestFullAccessToEvents(completion: done)
      } else {
        store.requestAccess(to: .event, completion: done)
      }
    case "events":
      guard granted,
        let arguments = call.arguments as? [String: Any],
        let from = (arguments["from"] as? NSNumber)?.doubleValue,
        let to = (arguments["to"] as? NSNumber)?.doubleValue
      else {
        result([])
        return
      }
      let predicate = store.predicateForEvents(
        withStart: Date(timeIntervalSince1970: from / 1000),
        end: Date(timeIntervalSince1970: to / 1000), calendars: nil)
      let events = store.events(matching: predicate)
        .sorted { $0.startDate < $1.startDate }
        .prefix(50)
      result(
        events.map { event -> [String: Any] in
          [
            "title": event.title ?? "",
            "start": Int64(event.startDate.timeIntervalSince1970 * 1000),
            "allDay": event.isAllDay,
          ]
        })
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Leaving and coming home with the app closed: region monitoring around
/// home, and on crossing it this phone tells the bridge itself (its own
/// presence sensor; the last one out switches every light off; after dark
/// the hall lights up), as `leftHome`/`cameHome` do in Dart.
/// `com.lumifx/home_away`: permission, where the phone is, the settings.
class HomeAwayBridge: NSObject, FlutterPlugin, CLLocationManagerDelegate,
  URLSessionDelegate
{
  static let shared = HomeAwayBridge()
  private static let region = "lumifx.home"
  private static let service = "com.lumifx.home_away"

  private var manager: CLLocationManager?
  private var accessReply: FlutterResult?
  private var locationReply: FlutterResult?
  private var pinned: (fingerprint: String, bridgeId: String)?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.lumifx/home_away", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(shared, channel: channel)
  }

  func start() {
    guard manager == nil else { return }
    let manager = CLLocationManager()
    manager.delegate = self
    self.manager = manager
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    start()
    switch call.method {
    case "requestAccess":
      accessReply?(false)
      accessReply = result
      manager?.requestAlwaysAuthorization()
      if manager?.authorizationStatus != .notDetermined {
        answerAccess()
      }
    case "currentLocation":
      locationReply?(nil)
      locationReply = result
      manager?.requestLocation()
    case "configure":
      if let config = call.arguments as? [String: Any],
        let data = try? JSONSerialization.data(withJSONObject: config)
      {
        Self.save(data)
      } else {
        Self.save(nil)
      }
      watch()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func answerAccess() {
    guard let reply = accessReply else { return }
    accessReply = nil
    let status = manager?.authorizationStatus
    reply(status == .authorizedAlways || status == .authorizedWhenInUse)
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    answerAccess()
    watch()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let reply = locationReply, let location = locations.last else { return }
    locationReply = nil
    reply([
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    locationReply?(nil)
    locationReply = nil
  }

  /// Watches the circle around home, or stops without settings.
  private func watch() {
    guard let manager = manager else { return }
    for region in manager.monitoredRegions where region.identifier == Self.region {
      manager.stopMonitoring(for: region)
    }
    guard let config = Self.load(),
      let latitude = config["latitude"] as? Double,
      let longitude = config["longitude"] as? Double,
      let radius = config["radius"] as? Double,
      CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
    else { return }
    let region = CLCircularRegion(
      center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
      radius: min(radius, manager.maximumRegionMonitoringDistance),
      identifier: Self.region)
    region.notifyOnEntry = true
    region.notifyOnExit = true
    manager.startMonitoring(for: region)
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    if region.identifier == Self.region { cross(entering: true) }
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    if region.identifier == Self.region { cross(entering: false) }
  }

  /// The phone crossed the circle: tells the bridge.
  private func cross(entering: Bool) {
    guard let config = Self.load(),
      let host = config["host"] as? String,
      let key = config["key"] as? String,
      let sensor = config["sensor"] as? String,
      let fingerprint = config["fingerprint"] as? String
    else { return }
    pinned = (fingerprint.lowercased(), (config["bridgeId"] as? String ?? "").lowercased())
    let offOnLeave = config["offOnLeave"] as? Bool ?? true
    let hall = config["hallGroup"] as? String
    var task = UIBackgroundTaskIdentifier.invalid
    task = UIApplication.shared.beginBackgroundTask {
      UIApplication.shared.endBackgroundTask(task)
    }
    let started = task
    let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    Task { @MainActor in
      defer {
        session.invalidateAndCancel()
        UIApplication.shared.endBackgroundTask(started)
      }
      func call(_ method: String, _ path: String, _ body: String? = nil) async -> Data? {
        guard let url = URL(string: "https://\(host)/api/\(key)\(path)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = method
        if let body = body {
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.httpBody = body.data(using: .utf8)
        }
        guard let (data, response) = try? await session.data(for: request),
          let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { return nil }
        return data
      }
      _ = await call("PUT", "/sensors/\(sensor)/state", "{\"presence\":\(entering)}")
      guard let data = await call("GET", "/sensors"),
        let sensors = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      else { return }
      func state(_ value: Any) -> [String: Any]? {
        (value as? [String: Any])?["state"] as? [String: Any]
      }
      if !entering {
        guard offOnLeave else { return }
        let someoneHome = sensors.contains { id, value in
          guard id != sensor, let entry = value as? [String: Any] else { return false }
          let type = entry["type"] as? String
          let counts =
            type == "Geofence"
            || (type == "CLIPPresence" && entry["modelid"] as? String == "LumiFXPresence")
          return counts && state(value)?["presence"] as? Bool == true
        }
        if !someoneHome {
          _ = await call("PUT", "/groups/0/action", "{\"on\":false,\"transitiontime\":20}")
        }
      } else if let hall = hall, !hall.isEmpty {
        let dark = sensors.values.contains { value in
          (value as? [String: Any])?["type"] as? String == "Daylight"
            && state(value)?["daylight"] as? Bool == false
        }
        if dark {
          _ = await call(
            "PUT", "/groups/\(hall)/action", "{\"on\":true,\"bri\":180,\"ct\":366}")
        }
      }
    }
  }

  /// Trusts only the bridge with the pinned certificate, as the app does.
  func urlSession(
    _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
      let trust = challenge.protectionSpace.serverTrust,
      let pinned = pinned,
      let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
      let leaf = chain.first
    else {
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }
    let digest = SHA256.hash(data: SecCertificateCopyData(leaf) as Data)
      .map { String(format: "%02x", $0) }.joined()
    let subject = (SecCertificateCopySubjectSummary(leaf) as String? ?? "").lowercased()
    if digest == pinned.fingerprint
      && (pinned.bridgeId.isEmpty || subject.contains(pinned.bridgeId))
    {
      completionHandler(.useCredential, URLCredential(trust: trust))
    } else {
      completionHandler(.cancelAuthenticationChallenge, nil)
    }
  }

  // The settings hold the bridge key: kept in the keychain.
  private static func save(_ data: Data?) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]
    SecItemDelete(query as CFDictionary)
    guard let data = data else { return }
    var item = query
    item[kSecValueData as String] = data
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(item as CFDictionary, nil)
  }

  private static func load() -> [String: Any]? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var found: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
      let data = found as? Data
    else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  }
}
