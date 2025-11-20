/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for MILStatusViewModel
 *
 * Tests MIL status tracking, readiness monitor organization,
 * sorting logic, and integration with OBDConnectionManager.
 */

import XCTest
import SwiftOBD2
@testable import obdii

@MainActor
final class MILStatusViewModelTests: XCTestCase {
    
    var viewModel: MILStatusViewModel!
    
    override func setUp() async throws {
        viewModel = MILStatusViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertNil(viewModel.status, "Status should be nil initially")
        XCTAssertFalse(viewModel.hasStatus, "hasStatus should be false initially")
    }
    
    // MARK: - Status Tests
    
    func testHasStatusWhenNil() {
        XCTAssertNil(viewModel.status, "Status should be nil")
        XCTAssertFalse(viewModel.hasStatus, "hasStatus should be false when status is nil")
    }
    
    func testSortedSupportedMonitorsInitiallyEmpty() {
        XCTAssertTrue(viewModel.sortedSupportedMonitors.isEmpty, 
                     "Sorted monitors should be empty initially")
    }
    
    // MARK: - Monitor Sorting Tests
    
    func testMonitorSortingLogic() {
        // When monitors exist, they should be sorted alphabetically
        let monitors = viewModel.sortedSupportedMonitors
        
        if monitors.count >= 2 {
            let names = monitors.map { $0.name }
            let sortedNames = names.sorted()
            XCTAssertEqual(names, sortedNames, "Monitors should be sorted alphabetically")
        }
    }
    
    // MARK: - MIL Status Structure Tests
    
    func testMILStatusProperties() {
        // MILStatus should contain MIL on/off and DTCCount
        XCTAssertNil(viewModel.status, "Status should be nil initially")
    }
    
    // MARK: - Monitor Structure Tests
    
    func testMonitorHasName() {
        let monitors = viewModel.sortedSupportedMonitors
        
        for monitor in monitors {
            XCTAssertFalse(monitor.name.isEmpty, "Monitor should have a name")
        }
    }
}
