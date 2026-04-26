import Combine
/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * PID storage and ordering manager singleton
 *
 * Loads all PIDs from JSON, manages enabled/disabled state, and persists
 * user preferences including gauge ordering. Supports drag-and-drop reordering
 * of enabled gauges. Maintains separate ordering for enabled and disabled gauges.
 * Uses UserDefaults for persistent storage across app sessions.
 */
import Foundation

@MainActor
final class PIDStore: ObservableObject {

  static let shared = PIDStore()

  @Published private(set) var pids: [OBDPID]

  private static let enabledKey = "PIDStore.enabledByCommand"
  private static let enabledGaugesOrderKey = "PIDStore.enabledGaugesOrder"
  private static let disabledGaugesOrderKey = "PIDStore.disabledGaugesOrder"

  private init() {
    let all = Self.loadMergedPIDsFromDefaults()
    self.pids = all
    persistEnabledFlags(pids)
    persistGaugeOrders(pids)
  }

  /// Reloads gauge enablement and ordering from `UserDefaults` (Swift `Data` or Flutter `String` JSON).
  func reloadFromUserDefaults() {
    let all = Self.loadMergedPIDsFromDefaults()
    pids = all
    persistEnabledFlags(pids)
    persistGaugeOrders(pids)
  }

  /// Builds the master PID list from JSON plus saved flags/order. Accepts Swift-written `Data` or Flutter `SharedPreferences` UTF-8 strings.
  private static func loadMergedPIDsFromDefaults() -> [OBDPID] {
    var all = OBDPIDLibrary.loadFromJSON()

    if let saved = decodeStringBoolMap(forKey: Self.enabledKey) {
      for i in all.indices {
        let command = all[i].pid.properties.command
        if let enabledFlag = saved[command] {
          all[i].enabled = enabledFlag
        }
      }
    }

    let savedEnabledOrder = loadOrder(forKey: Self.enabledGaugesOrderKey)
    let savedDisabledOrder = loadOrder(forKey: Self.disabledGaugesOrderKey)

    if savedEnabledOrder != nil || savedDisabledOrder != nil {
      all = Self.applySavedOrdering(
        to: all,
        enabledOrder: savedEnabledOrder,
        disabledOrder: savedDisabledOrder
      )
    }

    return all
  }

  private static func decodeStringBoolMap(forKey key: String) -> [String: Bool]? {
    let defaults = UserDefaults.standard
    if let data = defaults.data(forKey: key),
      let saved = try? JSONDecoder().decode([String: Bool].self, from: data)
    {
      return saved
    }
    if let str = defaults.string(forKey: key),
      let data = str.data(using: .utf8),
      let saved = try? JSONDecoder().decode([String: Bool].self, from: data)
    {
      return saved
    }
    return nil
  }

  // toggle enabled/disabled
  func toggle(_ pid: OBDPID) {
    guard let idx = pids.firstIndex(where: { $0.id == pid.id }) else { return }

    var new = pid
    new.enabled.toggle()
    pids[idx] = new

    pids = Self.reordered(pids)

    persistEnabledFlags(pids)
    persistGaugeOrders(pids)
  }
    
  // Returns all enabled gauge PIDs in their current user-defined order.
  var enabledGauges: [OBDPID] {
    pids.filter { $0.kind == .gauge && $0.enabled }
  }
    
  // Reorder the *enabled* gauges section.
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

    // save which pids are enabled
  private func persistEnabledFlags(_ pids: [OBDPID]) {
    let map = Dictionary(
      uniqueKeysWithValues:
        pids.map { ($0.pid.properties.command, $0.enabled) }
    )
    if let data = try? JSONEncoder().encode(map) {
      UserDefaults.standard.set(data, forKey: Self.enabledKey)
    }
  }

    // save the order of our gauges
  private func persistGaugeOrders(_ pids: [OBDPID]) {
    let enabled =
      pids
      .filter { $0.kind == .gauge && $0.enabled }
      .map { $0.pid.properties.command }

    let disabled =
      pids
      .filter { $0.kind == .gauge && !$0.enabled }
      .map { $0.pid.properties.command }

    if let e = try? JSONEncoder().encode(enabled) {
      UserDefaults.standard.set(e, forKey: Self.enabledGaugesOrderKey)
    }
    if let d = try? JSONEncoder().encode(disabled) {
      UserDefaults.standard.set(d, forKey: Self.disabledGaugesOrderKey)
    }
  }

    // load the order of gauges (Swift `Data` JSON or Flutter UTF-8 string JSON)
  private static func loadOrder(forKey key: String) -> [String]? {
    let defaults = UserDefaults.standard
    if let data = defaults.data(forKey: key),
      let order = try? JSONDecoder().decode([String].self, from: data)
    {
      return order
    }
    if let str = defaults.string(forKey: key),
      let data = str.data(using: .utf8),
      let order = try? JSONDecoder().decode([String].self, from: data)
    {
      return order
    }
    return nil
  }
  // Applies saved ordering to the gauge subsets only.
  private static func applySavedOrdering(
    to pids: [OBDPID],
    enabledOrder: [String]?,
    disabledOrder: [String]?
  ) -> [OBDPID] {

    var enabled = pids.filter { $0.kind == .gauge && $0.enabled }
    var disabled = pids.filter { $0.kind == .gauge && !$0.enabled }
    let others = pids.filter { $0.kind != .gauge }

    if let eo = enabledOrder {
      reorder(&enabled, using: eo)
    }
    if let doo = disabledOrder {
      reorder(&disabled, using: doo)
    }

    return enabled + disabled + others
  }
    
  // Sorts an array of PIDs in-place based on a saved list of command strings.
  private static func reorder(_ array: inout [OBDPID], using order: [String]) {
    let indexMap = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })

    array.sort { lhs, rhs in
      let l = indexMap[lhs.pid.properties.command]
      let r = indexMap[rhs.pid.properties.command]

      switch (l, r) {
      case (let li?, let ri?): return li < ri
      case (_?, nil): return true
      case (nil, _?): return false
      case (nil, nil): return false
      }
    }
  }
  // Returns the master list reordered using the invariant:
  //  enabled gauges → disabled gauges → non-gauges
  private static func reordered(_ pids: [OBDPID]) -> [OBDPID] {
    let enabled = pids.filter { $0.kind == .gauge && $0.enabled }
    let disabled = pids.filter { $0.kind == .gauge && !$0.enabled }
    let others = pids.filter { $0.kind != .gauge }
    return enabled + disabled + others
  }
}
