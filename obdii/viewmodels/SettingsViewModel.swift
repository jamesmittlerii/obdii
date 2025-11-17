/**
 
 * __Final Project__
 * Jim Mittler
 * 14 November 2025
 
 
View Model for showing/setting various settings. Used by CarPlay and SwiftUI
 
 _Italic text__
 __Bold text__
 ~~Strikethrough text~~
 
 */

import Foundation
import Combine
import SwiftUI
import SwiftOBD2
import Observation

@MainActor
@Observable
class SettingsViewModel : BaseViewModel {
    // Observable state for the View
    var wifiHost: String {
        didSet {
            guard !isApplyingExternalUpdate else { return }
            // Debounce to avoid hammering OBDService reinit
            hostDebounceTask?.cancel()
            let newValue = wifiHost
            hostDebounceTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self?.applyWiFiHostChange(newValue)
            }
        }
    }

    var wifiPort: Int {
        didSet {
            guard !isApplyingExternalUpdate else { return }
            portDebounceTask?.cancel()
            let newValue = wifiPort
            portDebounceTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self?.applyWiFiPortChange(newValue)
            }
        }
    }

    var autoConnectToOBD: Bool {
        didSet {
            guard !isApplyingExternalUpdate else { return }
            configData.autoConnectToOBD = autoConnectToOBD
            notifyChange()
        }
    }

    var connectionType: ConnectionType {
        didSet {
            guard !isApplyingExternalUpdate else { return }
            configData.connectionType = connectionType
            connectionManager.updateConnectionDetails()
            notifyChange()
        }
    }

    private(set) var connectionState: OBDConnectionManager.ConnectionState {
        didSet {
            // Mirror updates from manager; notify CarPlay/UI
            notifyChange()
        }
    }

    var units: MeasurementUnit {
        didSet {
            guard !isApplyingExternalUpdate else { return }
            if oldValue != units {
                configData.setUnits(units)
                notifyChange()
            }
        }
    }

    // Callback for non-SwiftUI consumers (CarPlay)
    //var onChanged: (() -> Void)?

    //  Private Model References
    private let configData: ConfigData
    private let connectionManager: OBDConnectionManager

    // Combine bridges to external publishers we cannot change
    private var cancellables = Set<AnyCancellable>()

    // Debounce tasks for Wi‑Fi settings
    private var hostDebounceTask: Task<Void, Never>?
    private var portDebounceTask: Task<Void, Never>?

    // Reentrancy guard for external -> VM updates
    private var isApplyingExternalUpdate = false

    //  UI Helpers
    /// Formatter to ensure the port is entered as a number
    let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        return formatter
    }()

    var isConnectButtonDisabled: Bool {
        connectionState == .connecting
    }

    //  Initializers

    // Designated initializer
    override init() {
        self.configData = ConfigData.shared
        self.connectionManager = OBDConnectionManager.shared

        // Initialize observable properties from the models
        self.wifiHost = configData.wifiHost
        self.wifiPort = configData.wifiPort
        self.autoConnectToOBD = configData.autoConnectToOBD
        self.connectionType = configData.connectionType
        self.connectionState = connectionManager.connectionState
        self.units = configData.unitsPublished

        super.init()
        
        bindExternalPublishers()
    }

    // Labeled convenience initializer for shared singletons (avoid colliding with @Observable init)
   

    // MARK: - Debounced apply helpers

    private func applyWiFiHostChange(_ newValue: String) {
        configData.wifiHost = newValue
        if connectionType == .wifi {
            connectionManager.updateConnectionDetails()
        }
        notifyChange()
    }

    private func applyWiFiPortChange(_ newValue: Int) {
        configData.wifiPort = newValue
        if connectionType == .wifi {
            connectionManager.updateConnectionDetails()
        }
        notifyChange()
    }

    // MARK: - External publishers bridge

    private func bindExternalPublishers() {
        // Mirror manager connection state into our observable property
        connectionManager.$connectionState
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                guard let self else { return }
                self.connectionState = newState
                self.notifyChange()
            }
            .store(in: &cancellables)

        // Mirror ConfigData unitsPublished to our units
        configData.$unitsPublished
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] newUnits in
                guard let self else { return }
                if self.units != newUnits {
                    self.isApplyingExternalUpdate = true
                    self.units = newUnits
                    self.isApplyingExternalUpdate = false
                    self.notifyChange()
                }
            }
            .store(in: &cancellables)

        // If connection type is changed elsewhere, keep us in sync
        configData.$publishedConnectionType
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] raw in
                guard let self else { return }
                let newType = ConnectionType(rawValue: raw) ?? .bluetooth
                if self.connectionType != newType {
                    self.isApplyingExternalUpdate = true
                    self.connectionType = newType
                    self.isApplyingExternalUpdate = false
                    self.notifyChange()
                }
            }
            .store(in: &cancellables)
    }

    //  User Actions

    /// Handles the primary connect/disconnect button tap.
    func handleConnectionButtonTap() {
        switch connectionManager.connectionState {
        case .connected:
            connectionManager.disconnect()
        case .disconnected, .failed:
            Task {
                await connectionManager.connect()
            }
        case .connecting:
            break
        }
    }

    // MARK: - Callback helper

    private func notifyChange() {
        onChanged?()
    }
}

