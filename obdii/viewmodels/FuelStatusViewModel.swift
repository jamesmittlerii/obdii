/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewModel for fuel system status display
 *
 * Subscribes to OBDConnectionManager for fuel status updates covering Bank 1
 * and Bank 2. Provides accessors for each bank and checks if any status exists.
 * Handles nil (waiting), empty, and populated states. Inherits from BaseViewModel
 * for CarPlay integration.
 */
import Combine
import Foundation
import Observation
import SwiftOBD2

@MainActor
protocol FuelStatusProviding {
  var fuelStatusPublisher: AnyPublisher<[StatusCodeMetadata?]?, Never> { get }
}

extension OBDConnectionManager: FuelStatusProviding {
  var fuelStatusPublisher: AnyPublisher<[StatusCodeMetadata?]?, Never> {
    $fuelStatus.eraseToAnyPublisher()
  }
}

@MainActor
@Observable
final class FuelStatusViewModel: BaseViewModel {

  struct BankRow: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let accessibilityLabel: String
  }

  private let provider: FuelStatusProviding
  private let interestRegistry: PIDInterestManaging
  private let interestToken: UUID
  // nil = waiting for first update
  // non-nil = data received (may contain nils for missing banks)
  private(set) var status: [StatusCodeMetadata?]? = nil {
    didSet {
      if oldValue != status {  // avoid duplicate updates
        onChanged?()
      }
    }
  }

  private var cancellables = Set<AnyCancellable>()

  // Designated initializer without default argument (nonisolated-safe)
  init(
    provider: FuelStatusProviding,
    interestRegistry: PIDInterestManaging? = nil
  ) {
    self.provider = provider
    let interestRegistry = interestRegistry ?? PIDInterestRegistry.shared
    self.interestRegistry = interestRegistry
    self.interestToken = interestRegistry.makeToken()
    super.init()

    provider.fuelStatusPublisher
      .removeDuplicates()
      .sink { [unowned self] newValue in
        self.status = newValue
      }
      .store(in: &cancellables)
  }

  // Convenience initializer that supplies the main-actor-isolated singleton
  @MainActor
  override convenience init() {
    self.init(provider: OBDConnectionManager.shared)
  }

  var isWaiting: Bool { status == nil }
  var bank1: StatusCodeMetadata? { status?[safe: 0] ?? nil }
  var bank2: StatusCodeMetadata? { status?[safe: 1] ?? nil }
  var bankRows: [BankRow] {
    [
      bank1.map {
        BankRow(id: "bank1", title: "Bank 1", description: $0.description, accessibilityLabel: "Bank 1, \($0.description)")
      },
      bank2.map {
        BankRow(id: "bank2", title: "Bank 2", description: $0.description, accessibilityLabel: "Bank 2, \($0.description)")
      },
    ].compactMap { $0 }
  }

  func onAppear() {
    interestRegistry.replace(pids: [.mode1(.fuelStatus)], for: interestToken)
  }

  func onDisappear() {
    interestRegistry.clear(token: interestToken)
  }

  // True if any bank contains a non-nil status value
  var hasAnyStatus: Bool {
    !bankRows.isEmpty
  }
}

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
