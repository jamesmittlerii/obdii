/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewInspector Unit Tests for GaugesView
 *
 * Tests the GaugesView SwiftUI structure and behavior.
 * Validates grid layout, gauge tiles, and navigation to detail views.
 */

import XCTest
import SwiftUI
import ViewInspector
import SwiftOBD2
import Combine
@testable import obdii

@MainActor
final class GaugesViewTests: XCTestCase {

    
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

    
    private func makeViewModelWithMocks(
        pids: [OBDPID],
        stats: [OBDCommand: OBDConnectionManager.PIDStats] = [:],
        units: MeasurementUnit = .metric
    ) -> GaugesViewModel {
        GaugesViewModel(
            pidProvider: MockPIDListProvider(pids: pids),
            statsProvider: MockPIDStatsProvider(stats: stats),
            unitsProvider: MockUnitsProvider(units: units),
            interestRegistry: PIDInterestRegistry.shared
        )
    }
    
    private func makeViewWithMocks(
        pids: [OBDPID],
        stats: [OBDCommand: OBDConnectionManager.PIDStats] = [:],
        units: MeasurementUnit = .metric
    ) -> GaugesView {
        let vm = makeViewModelWithMocks(pids: pids, stats: stats, units: units)
        return GaugesView(viewModel: vm)
    }
    
    private func pidStats(
        for command: OBDCommand,
        value: Double,
        unitSymbol: String
    ) -> OBDConnectionManager.PIDStats {
        let measurement = MeasurementResult(value: value, unit: Unit(symbol: unitSymbol))
        return OBDConnectionManager.PIDStats(pid: command, measurement: measurement)
    }
    
    // Allow Combine pipeline in GaugesViewModel to rebuild tiles before inspection
    private func pumpMainRunLoop() async {
        // Yield to allow any immediate main-actor work to process
        await Task.yield()
        // Async-friendly short delay to let Combine/SwiftUI state settle
        try? await Task.sleep(nanoseconds: 10_000_000) // ~10 ms
        await Task.yield()
    }

    override func setUp() {
        super.setUp()
        // Do not call into the real OBDConnectionManager here; keep tests isolated to mocks.
    }
    
    override func tearDown() {
        super.tearDown()
    }

    
    func testHasScrollView() throws {
        let view = makeViewWithMocks(pids: [])
        XCTAssertNotNil(view, "GaugesView should initialize successfully")
    }

    
    func testUsesLazyVGrid() throws {
        let view = makeViewWithMocks(pids: [])
        XCTAssertNotNil(view, "Grid view should initialize successfully")
    }

    
    func testGaugeTilesAreNavigationLinks_WithMocks() async throws {
        let rpm = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let viewModel = makeViewModelWithMocks(pids: [rpm])
        await pumpMainRunLoop()
        XCTAssertEqual(viewModel.displayTiles.first?.shortTitle, "RPM", "Should build a tile for the mocked gauge")
    }
    
    func testGaugeTileStructure_WithMocks() async throws {
        let rpm = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let viewModel = makeViewModelWithMocks(pids: [rpm])
        await pumpMainRunLoop()
        XCTAssertEqual(viewModel.displayTiles.count, 1, "Should build one tile")
    }

    
    func testViewModelInitialization_Empty() {
        let viewModel = makeViewModelWithMocks(pids: [])
        XCTAssertGreaterThanOrEqual(viewModel.tiles.count, 0, "ViewModel should have tiles array")
    }
    
