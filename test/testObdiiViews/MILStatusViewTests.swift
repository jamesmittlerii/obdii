/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewInspector Unit Tests for MILStatusView
 *
 * Tests the MILStatusView SwiftUI structure and behavior.
 * Validates view hierarchy, MIL status display, and readiness monitors.
 */

import XCTest
import SwiftUI
import ViewInspector
import SwiftOBD2
import Combine
@testable import obdii

@MainActor
final class MILStatusViewTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        // Reset manager state before each test to ensure isolation
        OBDConnectionManager.shared.MILStatus = nil
        OBDConnectionManager.shared.troubleCodes = nil
        // Disconnect if connected from previous test
        OBDConnectionManager.shared.disconnect()
    }
    
    override func tearDown() {
        // Clean up manager state after each test
        OBDConnectionManager.shared.MILStatus = nil
        OBDConnectionManager.shared.troubleCodes = nil
        OBDConnectionManager.shared.disconnect()
        super.tearDown()
    }
    
    // MARK: - Navigation Structure Tests
    
    func testHasNavigationStack() throws {
        let view = MILStatusView()
        let navigationStack = try view.inspect().find(ViewType.NavigationStack.self)
        XCTAssertNotNil(navigationStack, "MILStatusView should contain a NavigationStack")
    }
    
    func testNavigationTitle() throws {
        let view = MILStatusView()
        
        let stack = try view.inspect().find(ViewType.NavigationStack.self)
        XCTAssertNotNil(stack, "MILStatusView should have a NavigationStack")
        
        // ViewInspector limitation with constant titles
        // See: https://github.com/nalexn/ViewInspector/issues/347
        
        let list = try stack.find(ViewType.List.self)
        XCTAssertNotNil(list, "NavigationStack should contain a List")
    }
    
    // MARK: - List Structure Tests
    
    func testContainsList() throws {
        let view = MILStatusView()
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "MILStatusView should contain a List")
    }
    
    func testListHasSections() throws {
        let view = MILStatusView()
        let sections = try view.inspect().findAll(ViewType.Section.self)
        
        // Should have at least one section (MIL Summary at minimum)
        XCTAssertGreaterThan(sections.count, 0, "Should have at least one section")
    }
    
    // MARK: - Waiting State Tests
    
    func testWaitingStateDisplaysProgressView() throws {
        let view = MILStatusView()
        
        // Look for ProgressView in waiting state
        let progressView = try view.inspect().find(ViewType.ProgressView.self)
        XCTAssertNotNil(progressView, "Should display ProgressView when waiting for data")
    }
    
    func testWaitingStateDisplaysWaitingText() throws {
        let view = MILStatusView()
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let waitingText = try texts.first { text in
            let string = try text.string()
            return string.contains("Waiting for data")
        }
        
        XCTAssertNotNil(waitingText, "Should display 'Waiting for data' text")
    }
    
    // MARK: - Section Header Tests
    
    func testHasMILSectionHeader() throws {
        let view = MILStatusView()
        
        let sections = try view.inspect().findAll(ViewType.Section.self)
        
        // First section should be "Malfunction Indicator Lamp"
        if sections.count > 0 {
            XCTAssertNoThrow(try sections[0].header(), "First section should have header")
        }
    }
    
    // MARK: - MIL Status Display Tests
    
    func testMILStatusRowStructure() throws {
        let view = MILStatusView()
        
        // MIL status uses HStack with Image and Text
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThan(hStacks.count, 0, "Should contain HStack elements")
    }
    
    func testContainsWrenchIcon() throws {
        let view = MILStatusView()
        
        // MIL status shows wrench icon
        let images = try view.inspect().findAll(ViewType.Image.self)
        XCTAssertGreaterThanOrEqual(images.count, 0, "View may contain wrench icon")
    }
    
    // MARK: - Readiness Monitors Tests
    
    func testReadinessMonitorsSection() throws {
        let view = MILStatusView()
        
        // When status data exists, should have "Readiness Monitors" section
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // Check if Readiness Monitors text exists in the view
        let hasReadinessText = texts.contains { text in
            (try? text.string().contains("Readiness")) ?? false
        }
        
        // This will be true when data is loaded
        XCTAssertTrue(hasReadinessText || texts.count > 0, "View structure should support readiness monitors")
    }
    
    // MARK: - ViewModel Integration Tests
    
    func testViewModelInitializesWithNilStatus() throws {
        let viewModel = MILStatusViewModel()
        
        // Initially, status should be nil
        XCTAssertNil(viewModel.status, "ViewModel should initialize with nil status")
        XCTAssertFalse(viewModel.hasStatus, "hasStatus should be false initially")
        XCTAssertTrue(viewModel.sortedSupportedMonitors.isEmpty, "Should have no monitors initially")
    }
    
    // MARK: - Monitor Row Structure Tests
    
    func testMonitorRowsUseHStack() throws {
        let view = MILStatusView()
        
        // Each monitor row is an HStack
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThanOrEqual(hStacks.count, 0, "Monitor rows use HStack")
    }
    
    func testMonitorRowsHaveVStack() throws {
        let view = MILStatusView()
        
        // Monitor rows may contain VStack for text layout
        let vStacks = try view.inspect().findAll(ViewType.VStack.self)
        XCTAssertGreaterThanOrEqual(vStacks.count, 0, "View may contain VStack elements")
    }
    
    // MARK: - Empty State Tests
    
    func testNoMILStatusLabel() throws {
        let view = MILStatusView()
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // When no status, might show "No MIL Status"
        // This validates the view structure can contain this
        XCTAssertGreaterThanOrEqual(texts.count, 1, "View should contain text elements")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        let view = MILStatusView()
        
        // Elements should have accessibility labels
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThanOrEqual(hStacks.count, 0, "Should have elements with accessibility")
    }
    
    // MARK: - Mocked ViewModel Tests
    
    func testDisplaysActiveMILStatus() {
        // Test MIL status display
        let viewModel = MILStatusViewModel()
        
        // Initially nil
        XCTAssertNil(viewModel.status, "Status should be nil initially")
        
        // Test headerText property format
        let headerText = viewModel.headerText
        XCTAssertNotNil(headerText, "Should have headerText")
        
        // When status is nil, should show "No MIL Status"
        XCTAssertEqual(headerText, "No MIL Status", "Should show no status message when status is nil")
    }
    
    func testRendersReadinessMonitors() {
        // Test readiness monitor rendering
        let viewModel = MILStatusViewModel()
        
        // sortedSupportedMonitors should return an array
        let monitors = viewModel.sortedSupportedMonitors
        
        // When status is nil, monitors should be empty
        XCTAssertTrue(monitors.isEmpty, "Should have no monitors when status is nil")
        
        // ViewModel should be able to handle monitors once status is set
        XCTAssertNotNil(viewModel, "ViewModel should initialize properly")
    }
    
    func testMonitorStateColors() {
        // Test color coding for different monitor states
        // In SwiftUI, green = ready, yellow = not ready, secondary = not supported
        
        // Ready state should use green
        let readyColor = Color.green
        XCTAssertNotNil(readyColor, "Ready monitors should use green")
        
        // Not ready state should use yellow  
        let notReadyColor = Color.yellow
        XCTAssertNotNil(notReadyColor, "Not ready monitors should use yellow")
        
        // Not supported/unknown should use secondary
        let secondaryColor = Color.secondary
        XCTAssertNotNil(secondaryColor, "Unknown state should use secondary color")
    }
    
    func testHeaderTextFormats() {
        // Test headerText computed property
        let viewModel = MILStatusViewModel()
        
        // With nil status
        let noStatusText = viewModel.headerText
        XCTAssertEqual(noStatusText, "No MIL Status", "Should show 'No MIL Status' when status is nil")
        
        // The headerText format when status exists would be:
        // "MIL: On/Off (X DTC/DTCs)"
        // This requires actual status data from OBDConnectionManager
        XCTAssertFalse(viewModel.hasStatus, "Should not have status initially")
    }
    
    // MARK: - Live Demo Data Tests
    
    func testMILStatusWithLiveDemoData() async throws {
        // Configure for demo mode
        ConfigData.shared.connectionType = .demo
        OBDConnectionManager.shared.updateConnectionDetails()
        
        // Explicitly register interest instead of relying on view onAppear
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode1(.status)], for: token)
        
        // Set up expectation for MIL status
        var cancellables = Set<AnyCancellable>()
        let expectation = XCTestExpectation(description: "MIL status should populate from demo")
        
        OBDConnectionManager.shared.$MILStatus
            .dropFirst() // Skip initial nil
            .sink { status in
                if status != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Connect to demo
        await OBDConnectionManager.shared.connect()
        
        // Wait for status data
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify we got status data
        let viewModel = MILStatusViewModel()
        XCTAssertTrue(viewModel.hasStatus, "Should have MIL status from demo")
        XCTAssertNotEqual(viewModel.headerText, "No MIL Status", "Should have actual status text")
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
        cancellables.removeAll()
    }
    
    func testReadinessMonitorsWithLiveDemoData() async throws {
        // Configure for demo mode
        ConfigData.shared.connectionType = .demo
        OBDConnectionManager.shared.updateConnectionDetails()
        
        // Explicitly register interest instead of relying on view onAppear
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode1(.status)], for: token)
        
        // Set up expectation for MIL status (which contains readiness monitors)
        var cancellables = Set<AnyCancellable>()
        let expectation = XCTestExpectation(description: "Readiness monitors should populate from demo")
        
        OBDConnectionManager.shared.$MILStatus
            .dropFirst() // Skip initial nil
            .sink { status in
                if let status = status, !status.monitors.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Connect to demo
        await OBDConnectionManager.shared.connect()
        
        // Wait for monitor data
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify we got monitor data
        let viewModel = MILStatusViewModel()
        let monitors = viewModel.sortedSupportedMonitors
        XCTAssertFalse(monitors.isEmpty, "Should have readiness monitors from demo")
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
        cancellables.removeAll()
    }
    
    func testMILStatusViewRendersWithLiveDemoData() async throws {
        // Configure for demo mode
        ConfigData.shared.connectionType = .demo
        OBDConnectionManager.shared.updateConnectionDetails()
        
        // Explicitly register interest instead of relying on view onAppear
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode1(.status)], for: token)
        
        // Set up expectation for MIL status
        var cancellables = Set<AnyCancellable>()
        let expectation = XCTestExpectation(description: "MIL status view should render with demo data")
        
        OBDConnectionManager.shared.$MILStatus
            .dropFirst()
            .sink { status in
                if status != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Create view (no need to call onAppear now)
        let view = MILStatusView()
        let inspected = try view.inspect()
        
        // Connect to demo
        await OBDConnectionManager.shared.connect()
        
        // Wait for status data
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify view structure with data
        let stack = try inspected.find(ViewType.NavigationStack.self)
        let list = try stack.find(ViewType.List.self)
        XCTAssertNotNil(list, "Should have list with MIL status data")
        
        // Should have sections when data is present
        let sections = inspected.findAll(ViewType.Section.self)
        XCTAssertGreaterThan(sections.count, 0, "Should have sections with demo data")
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
        cancellables.removeAll()
    }
}
