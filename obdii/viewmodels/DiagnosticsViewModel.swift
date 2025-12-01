import Combine
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
import Observation
import SwiftOBD2

@MainActor
protocol DiagnosticsProviding {
  var diagnosticsPublisher: AnyPublisher<[TroubleCodeMetadata]?, Never> { get }
}

extension OBDConnectionManager: DiagnosticsProviding {
  var diagnosticsPublisher: AnyPublisher<[TroubleCodeMetadata]?, Never> {
    $troubleCodes.eraseToAnyPublisher()
  }
}

@MainActor
@Observable
final class DiagnosticsViewModel: BaseViewModel {

  struct Section: Equatable {
    let title: String
    let severity: CodeSeverity
    let items: [TroubleCodeMetadata]
  }

  private let provider: DiagnosticsProviding

  private(set) var codes: [TroubleCodeMetadata]? = nil {
    didSet {
      // Rebuild sections whenever codes changes
      rebuildSections(from: codes)
      if oldValue != codes {
        onChanged?()
      }
    }
  }
  private(set) var sections: [Section] = []

  private var cancellables = Set<AnyCancellable>()

  // Designated initializer without default argument (nonisolated-safe)
  init(provider: DiagnosticsProviding) {
    self.provider = provider
    super.init()

    provider.diagnosticsPublisher
      .removeDuplicates()
      .sink { [unowned self] newValue in
        self.codes = newValue
      }
      .store(in: &cancellables)
  }

  // Convenience initializer that supplies the main-actor-isolated singleton
  @MainActor
  override convenience init() {
    self.init(provider: OBDConnectionManager.shared)
  }

  private func rebuildSections(from codes: [TroubleCodeMetadata]?) {

    // Waiting for initial data
    guard let codes = codes else {
      sections = []
      return
    }

    // Loaded: empty payload
    guard !codes.isEmpty else {
      sections = []
      return
    }

    let grouped = Dictionary(grouping: codes, by: { $0.severity })
    let order: [CodeSeverity] = [.critical, .high, .moderate, .low]

    sections = order.compactMap { severity -> Section? in
      guard let list = grouped[severity], !list.isEmpty else { return nil }
      return Section(
        title: severity.displayTitle,
        severity: severity,
        items: list
      )
    }
  }
}

extension CodeSeverity {
  fileprivate var displayTitle: String {
    switch self {
    case .critical: return "Critical"
    case .high: return "High"
    case .moderate: return "Moderate"
    case .low: return "Low"
    }
  }
}
