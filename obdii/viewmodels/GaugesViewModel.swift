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
import SwiftUI

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

@MainActor
protocol PIDInterestManaging: AnyObject {
  func makeToken() -> UUID
  func replace(pids: Set<OBDCommand>, for token: UUID)
  func clear(token: UUID)
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

extension PIDInterestRegistry: PIDInterestManaging {}

@MainActor
@Observable
final class GaugesViewModel: BaseViewModel {

  struct Tile: Identifiable, Equatable {
    let id: UUID
    let pid: OBDPID
    let measurement: MeasurementResult?
  }

  struct RingDisplayData {
    let displayText: String
    let progress: Double?
    let progressColor: Color
    let accessibilityLabel: String
    let accessibilityValue: String
  }

  struct DisplayTile: Identifiable {
    let id: UUID
    let title: String
    let shortTitle: String
    let subtitle: String
    let valueText: String
    let valueColor: Color
    let valueAccessibilityLabel: String
    let tileAccessibilityIdentifier: String
    let ring: RingDisplayData
    let detailViewModel: GaugeDetailViewModel
  }

  private(set) var tiles: [Tile] = [] {
    didSet {
      if oldValue != tiles {
        onChanged?()
      }
    }
  }

  private(set) var displayTiles: [DisplayTile] = []

  var isEmpty: Bool { tiles.isEmpty }

  private let pidProvider: PIDListProviding
  private let statsProvider: PIDStatsProviding
  private let unitsProvider: UnitsProviding
  private let interestRegistry: PIDInterestManaging
  private let detailViewModelFactory: (OBDPID) -> GaugeDetailViewModel
  private let reorderEnabledGauges: (IndexSet, Int) -> Void
  private let interestToken: UUID
  private var isVisible = false
  private var currentUnits: MeasurementUnit = .metric

  private var cancellables = Set<AnyCancellable>()

  init(
    pidProvider: PIDListProviding,
    statsProvider: PIDStatsProviding,
    unitsProvider: UnitsProviding,
    interestRegistry: PIDInterestManaging,
    detailViewModelFactory: ((OBDPID) -> GaugeDetailViewModel)? = nil,
    reorderEnabledGauges: ((IndexSet, Int) -> Void)? = nil
  ) {
    self.pidProvider = pidProvider
    self.statsProvider = statsProvider
    self.unitsProvider = unitsProvider
    self.interestRegistry = interestRegistry
    self.detailViewModelFactory = detailViewModelFactory ?? { GaugeDetailViewModel(pid: $0) }
    self.reorderEnabledGauges = reorderEnabledGauges ?? { source, destination in
      PIDStore.shared.moveEnabled(fromOffsets: source, toOffset: destination)
    }
    self.interestToken = interestRegistry.makeToken()
    super.init()
    bind()
  }

  override convenience init() {
    self.init(
      pidProvider: PIDStore.shared,
      statsProvider: OBDConnectionManager.shared,
      unitsProvider: ConfigData.shared,
      interestRegistry: PIDInterestRegistry.shared
    )
  }

  func onAppear() {
    isVisible = true
    updateInterest()
  }

  func onDisappear() {
    isVisible = false
    interestRegistry.clear(token: interestToken)
  }

  @MainActor
  func reorder(fromOffsets source: IndexSet, toOffset destination: Int) {
    // Delegate ordering changes to the store so persistence stays consistent
    reorderEnabledGauges(source, destination)
  }

  @MainActor
  func reorderTile(withID sourceID: UUID, to targetID: UUID) {
    guard
      let sourceIndex = displayTiles.firstIndex(where: { $0.id == sourceID }),
      let targetIndex = displayTiles.firstIndex(where: { $0.id == targetID }),
      sourceIndex != targetIndex
    else {
      return
    }

    let destination = sourceIndex < targetIndex ? targetIndex + 1 : targetIndex
    reorder(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destination)
  }

  private func bind() {

    // Combine pids + stats
    let pidAndStats =
      Publishers
      .CombineLatest(pidProvider.pidsPublisher, statsProvider.pidStatsPublisher)

    // Units is just a rebuild trigger
    unitsProvider.unitsPublisher
      .removeDuplicates()
      .handleEvents(receiveOutput: { [weak self] units in
        self?.currentUnits = units
      })
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
    let rebuiltTiles =
      pids
      .filter { $0.enabled && $0.kind == .gauge }
      .map { pid in
        Tile(
          id: pid.id,
          pid: pid,
          measurement: stats[pid.pid]?.latest
        )
      }

    tiles = rebuiltTiles

    displayTiles = tiles.map(makeDisplayTile)

    if isVisible {
      updateInterest()
    }
  }

  private func makeDisplayTile(_ tile: Tile) -> DisplayTile {
    let valueText =
      tile.measurement.map { tile.pid.formatted(measurement: $0, includeUnits: true) }
      ?? "— \(tile.pid.unitLabel(for: currentUnits))"
    let valueColor =
      tile.measurement.map { tile.pid.color(for: $0.value, unit: currentUnits) }
      ?? .secondary

    return DisplayTile(
      id: tile.id,
      title: tile.pid.name,
      shortTitle: tile.pid.label,
      subtitle: tile.pid.displayRange(for: currentUnits),
      valueText: valueText,
      valueColor: valueColor,
      valueAccessibilityLabel: "\(tile.pid.name) value",
      tileAccessibilityIdentifier: "GaugeTile_\(tile.id.uuidString)",
      ring: makeRingDisplay(for: tile),
      detailViewModel: detailViewModelFactory(tile.pid)
    )
  }

  private func makeRingDisplay(for tile: Tile) -> RingDisplayData {
    let valueText =
      tile.measurement.map { tile.pid.formatted(measurement: $0, includeUnits: true) }
      ?? "— \(tile.pid.unitLabel(for: currentUnits))"
    let progress =
      tile.measurement.map { measurement in
        normalizedProgress(for: measurement.value, pid: tile.pid)
      }
    let progressColor =
      tile.measurement.map { tile.pid.color(for: $0.value, unit: currentUnits) }
      ?? .secondary

    return RingDisplayData(
      displayText: valueText,
      progress: progress,
      progressColor: progressColor,
      accessibilityLabel: tile.pid.name,
      accessibilityValue: valueText
    )
  }

  private func normalizedProgress(for value: Double, pid: OBDPID) -> Double {
    let ranges = [
      pid.typicalRange(for: currentUnits),
      pid.warningRange(for: currentUnits),
      pid.dangerRange(for: currentUnits),
    ].compactMap { $0 }
    let combinedRange =
      if let min = ranges.map(\.min).min(), let max = ranges.map(\.max).max() {
        ValueRange(min: min, max: max)
      } else {
        ValueRange(min: 0, max: 1)
      }

    return max(0, min(1, combinedRange.normalizedPosition(for: value)))
  }

  private func updateInterest() {
    let commands: Set<OBDCommand> = Set(tiles.map { $0.pid.pid })
    interestRegistry.replace(pids: commands, for: interestToken)
  }
}
