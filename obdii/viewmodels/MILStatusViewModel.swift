/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewModel for MIL (Malfunction Indicator Lamp) status
 *
 * Subscribes to OBDConnectionManager for MIL/Check Engine Light status updates.
 * Provides formatted header text, readiness monitor sorting by ready/not ready,
 * and handles nil vs populated states. Inherits from BaseViewModel for CarPlay
 * integration.
 */
import Foundation
import SwiftOBD2
import Observation
import Combine

@MainActor
@Observable
final class MILStatusViewModel: BaseViewModel {

    // MARK: - Dependencies

    private let manager: OBDConnectionManager

    // MARK: - Published State

    private(set) var status: Status? {
        didSet {
            if oldValue != status {
                onChanged?()
            }
        }
    }

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    override init() {
        self.manager = .shared
        self.status = manager.MILStatus   // seed initial snapshot

        super.init()

        bindMILStatus()
    }

    // MARK: - Bindings

    private func bindMILStatus() {
        manager.$MILStatus
            .removeDuplicates()
            .sink { [unowned self] newValue in
                self.status = newValue
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed UI Helpers

    var headerText: String {
        guard let status else { return "No MIL Status" }
        let dtcLabel = status.dtcCount == 1 ? "1 DTC" : "\(status.dtcCount) DTCs"
        return "MIL: \(status.milOn ? "On" : "Off") (\(dtcLabel))"
    }

    var hasStatus: Bool {
        status != nil
    }

    var sortedSupportedMonitors: [ReadinessMonitor] {
        guard let status else { return [] }

        let supported = status.monitors.filter { $0.supported }

        return supported.sorted { lhs, rhs in
            // 1. Not Ready → 2. Ready → 3. Unknown
            func readinessPriority(_ ready: Bool?) -> Int {
                switch ready {
                case .some(false): return 0
                case .some(true):  return 1
                case .none:        return 2
                }
            }

            let lp = readinessPriority(lhs.ready)
            let rp = readinessPriority(rhs.ready)

            if lp != rp { return lp < rp }

            // Tie-break alphabetically
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
