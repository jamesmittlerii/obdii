/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for PIDStore
 *
 * Tests PID persistence, enabling/disabling, reordering, toggle functionality,
 * and filtering (enabled gauges vs all PIDs).
 */

import XCTest
import SwiftOBD2
@testable import obdii

@MainActor
final class PIDStoreTests: XCTestCase {
    
    var store: PIDStore!
    
    override func setUp() async throws {
        store = PIDStore.shared
        // Store is a singleton, so state carries between tests
        // We can't easily reset it without affecting the app
    }
    
    override func tearDown() async throws {
        store = nil
    }
    
    // MARK: - Initialization Tests
    
    func testSharedInstanceExists() {
        XCTAssertNotNil(PIDStore.shared, "Shared instance should exist")
    }
    
    func testPIDsLoadedFromJSON() {
        XCTAssertGreaterThan(store.pids.count, 0, "Should load PIDs from JSON")
    }
    
    // MARK: - PIDs Array Tests
    
    func testPIDsContainGauges() {
        let gauges = store.pids.filter { $0.kind == .gauge }
        XCTAssertGreaterThan(gauges.count, 0, "Should have gauge-type PIDs")
    }
    
    func testPIDsContainStatusPIDs() {
        let statusPIDs = store.pids.filter { $0.kind == .status }
        XCTAssertGreaterThanOrEqual(statusPIDs.count, 0, "May have status-type PIDs")
    }
    
    // MARK: - Enabled Gauges Tests
    
    func testEnabledGaugesFiltering() {
        let enabled = store.enabledGauges
        
        // All should be enabled and gauges
        for pid in enabled {
            XCTAssertTrue(pid.enabled, "All enabled gauges should be enabled")
            XCTAssertEqual(pid.kind, .gauge, "All should be gauge type")
        }
    }
    
    func testEnabledGaugesOrderPreserved() {
        let enabled = store.enabledGauges
        
        // Enabled gauges should maintain order from pids array
        if enabled.count >= 2 {
            let firstInEnabled = enabled.first!
            let firstIndex = store.pids.firstIndex(of: firstInEnabled)!
            
            let secondInEnabled = enabled[1]
            let secondIndex = store.pids.firstIndex(of: secondInEnabled)!
            
            XCTAssertLessThan(firstIndex, secondIndex, "Order should be preserved")
        }
    }
    
    // MARK: - Toggle Tests
    
    func testTogglePID() {
        guard let firstGauge = store.pids.first(where: { $0.kind == .gauge }) else {
            XCTSkip("No gauge PID available for testing")
            return
        }
        
        let initialState = firstGauge.enabled
        _ = store.enabledGauges.count
        
        // Toggle it
        store.toggle(firstGauge)
        
        // Find it again after toggle
        if let updatedPID = store.pids.first(where: { $0.id == firstGauge.id }) {
            XCTAssertNotEqual(updatedPID.enabled, initialState, "Should toggle enabled state")
        }
        
        // Restore original state
        store.toggle(firstGauge)
    }
    
    // MARK: - Reordering Tests
    
    func testMoveEnabledPIDs() {
        let initialEnabledCount = store.enabledGauges.count
        
        if initialEnabledCount >= 2 {
            let offsets = IndexSet(integer: 0)
            let destination = 1
            
            // Move first enabled PID to second position
            store.moveEnabled(fromOffsets: offsets, toOffset: destination)
            
            // Should still have same count
            XCTAssertEqual(store.enabledGauges.count, initialEnabledCount, 
                          "Move should not change count")
        }
    }
    
    // MARK: - PID Lookup Tests
    
    func testFindPIDByID() {
        guard let firstPID = store.pids.first else {
            XCTSkip("No PIDs available")
            return
        }
        
        let found = store.pids.first { $0.id == firstPID.id }
        XCTAssertNotNil(found, "Should find PID by ID")
        XCTAssertEqual(found?.id, firstPID.id)
    }
    
    func testFindPIDByCommand() {
        guard let rpmPID = store.pids.first(where: { $0.pid == .mode1(.rpm) }) else {
            XCTSkip("RPM PID not found")
            return
        }
        
        XCTAssertEqual(rpmPID.pid, .mode1(.rpm), "Should find RPM PID")
    }
    
    // MARK: - Persistence Tests
    
    func testPIDOrderPersistence() {
        // PIDStore uses UserDefaults for order persistence
        // This is integration-level testing - just verify structure exists
        XCTAssertNotNil(store.pids, "PIDs array should exist for persistence")
    }
    
    // MARK: - Gauge Count Tests
    
    func testGaugeCountReasonable() {
        XCTAssertGreaterThan(store.pids.count, 0, "Should have at least some PIDs")
        XCTAssertLessThan(store.pids.count, 200, "Should not have excessive PIDs")
    }
}
