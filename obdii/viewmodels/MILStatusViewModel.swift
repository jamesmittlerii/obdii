/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
View Model for showing the Malfunction Indicator Light (CEL) status and detail. Used by CarPlay and SwiftUI
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */
import Foundation
import SwiftOBD2
import Observation

@MainActor
@Observable
final class MILStatusViewModel {
    // Callback for controllers (CarPlay, etc.) to observe changes, mirroring FuelStatusViewModel/DiagnosticsViewModel pattern
    var onStatusChanged: (() -> Void)?

    // Direct dependency on the manager (already @Observable)
    private let manager: OBDConnectionManager

    // Mirror of the current MIL status for consumers that expect a local property
    // Observation will track mutations to this property.
    private(set) var status: Status?
    private var lastEmitted: Status?

    init(connectionManager: OBDConnectionManager? = nil) {
        self.manager = connectionManager ?? OBDConnectionManager.shared
        // Initialize with current value
        self.status = manager.MILStatus
        self.lastEmitted = self.status
    }

    // Call this from UI lifecycle hooks (e.g., view .onAppear or controller setup)
    // to synchronize and notify non-Observation consumers (CarPlay).
    func refreshFromManager() {
        let newValue = manager.MILStatus
        if lastEmitted != newValue {
            lastEmitted = newValue
            status = newValue
            onStatusChanged?()
        }
    }

    var headerText: String {
        guard let status else { return "No MIL Status" }
        let dtcLabel = "\(status.dtcCount) DTC" + (status.dtcCount == 1 ? "" : "s")
        let milLabel = status.milOn ? "On" : "Off"
        return "MIL: \(milLabel) (\(dtcLabel))"
    }

    var hasStatus: Bool { status != nil }

    var sortedSupportedMonitors: [ReadinessMonitor] {
        guard let status else { return [] }
        let supported = status.monitors.filter { $0.supported }
        return supported.sorted { lhs, rhs in
            func priority(for ready: Bool?) -> Int {
                switch ready {
                case .some(false): return 0   // Not Ready first
                case .some(true):  return 1   // Ready next
                case .none:        return 2   // Unknown last
                }
            }
            let lp = priority(for: lhs.ready)
            let rp = priority(for: rhs.ready)
            if lp != rp { return lp < rp }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
