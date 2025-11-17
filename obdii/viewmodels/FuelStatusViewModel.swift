/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
View Model for showing the Fuel/O2 sensor statuses. Used by CarPlay and SwiftUI
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import Combine
import SwiftOBD2
import Foundation
import Observation

@MainActor
@Observable
final class FuelStatusViewModel : BaseViewModel{
    // Callback for controllers (CarPlay, etc.) to observe changes, mirroring DiagnosticsViewModel
    //var onChanged: (() -> Void)?

    // Optional container:
    // nil = not yet received any data
    // [] or only nils = received, but effectively empty
    private(set) var status: [StatusCodeMetadata?]? = nil {
        didSet {
            // Notify observers when the status array changes
            onChanged?()
        }
    }

    private var cancellable: AnyCancellable?

    override init() {
        super.init()
        let manager = OBDConnectionManager.shared
        cancellable = manager.$fuelStatus
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.status = newValue
            }
    }

    var bank1: StatusCodeMetadata? {
        guard let status, status.indices.contains(0) else { return nil }
        return status[0]
    }

    var bank2: StatusCodeMetadata? {
        guard let status, status.indices.contains(1) else { return nil }
        return status[1]
    }

    var hasAnyStatus: Bool {
        guard let status else { return false } // treat "not yet received" as no status for this flag
        return status.contains { $0 != nil }
    }
}

