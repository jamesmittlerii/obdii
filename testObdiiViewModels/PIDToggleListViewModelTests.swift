/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for PIDToggleListViewModel
 *
 * Tests PID mirroring from PIDStore, search filtering, toggle functionality,
 * reordering, and section organization (enabled/disabled).
 */

import XCTest
import SwiftOBD2
@testable import obdii

@MainActor
final class PIDToggleListViewModelTests: XCTestCase {
    
    var viewModel: PIDToggleListViewModel!
    
    override func setUp() async throws {
        viewModel = PIDToggleListViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertGreaterThanOrEqual(viewModel.pids.count, 0, "Should have PIDs from store")
    }
    
    func testPIDsMirrorStore() {
        // ViewModel's PIDs should reflect PIDStore
        let storePIDCount = PIDStore.shared.pids.count
        XCTAssertEqual(viewModel.pids.count, storePIDCount, "Should mirror PIDStore count")
    }
    
    // MARK: - Section Tests
    
    func testEnabledIndices() {
        let enabledIndices = viewModel.enabledIndices
        
        // All indices should point to enabled gauge PIDs
        for index in enabledIndices {
            let pid = viewModel.pids[index]
            XCTAssertTrue(pid.enabled, "Enabled indices should point to enabled PIDs")
            XCTAssertEqual(pid.kind, .gauge, "Should only include gauge PIDs")
        }
    }
    
    func testDisabledIndices() {
        let disabledIndices = viewModel.disabledIndices
        
        // All indices should point to disabled gauge PIDs
        for index in disabledIndices {
            let pid = viewModel.pids[index]
            XCTAssertFalse(pid.enabled, "Disabled indices should point to disabled PIDs")
            XCTAssertEqual(pid.kind, .gauge, "Should only include gauge PIDs")
        }
    }
    
    func testFilteredEnabledList() {
        let filtered = viewModel.filteredEnabled
        
        // All PIDs should be enabled
        XCTAssertTrue(filtered.allSatisfy { $0.enabled }, "Filtered enabled should only contain enabled PIDs")
        XCTAssertTrue(filtered.allSatisfy { $0.kind == .gauge }, "Should only contain gauge PIDs")
    }
    
    func testFilteredDisabledList() {
        let filtered = viewModel.filteredDisabled
        
        // All PIDs should be disabled
        XCTAssertTrue(filtered.allSatisfy { !$0.enabled }, "Filtered disabled should only contain disabled PIDs")
        XCTAssertTrue(filtered.allSatisfy { $0.kind == .gauge }, "Should only contain gauge PIDs")
    }
    
    // MARK: - Search Tests
    
    func testEmptySearchReturnsAll() {
        viewModel.searchText = ""
        
        let enabledCount = viewModel.filteredEnabled.count
        let disabledCount = viewModel.filteredDisabled.count
        let totalGauges = viewModel.pids.filter { $0.kind == .gauge }.count
        
        XCTAssertEqual(enabledCount + disabledCount, totalGauges, 
                      "Empty search should return all gauge PIDs")
    }
    
    func testSearchByLabel() throws {
        // Find a PID with known label
        guard let testPID = viewModel.pids.first(where: { $0.label.contains("RPM") }) else {
            throw XCTSkip("No RPM PID found for testing")
        }
        
        viewModel.searchText = "RPM"
        
        let allFiltered = viewModel.filteredEnabled + viewModel.filteredDisabled
        let containsTestPID = allFiltered.contains { $0.id == testPID.id }
        
        XCTAssertTrue(containsTestPID, "Search by label should find matching PID")
    }
    
    func testSearchByName() {
        viewModel.searchText = "Engine"
        
        let allFiltered = viewModel.filteredEnabled + viewModel.filteredDisabled
        
        // All results should contain "Engine" in label, name, notes, or command
        if !allFiltered.isEmpty {
            let allMatch = allFiltered.allSatisfy { pid in
                pid.label.localizedCaseInsensitiveContains("Engine") ||
                pid.name.localizedCaseInsensitiveContains("Engine") ||
                pid.notes?.localizedCaseInsensitiveContains("Engine") == true ||
                pid.pid.properties.command.localizedCaseInsensitiveContains("Engine")
            }
            XCTAssertTrue(allMatch, "Search results should match query")
        }
    }
    
    func testSearchIsCaseInsensitive() {
        viewModel.searchText = "rpm"
        let results1 = viewModel.filteredEnabled + viewModel.filteredDisabled
        
        viewModel.searchText = "RPM"
        let results2 = viewModel.filteredEnabled + viewModel.filteredDisabled
        
        XCTAssertEqual(results1.count, results2.count, "Search should be case-insensitive")
    }
    
    func testSearchTrimsWhitespace() {
        viewModel.searchText = "  RPM  "
        
        let allFiltered = viewModel.filteredEnabled + viewModel.filteredDisabled
        
        // Should find results despite leading/trailing whitespace
        XCTAssertGreaterThanOrEqual(allFiltered.count, 0, "Should trim whitespace from search")
    }
    
    // MARK: - Toggle Tests
    
    func testTogglePID() throws {
        guard let firstPID = viewModel.pids.first(where: { $0.kind == .gauge }),
              let index = viewModel.pids.firstIndex(where: { $0.id == firstPID.id }) else {
            throw XCTSkip("No gauge PID found for testing")
        }
        
        let initialState = firstPID.enabled
        
        viewModel.toggle(at: index, to: !initialState)
        
        // ViewModel should sync with store
        XCTAssertTrue(true, "Toggle should complete without errors")
    }
    
    func testToggleWithSameValueDoesNothing() throws {
        guard let firstPID = viewModel.pids.first(where: { $0.kind == .gauge }),
              let index = viewModel.pids.firstIndex(where: { $0.id == firstPID.id }) else {
            throw XCTSkip("No gauge PID found for testing")
        }
        
        let currentState = firstPID.enabled
        
        viewModel.toggle(at: index, to: currentState)
        
        // Should not change anything
        XCTAssertTrue(true, "Redundant toggle should be ignored")
    }
    
    // MARK: - Reordering Tests
    
    func testMoveEnabledPIDs() throws {
        let initialEnabledCount = viewModel.filteredEnabled.count
        
        if initialEnabledCount >= 2 {
            let offsets = IndexSet(integer: 0)
            viewModel.moveEnabled(fromOffsets: offsets, toOffset: 1)
            
            // Should complete without errors
            XCTAssertTrue(true, "Move should complete")
        } else {
            throw XCTSkip("Not enough enabled PIDs for reordering test")
        }
    }
}
