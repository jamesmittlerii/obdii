/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewModel for application settings screen
 *
 * Manages Wi-Fi connection details, connection type, auto-connect preference,
 * and measurement units. Provides two-way bindings with ConfigData and
 * OBDConnectionManager. Debounces Wi-Fi host/port changes to avoid frequent
 * reconnections. Handles connect/disconnect button tap logic.
 */
import Foundation
import Combine
import Observation
import SwiftOBD2

@MainActor
@Observable
final class SettingsViewModel: BaseViewModel {

    // MARK: - Observable Properties

    var wifiHost: String {
        didSet {
            debounceApply(&hostDebounceTask) { [unowned self] in
                applyWiFiHostChange(wifiHost)
            }
        }
    }

    var wifiPort: Int {
        didSet {
            debounceApply(&portDebounceTask) { [unowned self] in
                applyWiFiPortChange(wifiPort)
            }
        }
    }

    var autoConnectToOBD: Bool {
        didSet {
            configData.autoConnectToOBD = autoConnectToOBD
            onChanged?()
        }
    }

    var connectionType: ConnectionType {
        didSet {
            guard oldValue != connectionType else { return }   // <-- New guard
            configData.connectionType = connectionType
            connectionManager.updateConnectionDetails()
            onChanged?()
        }
    }

    private(set) var connectionState: OBDConnectionManager.ConnectionState {
        didSet { onChanged?() }
    }

    var units: MeasurementUnit {
        didSet {
            guard oldValue != units else { return }
            configData.setUnits(units)
            onChanged?()
        }
    }

    // MARK: - Dependencies

    private let configData: ConfigData
    private let connectionManager: OBDConnectionManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Debounce Tasks

    private var hostDebounceTask: Task<Void, Never>?
    private var portDebounceTask: Task<Void, Never>?

    private func debounceApply(
        _ task: inout Task<Void, Never>?,
        _ action: @escaping () -> Void
    ) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            action()
        }
    }

    // MARK: - UI Helpers

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

    // MARK: - Init

    override init() {
        self.configData = .shared
        self.connectionManager = .shared

        self.wifiHost = configData.wifiHost
        self.wifiPort = configData.wifiPort
        self.autoConnectToOBD = configData.autoConnectToOBD
        self.connectionType = configData.connectionType
        self.connectionState = connectionManager.connectionState
        self.units = configData.units

        super.init()
        bindExternalPublishers()
    }

    // MARK: - Update Helpers

    private func applyWiFiHostChange(_ newValue: String) {
        configData.wifiHost = newValue
        if connectionType == .wifi {
            connectionManager.updateConnectionDetails()
        }
        onChanged?()
    }

    private func applyWiFiPortChange(_ newValue: Int) {
        configData.wifiPort = newValue
        if connectionType == .wifi {
            connectionManager.updateConnectionDetails()
        }
        onChanged?()
    }

    // MARK: - External Publisher Bindings

    private func bindExternalPublishers() {

        connectionManager.$connectionState
            .removeDuplicates()
            .sink { [unowned self] newState in
                self.connectionState = newState
            }
            .store(in: &cancellables)

        configData.$units
            .removeDuplicates()
            .sink { [unowned self] newUnits in
                self.units = newUnits
            }
            .store(in: &cancellables)

        configData.$publishedConnectionType
            .removeDuplicates()
            .sink { [unowned self] raw in
                let newType = ConnectionType(rawValue: raw) ?? .bluetooth
                if self.connectionType != newType {   // <-- prevents reconnection
                    self.connectionType = newType      // didSet triggers updateConnectionDetails()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - User Actions

    func handleConnectionButtonTap() {
        switch connectionManager.connectionState {
        case .connected:
            connectionManager.disconnect()

        case .disconnected, .failed:
            Task { await connectionManager.connect() }

        case .connecting:
            break
        }
    }
}
