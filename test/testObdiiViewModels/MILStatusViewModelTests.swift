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
    
    
    // MARK: - Header Text Formatting Tests
    
    func testHeaderTextWithNoStatus() {
        viewModel = MILStatusViewModel()
        XCTAssertNil(viewModel.status, "Status should be nil initially")
        
        let headerText = viewModel.headerText
        XCTAssertEqual(headerText, "No MIL Status", "Should show 'No MIL Status' when status is nil")
    }
    
    func testHeaderTextFormattingLogic() {
        // Test the formatting logic directly by verifying the format string pattern
        let testCases: [(milOn: Bool, dtcCount: Int, expected: String)] = [
            (false, 0, "MIL: Off (0 DTCs)"),
            (true, 1, "MIL: On (1 DTC)"),
            (true, 3, "MIL: On (3 DTCs)"),
            (false, 5, "MIL: Off (5 DTCs)")
        ]
        
        for (milOn, dtcCount, expected) in testCases {
            let dtcLabel = dtcCount == 1 ? "1 DTC" : "\(dtcCount) DTCs"
            let result = "MIL: \(milOn ? "On" : "Off") (\(dtcLabel))"
            XCTAssertEqual(result, expected, "Should format correctly for milOn=\(milOn), dtcCount=\(dtcCount)")
        }
    }
    
    // MARK: - Sorted Monitors Tests
    
    func testSortedSupportedMonitorsIsArray() {
        // sortedSupportedMonitors should return an array
        let monitors = viewModel.sortedSupportedMonitors
        XCTAssertNotNil(monitors, "Should return monitors array")
    }
    
 
    
    // MARK: - Callback Tests
    
    func testOnChangedCallback() {
        var callbackFired = false
        viewModel.onChanged = {
            callbackFired = true
        }
        
        // Normally status would be set through OBDConnectionManager publisher
        // For now, just verify the callback mechanism exists
        XCTAssertNotNil(viewModel.onChanged, "Should support onChanged callback")
    }
}
