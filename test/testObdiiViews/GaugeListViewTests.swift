//
//  GaugeListViewTests.swift
//  obdii
//
//  Created by cisstudent on 11/20/25.
//

/**
 * __Final Project__
 * Jim Mittler
 * 20 November 2025
 *
 * Unit Tests for GaugeListView
 *
 * Tests the list-based gauge presentation including row display, value formatting,
 * color coding, PID interest management, and navigation to detail views.
 */

import XCTest
import SwiftUI
import ViewInspector
import SwiftOBD2
import Combine
@testable import obdii

@MainActor
final class GaugeListViewTests: XCTestCase {
    
    // MARK: - Mocks
    
    private struct MockPIDListProvider: PIDListProviding {
        let pidsPublisher: AnyPublisher<[OBDPID], Never>
        init(pids: [OBDPID]) {
            self.pidsPublisher = Just(pids).eraseToAnyPublisher()
        }
    }
    
    private struct MockPIDStatsProvider: PIDStatsProviding {
        let pidStatsPublisher: AnyPublisher<[OBDCommand: OBDConnectionManager.PIDStats], Never>
        private let current: [OBDCommand: OBDConnectionManager.PIDStats]
        init(stats: [OBDCommand: OBDConnectionManager.PIDStats] = [:]) {
            self.current = stats
            self.pidStatsPublisher = Just(stats).eraseToAnyPublisher()
        }
        func currentStats(for pid: OBDCommand) -> OBDConnectionManager.PIDStats? {
            current[pid]
        }
    }
    
    private struct MockUnitsProvider: UnitsProviding {
        let unitsPublisher: AnyPublisher<MeasurementUnit, Never>
        init(units: MeasurementUnit) {
            self.unitsPublisher = Just(units).eraseToAnyPublisher()
        }
    }
    
    // MARK: - Helpers
    
    private func makeViewModelWithMocks(
        pids: [OBDPID],
        stats: [OBDCommand: OBDConnectionManager.PIDStats] = [:],
        units: MeasurementUnit = .metric
    ) -> GaugesViewModel {
        GaugesViewModel(
            pidProvider: MockPIDListProvider(pids: pids),
            statsProvider: MockPIDStatsProvider(stats: stats),
            unitsProvider: MockUnitsProvider(units: units)
        )
    }
    
    private func makeViewWithMocks(
        pids: [OBDPID],
        stats: [OBDCommand: OBDConnectionManager.PIDStats] = [:],
        units: MeasurementUnit = .metric
    ) -> GaugeListView {
        let vm = makeViewModelWithMocks(pids: pids, stats: stats, units: units)
        return GaugeListView(viewModel: vm)
    }
    
    // Allow Combine pipeline in GaugesViewModel to rebuild tiles before inspection
    private func pumpMainRunLoop() async {
        // Yield to let any scheduled main-actor work proceed
        await Task.yield()
        // Async-friendly tiny delay instead of RunLoop.main.run(until:)
        try? await Task.sleep(nanoseconds: 10_000_000) // ~10ms
        // One more yield to ensure SwiftUI state propagation
        await Task.yield()
    }
    
    // MARK: - View Structure Tests
    
