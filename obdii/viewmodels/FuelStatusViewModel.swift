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

  private let provider: FuelStatusProviding
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
  init(provider: FuelStatusProviding) {
    self.provider = provider
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
  // Fuel system status for Bank 1
  var bank1: StatusCodeMetadata? {
    status?[safe: 0] ?? nil
  }
  // Fuel system status for Bank 2
  var bank2: StatusCodeMetadata? {
    status?[safe: 1] ?? nil
  }
  // True if any bank contains a non-nil status value
  var hasAnyStatus: Bool {
    guard let status else { return false }
    return status.contains { $0 != nil }
  }
}

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
