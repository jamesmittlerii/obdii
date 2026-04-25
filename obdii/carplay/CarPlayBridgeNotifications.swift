/**
 * Notification names posted from the Flutter iOS runner (`AppDelegate`) when
 * handset settings or gauge preferences change. CarPlay observes these and
 * refreshes native templates.
 *
 * Keep raw strings in sync with:
 * `flutter_obdii/ios/Runner/AppDelegate.swift` (`CarPlayBridgeNotifications`).
 */
import Foundation

enum CarPlayBridgeNotifications {
  static let settingsChanged = Notification.Name("CarPlayBridge.settingsChanged")
  static let gaugePreferencesChanged = Notification.Name("CarPlayBridge.gaugePreferencesChanged")
}
