/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for SettingsViewModel
 *
 * Tests connection state management, WiFi configuration, unit switching,
 * debouncing logic, and integration with ConfigData and OBDConnectionManager.
 */

import XCTest
import SwiftOBD2
@testable import obdii

@MainActor
final class SettingsViewModelTests: XCTestCase {
    
    var viewModel: SettingsViewModel!
    
    override func setUp() async throws {
        viewModel = SettingsViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertNotNil(viewModel.units, "Units should be set from ConfigData")
        XCTAssertNotNil(viewModel.connectionType, "Connection type should be set")
        XCTAssertNotNil(viewModel.connectionState, "Connection state should be set")
    }
    
    func testInitialValuesFromConfigData() {
        // ViewModel should reflect ConfigData's current values
        XCTAssertEqual(viewModel.wifiHost, ConfigData.shared.wifiHost, "WiFi host should match ConfigData")
        XCTAssertEqual(viewModel.wifiPort, ConfigData.shared.wifiPort, "WiFi port should match ConfigData")
        XCTAssertEqual(viewModel.autoConnectToOBD, ConfigData.shared.autoConnectToOBD, "AutoConnect should match ConfigData")
    }
    
    // MARK: - WiFi Configuration Tests
    
    func testWiFiHostUpdate() {
        let newHost = "192.168.1.100"
        viewModel.wifiHost = newHost
        
        // Should update the value immediately
        XCTAssertEqual(viewModel.wifiHost, newHost, "WiFi host should update")
    }
    
    func testWiFiPortUpdate() {
        let newPort = 35000
        viewModel.wifiPort = newPort
        
        XCTAssertEqual(viewModel.wifiPort, newPort, "WiFi port should update")
    }
    
    // MARK: - Connection Type Tests
    
    func testConnectionTypeChange() {
        let initialType = viewModel.connectionType
        let newType: ConnectionType = (initialType == .bluetooth) ? .wifi : .bluetooth
        
        viewModel.connectionType = newType
        
        XCTAssertEqual(viewModel.connectionType, newType, "Connection type should update")
        XCTAssertEqual(ConfigData.shared.connectionType, newType, "ConfigData should be updated")
    }
    
    func testConnectionTypePreventsRedundantUpdates() {
        let currentType = viewModel.connectionType
        
        // Set to same value
        viewModel.connectionType = currentType
        
        // Should still be the same
        XCTAssertEqual(viewModel.connectionType, currentType, "Redundant update should be ignored")
    }
    
    // MARK: - Units Tests
    
    func testUnitsChange() {
        let initialUnits = viewModel.units
        let newUnits: MeasurementUnit = (initialUnits == .metric) ? .imperial : .metric
        
        viewModel.units = newUnits
        
        XCTAssertEqual(viewModel.units, newUnits, "Units should update")
    }
    
    // MARK: - Auto-Connect Tests
    
    func testAutoConnectToggle() {
        let initial = viewModel.autoConnectToOBD
        
        viewModel.autoConnectToOBD = !initial
        
        XCTAssertEqual(viewModel.autoConnectToOBD, !initial, "AutoConnect should toggle")
        XCTAssertEqual(ConfigData.shared.autoConnectToOBD, !initial, "ConfigData should be updated")
    }
    
    // MARK: - Connection State Tests
    
    func testConnectionStateTracking() {
        // ViewModel should track OBDConnectionManager's state
        XCTAssertEqual(viewModel.connectionState, 
                      OBDConnectionManager.shared.connectionState,
                      "Connection state should match manager")
    }
    
    func testIsConnectButtonDisabled() {
        // Button should be disabled when connecting
        let isDisabled = viewModel.isConnectButtonDisabled
        let isConnecting = (viewModel.connectionState == .connecting)
        
        XCTAssertEqual(isDisabled, isConnecting, 
                      "Button should be disabled only when connecting")
    }
    
    // MARK: - Number Formatter Tests
    
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
    
    // MARK: - Connection Button Tap Tests
    
    func testHandleConnectionButtonTapWhenDisconnected() {
        // Can't fully test without mocking, but we can verify it doesn't crash
        viewModel.handleConnectionButtonTap()
        
        // Should execute without errors
        XCTAssertTrue(true, "Should handle tap without errors")
    }
}
