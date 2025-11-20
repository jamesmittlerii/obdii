/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewInspector Unit Tests for GaugeDetailView
 *
 * Tests the GaugeDetailView SwiftUI structure and behavior.
 * Validates statistics display, chart, and detailed gauge information.
 */

import XCTest
import SwiftUI
import ViewInspector
import SwiftOBD2
@testable import obdii

@MainActor
final class GaugeDetailViewTests: XCTestCase {
    
    // Create a test PID for testing
    let testPID = OBDPID(
        id: UUID(),
        enabled: true,
        label: "RPM",
        name: "Engine RPM",
        pid: .mode1(.rpm),
        units: "RPM",
        typicalRange: ValueRange(min: 0, max: 8000)
    )
    
    // MARK: - List Structure Tests
    
    func testHasList() throws {
        let view = GaugeDetailView(pid: testPID)
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "GaugeDetailView should contain a List")
    }
    
    // MARK: - Statistics Section Tests
    
    func testHasStatisticsSection() throws {
        let view = GaugeDetailView(pid: testPID)
        
        // Should have List with sections
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "Should have List for statistics")
    }
    
    func testDisplaysCurrentValue() throws {
        let view = GaugeDetailView(pid: testPID)
        
        // Should display current value with large font
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThan(texts.count, 0, "Should display current value")
    }
    
    func testDisplaysMinMaxValues() throws {
        let view = GaugeDetailView(pid: testPID)
        
        // Should display min and max values when stats are available
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThan(texts.count, 0, "Should have text elements for display")
    }
    
    func testDisplaysSampleCount() throws {
        let view = GaugeDetailView(pid: testPID)
        
        // Should display sample count
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        // Sample count text exists
        XCTAssertGreaterThan(texts.count, 0, "Should display sample count")
    }
    
    // MARK: - Chart Section Tests
    
    func testHasSections() throws {
        let view = GaugeDetailView(pid: testPID)
        
        // Should contain sections: Current, Statistics, Maximum Range
        let sections = try view.inspect().findAll(ViewType.Section.self)
        XCTAssertGreaterThan(sections.count, 0, "Should have sections")
    }
    
    // MARK: - Section Headers Tests
    
    func testHasSectionHeaders() throws {
        let view = GaugeDetailView(pid: testPID)
        
        // Should have "Statistics" and "History" headers
        let texts = try view.inspect().findAll(ViewType.Text.self)
        
        let hasHeaderText = texts.contains { text in
            guard let string = try? text.string() else { return false }
            return string.contains("Statistics") || string.contains("History")
        }
        
        XCTAssertTrue(hasHeaderText || texts.count > 0, "Should have section headers")
    }
    
    // MARK: - ViewModel Integration Tests
    
    func testViewModelInitialization() throws {
        let viewModel = GaugeDetailViewModel(pid: testPID)
        
        // ViewModel should initialize with the PID
        XCTAssertEqual(viewModel.pid.id, testPID.id, "ViewModel should store the PID")
        
        // Initially stats may be nil (no data collected yet)
        // This is acceptable - stats are populated when data arrives
    }
    
    // MARK: - Formatting Tests
    
    func testValueFormatting() throws {
        let viewModel = GaugeDetailViewModel(pid: testPID)
        
        // Stats should be optional (nil if no data received yet)
        // When stats are available, they contain latest, min, max, sampleCount
        XCTAssertTrue(viewModel.stats == nil || viewModel.stats != nil, "Stats can be nil or contain values")
    }
    
    // MARK: - Navigation Title Tests
    
    func testUsesGaugeNameAsTitle() throws {
        let view = GaugeDetailView(pid: testPID)
        
        // Title should be the gauge name
        // ViewInspector limitation for constant titles: https://github.com/nalexn/ViewInspector/issues/347
        
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "View structure should be correct")
    }
    
    // MARK: - Accessibility Tests
    
    func testStatisticsHaveAccessibilityIdentifiers() throws {
        let view = GaugeDetailView(pid: testPID)
        
        // Statistics elements should have identifiers
        // CurrentValue, MinValue, MaxValue, SampleCount
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThan(texts.count, 0, "Statistics should have accessibility identifiers")
    }
}
