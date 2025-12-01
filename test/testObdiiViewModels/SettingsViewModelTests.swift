/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for SettingsViewModel
 *
 * Tests connection state management, WiFi configuration, unit switching,
 * debouncing logic, and publisher bindings using mock providers for isolated testing.
 */

import XCTest
import SwiftOBD2
import Combine
@testable import obdii

final class MockSettingsConfig: SettingsConfigProviding {
    // Config data properties
    var wifiHost: String = "192.168.0.10"
    var wifiPort: Int = 35000
    var autoConnectToOBD: Bool = false
    var connectionType: ConnectionType = .bluetooth
    var units: MeasurementUnit = .metric
    
    func setUnits(_ units: MeasurementUnit) {
        self.units = units
    }
    
    // Publishers
    let unitsSubject = PassthroughSubject<MeasurementUnit, Never>()
    let connectionTypeSubject = PassthroughSubject<String, Never>()
    
    var unitsPublisher: AnyPublisher<MeasurementUnit, Never> {
        unitsSubject.eraseToAnyPublisher()
    }
    
    var connectionTypePublisher: AnyPublisher<String, Never> {
        connectionTypeSubject.eraseToAnyPublisher()
    }
}

final class MockOBDConnection: OBDConnectionControlling {
    // Connection manager properties
    var connectionState: OBDConnectionManager.ConnectionState = .disconnected
    var updateConnectionDetailsCallCount = 0
    var connectCallCount = 0
    var disconnectCallCount = 0
    
    func updateConnectionDetails() {
        updateConnectionDetailsCallCount += 1
    }
    
    func connect() async {
        connectCallCount += 1
    }
    
    func disconnect() {
        disconnectCallCount += 1
    }
    
    // Publishers
    let connectionStateSubject = PassthroughSubject<OBDConnectionManager.ConnectionState, Never>()
    
    var connectionStatePublisher: AnyPublisher<OBDConnectionManager.ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
}

@MainActor
final class SettingsViewModelTests: XCTestCase {
    
    var viewModel: SettingsViewModel!
    var mockConfig: MockSettingsConfig!
    var mockConnection: MockOBDConnection!
    
    override func setUp() async throws {
        mockConfig = MockSettingsConfig()
        mockConnection = MockOBDConnection()
        viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockConfig = nil
        mockConnection = nil
    }

    
    func testInitialization() {
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertEqual(viewModel.wifiHost, "192.168.0.10")
        XCTAssertEqual(viewModel.wifiPort, 35000)
        XCTAssertEqual(viewModel.autoConnectToOBD, false)
        XCTAssertEqual(viewModel.connectionType, .bluetooth)
        XCTAssertEqual(viewModel.units, .metric)
        XCTAssertEqual(viewModel.connectionState, .disconnected)
    }

    
    func testWiFiHostUpdate() async {
        let newHost = "192.168.1.100"
        viewModel.wifiHost = newHost
        
        // Wait for debounce (500ms)
        try? await Task.sleep(for: .seconds(0.6))
        
        XCTAssertEqual(viewModel.wifiHost, newHost)
        XCTAssertEqual(mockConfig.wifiHost, newHost, "Config should be updated")
    }
    
    func testWiFiPortUpdate() async {
        let newPort = 35001
        viewModel.wifiPort = newPort
        
        // Wait for debounce (500ms)
        try? await Task.sleep(for: .seconds(0.6))
        
        XCTAssertEqual(viewModel.wifiPort, newPort)
        XCTAssertEqual(mockConfig.wifiPort, newPort, "Config should be updated")
    }
    
    func testWiFiHostUpdateTriggersConnectionDetailsUpdateWhenWiFi() async {
        // Set connection type to WiFi
        viewModel.connectionType = .wifi
        
        mockConnection.updateConnectionDetailsCallCount = 0
        viewModel.wifiHost = "10.0.0.1"
        
        try? await Task.sleep(for: .seconds(0.6))
        
        XCTAssertEqual(mockConnection.updateConnectionDetailsCallCount, 1, 
                      "Should call updateConnectionDetails when WiFi is active")
    }
    
    func testWiFiHostUpdateDoesNotTriggerConnectionDetailsUpdateWhenBluetooth() async {
        // Connection type is bluetooth by default
        XCTAssertEqual(viewModel.connectionType, .bluetooth)
        
        mockConnection.updateConnectionDetailsCallCount = 0
        viewModel.wifiHost = "10.0.0.1"
        
        try? await Task.sleep(for: .seconds(0.6))
        
        XCTAssertEqual(mockConnection.updateConnectionDetailsCallCount, 0, 
                      "Should not call updateConnectionDetails when Bluetooth is active")
    }

    
    func testConnectionTypeChange() {
        viewModel.connectionType = .wifi
        
        XCTAssertEqual(viewModel.connectionType, .wifi)
        XCTAssertEqual(mockConfig.connectionType, .wifi, "Config should be updated")
        XCTAssertEqual(mockConnection.updateConnectionDetailsCallCount, 1, 
                      "Should call updateConnectionDetails")
    }
    
