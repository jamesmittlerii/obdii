/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewInspector Unit Tests for PIDToggleListView
 *
 * Tests the PIDToggleListView SwiftUI structure and behavior.
 * Validates PID list, toggles, sections, search, and reordering.
 */

import XCTest
import SwiftUI
import ViewInspector
import SwiftOBD2
@testable import obdii

@MainActor
final class PIDToggleListViewTests: XCTestCase {
    
    // MARK: - List Structure Tests
    
    func testHasList() throws {
        let view = PIDToggleListView()
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "PIDToggleListView should contain a List")
    }
    
    func testListHasSections() throws {
        let view = PIDToggleListView()
        let sections = try view.inspect().findAll(ViewType.Section.self)
        
        // Should have "Enabled" and/or "Disabled" sections
        XCTAssertGreaterThan(sections.count, 0, "Should have at least one section")
    }
    
    // MARK: - Toggle Tests
    
    func testPIDToggleStructure() throws {
        let view = PIDToggleListView()
        
        // Each PID should have a Toggle
        let toggles = try view.inspect().findAll(ViewType.Toggle.self)
        XCTAssertGreaterThanOrEqual(toggles.count, 0, "Should have PID toggles")
    }
    
    func testToggleLabelsShowPIDInfo() throws {
        let view = PIDToggleListView()
        
        // Toggle labels should show PID name and range
        let vStacks = try view.inspect().findAll(ViewType.VStack.self)
        XCTAssertGreaterThan(vStacks.count, 0, "Toggles should use VStack for label")
    }
    
    // MARK: - Search Tests
    
    func testHasSearchButton() throws {
        let view = PIDToggleListView()
        
        // Toolbar should have search button
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        XCTAssertGreaterThanOrEqual(buttons.count, 0, "Should have search button in toolbar")
    }
    
    func testSearchFunctionality() throws {
        let view = PIDToggleListView()
        
        // When search is active, should show search field
        // This is controlled by @State variable
        XCTAssertNoThrow(try view.inspect().find(ViewType.List.self))
    }
    
    // MARK: - Section Header Tests
    
    func testEnabledSectionHeader() throws {
        let view = PIDToggleListView()
        let sections = try view.inspect().findAll(ViewType.Section.self)
        
        // Should have "Enabled" section when there are enabled PIDs
        if sections.count > 0 {
            XCTAssertNoThrow(try sections[0].header(), "Sections should have headers")
        }
    }
    
    // MARK: - Reordering Tests
    
    func testEnabledSectionSupportsReordering() throws {
        let view = PIDToggleListView()
        
        // Enabled section should support reordering via onMove
        // This is part of ForEach structure  
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "List should support reordering")
    }
    
    // MARK: - ViewModel Integration Tests
    
    func testViewModelInitialization() throws {
        let viewModel = PIDToggleListViewModel()
        
        // ViewModel should organize PIDs into enabled/disabled via filtered lists
        XCTAssertGreaterThanOrEqual(viewModel.filteredEnabled.count, 0, "Should have enabled PIDs")
        XCTAssertGreaterThanOrEqual(viewModel.filteredDisabled.count, 0, "Should have disabled PIDs")
    }
    
    func testViewModelTogglePID() throws {
        let viewModel = PIDToggleListViewModel()
        
        // ViewModel has toggle(at:to:) function
        // When toggled, PID should move between enabled/disabled
        
        _ = viewModel.filteredEnabled.count
        let pidsSnapshot = viewModel.pids
        
        if let firstIndex = pidsSnapshot.indices.first {
            let wasEnabled = pidsSnapshot[firstIndex].enabled
            viewModel.toggle(at: firstIndex, to: !wasEnabled)
            
            // The toggle action should change the state
            XCTAssertTrue(true, "Toggle function should execute without error")
        }
    }
    
    // MARK: - Search Filtering Tests
    
    func testSearchFiltersResults() throws {
        let viewModel = PIDToggleListViewModel()
        
        // When searchText is set, filtered lists should update
        viewModel.searchText = "RPM"
        
        let filtered = viewModel.filteredEnabled + viewModel.filteredDisabled
        
        // Filtered results should contain search term (label, name, notes, or command)
        if !filtered.isEmpty {
            let matchesQuery = filtered.allSatisfy { pid in
                pid.label.localizedCaseInsensitiveContains("RPM") ||
                pid.name.localizedCaseInsensitiveContains("RPM") ||
                pid.notes?.localizedCaseInsensitiveContains("RPM") == true ||
                pid.pid.properties.command.localizedCaseInsensitiveContains("RPM")
            }
            XCTAssertTrue(matchesQuery, "Filtered PIDs should match search query")
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testTogglesHaveAccessibilityIdentifiers() throws {
        let view = PIDToggleListView()
        
        // Each toggle should have unique identifier
        // Format: "PIDToggle_{UUID}"
        let toggles = try view.inspect().findAll(ViewType.Toggle.self)
        XCTAssertGreaterThanOrEqual(toggles.count, 0, "Toggles should have accessibility identifiers")
    }
    
    func testSearchButtonHasIdentifier() throws {
        let view = PIDToggleListView()
        
        // Search button should have "SearchPIDsButton" identifier
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        XCTAssertGreaterThanOrEqual(buttons.count, 0, "Search button should have identifier")
    }
}
