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


import Foundation
import Combine
import Observation
import SwiftOBD2

// MARK: - Protocols
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


// MARK: - ConfigData Conformance
// ---------------------------------------------

extension ConfigData: SettingsConfigProviding {

    var connectionTypePublisher: AnyPublisher<String, Never> {
        $publishedConnectionType.eraseToAnyPublisher()
    }

    var unitsPublisher: AnyPublisher<MeasurementUnit, Never> {
        $units.eraseToAnyPublisher()
    }
}


// MARK: - OBDConnectionManager Conformance
// ---------------------------------------------

extension OBDConnectionManager: OBDConnectionControlling {

    var connectionStatePublisher: AnyPublisher<OBDConnectionManager.ConnectionState, Never> {
        $connectionState.eraseToAnyPublisher()
    }
}


// MARK: - SettingsViewModel
// ---------------------------------------------

@MainActor
@Observable
final class SettingsViewModel: BaseViewModel {

    // MARK: - Dependencies
    private let config: SettingsConfigProviding
    private let connection: OBDConnectionControlling

    // MARK: - Observable Properties

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

    var units: MeasurementUnit {
        didSet {
            guard oldValue != units else { return }
            config.setUnits(units)
            onChanged?()
        }
    }

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    
    // Subjects for debounced WiFi settings
    private let wifiHostSubject = PassthroughSubject<String, Never>()
    private let wifiPortSubject = PassthroughSubject<Int, Never>()

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

    init(
        config: SettingsConfigProviding,
        connection: OBDConnectionControlling
    ) {
        self.config = config
        self.connection = connection

        self.wifiHost = config.wifiHost
        self.wifiPort = config.wifiPort
        self.autoConnectToOBD = config.autoConnectToOBD
        self.connectionType = config.connectionType
        self.units = config.units
        self.connectionState = connection.connectionState

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

    // MARK: - Update Helpers

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

    // MARK: - External Publisher Bindings

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

    // MARK: - User Actions

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
}

