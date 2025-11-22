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
import Combine
@testable import obdii

// Local mock provider for MIL status publisher
final class MockMILStatusProvider: MILStatusProviding {
    let subject = PassthroughSubject<Status?, Never>()
    var milStatusPublisher: AnyPublisher<Status?, Never> {
        subject.eraseToAnyPublisher()
    }
}

@MainActor
final class MILStatusViewModelTests: XCTestCase {
    
    var viewModel: MILStatusViewModel!
    var mockProvider: MockMILStatusProvider!
    
    override func setUp() async throws {
        mockProvider = MockMILStatusProvider()
        viewModel = MILStatusViewModel(provider: mockProvider)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockProvider = nil
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
    
    func testStatusUpdatesFromProvider() {
        XCTAssertNil(viewModel.status)
        let monitors: [ReadinessMonitor] = [
            ReadinessMonitor(name: "Misfire", supported: true, ready: true),
            ReadinessMonitor(name: "Fuel System", supported: true, ready: false)
        ]
        let status = Status(milOn: true, dtcCount: 2, monitors: monitors)
        
        mockProvider.subject.send(status)
        
        XCTAssertNotNil(viewModel.status, "Status should update from provider")
        XCTAssertTrue(viewModel.hasStatus, "hasStatus should be true after update")
        XCTAssertEqual(viewModel.headerText, "MIL: On (2 DTCs)")
    }
    
    func testSortedSupportedMonitorsInitiallyEmpty() {
        XCTAssertTrue(viewModel.sortedSupportedMonitors.isEmpty, 
                     "Sorted monitors should be empty initially")
    }
    
    // MARK: - Monitor Sorting Tests
    
    func testMonitorSortingLogic() {
        // Create supported monitors with varying readiness and names
        let monitors: [ReadinessMonitor] = [
            ReadinessMonitor(name: "B Monitor", supported: true, ready: true),
            ReadinessMonitor(name: "A Monitor", supported: true, ready: false),
            ReadinessMonitor(name: "C Monitor", supported: true, ready: false),
            ReadinessMonitor(name: "Z Unsupported", supported: false, ready: true)
        ]
        let status = Status(milOn: false, dtcCount: 0, monitors: monitors)
        mockProvider.subject.send(status)
        
        let sorted = viewModel.sortedSupportedMonitors
        // Unsupported should be filtered out
        XCTAssertFalse(sorted.contains { $0.name == "Z Unsupported" }, "Unsupported monitors should be filtered")
        // Not Ready first, then Ready; within each group, alphabetical
        let names = sorted.map { $0.name }
        XCTAssertEqual(names, ["A Monitor", "C Monitor", "B Monitor"])
    }
    
    // MARK: - MIL Status Structure Tests
    
    func testMILStatusProperties() {
        XCTAssertNil(viewModel.status, "Status should be nil initially")
        
        let status = Status(milOn: false, dtcCount: 1, monitors: [])
        mockProvider.subject.send(status)
        
        XCTAssertNotNil(viewModel.status)
        XCTAssertEqual(viewModel.headerText, "MIL: Off (1 DTC)")
    }
    
    // MARK: - Monitor Structure Tests
    
    func testMonitorHasName() {
        let monitors: [ReadinessMonitor] = [
            ReadinessMonitor(name: "Alpha", supported: true, ready: true),
            ReadinessMonitor(name: "Beta", supported: true, ready: false)
        ]
        mockProvider.subject.send(Status(milOn: true, dtcCount: 0, monitors: monitors))
        
        for monitor in viewModel.sortedSupportedMonitors {
            XCTAssertFalse(monitor.name.isEmpty, "Monitor should have a name")
        }
    }
    
    // MARK: - Header Text Formatting Tests
    
    func testHeaderTextWithNoStatus() {
        XCTAssertNil(viewModel.status, "Status should be nil initially")
        let headerText = viewModel.headerText
        XCTAssertEqual(headerText, "No MIL Status", "Should show 'No MIL Status' when status is nil")
    }
    
    func testHeaderTextFormattingLogic() {
        let testCases: [(milOn: Bool, dtcCount: Int, expected: String)] = [
            (false, 0, "MIL: Off (0 DTCs)"),
            (true, 1, "MIL: On (1 DTC)"),
            (true, 3, "MIL: On (3 DTCs)"),
            (false, 5, "MIL: Off (5 DTCs)")
        ]
        
        for (milOn, dtcCount, expected) in testCases {
            mockProvider.subject.send(Status(milOn: milOn, dtcCount: dtcCount, monitors: []))
            XCTAssertEqual(viewModel.headerText, expected, "Should format correctly for milOn=\(milOn), dtcCount=\(dtcCount)")
        }
    }
    
    // MARK: - Sorted Monitors Tests
    
    func testSortedSupportedMonitorsIsArray() {
        let monitors = viewModel.sortedSupportedMonitors
        XCTAssertNotNil(monitors, "Should return monitors array")
    }
    
    // MARK: - Callback Tests
    
    func testOnChangedCallback() {
        var callbackFired = false
        viewModel.onChanged = {
            callbackFired = true
        }
        
        // Drive a change via the mock
        mockProvider.subject.send(Status(milOn: true, dtcCount: 0, monitors: []))
        
        // Allow main actor queue to process sink
        let exp = expectation(description: "Callback fired")
        DispatchQueue.main.async {
            XCTAssertTrue(callbackFired, "onChanged callback should set the flag when status updates")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}
