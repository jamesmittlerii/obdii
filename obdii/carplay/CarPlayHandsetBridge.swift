/**
 * Applies handset-originated settings delivered over the Flutter method channel
 * (mirrored as NotificationCenter payloads) onto native `ConfigData` and
 * `ConfigurationService`.
 *
 * Flutter uses slightly different persisted strings than SwiftOBD2 raw values
 * for units and connection type; this mapper accepts both.
 */
import Foundation
import SwiftOBD2

enum CarPlayHandsetBridge {

  @MainActor
  static func applySettings(userInfo: [AnyHashable: Any]?) {
    guard let info = userInfo as? [String: Any] else { return }

    if let host = info["wifiHost"] as? String {
      ConfigData.shared.wifiHost = host
    }

    if let portNumber = info["wifiPort"] as? NSNumber {
      ConfigData.shared.wifiPort = portNumber.intValue
    } else if let port = info["wifiPort"] as? Int {
      ConfigData.shared.wifiPort = port
    }

    if let auto = info["autoConnectToOBD"] as? NSNumber {
      ConfigData.shared.autoConnectToOBD = auto.boolValue
    } else if let auto = info["autoConnectToOBD"] as? Bool {
      ConfigData.shared.autoConnectToOBD = auto
    }

    if let rawConnection = info["connectionType"] as? String {
      ConfigData.shared.connectionType = mapConnectionType(rawConnection)
    }

    if let rawUnits = info["units"] as? String {
      ConfigData.shared.setUnits(mapMeasurementUnit(rawUnits))
    }
  }

  private static func mapConnectionType(_ raw: String) -> ConnectionType {
    switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "bluetooth": return .bluetooth
    case "wifi": return .wifi
    case "demo": return .demo
    default:
      return ConnectionType(rawValue: raw) ?? .bluetooth
    }
  }

  private static func mapMeasurementUnit(_ raw: String) -> MeasurementUnit {
    switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "metric": return .metric
    case "imperial": return .imperial
    default:
      return MeasurementUnit(rawValue: raw) ?? .metric
    }
  }
}