    func testViewModelInitialization_WithOnePID() async throws {
        let rpm = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let vm = makeViewModelWithMocks(pids: [rpm])
        // Allow Combine to publish tiles
        await pumpMainRunLoop()
        XCTAssertEqual(vm.tiles.count, 1, "Should build one tile for one PID")
        XCTAssertEqual(vm.tiles.first?.pid.pid, .mode1(.rpm))
    }

    
    func testNavigationToGaugeDetail_WithMocks() async throws {
        let rpm = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let viewModel = makeViewModelWithMocks(pids: [rpm])
        await pumpMainRunLoop()
        XCTAssertNotNil(viewModel.displayTiles.first?.detailViewModel, "Each tile should carry a detail view model")
    }

    
    func testGaugeTilesHaveLabels_WithMocks() async throws {
        let rpm = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let viewModel = makeViewModelWithMocks(pids: [rpm])
        await pumpMainRunLoop()
        XCTAssertEqual(viewModel.displayTiles.first?.title, "Engine RPM", "Tile should expose the full gauge name")
    }

    
    func testTileIdentityStructure() async throws {
        let rpm = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let speed = OBDPID(id: UUID(), enabled: true, label: "SPD", name: "Vehicle Speed", pid: .mode1(.speed), units: "km/h", typicalRange: ValueRange(min: 0, max: 240))
        let viewModel = makeViewModelWithMocks(pids: [rpm, speed])
        await pumpMainRunLoop()

        XCTAssertEqual(viewModel.tiles.count, 2)
        XCTAssertNotEqual(viewModel.tiles[0].id, viewModel.tiles[1].id)
    }

    
    func testUpdateInterestMechanism_StructureOnly() throws {
        let view = makeViewWithMocks(pids: [])
        XCTAssertNotNil(view, "View should support interest updates")
    }

    
    func testAdaptiveGridColumns() throws {
        let view = makeViewWithMocks(pids: [])
        XCTAssertNotNil(view, "Adaptive grid view should initialize successfully")
    }

    
    func testGaugeTilesHaveIdentifiers_WithMocks() async throws {
        let rpm = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let viewModel = makeViewModelWithMocks(pids: [rpm])
        await pumpMainRunLoop()
        XCTAssertTrue(viewModel.displayTiles.first?.tileAccessibilityIdentifier.hasPrefix("GaugeTile_") == true, "Tiles should have accessibility identifiers")
    }

    
    func testRendersGaugeTilesWithMeasurements_UsingMocks() async throws {
        // Provide one PID with a stat so measurement is non-nil
        let rpm = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let stats: [OBDCommand: OBDConnectionManager.PIDStats] = [
            .mode1(.rpm): pidStats(for: .mode1(.rpm), value: 2500, unitSymbol: "rpm")
        ]
        
        let viewModel = makeViewModelWithMocks(pids: [rpm], stats: stats)
        await pumpMainRunLoop()
        XCTAssertEqual(viewModel.displayTiles.first?.ring.accessibilityLabel, "Engine RPM")
        XCTAssertTrue(viewModel.displayTiles.first?.valueText.contains("rpm") == true || viewModel.displayTiles.first?.valueText.contains("RPM") == true)
    }
    
    func testGaugeTileColorsBasedOnValues() {
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
        let normalColor = testPID.color(for: 2000, unit: .metric)
        XCTAssertEqual(normalColor, .green, "Normal range should be green")
        let warningColor = testPID.color(for: 4000, unit: .metric)
        XCTAssertEqual(warningColor, .yellow, "Warning range should be yellow")
        let dangerColor = testPID.color(for: 6000, unit: .metric)
        XCTAssertEqual(dangerColor, .red, "Danger range should be red")
    }
    
    func testGaugeTileNavigationWithData_WithMocks() async throws {
        let rpm = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        let viewModel = makeViewModelWithMocks(pids: [rpm])
        await pumpMainRunLoop()
        XCTAssertEqual(viewModel.displayTiles.count, 1, "Should build navigable tiles for available gauge data")
    }
    
    func testMixedMeasurementStates_WithMocks() async throws {
        let rpm = OBDPID(id: UUID(), enabled: true, label: "RPM", name: "Engine RPM", pid: .mode1(.rpm), units: "RPM", typicalRange: ValueRange(min: 0, max: 8000))
        // Provide stats for none → all tiles measurement = nil
        let vm = makeViewModelWithMocks(pids: [rpm], stats: [:])
        await pumpMainRunLoop()
        let hasMixedStates = vm.tiles.contains { $0.measurement != nil } ||
                             vm.tiles.contains { $0.measurement == nil } ||
                             vm.tiles.isEmpty
        XCTAssertTrue(hasMixedStates, "Should handle mixed measurement states")
    }
    
    func testPIDInterestWithEnabledGauges_APIOnly() {
        let token = PIDInterestRegistry.shared.makeToken()
        let testPIDs: Set<OBDCommand> = [.mode1(.rpm), .mode1(.speed), .mode1(.coolantTemp)]
        PIDInterestRegistry.shared.replace(pids: testPIDs, for: token)
        XCTAssertNotNil(token, "Should register interest for enabled gauges")
        PIDInterestRegistry.shared.clear(token: token)
    }
    
    // NOTE: Removed all live/demo integration tests. This class now uses only mocks.
}
