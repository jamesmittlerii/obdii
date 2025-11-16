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
final class FuelStatusViewModel {
    // Callback for controllers (CarPlay, etc.) to observe changes, mirroring DiagnosticsViewModel
    var onChanged: (() -> Void)?

    private(set) var status: [StatusCodeMetadata?] = [] {
        didSet {
            // Notify observers when the status array changes
            onChanged?()
        }
    }

    private var cancellable: AnyCancellable?

    init(connectionManager: OBDConnectionManager? = nil) {
        let manager = connectionManager ?? OBDConnectionManager.shared
        cancellable = manager.$fuelStatus
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.status = newValue
            }
    }

    var bank1: StatusCodeMetadata? { status.indices.contains(0) ? status[0] : nil }
    var bank2: StatusCodeMetadata? { status.indices.contains(1) ? status[1] : nil }
    var hasAnyStatus: Bool { bank1 != nil || bank2 != nil }
}
