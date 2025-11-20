/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for ConfigData
 *
 * Tests configuration management, persistence via AppStorage/UserDefaults,
 * connection type/units switching, and Combine publisher integration.
 */

import XCTest
import SwiftOBD2
@testable import obdii

@MainActor
final class ConfigDataTests: XCTestCase {
    
    var configData: ConfigData!
    
    override func setUp() async throws {
        // Use ConfigData.shared since it's a singleton
        configData = ConfigData.shared
    }
    
    override func tearDown() async throws {
        // Reset to defaults after each test
        configData.wifiHost = "192.168.0.10"
        configData.wifiPort = 35000
        configData.autoConnectToOBD = true
        configData.connectionType = .bluetooth
        configData.setUnits(.metric)
    }
    
    // MARK: - Initialization Tests
    
    func testSharedInstanceExists() {
        XCTAssertNotNil(ConfigData.shared, "Shared instance should exist")
    }
    
    func testInitialValues() {
        // Default values should be set
        XCTAssertEqual(configData.wifiHost, "192.168.0.10", "Default WiFi host")
        XCTAssertEqual(configData.wifiPort, 35000, "Default WiFi port")
        XCTAssertTrue(configData.autoConnectToOBD, "Default auto-connect")
    }
    
    //MARK: - WiFi Configuration Tests
    
    func testWiFiHostUpdate() {
        let newHost = "192.168.1.100"
        configData.wifiHost = newHost
        
        XCTAssertEqual(configData.wifiHost, newHost, "WiFi host should update")
    }
    
    func testWiFiPortUpdate() {
        let newPort = 35001
        configData.wifiPort = newPort
        
        XCTAssertEqual(configData.wifiPort, newPort, "WiFi port should update")
    }
    
    func testWiFiPortValidRange() {
        let validPort = 8080
        configData.wifiPort = validPort
        
        XCTAssertEqual(configData.wifiPort, validPort, "Valid port should be set")
        XCTAssertGreaterThan(configData.wifiPort, 0, "Port should be positive")
        XCTAssertLessThanOrEqual(configData.wifiPort, 65535, "Port should be within valid range")
    }
    
    // MARK: - Connection Type Tests
    
    func testConnectionTypeDefault() {
        // Should default to bluetooth
        XCTAssertEqual(configData.connectionType, .bluetooth, "Default should be Bluetooth")
    }
    
    func testConnectionTypeSwitch() {
        configData.connectionType = .wifi
        XCTAssertEqual(configData.connectionType, .wifi, "Should switch to WiFi")
        
        configData.connectionType = .demo
        XCTAssertEqual(configData.connectionType, .demo, "Should switch to Demo")
        
        configData.connectionType = .bluetooth
        XCTAssertEqual(configData.connectionType, .bluetooth, "Should switch back to Bluetooth")
    }
    
    func testPublishedConnectionTypeSync() {
        configData.connectionType = .demo
        
        // Published property should reflect the change
        XCTAssertEqual(configData.publishedConnectionType, ConnectionType.demo.rawValue, 
                      "Published connection type should sync")
    }
    
    // MARK: - Units Tests
    
    func testUnitsDefault() {
        // Should default to metric
        XCTAssertEqual(configData.units, .metric, "Default should be metric")
    }
    
    func testUnitsSwitch() {
        configData.setUnits(.imperial)
        XCTAssertEqual(configData.units, .imperial, "Should switch to imperial")
        
        configData.setUnits(.metric)
        XCTAssertEqual(configData.units, .metric, "Should switch back to metric")
    }
    
    // MARK: - Auto-Connect Tests
    
    func testAutoConnectToggle() {
        configData.autoConnectToOBD = false
        XCTAssertFalse(configData.autoConnectToOBD, "Should disable auto-connect")
        
        configData.autoConnectToOBD = true
        XCTAssertTrue(configData.autoConnectToOBD, "Should enable auto-connect")
    }
    
    // MARK: - Persistence Tests
    
    func testPersistenceViaAppStorage() {
        let testHost = "10.0.0.1"
        configData.wifiHost = testHost
        
        // Should persist to UserDefaults via @AppStorage
        let savedHost = UserDefaults.standard.string(forKey: "wifiHost")
        XCTAssertEqual(savedHost, testHost, "Should persist to UserDefaults")
    }
    
    func testConnectionTypePersistence() {
        configData.connectionType = .wifi
        
        // Should persist the raw value
        let savedType = UserDefaults.standard.string(forKey: "connectionType")
        XCTAssertEqual(savedType, ConnectionType.wifi.rawValue, "Should persist connection type")
    }
    
    func testUnitsPersistence() {
        configData.setUnits(.imperial)
        
        // Should persist the raw value
        let savedUnits = UserDefaults.standard.string(forKey: "units")
        XCTAssertEqual(savedUnits, MeasurementUnit.imperial.rawValue, "Should persist units")
    }
}
