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
import Combine

@MainActor
@Observable
final class MILStatusViewModel : BaseViewModel{
    // Callback for controllers (CarPlay, etc.) to observe changes, mirroring FuelStatusViewModel/DiagnosticsViewModel pattern
   // var onChanged: (() -> Void)?

    // Keep a stable reference to the manager
    private let manager: OBDConnectionManager

    // Current MIL status snapshot for UI
    private(set) var status: Status?

    // Combine subscription
    private var cancellable: AnyCancellable?

    override init() {
        self.manager = OBDConnectionManager.shared

        
        // Seed with any existing value so initial UI can show immediately
        self.status = manager.MILStatus

        super.init()

        // Follow FuelStatusViewModel pattern
        cancellable = manager.$MILStatus
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                self.status = newValue
                // Match FuelStatusViewModel style: no manual equality gate here.
                self.onChanged?()
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
