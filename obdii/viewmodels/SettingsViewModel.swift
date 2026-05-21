/**
 * __Final Project__
 * Jim Mittler
 * 30 November 2025
 *
 * ViewModel for settings management
 *
 * Separate ConfigData for settings and OBDConnectionManager for live data updates
 *
 */

import Combine
import Foundation
import Observation
import SwiftOBD2

protocol AppInfoProviding {
  var aboutText: String { get }
}

struct BundleAppInfoProvider: AppInfoProviding {
  let bundle: Bundle

  init(bundle: Bundle = .main) {
    self.bundle = bundle
  }

  var aboutText: String {
    aboutDetailString(bundle: bundle)
  }
}

protocol SettingsLogExporting {
  func exportLogs(baseName: String) async throws -> URL
}

struct DefaultSettingsLogExporter: SettingsLogExporting {
  func exportLogs(baseName: String) async throws -> URL {
    let data = try await collectLogs(since: -300)
    let fileName = "\(sanitizedFilename(from: baseName))-logs.json"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    try data.write(to: url, options: .atomic)
    return url
  }

  private func sanitizedFilename(from name: String) -> String {
    let allowed = CharacterSet.alphanumerics
      .union(.whitespaces)
      .union(CharacterSet(charactersIn: "-_."))
    let cleanedScalars = name.unicodeScalars.map {
      allowed.contains($0) ? Character($0) : "-"
    }
    let interim = String(cleanedScalars)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return interim.isEmpty ? "App" : interim
  }
}

// ---------------------------------------------

@MainActor
protocol SettingsConfigProviding: AnyObject {
  var wifiHost: String { get set }
  var wifiPort: Int { get set }
  var autoConnectToOBD: Bool { get set }
  var connectionType: ConnectionType { get set }

  var units: MeasurementUnit { get }
  func setUnits(_ units: MeasurementUnit)

  // Publishers
  var unitsPublisher: AnyPublisher<MeasurementUnit, Never> { get }
  var connectionTypePublisher: AnyPublisher<String, Never> { get }
}

@MainActor
protocol OBDConnectionControlling: AnyObject {
  var connectionState: OBDConnectionManager.ConnectionState { get }

  func updateConnectionDetails()
  func connect() async
  func disconnect()

  var connectionStatePublisher: AnyPublisher<OBDConnectionManager.ConnectionState, Never> { get }
}

// Composite protocol exposed to SettingsViewModel
typealias SettingsDataProviding =
  SettingsConfigProviding & OBDConnectionControlling

// ---------------------------------------------

extension ConfigData: SettingsConfigProviding {

  var connectionTypePublisher: AnyPublisher<String, Never> {
    $publishedConnectionType.eraseToAnyPublisher()
  }

  var unitsPublisher: AnyPublisher<MeasurementUnit, Never> {
    $units.eraseToAnyPublisher()
  }
}

// ---------------------------------------------

extension OBDConnectionManager: OBDConnectionControlling {

  var connectionStatePublisher: AnyPublisher<OBDConnectionManager.ConnectionState, Never> {
    $connectionState.eraseToAnyPublisher()
  }
}

// ---------------------------------------------

@MainActor
@Observable
final class SettingsViewModel: BaseViewModel {

  private let config: SettingsConfigProviding
  private let connection: OBDConnectionControlling
  private let appInfoProvider: AppInfoProviding
  private let logExporter: SettingsLogExporting

  var wifiHost: String {
    didSet {
      wifiHostSubject.send(wifiHost)
    }
  }

  var wifiPort: Int {
    didSet {
      wifiPortSubject.send(wifiPort)
    }
  }

  var autoConnectToOBD: Bool {
    didSet {
      config.autoConnectToOBD = autoConnectToOBD
      onChanged?()
    }
  }

  var connectionType: ConnectionType {
    didSet {
      guard oldValue != connectionType else { return }
      config.connectionType = connectionType
      connection.updateConnectionDetails()
      onChanged?()
    }
  }

  private(set) var connectionState: OBDConnectionManager.ConnectionState {
    didSet { onChanged?() }
  }

