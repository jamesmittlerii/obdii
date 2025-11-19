import Foundation
import Combine
import SwiftOBD2
import Observation

@MainActor
@Observable
final class GaugesViewModel: BaseViewModel {

    struct Tile: Identifiable, Equatable {
        let id: UUID
        let pid: OBDPID
        let measurement: MeasurementResult?
    }

    // MARK: - Published State

    private(set) var tiles: [Tile] = [] {
        didSet {
            if oldValue != tiles {
                onChanged?()
            }
        }
    }

    // MARK: - Dependencies

    private let connectionManager: OBDConnectionManager
    private let pidStore: PIDStore
    private var cancellables = Set<AnyCancellable>()

    // Cache for unit-change rebuilds
    private var lastPids: [OBDPID] = []
    private var lastStats: [OBDCommand: OBDConnectionManager.PIDStats] = [:]

    // MARK: - Init

    override init() {
        self.connectionManager = .shared
        self.pidStore = .shared

        super.init()

        bindPIDAndStats()
        bindUnits()
    }

    // MARK: - Combine Bindings

    /// Rebuild tiles when the enabled PIDs list OR live stats change.
    private func bindPIDAndStats() {
        Publishers.CombineLatest(pidStore.$pids, connectionManager.$pidStats)
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink { [unowned self] pids, stats in
                self.lastPids = pids
                self.lastStats = stats
                self.rebuildTiles(pids: pids, stats: stats)
            }
            .store(in: &cancellables)
    }

    /// Rebuild tiles when measurement units change (metric ↔ imperial).
    private func bindUnits() {
        ConfigData.shared.$units
            .removeDuplicates()
            .sink { [unowned self] _ in
                self.rebuildTiles(pids: self.lastPids, stats: self.lastStats)
            }
            .store(in: &cancellables)
    }

    // MARK: - Tile Construction

    private func rebuildTiles(
        pids: [OBDPID],
        stats: [OBDCommand: OBDConnectionManager.PIDStats]
    ) {
        let enabled = pids.filter { $0.enabled && $0.kind == .gauge }

        tiles = enabled.map { pid in
            Tile(
                id: pid.id,
                pid: pid,
                measurement: stats[pid.pid]?.latest
            )
        }
    }
}
