import Foundation
import Combine

@MainActor
final class PIDStore: ObservableObject {

    // MARK: - Singleton
    static let shared = PIDStore()

    // MARK: - Published Model
    @Published private(set) var pids: [OBDPID]

    // MARK: - Persistence Keys
    private static let enabledKey              = "PIDStore.enabledByCommand"
    private static let enabledGaugesOrderKey   = "PIDStore.enabledGaugesOrder"
    private static let disabledGaugesOrderKey  = "PIDStore.disabledGaugesOrder"

    // MARK: - Init

    private init() {

        // 1. Load PIDs from JSON source
        var all = OBDPIDLibrary.loadFromJSON()

        // 2. Restore enabled/disabled flags
        if let data = UserDefaults.standard.data(forKey: Self.enabledKey),
           let saved = try? JSONDecoder().decode([String: Bool].self, from: data) {

            for i in all.indices {
                let command = all[i].pid.properties.command
                if let enabledFlag = saved[command] {
                    all[i].enabled = enabledFlag
                }
            }
        }

        // 3. Load persisted ordering for only gauges
        let savedEnabledOrder  = Self.loadOrder(forKey: Self.enabledGaugesOrderKey)
        let savedDisabledOrder = Self.loadOrder(forKey: Self.disabledGaugesOrderKey)

        // 4. Apply ordering (only if either list exists)
        if savedEnabledOrder != nil || savedDisabledOrder != nil {
            all = Self.applySavedOrdering(
                to: all,
                enabledOrder:  savedEnabledOrder,
                disabledOrder: savedDisabledOrder
            )
        }

        self.pids = all

        // 5. Persist state on first boot to lock in structure
        persistEnabledFlags(pids)
        persistGaugeOrders(pids)
    }

    // MARK: - Public API

    func toggle(_ pid: OBDPID) {
        guard let idx = pids.firstIndex(where: { $0.id == pid.id }) else { return }

        var new = pid
        new.enabled.toggle()
        pids[idx] = new

        pids = Self.reordered(pids)

        persistEnabledFlags(pids)
        persistGaugeOrders(pids)
    }

    /// Returns all enabled gauge PIDs in their current user-defined order.
    var enabledGauges: [OBDPID] {
        pids.filter { $0.kind == .gauge && $0.enabled }
    }

    /// Reorder the *enabled* gauges section.
    func moveEnabled(fromOffsets source: IndexSet, toOffset destination: Int) {

        // Resolve the indices of enabled gauges inside the master array
        let enabledIndices = pids.indices.filter { pids[$0].kind == .gauge && pids[$0].enabled }
        guard !enabledIndices.isEmpty else { return }

        // Extract the enabled subset
        var subset = enabledIndices.map { pids[$0] }

        // Perform the move
        subset.move(fromOffsets: source, toOffset: destination)

        // Write back to the master array
        var newPIDs = pids
        for (i, masterIndex) in enabledIndices.enumerated() {
            newPIDs[masterIndex] = subset[i]
        }

        pids = newPIDs
        persistGaugeOrders(pids)
    }

    // MARK: - Persistence

    private func persistEnabledFlags(_ pids: [OBDPID]) {
        let map = Dictionary(uniqueKeysWithValues:
            pids.map { ($0.pid.properties.command, $0.enabled) }
        )
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: Self.enabledKey)
        }
    }

    private func persistGaugeOrders(_ pids: [OBDPID]) {
        let enabled = pids
            .filter { $0.kind == .gauge && $0.enabled }
            .map { $0.pid.properties.command }

        let disabled = pids
            .filter { $0.kind == .gauge && !$0.enabled }
            .map { $0.pid.properties.command }

        if let e = try? JSONEncoder().encode(enabled) {
            UserDefaults.standard.set(e, forKey: Self.enabledGaugesOrderKey)
        }
        if let d = try? JSONEncoder().encode(disabled) {
            UserDefaults.standard.set(d, forKey: Self.disabledGaugesOrderKey)
        }
    }

    // MARK: - Helpers (Pure Functions)

    private static func loadOrder(forKey key: String) -> [String]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    /// Applies saved ordering to the gauge subsets only.
    private static func applySavedOrdering(
        to pids: [OBDPID],
        enabledOrder:  [String]?,
        disabledOrder: [String]?
    ) -> [OBDPID] {

        var enabled  = pids.filter { $0.kind == .gauge && $0.enabled }
        var disabled = pids.filter { $0.kind == .gauge && !$0.enabled }
        let others   = pids.filter { $0.kind != .gauge }

        if let eo = enabledOrder {
            reorder(&enabled, using: eo)
        }
        if let doo = disabledOrder {
            reorder(&disabled, using: doo)
        }

        return enabled + disabled + others
    }

    /// Sorts an array of PIDs in-place based on a saved list of command strings.
    private static func reorder(_ array: inout [OBDPID], using order: [String]) {
        let indexMap = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })

        array.sort { lhs, rhs in
            let l = indexMap[lhs.pid.properties.command]
            let r = indexMap[rhs.pid.properties.command]

            switch (l, r) {
            case let (li?, ri?): return li < ri
            case (_?, nil):      return true
            case (nil, _?):      return false
            case (nil, nil):     return false
            }
        }
    }

    /// Returns the master list reordered using the invariant:
    ///   enabled gauges → disabled gauges → non-gauges
    private static func reordered(_ pids: [OBDPID]) -> [OBDPID] {
        let enabled  = pids.filter { $0.kind == .gauge && $0.enabled }
        let disabled = pids.filter { $0.kind == .gauge && !$0.enabled }
        let others   = pids.filter { $0.kind != .gauge }
        return enabled + disabled + others
    }
}