    func testConnectionTypePreventsRedundantUpdates() {
        mockConnection.updateConnectionDetailsCallCount = 0
        
        // Set to same value
        viewModel.connectionType = .bluetooth
        
        XCTAssertEqual(viewModel.connectionType, .bluetooth)
        XCTAssertEqual(mockConnection.updateConnectionDetailsCallCount, 0, 
                      "Should not call updateConnectionDetails for redundant update")
    }

    
    func testUnitsChange() {
        viewModel.units = .imperial
        
        XCTAssertEqual(viewModel.units, .imperial)
        XCTAssertEqual(mockConfig.units, .imperial, "Config should be updated")
    }
    
    func testUnitsPreventsRedundantUpdates() {
        let initialUnits = viewModel.units
        
        // Set to same value
        viewModel.units = initialUnits
        
        XCTAssertEqual(viewModel.units, initialUnits, "Redundant update should be handled")
    }

    
    func testAutoConnectToggle() {
        viewModel.autoConnectToOBD = true
        
        XCTAssertEqual(viewModel.autoConnectToOBD, true)
        XCTAssertEqual(mockConfig.autoConnectToOBD, true, "Config should be updated")
    }

    
    func testConnectionStateUpdateFromPublisher() async {
        mockConnection.connectionStateSubject.send(.connecting)
        
        try? await Task.sleep(for: .seconds(0.1))
        
        XCTAssertEqual(viewModel.connectionState, .connecting)
    }
    
    func testConnectionStateProgression() async {
        mockConnection.connectionStateSubject.send(.connecting)
        try? await Task.sleep(for: .seconds(0.1))
        XCTAssertEqual(viewModel.connectionState, .connecting)
        
        mockConnection.connectionStateSubject.send(.connected)
        try? await Task.sleep(for: .seconds(0.1))
        XCTAssertEqual(viewModel.connectionState, .connected)
        
        mockConnection.connectionStateSubject.send(.disconnected)
        try? await Task.sleep(for: .seconds(0.1))
        XCTAssertEqual(viewModel.connectionState, .disconnected)
    }
    
    func testIsConnectButtonDisabled() {
        // Initially disconnected
        XCTAssertFalse(viewModel.isConnectButtonDisabled)
        
        // Simulate connecting state
        mockConnection.connectionState = .connecting
        viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertTrue(viewModel.isConnectButtonDisabled)
    }

    
    func testUnitsPublisherUpdatesViewModel() async {
        mockConfig.unitsSubject.send(.imperial)
        
        try? await Task.sleep(for: .seconds(0.1))
        
        XCTAssertEqual(viewModel.units, .imperial)
    }
    
    func testConnectionTypePublisherUpdatesViewModel() async {
        mockConfig.connectionTypeSubject.send(ConnectionType.wifi.rawValue)
        
        try? await Task.sleep(for: .seconds(0.1))
        
        XCTAssertEqual(viewModel.connectionType, .wifi)
    }

    
    func testNumberFormatter() {
        let formatter = viewModel.numberFormatter
        
        XCTAssertEqual(formatter.numberStyle, .none, "Should use no number style")
        XCTAssertFalse(formatter.allowsFloats, "Should not allow floats for port")
    }
    
    func testStaticNumberFormatter() {
        let formatter1 = SettingsViewModel.numberFormatter
        let formatter2 = SettingsViewModel.numberFormatter
        
        XCTAssertTrue(formatter1 === formatter2, "Should return same static instance")
    }

    
    func testHandleConnectionButtonTapWhenDisconnected() async {
        mockConnection.connectionState = .disconnected
        viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        
        viewModel.handleConnectionButtonTap()
        
        try? await Task.sleep(for: .seconds(0.1))
        
        XCTAssertEqual(mockConnection.connectCallCount, 1, "Should call connect")
    }
    
    func testHandleConnectionButtonTapWhenConnected() {
        mockConnection.connectionState = .connected
        viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        
        viewModel.handleConnectionButtonTap()
        
        XCTAssertEqual(mockConnection.disconnectCallCount, 1, "Should call disconnect")
    }
    
    func testHandleConnectionButtonTapWhenConnecting() {
        mockConnection.connectionState = .connecting
        viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        
        viewModel.handleConnectionButtonTap()
        
        XCTAssertEqual(mockConnection.connectCallCount, 0, "Should not call connect")
        XCTAssertEqual(mockConnection.disconnectCallCount, 0, "Should not call disconnect")
    }
    
    func testHandleConnectionButtonTapWhenFailed() async {
        mockConnection.connectionState = .failed(NSError(domain: "Test", code: 1))
        viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        
        viewModel.handleConnectionButtonTap()
        
        try? await Task.sleep(for: .seconds(0.1))
        
        XCTAssertEqual(mockConnection.connectCallCount, 1, "Should call connect when failed")
    }
}
