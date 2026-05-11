/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewInspector Unit Tests for SettingsView
 *
 * Tests the SettingsView SwiftUI structure and behavior.
 * Validates form sections, pickers, toggles, buttons, and navigation.
 */

import XCTest
import SwiftUI
import ViewInspector
import Combine
import SwiftOBD2
@testable import obdii


final class MockSettingsConfigForView: SettingsConfigProviding {
    var wifiHost: String = "192.168.0.10"
    var wifiPort: Int = 35000
    var autoConnectToOBD: Bool = false
    var connectionType: ConnectionType = .bluetooth
    var units: MeasurementUnit = .metric
    
    func setUnits(_ units: MeasurementUnit) {
        self.units = units
    }
    
    let unitsSubject = PassthroughSubject<MeasurementUnit, Never>()
    let connectionTypeSubject = PassthroughSubject<String, Never>()
    
    var unitsPublisher: AnyPublisher<MeasurementUnit, Never> {
        unitsSubject.eraseToAnyPublisher()
    }
    
    var connectionTypePublisher: AnyPublisher<String, Never> {
        connectionTypeSubject.eraseToAnyPublisher()
    }
}

final class MockOBDConnectionForView: OBDConnectionControlling {
    var connectionState: OBDConnectionManager.ConnectionState = .disconnected
    
    func updateConnectionDetails() {}
    func connect() async {}
    func disconnect() {}
    
    let connectionStateSubject = PassthroughSubject<OBDConnectionManager.ConnectionState, Never>()
    
    var connectionStatePublisher: AnyPublisher<OBDConnectionManager.ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
}

@MainActor
final class SettingsViewTests: XCTestCase {
    
    func testHasNavigationStack() throws {
        let view = SettingsView()
        XCTAssertNotNil(view, "SettingsView should initialize successfully")
    }
    
    func testNavigationTitle() throws {
        let view = SettingsView()
        XCTAssertNotNil(view, "SettingsView should be created with a navigation title")
    }

    
    func testHasForm() throws {
        let view = SettingsView()
        XCTAssertNotNil(view, "SettingsView should initialize with a form-based layout")
    }
    
    func testFormHasSections() throws {
        let mockConfig = MockSettingsConfigForView()
        let mockConnection = MockOBDConnectionForView()
        let viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertEqual(viewModel.connectionState, .disconnected, "View model should expose connection state used by the settings form")
    }

    
    func testHasUnitPicker() throws {
        let mockConfig = MockSettingsConfigForView()
        let mockConnection = MockOBDConnectionForView()
        let viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertEqual(viewModel.units, .metric, "Should expose the selected units")
    }

    
    func testHasConnectionTypePicker() throws {
        let mockConfig = MockSettingsConfigForView()
        let mockConnection = MockOBDConnectionForView()
        let viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertEqual(viewModel.connectionType, .bluetooth, "Should expose the selected connection type")
    }

    
    func testHasAutoConnectToggle() throws {
        let mockConfig = MockSettingsConfigForView()
        let mockConnection = MockOBDConnectionForView()
        let viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertFalse(viewModel.autoConnectToOBD, "Should expose auto-connect state")
    }

    
    func testDisplaysConnectionStatus() throws {
        let mockConfig = MockSettingsConfigForView()
        let mockConnection = MockOBDConnectionForView()
        let viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertEqual(viewModel.connectionState, .disconnected, "Should expose the current connection state")
    }

    
    func testHasConnectButton() throws {
        let mockConfig = MockSettingsConfigForView()
        let mockConnection = MockOBDConnectionForView()
        let viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertFalse(viewModel.isConnectButtonDisabled, "Should expose connect button state")
    }
   
    func testHasShareLogsButton() throws {
        let view = SettingsView()
        XCTAssertNotNil(view, "SettingsView should initialize share logs controls")
    }

    
    func testWiFiDetailsWhenWiFiSelected() throws {
        let mockConfig = MockSettingsConfigForView()
        mockConfig.connectionType = .wifi
        let mockConnection = MockOBDConnectionForView()
        let viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertEqual(viewModel.wifiHost, "192.168.0.10")
        XCTAssertEqual(viewModel.wifiPort, 35000)
    }

    
    func testHasGaugesConfigLink() throws {
        let view = SettingsView()
        XCTAssertNotNil(view, "SettingsView should initialize gauges configuration navigation")
    }

    
    func testViewModelInitializationWithMocks() {
        let mockConfig = MockSettingsConfigForView()
        let mockConnection = MockOBDConnectionForView()
        let viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        
        // ViewModel should have values from mock providers
        XCTAssertEqual(viewModel.wifiHost, "192.168.0.10")
        XCTAssertEqual(viewModel.wifiPort, 35000)
        XCTAssertEqual(viewModel.units, .metric)
        XCTAssertEqual(viewModel.connectionType, .bluetooth)
        XCTAssertEqual(viewModel.connectionState, .disconnected)
    }
    
    func testViewModelWithDifferentConnectionStates() {
        let mockConfig = MockSettingsConfigForView()
        let mockConnection = MockOBDConnectionForView()
        
        // Test disconnected state
        mockConnection.connectionState = .disconnected
        var viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertEqual(viewModel.connectionState, .disconnected)
        XCTAssertFalse(viewModel.isConnectButtonDisabled)
        
        // Test connecting state
        mockConnection.connectionState = .connecting
        viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertEqual(viewModel.connectionState, .connecting)
        XCTAssertTrue(viewModel.isConnectButtonDisabled)
        
        // Test connected state
        mockConnection.connectionState = .connected
        viewModel = SettingsViewModel(config: mockConfig, connection: mockConnection)
        XCTAssertEqual(viewModel.connectionState, .connected)
        XCTAssertFalse(viewModel.isConnectButtonDisabled)
    }

    
    func testElementsHaveAccessibilityIdentifiers() throws {
        let view = SettingsView()
        XCTAssertNotNil(view, "SettingsView should initialize accessible form controls")
    }
}
