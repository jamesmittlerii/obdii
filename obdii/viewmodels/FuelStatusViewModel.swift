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
import SwiftOBD2
import Foundation
import Observation

@MainActor
@Observable
final class FuelStatusViewModel: BaseViewModel {

    // MARK: - Published state
    
    /// nil = waiting for first update
    /// non-nil = data received (may contain nils for missing banks)
    private(set) var status: [StatusCodeMetadata?]? = nil {
        didSet {
            if oldValue != status {  // avoid duplicate updates
                onChanged?()
            }
        }
    }

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    override init() {
        super.init()

        OBDConnectionManager.shared.$fuelStatus
            .removeDuplicates()
            .sink { [unowned self] newValue in
                self.status = newValue
            }
            .store(in: &cancellables)
    }

    // MARK: - Accessors

    /// Fuel system status for Bank 1
    var bank1: StatusCodeMetadata? {
        status?[safe: 0] ?? nil
    }

    /// Fuel system status for Bank 2
    var bank2: StatusCodeMetadata? {
        status?[safe: 1] ?? nil
    }

    /// True if any bank contains a non-nil status value
    var hasAnyStatus: Bool {
        guard let status else { return false }
        return status.contains { $0 != nil }
    }
}

// MARK: - Safe indexing helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
