/**
 * __Final Project__
 * Jim Mittler
 * 20 November 2025
 *
 * Unit Tests for OBDConnectionManager
 *
 * Tests connection lifecycle, state transitions, continuous PID updates,
 * statistics tracking, and demand-driven polling integration.
 * Uses demo mode for safe, repeatable testing without requiring actual hardware.
 */

import XCTest
import SwiftOBD2
import Combine
@testable import obdii

@MainActor
final class OBDConnectionManagerTests: XCTestCase {
    
    var manager: OBDConnectionManager!
    var configData: ConfigData!
    var cancellables: Set<AnyCancellable> = []
    
    override func setUp() async throws {
        manager = OBDConnectionManager.shared
        configData = ConfigData.shared
        cancellables = []
        
        // Ensure we start disconnected
        if manager.connectionState != .disconnected {
            manager.disconnect()
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
        }
        
        // Set to demo mode for testing
        configData.connectionType = .demo
        manager.updateConnectionDetails()
    }
    
    override func tearDown() async throws {
        // Clean disconnect
        if manager.connectionState != .disconnected {
            manager.disconnect()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        cancellables.removeAll()
        manager = nil
        configData = nil
    }
    
    // MARK: - Initialization Tests
    
    func testSharedInstanceExists() {
        XCTAssertNotNil(OBDConnectionManager.shared, "Shared instance should exist")
    }
    
    func testInitialStateDisconnected() {
        XCTAssertEqual(manager.connectionState, .disconnected, "Should start disconnected")
    }
    
    func testInitialPublishedStatesNil() {
        XCTAssertNil(manager.troubleCodes, "Trouble codes should be nil initially")
        XCTAssertNil(manager.fuelStatus, "Fuel status should be nil initially")
        XCTAssertNil(manager.MILStatus, "MIL status should be nil initially")
        XCTAssertNil(manager.connectedPeripheralName, "Peripheral name should be nil initially")
    }
    
    func testInitialPidStatsEmpty() {
        XCTAssertTrue(manager.pidStats.isEmpty, "PID stats should be empty initially")
    }
    
    // MARK: - Connection Lifecycle Tests
    
    func testConnectInDemoMode() async {
        let expectation = XCTestExpectation(description: "Should connect in demo mode")
        
        var stateChanges: [OBDConnectionManager.ConnectionState] = []
        manager.$connectionState
            .sink { state in
                stateChanges.append(state)
                if state == .connected {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await manager.connect()
        
        await fulfillment(of: [expectation], timeout: 35.0)
        
        XCTAssertEqual(manager.connectionState, .connected, "Should be connected")
        XCTAssertTrue(stateChanges.contains(.connecting), "Should have transitioned through connecting")
        XCTAssertTrue(stateChanges.contains(.connected), "Should have reached connected state")
    }
    
    func testDisconnectFromConnectedState() async {
        // First connect
        await manager.connect()
        
        // Wait for connection
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 sec
        
        XCTAssertEqual(manager.connectionState, .connected, "Should be connected before disconnect")
        
        // Now disconnect
        manager.disconnect()
        
        XCTAssertEqual(manager.connectionState, .disconnected, "Should be disconnected")
        XCTAssertNil(manager.troubleCodes, "Trouble codes should be cleared")
        XCTAssertNil(manager.fuelStatus, "Fuel status should be cleared")
        XCTAssertNil(manager.MILStatus, "MIL status should be cleared")
        XCTAssertTrue(manager.pidStats.isEmpty, "PID stats should be cleared")
    }
    
    func testMultipleConnectAttempts() async {
        await manager.connect()
        
        // Wait for connection
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 sec
        
        let firstState = manager.connectionState
        
        // Attempt second connection while already connected
        await manager.connect()
        
        let secondState = manager.connectionState
        
        // Should remain in the same connected state
        XCTAssertEqual(firstState, .connected)
        XCTAssertEqual(secondState, .connected)
    }
    
    // MARK: - Configuration Update Tests
    
    func testUpdateConnectionDetails() {
        configData.connectionType = .wifi
        configData.wifiHost = "192.168.0.10"
        configData.wifiPort = 35000
        
        manager.updateConnectionDetails()
        
        // Should have recreated the service
        // If state was connected, it should disconnect first
        XCTAssertEqual(manager.connectionState, .disconnected, "Should be disconnected after config update")
    }
    
    // MARK: - PID Statistics Tests
    
    func testStatsForPIDWithNoData() {
        let stats = manager.stats(for: .mode1(.rpm))
        XCTAssertNil(stats, "Should return nil for PID with no data")
    }
    
    func testPIDStatsPublishing() async {
        let expectation = XCTestExpectation(description: "Should receive PID stats")
        
        // Register interest in RPM
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode1(.rpm)], for: token)
        
        manager.$pidStats
            .dropFirst() // Skip initial empty state
            .sink { stats in
                if !stats.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await manager.connect()
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertFalse(manager.pidStats.isEmpty, "Should have PID stats after connection")
        
        // Check that RPM stats exist
        let rpmStats = manager.stats(for: .mode1(.rpm))
        XCTAssertNotNil(rpmStats, "RPM stats should exist")
        
        if let stats = rpmStats {
            XCTAssertGreaterThan(stats.sampleCount, 0, "Should have at least one sample")
            XCTAssertLessThanOrEqual(stats.min, stats.max, "Min should be <= max")
        }
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    // MARK: - Trouble Codes Tests
    
    func testTroubleCodesPublishing() async {
        let expectation = XCTestExpectation(description: "Should receive trouble codes")
        
        // Register interest in DTCs
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode3(.GET_DTC)], for: token)
        
        manager.$troubleCodes
            .dropFirst() // Skip initial nil
            .sink { codes in
                if codes != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await manager.connect()
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertNotNil(manager.troubleCodes, "Trouble codes should be set")
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    // MARK: - Fuel Status Tests
    
    func testFuelStatusPublishing() async {
        let expectation = XCTestExpectation(description: "Should receive fuel status")
        
        // Register interest in fuel status
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode1(.fuelStatus)], for: token)
        
        manager.$fuelStatus
            .dropFirst() // Skip initial nil
            .sink { status in
                if status != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await manager.connect()
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertNotNil(manager.fuelStatus, "Fuel status should be set")
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    // MARK: - MIL Status Tests
    
    func testMILStatusPublishing() async {
        let expectation = XCTestExpectation(description: "Should receive MIL status")
        
        // Register interest in MIL status
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode1(.status)], for: token)
        
        manager.$MILStatus
            .dropFirst() // Skip initial nil
            .sink { status in
                if status != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await manager.connect()
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertNotNil(manager.MILStatus, "MIL status should be set")
        
        if let milStatus = manager.MILStatus {
            // Verify it has expected properties
            XCTAssertNotNil(milStatus.milOn, "MIL on status should be set")
            XCTAssertGreaterThanOrEqual(milStatus.dtcCount, 0, "DTC count should be set")
        }
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    // MARK: - Demand-Driven Polling Integration Tests
    
    func testDemandDrivenPollingIntegration() async {
        await manager.connect()
        
        // Wait for connection
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 sec
        
        let expectation = XCTestExpectation(description: "Should receive speed stats")
        
        // Initially no speed stats
        XCTAssertNil(manager.stats(for: .mode1(.speed)), "Speed stats should not exist yet")
        
        manager.$pidStats
            .sink { stats in
                if stats[.mode1(.speed)] != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Register interest in speed
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode1(.speed)], for: token)
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Now speed stats should exist
        XCTAssertNotNil(manager.stats(for: .mode1(.speed)), "Speed stats should exist after registering interest")
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    func testStatsUpdatesWhenInterestChanges() async {
        await manager.connect()
        
        // Wait for connection
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 sec
        
        // Register interest in RPM
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode1(.rpm)], for: token)
        
        // Wait for initial data
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 sec
        
        XCTAssertNotNil(manager.stats(for: .mode1(.rpm)), "RPM stats should exist")
        
        // Change interest to speed
        PIDInterestRegistry.shared.replace(pids: [.mode1(.speed)], for: token)
        
        // Wait for new data
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 sec
        
        XCTAssertNotNil(manager.stats(for: .mode1(.speed)), "Speed stats should exist after interest change")
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    // MARK: - ConnectionState Equatable Tests
    
    func testConnectionStateEquality() {
        XCTAssertEqual(OBDConnectionManager.ConnectionState.disconnected, .disconnected)
        XCTAssertEqual(OBDConnectionManager.ConnectionState.connecting, .connecting)
        XCTAssertEqual(OBDConnectionManager.ConnectionState.connected, .connected)
        
        let error1 = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error2 = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        XCTAssertEqual(OBDConnectionManager.ConnectionState.failed(error1), .failed(error2))
        
        XCTAssertNotEqual(OBDConnectionManager.ConnectionState.disconnected, .connecting)
        XCTAssertNotEqual(OBDConnectionManager.ConnectionState.connected, .failed(error1))
    }
    
    func testConnectionStateIsFailed() {
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        let failedState = OBDConnectionManager.ConnectionState.failed(error)
        
        XCTAssertTrue(failedState.isFailed, "Failed state should return true for isFailed")
        XCTAssertFalse(OBDConnectionManager.ConnectionState.disconnected.isFailed)
        XCTAssertFalse(OBDConnectionManager.ConnectionState.connecting.isFailed)
        XCTAssertFalse(OBDConnectionManager.ConnectionState.connected.isFailed)
    }
    
    // MARK: - PIDStats Tests
    
    func testPIDStatsCreation() {
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 2500.0, unit: unit)
        
        let stats = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: measurement)
        
        XCTAssertEqual(stats.pid, .mode1(.rpm))
        XCTAssertEqual(stats.latest.value, 2500.0)
        XCTAssertEqual(stats.min, 2500.0)
        XCTAssertEqual(stats.max, 2500.0)
        XCTAssertEqual(stats.sampleCount, 1)
    }
    
