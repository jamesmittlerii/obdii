/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
View Model for showing the Diagnostic Trouble Codes. Used by CarPlay and SwiftUI
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */


import Foundation
import Combine
import SwiftOBD2
import Observation

@MainActor
@Observable
final class DiagnosticsViewModel : BaseViewModel{
    struct Section: Equatable {
        let title: String
        let severity: CodeSeverity
        let items: [TroubleCodeMetadata]
    }

    // Optional source mirror: nil = waiting, [] = loaded but empty
    private(set) var codes: [TroubleCodeMetadata]? = nil

    private(set) var sections: [Section] = [] {
        didSet {
            if oldValue != sections {
                onChanged?()
            }
        }
    }
    private(set) var isEmpty: Bool = true

    private var cancellable: AnyCancellable?

    override init() {
        super.init()

        let manager = OBDConnectionManager.shared
        cancellable = manager.$troubleCodes
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] codes in
                guard let self else { return }
                self.codes = codes
                self.rebuildSections(from: codes)
            }
    }

    private func rebuildSections(from codes: [TroubleCodeMetadata]?) {
        // Waiting state
        guard let codes = codes else {
            sections = []
            isEmpty = false // Not "empty" yet; we're waiting
            return
        }

        // Loaded: empty payload
        guard !codes.isEmpty else {
            sections = []
            isEmpty = true
            return
        }

        let grouped = Dictionary(grouping: codes, by: { $0.severity })
        let order: [CodeSeverity] = [.critical, .high, .moderate, .low]

        sections = order.compactMap { severity in
            guard let list = grouped[severity], !list.isEmpty else { return nil }
            return Section(
                title: title(for: severity),
                severity: severity,
                items: list
            )
        }
        isEmpty = sections.isEmpty
    }

    private func title(for severity: CodeSeverity) -> String {
        switch severity {
        case .critical: return "Critical"
        case .high:     return "High"
        case .moderate: return "Moderate"
        case .low:      return "Low"
        }
    }
}