  private(set) var shareURL: URL? {
    didSet { onChanged?() }
  }

  private(set) var isGeneratingLogs = false {
    didSet { onChanged?() }
  }

  private(set) var shareErrorMessage: String? {
    didSet { onChanged?() }
  }

  var units: MeasurementUnit {
    didSet {
      guard oldValue != units else { return }
      config.setUnits(units)
      onChanged?()
    }
  }

  private var cancellables = Set<AnyCancellable>()

  // Subjects for debounced WiFi settings
  private let wifiHostSubject = PassthroughSubject<String, Never>()
  private let wifiPortSubject = PassthroughSubject<Int, Never>()

  static let numberFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .none
    f.allowsFloats = false
    return f
  }()

  var numberFormatter: NumberFormatter { Self.numberFormatter }

  var isConnectButtonDisabled: Bool {
    connectionState == .connecting
  }

  var aboutText: String {
    appInfoProvider.aboutText
  }

  init(
    config: SettingsConfigProviding,
    connection: OBDConnectionControlling,
    appInfoProvider: AppInfoProviding = BundleAppInfoProvider(),
    logExporter: SettingsLogExporting = DefaultSettingsLogExporter()
  ) {
    self.config = config
    self.connection = connection
    self.appInfoProvider = appInfoProvider
    self.logExporter = logExporter

    self.wifiHost = config.wifiHost
    self.wifiPort = config.wifiPort
    self.autoConnectToOBD = config.autoConnectToOBD
    self.connectionType = config.connectionType
    self.units = config.units
    self.connectionState = connection.connectionState
    self.shareURL = nil
    self.shareErrorMessage = nil

    super.init()
    bindExternalPublishers()
  }

  @MainActor
  override convenience init() {
    self.init(
      config: ConfigData.shared,
      connection: OBDConnectionManager.shared
    )
  }

  private func applyWiFiHostChange(_ newValue: String) {
    config.wifiHost = newValue
    if connectionType == .wifi {
      connection.updateConnectionDetails()
    }
    onChanged?()
  }

  private func applyWiFiPortChange(_ newValue: Int) {
    config.wifiPort = newValue
    if connectionType == .wifi {
      connection.updateConnectionDetails()
    }
    onChanged?()
  }

  private func bindExternalPublishers() {

    connection.connectionStatePublisher
      .removeDuplicates()
      .sink { [unowned self] newState in
        self.connectionState = newState
      }
      .store(in: &cancellables)

    config.unitsPublisher
      .removeDuplicates()
      .sink { [unowned self] newUnits in
        if self.units != newUnits {
          self.units = newUnits
        }
      }
      .store(in: &cancellables)

    config.connectionTypePublisher
      .removeDuplicates()
      .sink { [unowned self] raw in
        let newType = ConnectionType(rawValue: raw) ?? .bluetooth
        if self.connectionType != newType {
          self.connectionType = newType
        }
      }
      .store(in: &cancellables)

    // Debounced WiFi host changes
    wifiHostSubject
      .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
      .sink { [unowned self] newHost in
        self.applyWiFiHostChange(newHost)
      }
      .store(in: &cancellables)

    // Debounced WiFi port changes
    wifiPortSubject
      .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
      .sink { [unowned self] newPort in
        self.applyWiFiPortChange(newPort)
      }
      .store(in: &cancellables)
  }

  func handleConnectionButtonTap() {
    switch connection.connectionState {
    case .connected:
      connection.disconnect()

    case .disconnected, .failed:
      Task { await connection.connect() }

    case .connecting:
      break
    }
  }

  func prepareLogShare() async {
    isGeneratingLogs = true
    shareErrorMessage = nil
    defer { isGeneratingLogs = false }

    do {
      shareURL = try await logExporter.exportLogs(baseName: aboutText)
    } catch {
      shareErrorMessage = error.localizedDescription
    }
  }

  func clearShareURL() {
    shareURL = nil
  }

  func clearShareError() {
    shareErrorMessage = nil
  }

  func setShareError(_ message: String) {
    shareErrorMessage = message
  }
}