    func testPIDStatsUpdate() {
        let unit = Unit(symbol: "rpm")
        let measurement1 = MeasurementResult(value: 2500.0, unit: unit)
        
        var stats = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: measurement1)
        
        let measurement2 = MeasurementResult(value: 3000.0, unit: unit)
        
        stats.update(with: measurement2)
        
        XCTAssertEqual(stats.latest.value, 3000.0, "Latest should be updated")
        XCTAssertEqual(stats.min, 2500.0, "Min should remain")
        XCTAssertEqual(stats.max, 3000.0, "Max should be updated")
        XCTAssertEqual(stats.sampleCount, 2, "Sample count should increment")
        
        let measurement3 = MeasurementResult(value: 2000.0, unit: unit)
        
        stats.update(with: measurement3)
        
        XCTAssertEqual(stats.latest.value, 2000.0, "Latest should be updated")
        XCTAssertEqual(stats.min, 2000.0, "Min should be updated")
        XCTAssertEqual(stats.max, 3000.0, "Max should remain")
        XCTAssertEqual(stats.sampleCount, 3, "Sample count should increment")
    }
    
    func testPIDStatsEquality() {
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 2500.0, unit: unit)
        
        let stats1 = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: measurement)
        let stats2 = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: measurement)
        
        XCTAssertEqual(stats1, stats2, "Stats with same values should be equal")
        
        var stats3 = stats1
        stats3.update(with: MeasurementResult(value: 3000.0, unit: unit))
        
        XCTAssertNotEqual(stats1, stats3, "Stats with different values should not be equal")
    }
}
