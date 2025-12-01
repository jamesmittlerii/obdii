/**
 * __Final Project__
 * Jim Mittler
 * 30 November 2025
 *
 * ViewModel for our selected gauges
 *
 * Keeps an array of visible tiles. Update when new data arrives.
 *
 */

import Combine
import Foundation
import Observation
import SwiftOBD2

@MainActor
protocol PIDListProviding {
  var pidsPublisher: AnyPublisher<[OBDPID], Never> { get }
}

@MainActor
protocol PIDStatsProviding {
  var pidStatsPublisher: AnyPublisher<[OBDCommand: OBDConnectionManager.PIDStats], Never> { get }
  func currentStats(for pid: OBDCommand) -> OBDConnectionManager.PIDStats?
}

@MainActor
protocol UnitsProviding {
  var unitsPublisher: AnyPublisher<MeasurementUnit, Never> { get }
}

extension PIDStore: PIDListProviding {
  var pidsPublisher: AnyPublisher<[OBDPID], Never> { $pids.eraseToAnyPublisher() }
}

extension OBDConnectionManager: PIDStatsProviding {
  var pidStatsPublisher: AnyPublisher<[OBDCommand: PIDStats], Never> {
    $pidStats.eraseToAnyPublisher()
  }
  func currentStats(for pid: OBDCommand) -> PIDStats? { stats(for: pid) }
}

extension ConfigData: UnitsProviding {}

@MainActor
@Observable
final class GaugesViewModel: BaseViewModel {

  struct Tile: Identifiable, Equatable {
    let id: UUID
    let pid: OBDPID
    let measurement: MeasurementResult?
  }

  private(set) var tiles: [Tile] = [] {
    didSet {
      if oldValue != tiles {
        onChanged?()
      }
    }
  }

  var isEmpty: Bool { tiles.isEmpty }

  private let pidProvider: PIDListProviding
  private let statsProvider: PIDStatsProviding
  private let unitsProvider: UnitsProviding

  private var cancellables = Set<AnyCancellable>()

  init(
    pidProvider: PIDListProviding,
    statsProvider: PIDStatsProviding,
    unitsProvider: UnitsProviding
  ) {
    self.pidProvider = pidProvider
    self.statsProvider = statsProvider
    self.unitsProvider = unitsProvider
    super.init()
    bind()
  }

  override convenience init() {
    self.init(
      pidProvider: PIDStore.shared,
      statsProvider: OBDConnectionManager.shared,
      unitsProvider: ConfigData.shared
    )
  }

  private func bind() {

    // Combine pids + stats
    let pidAndStats =
      Publishers
      .CombineLatest(pidProvider.pidsPublisher, statsProvider.pidStatsPublisher)

    // Units is just a rebuild trigger
    unitsProvider.unitsPublisher
      .removeDuplicates()
      .flatMap { _ in pidAndStats }  // re-trigger with last values
      .merge(with: pidAndStats)  // also update on pid/stats changes
      .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
      .sink { [weak self] pids, stats in
        self?.rebuildTiles(pids: pids, stats: stats)
      }
      .store(in: &cancellables)
  }

  private func rebuildTiles(
    pids: [OBDPID],
    stats: [OBDCommand: OBDConnectionManager.PIDStats]
  ) {
    tiles =
      pids
      .filter { $0.enabled && $0.kind == .gauge }
      .map { pid in
        Tile(
          id: pid.id,
          pid: pid,
          measurement: stats[pid.pid]?.latest
        )
      }
  }
}
