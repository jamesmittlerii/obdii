/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewModel for single gauge detail view
 *
 * Tracks statistics for a specific PID including current value, min/max observed,
 * and sample count. Subscribes to OBDConnectionManager's pidStats publisher.
 * Refreshes when units change. Deduplicates updates to prevent unnecessary
 * UI refreshes. Inherits from BaseViewModel for CarPlay integration.
 */
import SwiftUI
import SwiftOBD2
import Combine
import Observation

@MainActor
@Observable
final class GaugeDetailViewModel: BaseViewModel {

    // MARK: - Dependencies

    let pid: OBDPID
    private let connectionManager: OBDConnectionManager

    // MARK: - Observable State

    private(set) var stats: OBDConnectionManager.PIDStats? {
        didSet {
            if oldValue != stats {
                onChanged?()
            }
        }
    }

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(pid: OBDPID) {
        self.pid = pid
        self.connectionManager = .shared
        self.stats = connectionManager.pidStats[pid.pid]

        super.init()

        bindPIDStats()
        bindUnits()
    }

    // MARK: - Combining PID Stats

    private func bindPIDStats() {
        connectionManager.$pidStats
            .map { [pid] dict in
                dict[pid.pid]
            }
            .removeDuplicates(by: Self.isSameStats)
            .sink { [unowned self] newValue in
                self.stats = newValue
            }
            .store(in: &cancellables)
    }

    // MARK: - Units Change Handling

    private func bindUnits() {
        ConfigData.shared.$units
            .removeDuplicates()
            .sink { [unowned self] _ in
                // Force a refresh so the UI re-renders with new unit formatting
                self.stats = self.connectionManager.pidStats[self.pid.pid]
            }
            .store(in: &cancellables)
    }

    // MARK: - Deduplication Logic

    /// Prevents UI from updating unless the change is meaningful.
    private static func isSameStats(
        _ lhs: OBDConnectionManager.PIDStats?,
        _ rhs: OBDConnectionManager.PIDStats?
    ) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true

        case let (l?, r?):
            return l.sampleCount == r.sampleCount &&
                   l.latest.value == r.latest.value &&
                   l.min == r.min &&
                   l.max == r.max

        default:
            return false
        }
    }
}
