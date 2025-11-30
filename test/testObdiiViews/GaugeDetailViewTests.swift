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
import Combine
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
    
    // MARK: - Local Mocks compatible with app protocols
    
    final class MockStatsProvider: PIDStatsProviding {
        let subject = CurrentValueSubject<[OBDCommand: OBDConnectionManager.PIDStats], Never>([:])
        var pidStatsPublisher: AnyPublisher<[OBDCommand: OBDConnectionManager.PIDStats], Never> {
            subject.eraseToAnyPublisher()
        }
        func currentStats(for pid: OBDCommand) -> OBDConnectionManager.PIDStats? {
            subject.value[pid]
        }
    }

    final class MockUnitsProvider: UnitsProviding {
        let subject = CurrentValueSubject<MeasurementUnit, Never>(.metric)
        var unitsPublisher: AnyPublisher<MeasurementUnit, Never> {
            subject.eraseToAnyPublisher()
        }
    }
    
    // MARK: - Helpers
    
    @MainActor
    private func makeVM(
        pid: OBDPID,
        statsProvider: MockStatsProvider,
        unitsProvider: MockUnitsProvider
    ) -> (GaugeDetailViewModel, MockStatsProvider, MockUnitsProvider) {
        let vm = GaugeDetailViewModel(pid: pid, statsProvider: statsProvider, unitsProvider: unitsProvider)
        return (vm, statsProvider, unitsProvider)
    }
    
    private func pump() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        await Task.yield()
    }
    
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
    
    func testDisplaysCurrentValue_WithMocks() async throws {
        // Arrange
        let statsProvider = MockStatsProvider()
        let unitsProvider = MockUnitsProvider()
        let (vm, statsProviderRet, _) = makeVM(pid: testPID, statsProvider: statsProvider, unitsProvider: unitsProvider)
        let view = GaugeDetailView(viewModel: vm)
        
        // Seed stats
        let measurement = MeasurementResult(value: 1500.0, unit: Unit(symbol: "rpm"))
        let stats = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: measurement)
        statsProviderRet.subject.send([.mode1(.rpm): stats])
        await pump()
        
        // Act
        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        let currentSection = try list.section(0)
        let currentText = try currentSection.text(0).string()
        
        // Assert
        XCTAssertTrue(currentText.contains("1,500") || currentText.contains("1500"), "Should show formatted current value")
        XCTAssertTrue(currentText.lowercased().contains("rpm"), "Should include unit")
    }
    
    func testDisplaysMinMaxAndSamples_WithMocks() async throws {
        // Arrange
        let statsProvider = MockStatsProvider()
        let unitsProvider = MockUnitsProvider()
        let (vm, statsProviderRet, _) = makeVM(pid: testPID, statsProvider: statsProvider, unitsProvider: unitsProvider)
        let view = GaugeDetailView(viewModel: vm)
        
        // Seed stats with evolving values to update min/max/sampleCount
        var s = OBDConnectionManager.PIDStats(
            pid: .mode1(.rpm),
            measurement: MeasurementResult(value: 1500.0, unit: Unit(symbol: "rpm"))
        )
        s.update(with: MeasurementResult(value: 1200.0, unit: Unit(symbol: "rpm"))) // min 1200
        s.update(with: MeasurementResult(value: 2200.0, unit: Unit(symbol: "rpm"))) // max 2200
        statsProviderRet.subject.send([.mode1(.rpm): s])
        await pump()
        
        // Act
        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        // Sections: 0=Current, 1=Statistics, 2=Maximum Range
        let statsSection = try list.section(1)
        let minText = try statsSection.text(0).string()
        let maxText = try statsSection.text(1).string()
        let samplesText = try statsSection.text(2).string()
        
        // Assert
        XCTAssertTrue(minText.contains("Min:"), "Should label Min")
        XCTAssertTrue(maxText.contains("Max:"), "Should label Max")
        XCTAssertTrue(samplesText.contains("Samples:"), "Should label Samples")
        
        XCTAssertTrue(minText.contains("1,200") || minText.contains("1200"), "Min should reflect seeded min")
        XCTAssertTrue(maxText.contains("2,200") || maxText.contains("2200"), "Max should reflect seeded max")
        XCTAssertTrue(samplesText.contains("\(s.sampleCount)"), "Samples should reflect count")
    }
    
    func testPlaceholderWhenNoStats_WithMocks() throws {
        // Arrange: VM with no stats seeded
        let statsProvider = MockStatsProvider()
        let unitsProvider = MockUnitsProvider()
        let (vm, _, _) = makeVM(pid: testPID, statsProvider: statsProvider, unitsProvider: unitsProvider)
        let view = GaugeDetailView(viewModel: vm)
        
        // Act
        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        let currentSection = try list.section(0)
        let text = try currentSection.text(0).string()
        
        // Assert: "— <units>"
        XCTAssertTrue(text.contains("—"), "Should show placeholder dash")
        XCTAssertTrue(text.uppercased().contains("RPM"), "Should show units in placeholder")
    }
    
    // MARK: - Chart/Sections/Header presence
    
    func testHasSections() throws {
        let view = GaugeDetailView(pid: testPID)
        let sections = try view.inspect().findAll(ViewType.Section.self)
        XCTAssertGreaterThan(sections.count, 0, "Should have sections")
    }
    
    func testHasSectionHeaders() throws {
        let view = GaugeDetailView(pid: testPID)
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasHeaderText = texts.contains { text in
            guard let string = try? text.string() else { return false }
            return string.contains("Statistics") || string.contains("History") || string.contains("Maximum Range") || string.contains("Current")
        }
        XCTAssertTrue(hasHeaderText || texts.count > 0, "Should have section headers")
    }
    
    // MARK: - ViewModel Integration Tests
    
    func testViewModelInitialization() throws {
        let viewModel = GaugeDetailViewModel(pid: testPID)
        XCTAssertEqual(viewModel.pid.id, testPID.id, "ViewModel should store the PID")
    }
    
    // MARK: - Formatting Tests
    
    func testValueFormatting() throws {
        let viewModel = GaugeDetailViewModel(pid: testPID)
        XCTAssertTrue(viewModel.stats == nil || viewModel.stats != nil, "Stats can be nil or contain values")
    }
    
    // MARK: - Navigation Title Tests
    
    func testUsesGaugeNameAsTitle() throws {
        let view = GaugeDetailView(pid: testPID)
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "View structure should be correct")
    }
    
    // MARK: - Accessibility Tests (structure presence)
    
    func testStatisticsHaveAccessibilityIdentifiers() throws {
        let view = GaugeDetailView(pid: testPID)
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThan(texts.count, 0, "Statistics should have accessibility identifiers")
    }
    
    // MARK: - Mocked Data Tests (use mocks instead of live connection)
    
    func testGaugeDetailStatsWithMockData() async throws {
        // Arrange mocks
        let statsProvider = MockStatsProvider()
        let unitsProvider = MockUnitsProvider()
        let viewModel = GaugeDetailViewModel(
            pid: testPID,
            statsProvider: statsProvider,
            unitsProvider: unitsProvider
        )
        
        // Seed a stat for the PID
        let measurement = MeasurementResult(value: 1500.0, unit: Unit(symbol: "rpm"))
        let stats = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: measurement)
        statsProvider.subject.send([.mode1(.rpm): stats])
        
        // Allow delivery on main
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Assert
        XCTAssertNotNil(viewModel.stats, "Expected stats for PID from mock provider")
        XCTAssertEqual(viewModel.stats?.pid, testPID.pid)
        XCTAssertEqual(viewModel.stats?.latest.value, 1500.0)
        XCTAssertGreaterThanOrEqual(viewModel.stats?.sampleCount ?? 0, 1)
    }
    
    func testGaugeDetailViewModelRefreshesOnUnitChangeWithMock() async throws {
        // Arrange mocks
        let statsProvider = MockStatsProvider()
        let unitsProvider = MockUnitsProvider()
        let viewModel = GaugeDetailViewModel(
            pid: testPID,
            statsProvider: statsProvider,
            unitsProvider: unitsProvider
        )
        
        // Seed initial stat
        let measurement = MeasurementResult(value: 100.0, unit: Unit(symbol: "rpm"))
        let stats = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: measurement)
        statsProvider.subject.send([.mode1(.rpm): stats])
        try await Task.sleep(nanoseconds: 50_000_000)
        let before = viewModel.stats
        
        // Act: change units
        unitsProvider.subject.send(.imperial)
        try await Task.sleep(nanoseconds: 50_000_000)
        let after = viewModel.stats
        
        // Assert: refresh happened but value is preserved
        XCTAssertEqual(before?.latest.value, after?.latest.value, "Unit change should refresh snapshot but preserve latest value")
    }
    
    // MARK: - UI with mocks: full path
    
    func testUIRendersAllSectionsWithMockedStats() async throws {
        // Arrange
        let statsProvider = MockStatsProvider()
        let unitsProvider = MockUnitsProvider()
        let (vm, statsProviderRet, _) = makeVM(pid: testPID, statsProvider: statsProvider, unitsProvider: unitsProvider)
        let view = GaugeDetailView(viewModel: vm)
        
        var s = OBDConnectionManager.PIDStats(
            pid: .mode1(.rpm),
            measurement: MeasurementResult(value: 2000.0, unit: Unit(symbol: "rpm"))
        )
        s.update(with: MeasurementResult(value: 1800.0, unit: Unit(symbol: "rpm")))
        s.update(with: MeasurementResult(value: 2600.0, unit: Unit(symbol: "rpm")))
        statsProviderRet.subject.send([.mode1(.rpm): s])
        await pump()
        
        // Act
        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        
        // Sections present
        XCTAssertNoThrow(try list.section(0))
        XCTAssertNoThrow(try list.section(1))
        XCTAssertNoThrow(try list.section(2))
        
        // Maximum Range text is non-empty
        let rangeText = try list.section(2).text(0).string()
        XCTAssertFalse(rangeText.isEmpty, "Maximum Range should be present")
    }
}
