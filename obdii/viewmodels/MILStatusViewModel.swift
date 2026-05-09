import Combine
/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewModel for MIL (Malfunction Indicator Lamp) status
 *
 * Subscribes to OBDConnectionManager for MIL/Check Engine Light status updates.
 * Provides formatted header text, readiness monitor sorting by ready/not ready,
 * and handles nil vs populated states. Inherits from BaseViewModel for CarPlay
 * integration.
 */
import Foundation
import Observation
import SwiftOBD2

@MainActor
protocol MILStatusProviding {
  var milStatusPublisher: AnyPublisher<Status?, Never> { get }
}

extension OBDConnectionManager: MILStatusProviding {
  var milStatusPublisher: AnyPublisher<Status?, Never> {
    $milStatus.eraseToAnyPublisher()
  }
}

@MainActor
@Observable
final class MILStatusViewModel: BaseViewModel {

  struct SummaryRow: Equatable {
    let symbolName: String
    let symbolColor: String
    let text: String
  }

  struct MonitorRow: Identifiable, Equatable {
    let id: String
    let name: String
    let readyText: String
    let symbolName: String
    let symbolColor: String
    let accessibilityLabel: String
  }

  private let provider: MILStatusProviding
  private let interestRegistry: PIDInterestManaging
  private let interestToken: UUID

  private(set) var status: Status? {
    didSet {
      if oldValue != status {
        onChanged?()
      }
    }
  }

  private var cancellables = Set<AnyCancellable>()

  init(
    provider: MILStatusProviding,
    interestRegistry: PIDInterestManaging? = nil
  ) {
    self.provider = provider
    let interestRegistry = interestRegistry ?? PIDInterestRegistry.shared
    self.interestRegistry = interestRegistry
    self.interestToken = interestRegistry.makeToken()
    super.init()

    provider.milStatusPublisher
      .removeDuplicates()
      .sink { [unowned self] newValue in
        self.status = newValue
      }
      .store(in: &cancellables)
  }

  @MainActor
  override convenience init() {
    self.init(provider: OBDConnectionManager.shared)
  }

  var isWaiting: Bool {
    status == nil
  }

  var headerText: String {
    guard let status else { return "No MIL Status" }
    let dtcLabel = status.dtcCount == 1 ? "1 DTC" : "\(status.dtcCount) DTCs"
    return "MIL: \(status.milOn ? "On" : "Off") (\(dtcLabel))"
  }

  var hasStatus: Bool {
    status != nil
  }

  var summaryRow: SummaryRow? {
    guard let status else { return nil }
    return SummaryRow(
      symbolName: "wrench.and.screwdriver",
      symbolColor: status.milOn ? "orange" : "blue",
      text: headerText
    )
  }

  var sortedSupportedMonitors: [ReadinessMonitor] {
    guard let status else { return [] }

    let supported = status.monitors.filter { $0.supported }

    return supported.sorted { lhs, rhs in
      // 1. Not Ready → 2. Ready → 3. Unknown
      func readinessPriority(_ ready: Bool?) -> Int {
        switch ready {
        case .some(false): return 0
        case .some(true): return 1
        case .none: return 2
        }
      }

      let lp = readinessPriority(lhs.ready)
      let rp = readinessPriority(rhs.ready)

      if lp != rp { return lp < rp }

      // Tie-break alphabetically
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
  }

  var monitorRows: [MonitorRow] {
    sortedSupportedMonitors.map {
      MonitorRow(
        id: $0.name,
        name: $0.name,
        readyText: $0.ready ? "Ready" : "Not Ready",
        symbolName: "gauge",
        symbolColor: $0.ready ? "blue" : "orange",
        accessibilityLabel: "\($0.name), \($0.ready ? "Ready" : "Not Ready")"
      )
    }
  }

  func onAppear() {
    interestRegistry.replace(pids: [.mode1(.status)], for: interestToken)
  }

  func onDisappear() {
    interestRegistry.clear(token: interestToken)
  }
}
