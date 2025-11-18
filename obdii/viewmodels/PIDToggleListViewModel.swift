/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
View Model for showing and updating the selected PIDs. Used by SwiftUI
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import Foundation
import Observation
import SwiftOBD2

@MainActor
@Observable
final class PIDToggleListViewModel {
    // Mirror of the store PIDs for simple view binding (derived from store)
    // Keep a local cache if you want to avoid recomputing filters frequently
    var pids: [OBDPID] = []

    // Search text for filtering
    var searchText: String = ""

    private let store: PIDStore

    // Designated initializer without default argument to avoid nonisolated default evaluation
    init() {
        self.store = PIDStore.shared
        // Initialize local mirror
        self.pids = store.pids
    }

    

    // Computed helpers for sections
    var enabledIndices: [Int] {
        pids.indices.filter { pids[$0].enabled && pids[$0].kind == .gauge }
    }

    var disabledIndices: [Int] {
        pids.indices.filter { !pids[$0].enabled && pids[$0].kind == .gauge }
    }

    // Filtered projections for the view
    var filteredEnabled: [OBDPID] {
        // Keep our mirror in sync with the store when accessed
        syncFromStore()
        let base = pids.filter { $0.enabled && $0.kind == .gauge }
        let q = normalizedQuery
        guard !q.isEmpty else { return base }
        return base.filter { matchesQuery($0, q) }
    }

    var filteredDisabled: [OBDPID] {
        // Keep our mirror in sync with the store when accessed
        syncFromStore()
        let base = pids.filter { !$0.enabled && $0.kind == .gauge }
        let q = normalizedQuery
        guard !q.isEmpty else { return base }
        return base.filter { matchesQuery($0, q) }
    }

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func matchesQuery(_ pid: OBDPID, _ q: String) -> Bool {
        if q.isEmpty { return true }
        // Search label, name, notes, and command string if available
        if pid.label.lowercased().contains(q) { return true }
        if pid.name.lowercased().contains(q) { return true }
        if let notes = pid.notes?.lowercased(), notes.contains(q) { return true }
        let command = pid.pid.properties.command.lowercased()
        if command.contains(q) { return true }
        return false
    }

    // Intents
    func toggle(at index: Int, to isOn: Bool) {
        // Ensure mirror is current and validate index after syncing
        syncFromStore()
        guard pids.indices.contains(index) else { return }

        let pid = pids[index]

        // Only flip if the desired state differs from current
        if pid.enabled != isOn {
            store.toggle(pid)
            // Update local mirror after mutation
            pids = store.pids
        }
    }

    // we allow reordering so send that back to the store to handle
    func moveEnabled(fromOffsets indices: IndexSet, toOffset newOffset: Int) {
        // Ensure mirror is current
        syncFromStore()
        store.moveEnabled(fromOffsets: indices, toOffset: newOffset)
        // Update local mirror after mutation
        pids = store.pids
    }

    // Keep our local pids in sync with the store when accessed
    private func syncFromStore() {
        if pids != store.pids {
            pids = store.pids
        }
    }
}
