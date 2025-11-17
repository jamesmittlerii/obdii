/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
View Model for displaying a single gauge..either graphically or in text detail. Used by CarPlay and SwiftUI
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import SwiftUI
import SwiftOBD2
import Combine
import Observation

@MainActor
@Observable
final class GaugeDetailViewModel : BaseViewModel{
    let pid: OBDPID
    private let connectionManager: OBDConnectionManager

    // Expose the live stats for this PID (SwiftUI observes via @Observable)
    private(set) var stats: OBDConnectionManager.PIDStats? {
        didSet {
            if oldValue != stats {
                onChanged?()
            }
        }
    }

    // Non-SwiftUI observation hook for controllers (CarPlay, etc.)
   // var onChanged: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()

    init(pid: OBDPID) {
        
        self.pid = pid
        self.connectionManager = OBDConnectionManager.shared

        // Seed with current value if available
        self.stats = connectionManager.stats(for: pid.pid)
        
        super.init()

        // Subscribe to pidStats and extract the one for our pid
        connectionManager.$pidStats
            .map { dict in
                dict[pid.pid]
            }
            .removeDuplicates(by: { lhs, rhs in
                // Shallow equality: compare latest value and sampleCount to reduce UI updates
                switch (lhs, rhs) {
                case (nil, nil):
                    return true
                case let (l?, r?):
                    return l.sampleCount == r.sampleCount && l.latest.value == r.latest.value && l.min == r.min && l.max == r.max
                default:
                    return false
                }
            })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.stats = newValue
            }
            .store(in: &cancellables)

        // Also listen to units changes so the view can re-render formatting even if stats didn’t change
        ConfigData.shared.$unitsPublished
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.stats = self.connectionManager.stats(for: self.pid.pid)
            }
            .store(in: &cancellables)
    }
}
