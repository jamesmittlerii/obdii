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

  struct CodeRow: Identifiable, Equatable {
    let id: String
    let title: String
    let severityText: String
    let symbolName: String
    let detailViewModel: DTCDetailViewModel

    static func == (lhs: CodeRow, rhs: CodeRow) -> Bool {
      lhs.id == rhs.id
        && lhs.title == rhs.title
        && lhs.severityText == rhs.severityText
        && lhs.symbolName == rhs.symbolName
    }
  }

  struct Section: Equatable {
    let title: String
    let severity: CodeSeverity
    let items: [CodeRow]

    init(title: String, severity: CodeSeverity, items: [CodeRow]) {
      self.title = title
      self.severity = severity
      self.items = items
    }

    init(title: String, severity: CodeSeverity, items: [TroubleCodeMetadata]) {
      self.title = title
      self.severity = severity
      self.items = items.map {
        let symbolName: String
        switch $0.severity {
        case .low: symbolName = "exclamationmark.circle"
        case .moderate: symbolName = "exclamationmark.triangle"
        case .high: symbolName = "bolt.trianglebadge.exclamationmark"
        case .critical: symbolName = "xmark.octagon"
        }
        return CodeRow(
          id: $0.code,
          title: "\($0.code) • \($0.title)",
          severityText: $0.severity.rawValue,
          symbolName: symbolName,
          detailViewModel: DTCDetailViewModel(code: $0)
        )
      }
    }
  }

  private let provider: DiagnosticsProviding
  private let interestRegistry: PIDInterestManaging
  private let interestToken: UUID

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
  init(
    provider: DiagnosticsProviding,
    interestRegistry: PIDInterestManaging? = nil
  ) {
    self.provider = provider
    let interestRegistry = interestRegistry ?? PIDInterestRegistry.shared
    self.interestRegistry = interestRegistry
    self.interestToken = interestRegistry.makeToken()
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

  var isWaiting: Bool {
    codes == nil
  }

  var isEmpty: Bool {
    codes != nil && sections.isEmpty
  }

  func onAppear() {
    interestRegistry.replace(pids: [.mode3(.GET_DTC)], for: interestToken)
  }

  func onDisappear() {
    interestRegistry.clear(token: interestToken)
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
        items: list.map {
          CodeRow(
            id: $0.code,
            title: "\($0.code) • \($0.title)",
            severityText: $0.severity.rawValue,
            symbolName: symbolName(for: $0.severity),
            detailViewModel: DTCDetailViewModel(code: $0)
          )
        }
      )
    }
  }

  private func symbolName(for severity: CodeSeverity) -> String {
    switch severity {
    case .low: "exclamationmark.circle"
    case .moderate: "exclamationmark.triangle"
    case .high: "bolt.trianglebadge.exclamationmark"
    case .critical: "xmark.octagon"
    }
  }
}

@Observable
final class DTCDetailViewModel {
  struct OverviewItem: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
  }

  let code: TroubleCodeMetadata

  init(code: TroubleCodeMetadata) {
    self.code = code
  }

  var navigationTitle: String { code.code }
  var overviewItems: [OverviewItem] {
    [
      OverviewItem(id: "code", label: "Code", value: code.code),
      OverviewItem(id: "title", label: "Title", value: code.title),
      OverviewItem(id: "severity", label: "Severity", value: code.severity.rawValue),
    ]
  }
  var descriptionText: String { code.description }
  var causes: [String] { code.causes }
  var remedies: [String] { code.remedies }
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
