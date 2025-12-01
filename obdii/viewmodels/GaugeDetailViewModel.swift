import Combine
import Observation
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
import SwiftOBD2

@MainActor
@Observable
final class GaugeDetailViewModel: BaseViewModel {

  let pid: OBDPID
  private let statsProvider: PIDStatsProviding
  private let unitsProvider: UnitsProviding

  private(set) var stats: OBDConnectionManager.PIDStats? {
    didSet {
      if oldValue != stats {
        onChanged?()
      }
    }
  }

  private var cancellables = Set<AnyCancellable>()

  init(
    pid: OBDPID,
    statsProvider: PIDStatsProviding,
    unitsProvider: UnitsProviding
  ) {
    self.pid = pid
    self.statsProvider = statsProvider
    self.unitsProvider = unitsProvider
    self.stats = statsProvider.currentStats(for: pid.pid)

    super.init()

    bindPIDStats()
    bindUnits()
  }

  convenience init(pid: OBDPID) {
    self.init(
      pid: pid,
      statsProvider: OBDConnectionManager.shared,
      unitsProvider: ConfigData.shared
    )
  }

  private func bindPIDStats() {
    statsProvider.pidStatsPublisher
      .map { [pid] dict in
        dict[pid.pid]
      }
      .removeDuplicates(by: Self.isSameStats)
      .sink { [unowned self] newValue in
        self.stats = newValue
      }
      .store(in: &cancellables)
  }

  private func bindUnits() {
    unitsProvider.unitsPublisher
      .removeDuplicates()
      .sink { [unowned self] _ in
        // Force a refresh so the UI re-renders with new unit formatting
        self.stats = self.statsProvider.currentStats(for: self.pid.pid)
      }
      .store(in: &cancellables)
  }
  // Prevents UI from updating unless the change is meaningful.
  private static func isSameStats(
    _ lhs: OBDConnectionManager.PIDStats?,
    _ rhs: OBDConnectionManager.PIDStats?
  ) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
      return true

    case (let l?, let r?):
      return l.sampleCount == r.sampleCount && l.latest.value == r.latest.value && l.min == r.min
        && l.max == r.max

    default:
      return false
    }
  }
}
