/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewModel for diagnostic trouble codes display
 *
 * Subscribes to OBDConnectionManager for DTC updates and organizes them
 * into severity-based sections (Critical, High, Moderate, Low).
 * Handles waiting state (nil) vs loaded state (possibly empty array).
 * Inherits from BaseViewModel for CarPlay integration.
 */
import Foundation
import Combine
import SwiftOBD2
import Observation

@MainActor
@Observable
final class DiagnosticsViewModel: BaseViewModel {

    struct Section: Equatable {
        let title: String
        let severity: CodeSeverity
        let items: [TroubleCodeMetadata]
    }

    // MARK: - Published State

    private(set) var codes: [TroubleCodeMetadata]? = nil {
        didSet {
            if oldValue != codes {
                onChanged?()
            }
        }
    }
    private(set) var sections: [Section] = []
    private(set) var isEmpty: Bool = true

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    override init() {
        super.init()

        OBDConnectionManager.shared.$troubleCodes
            .removeDuplicates()
            .sink { [unowned self] codes in
                self.rebuildSections(from: codes)
                self.codes = codes
                
            }
            .store(in: &cancellables)
    }

    // MARK: - Section Construction

    private func rebuildSections(from codes: [TroubleCodeMetadata]?) {

        // Waiting for initial data
        guard let codes = codes else {
            sections = []
            isEmpty = false
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

        let builtSections = order.compactMap { severity -> Section? in
            guard let list = grouped[severity], !list.isEmpty else { return nil }
            return Section(
                title: severity.displayTitle,
                severity: severity,
                items: list
            )
        }

        sections = builtSections
        isEmpty = builtSections.isEmpty
    }
}

// MARK: - CodeSeverity → Display Logic

private extension CodeSeverity {
    var displayTitle: String {
        switch self {
        case .critical: return "Critical"
        case .high:     return "High"
        case .moderate: return "Moderate"
        case .low:      return "Low"
        }
    }
}
