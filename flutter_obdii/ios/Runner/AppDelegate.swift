import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let channelName = "com.jamesmittlerii.obdii/carplay_bridge"

  /// Keep `Notification.Name` raw strings in sync with `obdii/carplay/CarPlayBridgeNotifications.swift`.
  enum CarPlayBridgeNotifications {
    static let settingsChanged = Notification.Name("CarPlayBridge.settingsChanged")
    static let gaugePreferencesChanged = Notification.Name("CarPlayBridge.gaugePreferencesChanged")
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CarPlayBridge")
    registerCarPlayBridgeChannel(on: registrar.messenger())
  }

  private func registerCarPlayBridgeChannel(on messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "settingsChanged":
        guard let arguments = call.arguments as? [String: Any] else {
          result(
            FlutterError(
              code: "bad_args",
              message: "settingsChanged expects a dictionary payload",
              details: nil
            )
          )
          return
        }
        NotificationCenter.default.post(
          name: CarPlayBridgeNotifications.settingsChanged,
          object: nil,
          userInfo: arguments
        )
        result(nil)

      case "gaugePreferencesChanged":
        NotificationCenter.default.post(
          name: CarPlayBridgeNotifications.gaugePreferencesChanged,
          object: nil
        )
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