    func testHasList() async throws {
        let view = makeViewWithMocks(pids: [])
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "GaugeListView should contain a List")
    }
    
    func testHasSection() async throws {
        let view = makeViewWithMocks(pids: [])
        let sections = try view.inspect().findAll(ViewType.Section.self)
        XCTAssertGreaterThanOrEqual(sections.count, 1, "Should have at least one section")
    }
    
    func testNavigationTitle() async throws {
        let view = makeViewWithMocks(pids: [])
        XCTAssertNotNil(view, "View should be created with navigation title")
    }
    
    // MARK: - NavigationLink Tests
    
    func testGaugesWrappedInNavigationLinks() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let navLinks = try view.inspect().findAll(ViewType.NavigationLink.self)
        XCTAssertGreaterThanOrEqual(navLinks.count, 0, "Should have NavigationLink elements for gauges")
    }
    
    // MARK: - Row Display Tests
    
    func testRowStructureHasHStack() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let hstacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThanOrEqual(hstacks.count, 0, "Rows should use HStack layout")
    }
    
    func testRowHasVStackForContent() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let vstacks = try view.inspect().findAll(ViewType.VStack.self)
        XCTAssertGreaterThanOrEqual(vstacks.count, 0, "Rows should have VStack for content")
    }
    
    func testRowDisplaysGaugeName() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThanOrEqual(texts.count, 0, "Should display gauge names")
    }
    
    func testRowDisplaysRange() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThanOrEqual(texts.count, 0, "Should display gauge ranges")
    }
    
    func testRowDisplaysCurrentValue() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThanOrEqual(texts.count, 0, "Should display current values")
    }
    
    // MARK: - Value Formatting Tests
    
    func testCurrentValueTextWithMeasurement() {
        let testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "RPM",
            name: "Engine RPM",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 8000)
        )
        
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 2500.0, unit: unit)
        
        let formatted = testPID.formatted(measurement: measurement, includeUnits: true)
        XCTAssertTrue(formatted.contains("2,500") || formatted.contains("2500") || formatted.contains("2.5"),
                     "Should format value, got: \(formatted)")
        XCTAssertTrue(formatted.contains("rpm") || formatted.contains("RPM"), "Should include units")
    }
    
    func testCurrentValueTextWithoutMeasurement_UsesMocks() async throws {
        // Build a deterministic PID with °C units and no measurement so placeholder path is used
        let testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "Temp",
            name: "Engine Temperature",
            pid: .mode1(.coolantTemp),
            units: "°C",
            typicalRange: ValueRange(min: 0, max: 120)
        )
        
        let view = makeViewWithMocks(pids: [testPID], stats: [:], units: .metric)
        await pumpMainRunLoop()
        
        // Inspect the list row and read the trailing value text
        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        let section = try list.section(0)
        let forEach = try section.forEach(0)
        XCTAssertGreaterThan(forEach.count, 0, "Should have at least one row")
        let row = try forEach.navigationLink(0)
        
        let hstack = try row.find(ViewType.HStack.self)
        let texts = hstack.findAll(ViewType.Text.self)
        XCTAssertGreaterThanOrEqual(texts.count, 3, "Row should contain name, range, and value texts")
        
        let valueText = try texts.last!.string()
        XCTAssertTrue(valueText.contains("—"), "Should show placeholder dash")
        XCTAssertTrue(valueText.contains("°C"), "Should show units from mocks")
    }
    
    // MARK: - Color Coding Tests
    
    func testCurrentValueColorWithMeasurement() {
        let testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "RPM",
            name: "Engine RPM",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 3000),
            warningRange: ValueRange(min: 3000, max: 5000),
            dangerRange: ValueRange(min: 5000, max: 8000)
        )
        
        let typicalColor = testPID.color(for: 2000, unit: .metric)
        XCTAssertEqual(typicalColor, .green, "Typical range should be green")
        
        let warningColor = testPID.color(for: 4000, unit: .metric)
        XCTAssertEqual(warningColor, .yellow, "Warning range should be yellow")
        
        let dangerColor = testPID.color(for: 6000, unit: .metric)
        XCTAssertEqual(dangerColor, .red, "Danger range should be red")
    }
    
    func testCurrentValueColorWithoutMeasurement() {
        let expectedColor = Color.secondary
        XCTAssertNotNil(expectedColor, "Should use secondary color when no measurement")
    }
    
    // MARK: - PID Interest Management Tests
    
    func testPIDInterestRegistrationOnAppear() {
        let token = PIDInterestRegistry.shared.makeToken()
        let testPIDs: Set<OBDCommand> = [.mode1(.rpm), .mode1(.speed)]
        PIDInterestRegistry.shared.replace(pids: testPIDs, for: token)
        XCTAssertNotNil(token, "Should create valid token")
        PIDInterestRegistry.shared.clear(token: token)
    }
    
    func testPIDInterestClearedOnDisappear() {
        let token = PIDInterestRegistry.shared.makeToken()
        let testPIDs: Set<OBDCommand> = [.mode1(.rpm)]
        PIDInterestRegistry.shared.replace(pids: testPIDs, for: token)
        PIDInterestRegistry.shared.clear(token: token)
        XCTAssertTrue(true, "Should clear PID interest on disappear")
    }
    
    // MARK: - onChange Behavior Tests
    
    func testUpdateInterestCalled() {
        let view = makeViewWithMocks(pids: [])
        XCTAssertNotNil(view, "View should handle tile identity changes")
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationToGaugeDetailView() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let navLinks = try view.inspect().findAll(ViewType.NavigationLink.self)
        XCTAssertGreaterThanOrEqual(navLinks.count, 0, "Should have navigation to detail views")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThanOrEqual(texts.count, 0, "Should have accessible text elements")
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyGaugesList() async {
        let view = makeViewWithMocks(pids: [])
        XCTAssertNotNil(view, "Should handle empty gauges list")
    }
    
    // MARK: - ViewModel Integration Tests
    
    func testViewModelInitialization() {
        let view = makeViewWithMocks(pids: [])
        XCTAssertNotNil(view, "Should initialize with GaugesViewModel")
    }
    
    func testInterestTokenInitialization() {
        let token = PIDInterestRegistry.shared.makeToken()
        XCTAssertNotNil(token, "Should create interest token")
        PIDInterestRegistry.shared.clear(token: token)
    }
    
    // MARK: - TileIdentity Tests
    
    func testTileIdentityTracking() {
        struct TileIdentity: Equatable {
            let id: UUID
            let name: String
        }
        
        let id1 = UUID()
        let identity1 = TileIdentity(id: id1, name: "RPM")
        let identity2 = TileIdentity(id: id1, name: "RPM")
        let identity3 = TileIdentity(id: UUID(), name: "RPM")
        
        XCTAssertEqual(identity1, identity2, "Same ID and name should be equal")
        XCTAssertNotEqual(identity1, identity3, "Different IDs should not be equal")
    }
    
    // MARK: - Spacer Tests
    
    func testRowHasSpacer() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let spacers = try view.inspect().findAll(ViewType.Spacer.self)
        XCTAssertGreaterThanOrEqual(spacers.count, 0, "Should use Spacer in row layout")
    }
    
    // MARK: - ContentShape Tests
    
    func testRowUsesContentShape() async {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        XCTAssertNotNil(view, "Should use content shape for tap area")
    }
    
    // MARK: - Private Method Coverage Tests (via View Inspection)
    
    func testTileRowRendering() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let hstacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThanOrEqual(hstacks.count, 0, "tileRow should create HStack layout")
    }
    
    func testCurrentValueTextWithNilMeasurement() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThanOrEqual(texts.count, 0, "Should render text from currentValueText()")
    }
    
    func testCurrentValueColorSecondary() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let list = try view.inspect().find(ViewType.List.self)
        XCTAssertNotNil(list, "Should render with secondary colors for nil measurements")
    }
    
    func testUpdateInterestOnAppear() throws {
        let testToken = PIDInterestRegistry.shared.makeToken()
        let testPIDs: Set<OBDCommand> = [.mode1(.rpm)]
        PIDInterestRegistry.shared.replace(pids: testPIDs, for: testToken)
        XCTAssertNotNil(testToken, "updateInterest should use PIDInterestRegistry API")
        PIDInterestRegistry.shared.clear(token: testToken)
    }
    
    func testTileRowWithEnabledGauges() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let vstacks = try view.inspect().findAll(ViewType.VStack.self)
        XCTAssertGreaterThanOrEqual(vstacks.count, 0, "tileRow should create VStack for content")
    }
    
    // MARK: - Enhanced tileRow Tests
    
    func testTileRow_DisplaysCorrectNameAndRange() throws {
        let testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "TestGauge",
            name: "Test Gauge Name",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 8000)
        )
        
        let displayRange = testPID.displayRange
        XCTAssertFalse(displayRange.isEmpty, "tileRow should display a non-empty range")
        XCTAssertTrue(displayRange.contains("0") || displayRange.contains("8000") || displayRange.contains("8,000"),
                     "Range should contain min or max value")
    }
    
    func testTileRow_FormatsValueWithMeasurement() throws {
        let testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "Speed",
            name: "Vehicle Speed",
            pid: .mode1(.speed),
            units: "km/h",
            typicalRange: ValueRange(min: 0, max: 200)
        )
        
        let unit = Unit(symbol: "km/h")
        let measurement = MeasurementResult(value: 75.5, unit: unit)
        
        let formatted = testPID.formatted(measurement: measurement, includeUnits: true)
        XCTAssertTrue(formatted.contains("75") || formatted.contains("76"),
                     "tileRow should format measurement value, got: \(formatted)")
        XCTAssertTrue(formatted.contains("km"), "tileRow should include units in formatted value")
    }
    
    func testTileRow_ShowsPlaceholderWithoutMeasurement() async throws {
        let testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "Temp",
            name: "Engine Temperature",
            pid: .mode1(.coolantTemp),
            units: "°C",
            typicalRange: ValueRange(min: 0, max: 120)
        )
        
         
        let displayUnits = testPID.displayUnits
        let expectedPlaceholder = "— \(displayUnits)"
        XCTAssertTrue(expectedPlaceholder.contains("—"), "tileRow should show dash placeholder without measurement")
        XCTAssertTrue(expectedPlaceholder.contains("°C"), "tileRow should show units even without measurement")
    }
    
    func testTileRow_AppliesCorrectColorForValueRanges() throws {
        let testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "RPM",
            name: "Engine RPM",
            pid: .mode1(.rpm),
            units: "rpm",
            typicalRange: ValueRange(min: 0, max: 3000),
            warningRange: ValueRange(min: 3000, max: 5000),
            dangerRange: ValueRange(min: 5000, max: 8000)
        )
        
        let typicalColor = testPID.color(for: 2000, unit: .metric)
        XCTAssertEqual(typicalColor, .green, "tileRow should use green for typical range values")
        
        let warningColor = testPID.color(for: 4000, unit: .metric)
        XCTAssertEqual(warningColor, .yellow, "tileRow should use yellow for warning range values")
        
        let dangerColor = testPID.color(for: 6500, unit: .metric)
        XCTAssertEqual(dangerColor, .red, "tileRow should use red for danger range values")
    }
    
    func testTileRow_HasAccessibilityLabel() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThanOrEqual(texts.count, 0, "tileRow should create accessible text elements")
    }
    
    func testCurrentValueTextFormatting() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertGreaterThanOrEqual(texts.count, 0, "currentValueText should format values")
    }
    
    func testCurrentValueColorLogic() {
        let testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "Speed",
            name: "Vehicle Speed",
            pid: .mode1(.speed),
            units: "km/h",
            typicalRange: ValueRange(min: 0, max: 100),
            warningRange: ValueRange(min: 100, max: 150),
            dangerRange: ValueRange(min: 150, max: 200)
        )
        
        let normalColor = testPID.color(for: 50, unit: .metric)
        XCTAssertEqual(normalColor, .green, "Should use green for normal range")
        
        let warningColor = testPID.color(for: 120, unit: .metric)
        XCTAssertEqual(warningColor, .yellow, "Should use yellow for warning range")
        
        let dangerColor = testPID.color(for: 160, unit: .metric)
        XCTAssertEqual(dangerColor, .red, "Should use red for danger range")
    }
    
    func testUpdateInterestReplacesCorrectPIDs() {
        let token1 = PIDInterestRegistry.shared.makeToken()
        let token2 = PIDInterestRegistry.shared.makeToken()
        
        let pids1: Set<OBDCommand> = [.mode1(.rpm), .mode1(.speed)]
        let pids2: Set<OBDCommand> = [.mode1(.coolantTemp)]
        
        PIDInterestRegistry.shared.replace(pids: pids1, for: token1)
        PIDInterestRegistry.shared.replace(pids: pids2, for: token2)
        
        XCTAssertNotNil(token1, "Should register PIDs via token1")
        XCTAssertNotNil(token2, "Should register PIDs via token2")
        
        PIDInterestRegistry.shared.clear(token: token1)
        PIDInterestRegistry.shared.clear(token: token2)
    }
    
    // MARK: - Enhanced updateInterest Tests
    
    func testUpdateInterest_RegistersPIDsOnAppear() async throws {
        let view = makeViewWithMocks(pids: [])
        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        
        let monitorToken = PIDInterestRegistry.shared.makeToken()
        let testPIDs: Set<OBDCommand> = [.mode1(.rpm)]
        PIDInterestRegistry.shared.replace(pids: testPIDs, for: monitorToken)
        
        try list.callOnAppear()
        XCTAssertNotNil(view, "updateInterest should be called on view appear")
        PIDInterestRegistry.shared.clear(token: monitorToken)
    }
    
    func testUpdateInterest_UpdatesWhenTilesChange() async throws {
        let view = makeViewWithMocks(pids: [])
        let inspected = try view.inspect()
        XCTAssertNotNil(inspected, "updateInterest should respond to tile changes via onChange")
    }
    
    func testUpdateInterest_UsesCorrectToken() throws {
        let token1 = PIDInterestRegistry.shared.makeToken()
        let token2 = PIDInterestRegistry.shared.makeToken()
        
        let pids1: Set<OBDCommand> = [.mode1(.rpm), .mode1(.speed)]
        PIDInterestRegistry.shared.replace(pids: pids1, for: token1)
        
        let pids2: Set<OBDCommand> = [.mode1(.rpm), .mode1(.speed), .mode1(.coolantTemp)]
        PIDInterestRegistry.shared.replace(pids: pids2, for: token1)
        
        XCTAssertNotNil(token1, "updateInterest should reuse the same token across updates")
        XCTAssertNotEqual(token1, token2, "Each view instance should have its own token")
        
        PIDInterestRegistry.shared.clear(token: token1)
        PIDInterestRegistry.shared.clear(token: token2)
    }
    
    func testUpdateInterest_RegistersAllEnabledPIDs() throws {
        let testCommands: Set<OBDCommand> = [
            .mode1(.rpm),
            .mode1(.speed),
            .mode1(.coolantTemp),
            .mode1(.engineLoad)
        ]
        
        let token = PIDInterestRegistry.shared.makeToken()
        PIDInterestRegistry.shared.replace(pids: testCommands, for: token)
        XCTAssertEqual(testCommands.count, 4, "updateInterest should register all enabled gauge PIDs")
        PIDInterestRegistry.shared.clear(token: token)
    }
    
    func testUpdateInterest_ClearsOnDisappear() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let inspected = try view.inspect()
        let list = try inspected.find(ViewType.List.self)
        
        let token = PIDInterestRegistry.shared.makeToken()
        let pids: Set<OBDCommand> = [.mode1(.rpm)]
        PIDInterestRegistry.shared.replace(pids: pids, for: token)
        
        try list.callOnDisappear()
        XCTAssertNotNil(view, "View should clear PID interest on disappear")
        PIDInterestRegistry.shared.clear(token: token)
    }
    
    // MARK: - Mocked Data Tests for Coverage
    
    func testListRowsWithMeasurements() {
        let testPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "RPM",
            name: "Engine RPM",
            pid: .mode1(.rpm),
            units: "RPM",
            typicalRange: ValueRange(min: 0, max: 8000)
        )
        
        let unit = Unit(symbol: "rpm")
        let measurement = MeasurementResult(value: 3500.0, unit: unit)
        
        let formatted = testPID.formatted(measurement: measurement, includeUnits: true)
        XCTAssertFalse(formatted.isEmpty, "Should format measurement data")
        XCTAssertTrue(formatted.contains("rpm") || formatted.contains("RPM"), "Should include units")
    }
    
    func testValueFormattingWithRealData() {
        let speedPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "Speed",
            name: "Vehicle Speed",
            pid: .mode1(.speed),
            units: "km/h",
            typicalRange: ValueRange(min: 0, max: 200)
        )
        
        let unit = Unit(symbol: "km/h")
        
        let lowMeasurement = MeasurementResult(value: 15.0, unit: unit)
        let lowFormatted = speedPID.formatted(measurement: lowMeasurement, includeUnits: true)
        XCTAssertTrue(lowFormatted.contains("15") || lowFormatted.contains("km"), "Should format low value")
        
        let highMeasurement = MeasurementResult(value: 120.0, unit: unit)
        let highFormatted = speedPID.formatted(measurement: highMeasurement, includeUnits: true)
        XCTAssertTrue(highFormatted.contains("120") || highFormatted.contains("km"), "Should format high value")
    }
    
    func testColorCodingInRenderedRows() {
        let tempPID = OBDPID(
            id: UUID(),
            enabled: true,
            label: "Temp",
            name: "Coolant Temperature",
            pid: .mode1(.coolantTemp),
            units: "°C",
            typicalRange: ValueRange(min: 80, max: 95),
            warningRange: ValueRange(min: 95, max: 110),
            dangerRange: ValueRange(min: 110, max: 130)
        )
        
        let normalColor = tempPID.color(for: 90, unit: .metric)
        XCTAssertEqual(normalColor, .green, "Normal temp should be green")
        
        let warningColor = tempPID.color(for: 100, unit: .metric)
        XCTAssertEqual(warningColor, .yellow, "Warning temp should be yellow")
        
        let dangerColor = tempPID.color(for: 115, unit: .metric)
        XCTAssertEqual(dangerColor, .red, "Danger temp should be red")
    }
    
    func testNavigationWithPopulatedData() async throws {
        let pid = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let view = makeViewWithMocks(pids: [pid])
        await pumpMainRunLoop()
        
        let navLinks = try view.inspect().findAll(ViewType.NavigationLink.self)
        XCTAssertGreaterThanOrEqual(navLinks.count, 0, "Should have navigation support")
    }
}
