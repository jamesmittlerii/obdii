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
import Combine
import SwiftOBD2

@MainActor
final class PIDToggleListViewModel: ObservableObject {
    // Mirror of the store PIDs for simple view binding
    @Published private(set) var pids: [OBDPID] = []

    // Search text for filtering
    @Published var searchText: String = ""

    private let store: PIDStore
    private var cancellables = Set<AnyCancellable>()

    // Designated initializer without default argument to avoid nonisolated default evaluation
    init(store: PIDStore) {
        self.store = store

        // Keep local pids in sync with the store, and log enabled names
        store.$pids
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .assign(to: &$pids)
    }

    // Convenience initializer accessing MainActor-isolated singleton safely
    convenience init() {
        self.init(store: .shared)
    }

    // Computed helpers for sections
    var enabledIndices: [Int] {
        return pids.indices.filter { pids[$0].enabled && pids[$0].kind == .gauge }
        
    }

    var disabledIndices: [Int] {
        pids.indices.filter { !pids[$0].enabled && pids[$0].kind == .gauge }
    }

    // Filtered projections for the view
    var filteredEnabled: [OBDPID] {
        let base = pids.filter { $0.enabled && $0.kind == .gauge }
        let q = normalizedQuery
        guard !q.isEmpty else { return base }
        return base.filter { matchesQuery($0, q) }
    }

    var filteredDisabled: [OBDPID] {
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
        store.toggle(pids[index])
    }

    // we allow reordering so send that back to the store to handle
    func moveEnabled(fromOffsets indices: IndexSet, toOffset newOffset: Int) {
        
        store.moveEnabled(fromOffsets: indices, toOffset: newOffset)
    }
}
