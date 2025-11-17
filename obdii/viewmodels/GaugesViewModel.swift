/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
View Model for showing the a collection of enabled/selected Gauges. Used by CarPlay and SwiftUI
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import Foundation
import Combine
import SwiftOBD2
import Observation

@MainActor
@Observable
final class GaugesViewModel : BaseViewModel{
    struct Tile: Identifiable, Equatable {
        let id: UUID
        let pid: OBDPID
        let measurement: MeasurementResult?
    }

    // Non-SwiftUI observation hook for controllers (CarPlay, etc.)
    //var onChanged: (() -> Void)?

    // Observation tracks mutations to this var.
    private(set) var tiles: [Tile] = [] {
        didSet {
            // Bridge for legacy Combine consumers (CarPlay controllers)
            tilesPublisher.send(tiles)
            // Notify non-SwiftUI observers
            if oldValue != tiles {
                onChanged?()
            }
        }
    }

    // Legacy Combine bridge so UIKit/CarPlay code can still throttle/subscribe.
    let tilesPublisher = PassthroughSubject<[Tile], Never>()

    private let connectionManager: OBDConnectionManager
    private let pidStore: PIDStore
    private var cancellables = Set<AnyCancellable>()

    // Cache the latest inputs so we can rebuild on units changes
    private var lastPids: [OBDPID] = []
    private var lastStats: [OBDCommand: OBDConnectionManager.PIDStats] = [:]

    // Designated initializer (no default args that touch main-actor singletons)
    override init() {
        self.connectionManager = OBDConnectionManager.shared
        self.pidStore = PIDStore.shared
        super.init()

        // Rebuild tiles whenever enabled PIDs or live stats change
        Publishers.CombineLatest(pidStore.$pids, connectionManager.$pidStats)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pids, stats in
                guard let self else { return }
                self.lastPids = pids
                self.lastStats = stats
                self.rebuildTiles(pids: pids, stats: stats)
            }
            .store(in: &cancellables)

        // Also rebuild when units change so display strings update
        ConfigData.shared.$unitsPublished
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.rebuildTiles(pids: self.lastPids, stats: self.lastStats)
            }
            .store(in: &cancellables)
    }

    

    private func rebuildTiles(pids: [OBDPID], stats: [OBDCommand: OBDConnectionManager.PIDStats]) {
        let enabled = pids.filter { $0.enabled && $0.kind == .gauge }
        tiles = enabled.map { pid in
            let measurement = stats[pid.pid]?.latest
            return Tile(id: pid.id, pid: pid, measurement: measurement)
        }
    }
}
