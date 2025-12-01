import OSLog
/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * CarPlay application delegate
 *
 * Main entry point for the CarPlay application. This minimal delegate handles
 * app-level initialization and provides a shared logger for app startup events.
 *
 * Scene-specific behavior (including the CarPlay interface) is managed by
 * CarPlaySceneDelegate, as configured in the app's Info.plist.
 */
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  // App-wide logger for initialization and startup events
  static let logger = Logger(subsystem: "com.rheosoft.obdii", category: "AppInit")

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // App-level setup (scene-specific setup is in CarPlaySceneDelegate)
    return true
  }
}
