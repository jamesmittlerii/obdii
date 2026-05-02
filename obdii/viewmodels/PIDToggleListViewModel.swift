import Combine
/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewModel for PID toggle/reorder list
 *
 * Mirrors PIDStore's PIDs for UI display, supports search filtering by label,
 * name, notes, and command. Provides filtered enabled/disabled lists for
 * sections. Delegates toggle and reordering actions to PIDStore while keeping
 * local mirror synchronized.
 */
import Foundation
import Observation
import SwiftOBD2
import SwiftUI

@MainActor
protocol PIDStoreProviding: AnyObject {
  var pids: [OBDPID] { get }
  var pidsPublisher: AnyPublisher<[OBDPID], Never> { get }
  func toggle(_ pid: OBDPID)
  func moveEnabled(fromOffsets offsets: IndexSet, toOffset newOffset: Int)
}

extension PIDStore: PIDStoreProviding {}

@MainActor
@Observable
final class PIDToggleListViewModel {
  struct Row: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let isOn: Bool
    let accessibilityIdentifier: String
  }

  // Local mirror of the store’s PID list (copied for sorting/filtering UI).
  private(set) var pids: [OBDPID] = []
  // Raw search string from the UI.
  var searchText: String = ""

  private let store: PIDStoreProviding
  private var cancellables = Set<AnyCancellable>()

  init(store: PIDStoreProviding? = nil) {
    let store = store ?? PIDStore.shared
    self.store = store
    self.pids = store.pids  // seed mirror

    // Keep local mirror in sync with the store without mutating during view computation
    store.pidsPublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] in self?.pids = $0 }
      .store(in: &cancellables)
  }

  var enabledIndices: [Int] {
    pids.indices.filter { pids[$0].enabled && pids[$0].kind == .gauge }
  }

  var disabledIndices: [Int] {
    pids.indices.filter { !pids[$0].enabled && pids[$0].kind == .gauge }
  }

  var filteredEnabled: [OBDPID] {
    let base = pids.filter { $0.enabled && $0.kind == .gauge }
    return applySearch(base)
  }

  var filteredDisabled: [OBDPID] {
    let base = pids.filter { !$0.enabled && $0.kind == .gauge }
    return applySearch(base)
  }

  var enabledRows: [Row] {
    filteredEnabled.map(makeRow)
  }

  var disabledRows: [Row] {
    filteredDisabled.map(makeRow)
  }

  var isSearchActive: Bool {
    !searchText.isEmpty
  }

  var emptySearchMessage: String? {
    guard enabledRows.isEmpty && disabledRows.isEmpty && isSearchActive else { return nil }
    return "No results for “\(searchText)”"
  }

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

  func toggle(at index: Int, to isOn: Bool) {
    guard pids.indices.contains(index) else { return }
    let pid = pids[index]
    guard pid.enabled != isOn else { return }
    store.toggle(pid)  // subscription will update pids
  }

  func moveEnabled(fromOffsets offsets: IndexSet, toOffset newOffset: Int) {
    store.moveEnabled(fromOffsets: offsets, toOffset: newOffset)  // subscription will update pids
  }

  func binding(for rowID: UUID) -> Binding<Bool> {
    Binding(
      get: {
        self.pids.first(where: { $0.id == rowID })?.enabled ?? false
      },
      set: { newValue in
        if let index = self.pids.firstIndex(where: { $0.id == rowID }) {
          self.toggle(at: index, to: newValue)
        }
      }
    )
  }

  private func makeRow(_ pid: OBDPID) -> Row {
    Row(
      id: pid.id,
      title: pid.name,
      subtitle: pid.displayRange,
      isOn: pid.enabled,
      accessibilityIdentifier: "PIDToggle_\(pid.id.uuidString)"
    )
  }
}
