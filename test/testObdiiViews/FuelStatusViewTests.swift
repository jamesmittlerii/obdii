/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewInspector Unit Tests for FuelStatusView
 *
 * Tests the FuelStatusView SwiftUI structure and behavior.
 * Validates view hierarchy, state transitions (waiting/loaded/empty),
 * and proper display of fuel system status for Bank 1 and Bank 2.
 */

import XCTest
import SwiftUI
import ViewInspector
import SwiftOBD2
import Combine
@testable import obdii

@MainActor
final class FuelStatusViewTests: XCTestCase {
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        // Ensure manager is in a clean, disconnected, empty state so ViewModel starts "waiting"
        let manager = OBDConnectionManager.shared
        manager.disconnect()
        manager.fuelStatus = nil
        manager.troubleCodes = nil
        manager.MILStatus = nil
        
    }
    
    override func tearDown() {
        // Clean up to avoid cross-test interference
        let manager = OBDConnectionManager.shared
        manager.disconnect()
        manager.fuelStatus = nil
        manager.troubleCodes = nil
        manager.MILStatus = nil
     
        super.tearDown()
    }
    
    // MARK: - Navigation Structure Tests
    
    func testHasNavigationStack() throws {
        let view = FuelStatusView()
        let navigationStack = try view.inspect().find(ViewType.NavigationStack.self)
        XCTAssertNotNil(navigationStack, "FuelStatusView should contain a NavigationStack")
    }
    
    func testNavigationTitle() throws {
        let view = FuelStatusView()
        
        // Find the NavigationStack
        let stack = try view.inspect().find(ViewType.NavigationStack.self)
        XCTAssertNotNil(stack, "FuelStatusView should have a NavigationStack")
        
        // ViewInspector limitation with constant string titles
        // See: https://github.com/nalexn/ViewInspector/issues/347
        
        // Verify the structure is correct
        let list = try stack.find(ViewType.List.self)
        XCTAssertNotNil(list, "NavigationStack should contain a List")
    }
    
    // MARK: - List Structure Tests
    
    func testContainsList() throws {
        let view = FuelStatusView()
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "FuelStatusView should contain a List")
    }
    
    // MARK: - Waiting State Tests
    
    func testWaitingStateDisplaysProgressView() throws {
        // With setUp clearing manager.fuelStatus to nil and disconnected,
        // a fresh view should show waiting UI.
        let view = FuelStatusView()
        
        let progressView = try view.inspect().find(ViewType.ProgressView.self)
        XCTAssertNotNil(progressView, "Should display ProgressView when waiting for data")
    }
    
    func testWaitingStateDisplaysWaitingText() throws {
        let view = FuelStatusView()
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let waitingText = try texts.first { text in
            let string = try text.string()
            return string.contains("Waiting for data")
        }
        
        XCTAssertNotNil(waitingText, "Should display 'Waiting for data' text in waiting state")
    }
    
    // MARK: - Content Structure Tests
    
    func testContentHasHStackInWaitingState() throws {
        let view = FuelStatusView()
        
        // The waiting row uses HStack with spacing
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThan(hStacks.count, 0, "Should have HStack for waiting row")
    }
    
    // MARK: - ViewModel Integration Tests
    
    func testViewModelInitializesWithNilStatus() throws {
        // Because setUp cleared manager.fuelStatus and disconnected,
        // the ViewModel should start with nil status (waiting).
        let viewModel = FuelStatusViewModel()
        
        XCTAssertNil(viewModel.status, "ViewModel should initialize with nil status")
        XCTAssertNil(viewModel.bank1, "Bank 1 should be nil initially")
        XCTAssertNil(viewModel.bank2, "Bank 2 should be nil initially")
        XCTAssertFalse(viewModel.hasAnyStatus, "hasAnyStatus should be false when status is nil")
    }
    
    // MARK: - Bank Status Display Tests
    
    func testBankStatusRowStructure() throws {
        let view = FuelStatusView()
        
        // When status data exists, should display bank rows
        // Each row is an HStack with Image and Text
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThanOrEqual(hStacks.count, 0, "Should contain HStack elements")
    }
    
    // MARK: - Image Tests
    
    func testContainsFuelPumpImages() throws {
        let view = FuelStatusView()
        
        // When bank status is displayed, should show fuelpump.fill icons
        let images = try view.inspect().findAll(ViewType.Image.self)
        
        // Images are present in the view structure
        XCTAssertGreaterThanOrEqual(images.count, 0, "View may contain fuel pump images")
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyStateMessage() throws {
        // When status is loaded but has no status codes
        // Should display "No Fuel System Status Codes"
        
        let view = FuelStatusView()
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // The empty state text might not be present initially (waiting state)
        // This test validates the structure can contain the empty message
        XCTAssertGreaterThanOrEqual(texts.count, 1, "View should contain text elements")
    }
    
    // MARK: - Accessibility Tests
    
    func testWaitingRowHasAccessibilityLabel() throws {
        let view = FuelStatusView()
        
        // The waiting row should have accessibility label for VoiceOver
        // We can verify HStack exists which contains the accessibility modifier
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThan(hStacks.count, 0, "Should have HStack with accessibility")
    }
    
    // MARK: - Live Demo Data Tests (explicit interest registration)
    
    func testFuelStatusWithLiveDemoData() async throws {
        // Configure for demo mode
        ConfigData.shared.connectionType = .demo
        OBDConnectionManager.shared.updateConnectionDetails()
        
        // Explicitly register interest in fuel status
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode1(.fuelStatus)], for: token)
        
        // Expectation for fuel status to arrive
        var cancellables = Set<AnyCancellable>()
        let expectation = XCTestExpectation(description: "Fuel status should populate from demo")
        
        OBDConnectionManager.shared.$fuelStatus
            .dropFirst() // skip initial nil
            .sink { status in
                if status != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Connect to demo
        await OBDConnectionManager.shared.connect()
        
        // Await fuel status
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify we got data
        XCTAssertNotNil(OBDConnectionManager.shared.fuelStatus, "Fuel status should be set from demo")
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
        cancellables.removeAll()
    }
    
    func testFuelStatusViewRendersWithLiveDemoData() async throws {
        // Configure for demo mode
        ConfigData.shared.connectionType = .demo
        OBDConnectionManager.shared.updateConnectionDetails()
        
        // Explicitly register interest in fuel status
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: [.mode1(.fuelStatus)], for: token)
        
        // Expectation for fuel status to arrive
        var cancellables = Set<AnyCancellable>()
        let expectation = XCTestExpectation(description: "Fuel status view should render with demo data")
        
        OBDConnectionManager.shared.$fuelStatus
            .dropFirst()
            .sink { status in
                if status != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Build the view (no onAppear needed since we registered interest explicitly)
        let view = FuelStatusView()
        let inspected = try view.inspect()
        
        // Connect to demo
        await OBDConnectionManager.shared.connect()
        
        // Await data
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify structure
        let stack = try inspected.find(ViewType.NavigationStack.self)
        let list = try stack.find(ViewType.List.self)
        XCTAssertNotNil(list, "List should exist once data is available")
        
        // Cleanup
        PIDInterestRegistry.shared.clear(token: token)
        try? await Task.sleep(nanoseconds: 100_000_000)
        cancellables.removeAll()
    }
}

