/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * Unit Tests for GaugesViewModel
 *
 * Tests tile generation from enabled gauges, TileIdentity helper,
 * and integration with PIDStore for gauge lists.
 */

import XCTest
import Combine
import SwiftOBD2
@testable import obdii

@MainActor
final class GaugesViewModelTests: XCTestCase {

    // MARK: - Mocks

    final class MockPIDProvider: PIDListProviding {
        let subject = CurrentValueSubject<[OBDPID], Never>([])
        var pidsPublisher: AnyPublisher<[OBDPID], Never> { subject.eraseToAnyPublisher() }
    }

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
        var unitsPublisher: AnyPublisher<MeasurementUnit, Never> { subject.eraseToAnyPublisher() }
    }

    // MARK: - Test State

    var viewModel: GaugesViewModel!
    var pidProvider: MockPIDProvider!
    var statsProvider: MockStatsProvider!
    var unitsProvider: MockUnitsProvider!

    override func setUp() async throws {
        pidProvider = MockPIDProvider()
        statsProvider = MockStatsProvider()
        unitsProvider = MockUnitsProvider()

        viewModel = GaugesViewModel(
            pidProvider: pidProvider,
            statsProvider: statsProvider,
            unitsProvider: unitsProvider
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        pidProvider = nil
        statsProvider = nil
        unitsProvider = nil
    }

    // Helper to build a simple gauge PID
    private func makeGaugePID(
        id: UUID = UUID(),
        enabled: Bool = true,
        label: String = "RPM",
        name: String = "Engine RPM",
        command: OBDCommand = .mode1(.rpm),
        units: String = "RPM"
    ) -> OBDPID {
        OBDPID(
            id: id,
            enabled: enabled,
            label: label,
            name: name,
            pid: command,
            formula: nil,
            units: units,
            typicalRange: nil,
            warningRange: nil,
            dangerRange: nil,
            notes: nil,
            kind: .gauge
        )
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertEqual(viewModel.tiles.count, 0, "Starts empty until publishers emit")
    }

    func testTilesMatchEnabledGauges() async throws {
        // Prepare two PIDs: one enabled gauge, one disabled gauge
        let pidEnabled = makeGaugePID(command: .mode1(.rpm))
        let pidDisabled = makeGaugePID(enabled: false, label: "Speed", name: "Vehicle Speed", command: .mode1(.speed))

        pidProvider.subject.send([pidEnabled, pidDisabled])

        // Stats not required for count; throttle is 1s so wait briefly
        try await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s

        XCTAssertEqual(viewModel.tiles.count, 1, "Tiles should include only enabled gauges")
        XCTAssertEqual(viewModel.tiles.first?.pid, pidEnabled)
    }

    // MARK: - Tile Tests

    func testTilesHaveValidPIDs() async throws {
        let pid1 = makeGaugePID(command: .mode1(.rpm))
        let pid2 = makeGaugePID(command: .mode1(.speed))
        pidProvider.subject.send([pid1, pid2])

        try await Task.sleep(nanoseconds: 1_200_000_000)

        for tile in viewModel.tiles {
            XCTAssertTrue(tile.pid.enabled, "Tile PIDs should be enabled")
            XCTAssertEqual(tile.pid.kind, .gauge, "Tile PIDs should be gauge type")
        }
    }

    func testTileIdentity() async throws {
        let pid = makeGaugePID()
        pidProvider.subject.send([pid])
        try await Task.sleep(nanoseconds: 1_200_000_000)

        for tile in viewModel.tiles {
            XCTAssertNotEqual(tile.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                              "Tile ID should be valid UUID")
        }
    }

    func testTilesHaveMeasurements() async throws {
        let pidRPM = makeGaugePID(command: .mode1(.rpm), units: "RPM")
        pidProvider.subject.send([pidRPM])

        // Provide a matching measurement for RPM
        let measurement = MeasurementResult(value: 1500.0, unit: Unit(symbol: "rpm"))
        let stats = OBDConnectionManager.PIDStats(pid: .mode1(.rpm), measurement: measurement)
        statsProvider.subject.send([.mode1(.rpm): stats])

        try await Task.sleep(nanoseconds: 1_200_000_000)

        // Now measurement should be present
        XCTAssertEqual(viewModel.tiles.count, 1)
        XCTAssertEqual(viewModel.tiles.first?.measurement?.value, 1500.0)
    }

    func testUnitChangeRebuildsTiles() async throws {
        let pidSpeed = makeGaugePID(command: .mode1(.speed), units: "km/h")
        pidProvider.subject.send([pidSpeed])

        let measurement = MeasurementResult(value: 100.0, unit: UnitSpeed.kilometersPerHour)
        let stats = OBDConnectionManager.PIDStats(pid: .mode1(.speed), measurement: measurement)
        statsProvider.subject.send([.mode1(.speed): stats])

        try await Task.sleep(nanoseconds: 1_200_000_000)
        let firstTiles = viewModel.tiles

        // Trigger unit change
        unitsProvider.subject.send(.imperial)

        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s (unit rebuild isn't throttled)

        let secondTiles = viewModel.tiles
        XCTAssertEqual(firstTiles.map(\.id), secondTiles.map(\.id), "Unit change should rebuild tiles with same identities")
        // Measurement object is still the same latest; conversion is handled by UI formatting, so just assert presence
        XCTAssertNotNil(secondTiles.first?.measurement)
    }

    func testTileIdentityHashable() async throws {
        let pids = [
            makeGaugePID(command: .mode1(.rpm)),
            makeGaugePID(command: .mode1(.speed)),
            makeGaugePID(command: .mode1(.coolantTemp), units: "°C")
        ]
        pidProvider.subject.send(pids)

        try await Task.sleep(nanoseconds: 1_200_000_000)

        let tiles = viewModel.tiles
        let uniqueIDs = Set(tiles.map { $0.id })
        XCTAssertEqual(tiles.count, uniqueIDs.count, "All tiles should have unique IDs")
    }
}
