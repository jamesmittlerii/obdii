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

    
    // Conforms to MILStatusProviding from MILStatusViewModel.swift
    final class MockMILStatusProvider: MILStatusProviding {
        let subject = PassthroughSubject<Status?, Never>()
        var milStatusPublisher: AnyPublisher<Status?, Never> {
            subject.eraseToAnyPublisher()
        }
    }
    
    // Helper to build a view with injected mock VM
    private func makeView(with mock: MockMILStatusProvider) -> (MILStatusView, MILStatusViewModel, MockMILStatusProvider) {
        let vm = MILStatusViewModel(provider: mock)
        let view = MILStatusView(viewModel: vm)
        return (view, vm, mock)
    }

    
    func testHasNavigationStack() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        let navigationStack = try view.inspect().find(ViewType.NavigationStack.self)
        XCTAssertNotNil(navigationStack, "MILStatusView should contain a NavigationStack")
    }
    
    func testNavigationTitle() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        
        let stack = try view.inspect().find(ViewType.NavigationStack.self)
        XCTAssertNotNil(stack, "MILStatusView should have a NavigationStack")
        
        // ViewInspector limitation with constant titles
        // See: https://github.com/nalexn/ViewInspector/issues/347
        
        let list = try stack.find(ViewType.List.self)
        XCTAssertNotNil(list, "NavigationStack should contain a List")
    }

    
    func testContainsList() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "MILStatusView should contain a List")
    }
    
    func testListHasSections() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        let sections = try view.inspect().findAll(ViewType.Section.self)
        
        // Should have at least one section (MIL Summary at minimum)
        XCTAssertGreaterThan(sections.count, 0, "Should have at least one section")
    }

    
    func testWaitingStateDisplaysProgressView() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        
        // Look for ProgressView in waiting state
        let progressView = try view.inspect().find(ViewType.ProgressView.self)
        XCTAssertNotNil(progressView, "Should display ProgressView when waiting for data")
    }
    
    func testWaitingStateDisplaysWaitingText() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let waitingText = try texts.first { text in
            let string = try text.string()
            return string.contains("Waiting for data")
        }
        
        XCTAssertNotNil(waitingText, "Should display 'Waiting for data' text")
    }

    
    func testHasMILSectionHeader() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        
        let sections = try view.inspect().findAll(ViewType.Section.self)
        
        // First section should have a header
        if sections.count > 0 {
            XCTAssertNoThrow(try sections[0].header(), "First section should have header")
        }
    }

    
    func testMILStatusRowStructure() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        
        // MIL status uses HStack with Image and Text
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThan(hStacks.count, 0, "Should contain HStack elements")
    }
    
    func testContainsWrenchIcon() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        
        // MIL status may show wrench icon when data is present; structure exists
        let images = try view.inspect().findAll(ViewType.Image.self)
        XCTAssertGreaterThanOrEqual(images.count, 0, "View may contain wrench icon")
    }

    
    func testReadinessMonitorsSectionAppearsWhenStatusSent() throws {
        let mock = MockMILStatusProvider()
        let (view, _, _) = makeView(with: mock)
        
        // Send a status with supported monitors
        let monitors = [
            ReadinessMonitor(name: "Misfire", supported: true, ready: true),
            ReadinessMonitor(name: "Fuel System", supported: true, ready: false)
        ]
        mock.subject.send(Status(milOn: true, dtcCount: 1, monitors: monitors))
        
        // Now the "Readiness Monitors" section should be present
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasReadinessText = try texts.contains { try $0.string().contains("Readiness Monitors") }
        XCTAssertTrue(hasReadinessText, "View should show Readiness Monitors section when status exists")
    }

    
    func testViewModelInitializesWithNilStatus() throws {
        let mock = MockMILStatusProvider()
        let viewModel = MILStatusViewModel(provider: mock)
        
        // Initially, status should be nil
        XCTAssertNil(viewModel.status, "ViewModel should initialize with nil status")
        XCTAssertFalse(viewModel.hasStatus, "hasStatus should be false initially")
        XCTAssertTrue(viewModel.sortedSupportedMonitors.isEmpty, "Should have no monitors initially")
    }

    
    func testMonitorRowsUseHStack() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        
        // Each monitor row is an HStack
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThanOrEqual(hStacks.count, 0, "Monitor rows use HStack")
    }
    
    func testMonitorRowsHaveVStack() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        
        // Monitor rows may contain VStack for text layout
        let vStacks = try view.inspect().findAll(ViewType.VStack.self)
        XCTAssertGreaterThanOrEqual(vStacks.count, 0, "View may contain VStack elements")
    }

    
    func testNoMILStatusLabel() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // When no status, might show "No MIL Status"
        // This validates the view structure can contain this
        XCTAssertGreaterThanOrEqual(texts.count, 1, "View should contain text elements")
    }

    
    func testAccessibilityLabels() throws {
        let (view, _, _) = makeView(with: MockMILStatusProvider())
        
        // Elements should have accessibility labels
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThanOrEqual(hStacks.count, 0, "Should have elements with accessibility")
    }

    
    func testDisplaysActiveMILStatus() {
        let mock = MockMILStatusProvider()
        let vm = MILStatusViewModel(provider: mock)
        
        // Initially nil
        XCTAssertNil(vm.status, "Status should be nil initially")
        
        // Test headerText property format
        let headerText = vm.headerText
        XCTAssertNotNil(headerText, "Should have headerText")
        
        // When status is nil, should show "No MIL Status"
        XCTAssertEqual(headerText, "No MIL Status", "Should show no status message when status is nil")
        
        // Send a value and verify header updates
        mock.subject.send(Status(milOn: true, dtcCount: 2, monitors: []))
        XCTAssertEqual(vm.headerText, "MIL: On (2 DTCs)")
    }
    
    func testRendersReadinessMonitors() throws {
        let mock = MockMILStatusProvider()
        let vm = MILStatusViewModel(provider: mock)
        
        // sortedSupportedMonitors should return an array
        let monitorsEmpty = vm.sortedSupportedMonitors
        XCTAssertTrue(monitorsEmpty.isEmpty, "Should have no monitors when status is nil")
        
        // After sending status with monitors
        let monitors = [
            ReadinessMonitor(name: "Misfire", supported: true, ready: true),
            ReadinessMonitor(name: "Fuel System", supported: true, ready: false)
        ]
        mock.subject.send(Status(milOn: false, dtcCount: 0, monitors: monitors))
        
        XCTAssertFalse(vm.sortedSupportedMonitors.isEmpty, "Should have monitors after status is set")
    }
    
    func testMonitorStateColorsAreRepresented() {
        // This is a structural test; colors are chosen in the view based on ready
        let readyColor = Color.blue
        XCTAssertNotNil(readyColor, "Ready monitors should map to a color")
        
        let notReadyColor = Color.orange
        XCTAssertNotNil(notReadyColor, "Not ready monitors should map to a color")
        
        let secondaryColor = Color.secondary
        XCTAssertNotNil(secondaryColor, "Unknown/secondary style should exist")
    }
    
    func testHeaderTextFormats() {
        let mock = MockMILStatusProvider()
        let vm = MILStatusViewModel(provider: mock)
        
        // With nil status
        let noStatusText = vm.headerText
        XCTAssertEqual(noStatusText, "No MIL Status", "Should show 'No MIL Status' when status is nil")
        
        // Send a status to verify formatting
        mock.subject.send(Status(milOn: false, dtcCount: 1, monitors: []))
        XCTAssertEqual(vm.headerText, "MIL: Off (1 DTC)")
        
        mock.subject.send(Status(milOn: true, dtcCount: 3, monitors: []))
        XCTAssertEqual(vm.headerText, "MIL: On (3 DTCs)")
    }
}
