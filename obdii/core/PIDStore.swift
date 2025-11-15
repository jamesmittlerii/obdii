/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
These are the pids we are publishing
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import Foundation
import Combine

@MainActor
final class PIDStore: ObservableObject {
    static let shared = PIDStore()

    @Published var pids: [OBDPID]

    // Persist enabled flags keyed by the Mode1 command string (CommandProperties.command)
    private static let enabledKey = "PIDStore.enabledByCommand"

    // Persist the order of enabled and disabled gauges by their Mode1 command string
    private static let enabledGaugesOrderKey = "PIDStore.enabledGaugesOrder"
    private static let disabledGaugesOrderKey = "PIDStore.disabledGaugesOrder"

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Start from the library defaults
        var initial = OBDPIDLibrary.standard

        // Restore saved enabled flags keyed by command string
        if let data = UserDefaults.standard.data(forKey: PIDStore.enabledKey),
           let saved = try? JSONDecoder().decode([String: Bool].self, from: data) {
            for i in initial.indices {
                let commandKey = initial[i].pid.properties.command
                if let savedEnabled = saved[commandKey] {
                    initial[i].enabled = savedEnabled
                }
            }
        }

        // Restore gauges order for enabled and disabled subsets (non-gauges keep library order)
        let enabledOrder: [String]? = {
            if let data = UserDefaults.standard.data(forKey: PIDStore.enabledGaugesOrderKey),
               let list = try? JSONDecoder().decode([String].self, from: data) {
                return list
            }
            return nil
        }()

        let disabledOrder: [String]? = {
            if let data = UserDefaults.standard.data(forKey: PIDStore.disabledGaugesOrderKey),
               let list = try? JSONDecoder().decode([String].self, from: data) {
                return list
            }
            return nil
        }()

        if enabledOrder != nil || disabledOrder != nil {
            // Partition into enabled gauges, disabled gauges, and non-gauges preserving current relative order
            var enabledGauges = initial.filter { $0.kind == .gauge && $0.enabled }
            var disabledGauges = initial.filter { $0.kind == .gauge && !$0.enabled }
            let nonGauges = initial.filter { $0.kind != .gauge }

            // Helper to sort a PID array by a saved order of command strings
            func sortByOrder(_ array: inout [OBDPID], order: [String]) {
                let indexByCommand = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
                array.sort { lhs, rhs in
                    let l = indexByCommand[lhs.pid.properties.command]
                    let r = indexByCommand[rhs.pid.properties.command]
                    switch (l, r) {
                    case let (li?, ri?): return li < ri
                    case (_?, nil): return true
                    case (nil, _?): return false
                    case (nil, nil): return false
                    }
                }
            }

            if let eo = enabledOrder { sortByOrder(&enabledGauges, order: eo) }
            if let doo = disabledOrder { sortByOrder(&disabledGauges, order: doo) }

            // Reassemble master list: enabled gauges, then disabled gauges, then non-gauges
            initial = enabledGauges + disabledGauges + nonGauges
        }

        self.pids = initial

        // Observe changes and persist enabled flags and orders
        $pids
            .sink { [weak self] (pids: [OBDPID]) in
                guard let self else { return }
                self.persistEnabledFlags(pids)
                self.persistGaugeOrders(pids)
            }
            .store(in: &cancellables)
    }

    //  Public API

    func toggle(_ pid: OBDPID) {
        // 1. Ensure the PID exists in the array and get its index
        guard let index = pids.firstIndex(where: { $0.id == pid.id }) else {
            return
        }
        
        // 2. Create a mutable copy of the target PID and toggle its 'enabled' state
        var toggledPID = pid
        toggledPID.enabled.toggle()
        
        // 3. Replace the original element at the found index with the modified element
        pids[index] = toggledPID
        
        // Keep invariant: enabled gauges first, then disabled gauges, then non-gauges
        let enabledGauges = pids.filter { $0.kind == .gauge && $0.enabled }
        let disabledGauges = pids.filter { $0.kind == .gauge && !$0.enabled }
        let nonGauges = pids.filter { $0.kind != .gauge }
        pids = enabledGauges + disabledGauges + nonGauges
    }

    var enabledGauges: [OBDPID] {
        pids.filter { $0.enabled && $0.kind == .gauge }
    }

    /// Reorder within the enabled gauges subset (matches UI section).
    func moveEnabled(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Extract master indices of enabled gauges
        let enabledGaugeIndicesInMaster: [Int] = pids.indices.filter { pids[$0].enabled && pids[$0].kind == .gauge }
        guard !enabledGaugeIndicesInMaster.isEmpty else { return }

        // Build subset and move
        var enabledGaugesArray: [OBDPID] = enabledGaugeIndicesInMaster.map { pids[$0] }

        enabledGaugesArray.move(fromOffsets: source, toOffset: destination)

        // Write back moved gauges into original master positions
        var newPIDs = pids
        for (i, masterIndex) in enabledGaugeIndicesInMaster.enumerated() {
            newPIDs[masterIndex] = enabledGaugesArray[i]
        }
        pids = newPIDs
    }

    //  Persistence

    private func persistEnabledFlags(_ pids: [OBDPID]) {
        // Key by the stable Mode1 command string
        let map: [String: Bool] = Dictionary(
            uniqueKeysWithValues: pids.map { ($0.pid.properties.command, $0.enabled) }
        )
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: PIDStore.enabledKey)
        }
    }

    // Save orders for both enabled and disabled gauges
    private func persistGaugeOrders(_ pids: [OBDPID]) {
        let enabledGaugeCommands = pids.filter { $0.kind == .gauge && $0.enabled }.map { $0.pid.properties.command }
        let disabledGaugeCommands = pids.filter { $0.kind == .gauge && !$0.enabled }.map { $0.pid.properties.command }

        if let data = try? JSONEncoder().encode(enabledGaugeCommands) {
            UserDefaults.standard.set(data, forKey: PIDStore.enabledGaugesOrderKey)
        }
        if let data = try? JSONEncoder().encode(disabledGaugeCommands) {
            UserDefaults.standard.set(data, forKey: PIDStore.disabledGaugesOrderKey)
        }
    }
}
