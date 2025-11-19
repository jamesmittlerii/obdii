import Foundation
import Observation
import SwiftOBD2

@MainActor
@Observable
final class PIDToggleListViewModel {

    // MARK: - Published State

    /// Local mirror of the store’s PID list (copied for sorting/filtering UI).
    private(set) var pids: [OBDPID] = []

    /// Raw search string from the UI.
    var searchText: String = ""

    // MARK: - Dependencies

    private let store: PIDStore

    // MARK: - Init

    init() {
        self.store = .shared
        self.pids = store.pids      // seed mirror
    }

    // MARK: - Section Helpers

    var enabledIndices: [Int] {
        pids.indices.filter { pids[$0].enabled && pids[$0].kind == .gauge }
    }

    var disabledIndices: [Int] {
        pids.indices.filter { !pids[$0].enabled && pids[$0].kind == .gauge }
    }

    // MARK: - Filtered Lists for UI

    var filteredEnabled: [OBDPID] {
        syncFromStore()
        let base = pids.filter { $0.enabled && $0.kind == .gauge }
        return applySearch(base)
    }

    var filteredDisabled: [OBDPID] {
        syncFromStore()
        let base = pids.filter { !$0.enabled && $0.kind == .gauge }
        return applySearch(base)
    }

    // MARK: - Search Helpers

    private var normalizedQuery: String {
        searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func applySearch(_ list: [OBDPID]) -> [OBDPID] {
        let q = normalizedQuery
        guard !q.isEmpty else { return list }
        return list.filter { matchesQuery($0, q) }
    }

    private func matchesQuery(_ pid: OBDPID, _ q: String) -> Bool {
        // Search label, name, notes, and PID command
        if pid.label.lowercased().contains(q) { return true }
        if pid.name.lowercased().contains(q) { return true }
        if pid.notes?.lowercased().contains(q) == true { return true }
        if pid.pid.properties.command.lowercased().contains(q) { return true }
        return false
    }

    // MARK: - Intents (User Actions)

    func toggle(at index: Int, to isOn: Bool) {
        syncFromStore()
        guard pids.indices.contains(index) else { return }

        let pid = pids[index]

        guard pid.enabled != isOn else { return }

        store.toggle(pid)
        pids = store.pids
    }

    func moveEnabled(fromOffsets offsets: IndexSet, toOffset newOffset: Int) {
        syncFromStore()
        store.moveEnabled(fromOffsets: offsets, toOffset: newOffset)
        pids = store.pids
    }

    // MARK: - Mirror Synchronization

    /// Refresh the local PID mirror when the store changes.
    private func syncFromStore() {
        if pids != store.pids {
            pids = store.pids
        }
    }
}
